"""Session manager — the core orchestrator for the prepare oracle.

Exposes a ``SessionManager`` class that handles the full session lifecycle:
start, status, add (announcement / bundle), remove, diff, verify, commit, abort.
"""

from __future__ import annotations

import datetime
import hashlib
import json
import os
import platform
import shutil
import uuid
import zipfile

from pathlib import Path
from typing import TYPE_CHECKING

from data.lib.remote import catalog as _catalog_mod
from data.lib.remote import fetch as _fetch_mod
from data.lib.remote.models import AddAnnouncementOp
from data.lib.remote.models import AddBundleOp
from data.lib.remote.models import AddVersionOp
from data.lib.remote.models import LockFile
from data.lib.remote.models import RemoveOp
from data.lib.remote.models import SessionStatus
from data.lib.remote.models import TodoList
from data.lib.remote.models import _load_json_model
from data.lib.remote.models import _persist_json
from data.lib.remote.models import _session_path


if TYPE_CHECKING:
    from data.lib.remote.channel import Channel


# ---------------------------------------------------------------------------
# Path helpers
# ---------------------------------------------------------------------------

CURRENT_SESSION_FILE = "current"


def _generate_session_id() -> str:
    stamp = (
        datetime.datetime.now(datetime.UTC)
        .replace(microsecond=0)
        .isoformat()
        .replace("+00:00", "Z")
        .replace("-", "")
        .replace(":", "")
    )
    short_uuid = uuid.uuid4().hex[:8]
    return f"session-{stamp}-{short_uuid}"


def _file_sha256(path: Path) -> str:
    hasher = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            hasher.update(chunk)
    return hasher.hexdigest()


# ---------------------------------------------------------------------------
# Session manager
# ---------------------------------------------------------------------------


class SessionNotActiveError(Exception):
    """Raised when no session is currently active."""


class SessionCommittedError(Exception):
    """Raised when an operation is attempted on an already-committed session."""


class SessionManager:
    """Lifecycle manager for a single remote content preparation session."""

    def __init__(
        self,
        sessions_root: Path,
        session_id: str,
        *,
        lockfile: LockFile | None = None,
        todo: TodoList | None = None,
    ) -> None:
        self.sessions_root = sessions_root
        self.session_id = session_id
        self._session_dir = _session_path(sessions_root, session_id)
        self._locked = lockfile is not None
        self._lockfile: LockFile | None = lockfile
        self._todo: TodoList | None = todo

    # ---- properties --------------------------------------------------------

    @property
    def session_dir(self) -> Path:
        return self._session_dir

    @property
    def remote_state_dir(self) -> Path:
        return self._session_dir / "remote-state"

    @property
    def staged_dir(self) -> Path:
        return self._session_dir / "staged"

    @property
    def merged_dir(self) -> Path:
        return self._session_dir / "merged"

    @property
    def lockfile_path(self) -> Path:
        return self._session_dir / "lockfile.json"

    @property
    def todo_path(self) -> Path:
        return self._session_dir / "todo.json"

    # ---- factory: start ----------------------------------------------------

    @classmethod
    def start(
        cls,
        sessions_root: Path,
        *,
        backend: str,
        origin_dir: Path | None,
        resource_root: str,
        channel: Channel,
        # s3/minio params
        mc_bin: str | None = None,
        endpoint: str | None = None,
        bucket: str | None = None,
        access_key: str | None = None,
        secret_key: str | None = None,
        alias_name: str | None = None,
    ) -> SessionManager:
        session_id = _generate_session_id()
        session_dir = _session_path(sessions_root, session_id)

        if session_dir.exists():
            raise FileExistsError(f"Session directory already exists: {session_dir}")

        session_dir.mkdir(parents=True, exist_ok=False)

        lockfile = LockFile(
            session_id=session_id,
            timestamp=datetime.datetime.now(datetime.UTC)
            .replace(microsecond=0)
            .isoformat()
            .replace("+00:00", "Z"),
            host=platform.node(),
            pid=os.getpid(),
            backend=backend,
        )

        todo = TodoList(
            session_id=session_id,
            lock_snapshot={
                "backend": lockfile.backend,
                "timestamp": lockfile.timestamp,
                "host": lockfile.host,
                "pid": lockfile.pid,
            },
        )

        try:
            (session_dir / "lockfile.json").write_text(
                lockfile.model_dump_json(indent=4, by_alias=True) + "\n",
                encoding="utf-8",
            )
            _persist_json(session_dir / "todo.json", todo)
            (session_dir / "staged").mkdir(parents=True, exist_ok=True)
            (session_dir / "merged").mkdir(parents=True, exist_ok=True)

            remote_state_dir = session_dir / "remote-state"
            if origin_dir is not None:
                _fetch_mod.fetch_remote_state_local(
                    origin_dir=origin_dir,
                    resource_root=resource_root,
                    channel=channel,
                    output_dir=remote_state_dir,
                )
            elif backend in ("minio", "s3"):
                if mc_bin is None:
                    from data.lib.utils import get_command

                    mc_bin = get_command("mc")
                if endpoint is None or bucket is None or access_key is None:
                    raise ValueError(
                        "endpoint, bucket, and access_key are required for s3/minio fetch"
                    )
                _fetch_mod.fetch_remote_state_s3(
                    mc_bin=mc_bin,
                    endpoint=endpoint,
                    bucket=bucket,
                    access_key=access_key,
                    secret_key=secret_key or "",
                    alias_name=alias_name or f"efa-{backend}",
                    resource_root=resource_root,
                    channel=channel,
                    output_dir=remote_state_dir,
                )

            _write_current_session(sessions_root, session_id)

        except Exception:
            if session_dir.exists():
                shutil.rmtree(session_dir, ignore_errors=True)
            raise

        return cls(sessions_root, session_id, lockfile=lockfile, todo=todo)

    # ---- factory: from current session -------------------------------------

    @classmethod
    def from_current(
        cls,
        sessions_root: Path,
    ) -> SessionManager:
        session_id = _read_current_session(sessions_root)
        if session_id is None:
            raise SessionNotActiveError(
                "No session is currently active. Run `./x remote prepare start`."
            )
        return cls.from_session_id(sessions_root, session_id)

    @classmethod
    def from_session_id(
        cls,
        sessions_root: Path,
        session_id: str,
    ) -> SessionManager:
        session_dir = _session_path(sessions_root, session_id)
        if not session_dir.is_dir():
            raise FileNotFoundError(f"Session directory does not exist: {session_dir}")

        lockfile_path = session_dir / "lockfile.json"
        lockfile: LockFile | None = None
        if lockfile_path.is_file():
            lockfile = _load_json_model(lockfile_path, LockFile)

        todo_path = session_dir / "todo.json"
        todo: TodoList | None = None
        if todo_path.is_file():
            todo = _load_json_model(todo_path, TodoList)

        return cls(sessions_root, session_id, lockfile=lockfile, todo=todo)

    @classmethod
    def find_latest_committed(
        cls,
        sessions_root: Path,
    ) -> SessionManager:
        if not sessions_root.is_dir():
            raise FileNotFoundError(f"Sessions root does not exist: {sessions_root}")
        latest: tuple[str, SessionManager] | None = None
        for entry in sorted(sessions_root.iterdir(), reverse=True):
            if not entry.is_dir():
                continue
            if entry.name in (CURRENT_SESSION_FILE,):
                continue
            todo_path = entry / "todo.json"
            if not todo_path.is_file():
                continue
            try:
                todo = _load_json_model(todo_path, TodoList)
            except Exception:
                continue
            if todo.committed and (latest is None or entry.name > latest[0]):
                mgr = cls.from_session_id(sessions_root, entry.name)
                latest = (entry.name, mgr)
        if latest is None:
            raise FileNotFoundError("No committed session found.")
        return latest[1]

    # ---- lockfile helpers --------------------------------------------------

    def _ensure_not_committed(self) -> None:
        self._load_todo()
        if self._todo and self._todo.committed:
            raise SessionCommittedError(
                f"Session {self.session_id} has already been committed and is immutable."
            )

    def _load_todo(self) -> TodoList:
        if self._todo is None:
            self._todo = _load_json_model(self.todo_path, TodoList)
        return self._todo

    def _save_todo(self) -> None:
        if self._todo:
            _persist_json(self.todo_path, self._todo)

    def _load_lockfile(self) -> LockFile:
        if self._lockfile is None:
            if self.lockfile_path.is_file():
                self._lockfile = _load_json_model(self.lockfile_path, LockFile)
            else:
                todo = self._load_todo()
                if todo.lock_snapshot:
                    self._lockfile = LockFile(
                        session_id=self.session_id,
                        backend=str(todo.lock_snapshot["backend"]),
                        timestamp=str(todo.lock_snapshot["timestamp"]),
                        host=str(todo.lock_snapshot["host"]),
                        pid=int(todo.lock_snapshot["pid"]),
                    )
                else:
                    raise FileNotFoundError(
                        f"Lockfile not found and no snapshot in todo: {self.lockfile_path}"
                    )
        return self._lockfile

    # ---- operations --------------------------------------------------------

    def status(self) -> SessionStatus:
        lock = self._load_lockfile()
        todo = self._load_todo()
        return SessionStatus(
            session_id=self.session_id,
            backend=lock.backend,
            timestamp=lock.timestamp,
            host=lock.host,
            pid=lock.pid,
            operation_count=len(todo.operations),
            committed=todo.committed,
        )

    def add_announcement(
        self,
        *,
        zh_path: Path,
        en_path: Path,
        document_id: str,
        title_zh: str,
        title_en: str,
        summary_zh: str,
        summary_en: str,
        published_at: str,
        min_app_ver: str | None,
        startup: bool,
        tags: list[str],
        resource_root: str,
        channel: Channel,
    ) -> None:
        self._ensure_not_committed()
        todo = self._load_todo()

        ts_suffix = _utc_timestamp().replace("-", "").replace(":", "") + "Z"
        document_id = f"{document_id}-{ts_suffix}"

        for op in todo.operations:
            if isinstance(op, (AddAnnouncementOp, AddVersionOp)) and op.document_id == document_id:
                raise ValueError(
                    f"Document with document_id {document_id!r}"
                    f" already exists in session {self.session_id}"
                )

        _validate_path_segment(document_id, "document_id")

        zh_staged = f"documents/{document_id}_zh.md"
        en_staged = f"documents/{document_id}_en.md"
        zh_target = self.staged_dir / zh_staged
        en_target = self.staged_dir / en_staged

        zh_target.parent.mkdir(parents=True, exist_ok=True)
        en_target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(zh_path, zh_target)
        shutil.copyfile(en_path, en_target)

        zh_body_sha256 = _file_sha256(zh_target)
        zh_body_size = zh_target.stat().st_size
        en_body_sha256 = _file_sha256(en_target)
        en_body_size = en_target.stat().st_size

        entry: dict[str, object] = {
            "id": document_id,
            "kind": "announcement",
            "source": "remote",
            "publishedAt": published_at,
            "tags": tags,
            "startup": startup,
            "minAppVer": min_app_ver,
            "appVer": None,
            "localizations": {
                "en": {
                    "title": title_en,
                    "summary": summary_en,
                    "bodyPath": f"documents/body/en/{document_id}.md",
                    "bodySha256": en_body_sha256,
                    "bodySize": en_body_size,
                },
                "zh": {
                    "title": title_zh,
                    "summary": summary_zh,
                    "bodyPath": f"documents/body/zh/{document_id}.md",
                    "bodySha256": zh_body_sha256,
                    "bodySize": zh_body_size,
                },
            },
        }

        op = AddAnnouncementOp(
            document_id=document_id,
            fields=entry,
            staged_files={"zh": zh_staged, "en": en_staged},
        )
        todo.operations.append(op)
        self._save_todo()

    def add_version(
        self,
        *,
        zh_path: Path,
        en_path: Path,
        document_id: str | None = None,
        title_zh: str,
        title_en: str,
        summary_zh: str,
        summary_en: str,
        app_ver: str,
        published_at: str,
        tags: list[str],
        resource_root: str,
        channel: Channel,
    ) -> None:
        self._ensure_not_committed()
        todo = self._load_todo()

        if document_id is None:
            document_id = f"version-{app_ver}"
        _validate_path_segment(document_id, "document_id")

        for op in todo.operations:
            if isinstance(op, (AddAnnouncementOp, AddVersionOp)) and op.document_id == document_id:
                raise ValueError(
                    f"Document with document_id {document_id!r}"
                    f" already exists in session {self.session_id}"
                )

        zh_staged = f"documents/{document_id}_zh.md"
        en_staged = f"documents/{document_id}_en.md"
        zh_target = self.staged_dir / zh_staged
        en_target = self.staged_dir / en_staged

        zh_target.parent.mkdir(parents=True, exist_ok=True)
        en_target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(zh_path, zh_target)
        shutil.copyfile(en_path, en_target)

        zh_body_sha256 = _file_sha256(zh_target)
        zh_body_size = zh_target.stat().st_size
        en_body_sha256 = _file_sha256(en_target)
        en_body_size = en_target.stat().st_size

        entry: dict[str, object] = {
            "id": document_id,
            "kind": "version",
            "source": "remote",
            "publishedAt": published_at,
            "tags": tags,
            "startup": False,
            "minAppVer": None,
            "appVer": app_ver,
            "localizations": {
                "en": {
                    "title": title_en,
                    "summary": summary_en,
                    "bodyPath": f"documents/body/en/{document_id}.md",
                    "bodySha256": en_body_sha256,
                    "bodySize": en_body_size,
                },
                "zh": {
                    "title": title_zh,
                    "summary": summary_zh,
                    "bodyPath": f"documents/body/zh/{document_id}.md",
                    "bodySha256": zh_body_sha256,
                    "bodySize": zh_body_size,
                },
            },
        }

        op = AddVersionOp(
            document_id=document_id,
            fields=entry,
            staged_files={"zh": zh_staged, "en": en_staged},
        )
        todo.operations.append(op)
        self._save_todo()

    def add_bundle(
        self,
        *,
        full_path: Path,
        manifest_path: Path,
        artifact_id: str | None = None,
        resource_root: str,
        channel: Channel,
        increment_path: Path | None = None,
        increment_artifact_id: str | None = None,
    ) -> None:
        self._ensure_not_committed()
        todo = self._load_todo()

        full_descriptor = _read_zip_json(full_path, "descriptor.json")
        if full_descriptor.get("isIncremental") is True:
            raise ValueError(f"Full bundle archive must not be incremental: {full_path}")

        if artifact_id is None:
            artifact_id = _derive_artifact_id(full_descriptor, variant="full")

        _validate_path_segment(artifact_id, "artifact_id")

        for op in todo.operations:
            if isinstance(op, AddBundleOp) and op.artifact_id == artifact_id:
                raise ValueError(
                    f"Bundle with artifact_id {artifact_id!r}"
                    f" already exists in session {self.session_id}"
                )

        bundle_id = _require_string(full_descriptor, "bundleId", str(full_path))
        _validate_path_segment(bundle_id, "bundle_id (from descriptor.json)")

        staged_files: dict[str, str] = {}
        staged_files["zip"] = f"bundles/{artifact_id}.zip"
        staged_files["manifest"] = f"bundles/{artifact_id}.manifest.json"

        full_zip_target = self.staged_dir / staged_files["zip"]
        full_manifest_target = self.staged_dir / staged_files["manifest"]
        full_zip_target.parent.mkdir(parents=True, exist_ok=True)
        _copy_or_hardlink(full_path, full_zip_target)
        _copy_or_hardlink(manifest_path, full_manifest_target)

        full_entry = _bundle_artifact_entry(
            archive_path=full_path,
            manifest_path=manifest_path,
            artifact_id=artifact_id,
            variant="full",
            descriptor=full_descriptor,
            artifact_relative_path=f"bundles/{bundle_id}/{artifact_id}.zip",
            manifest_relative_path=f"bundles/{bundle_id}/{artifact_id}.manifest.json",
        )

        op = AddBundleOp(
            artifact_id=artifact_id,
            bundle_id=bundle_id,
            variant="full",
            fields=full_entry,
            staged_files=staged_files,
        )
        todo.operations.append(op)

        if increment_path is not None:
            inc_descriptor = _read_zip_json(increment_path, "descriptor.json")
            if inc_descriptor.get("isIncremental") is not True:
                raise ValueError(f"Incremental bundle must declare isIncremental: {increment_path}")
            inc_bundle_id = _require_string(inc_descriptor, "bundleId", str(increment_path))
            _validate_path_segment(inc_bundle_id, "inc_bundle_id (from descriptor.json)")
            if inc_bundle_id != bundle_id:
                raise ValueError(
                    f"Incremental bundle id does not match full: {inc_bundle_id} != {bundle_id}"
                )

            if increment_artifact_id is None:
                increment_artifact_id = _derive_artifact_id(inc_descriptor, variant="incremental")
            _validate_path_segment(increment_artifact_id, "increment_artifact_id")
            if increment_artifact_id == artifact_id:
                raise ValueError(
                    f"increment_artifact_id {increment_artifact_id!r}"
                    f" must differ from artifact_id {artifact_id!r}"
                    f" (staged paths would collide)"
                )
            for op in todo.operations:
                if isinstance(op, AddBundleOp) and op.artifact_id == increment_artifact_id:
                    raise ValueError(
                        f"Bundle with artifact_id {increment_artifact_id!r}"
                        f" already exists in session {self.session_id}"
                    )

            inc_staged: dict[str, str] = {}
            inc_staged["zip"] = f"bundles/{increment_artifact_id}.zip"
            inc_zip_target = self.staged_dir / inc_staged["zip"]
            inc_zip_target.parent.mkdir(parents=True, exist_ok=True)
            _copy_or_hardlink(increment_path, inc_zip_target)

            inc_entry = _bundle_artifact_entry(
                archive_path=increment_path,
                manifest_path=manifest_path,
                artifact_id=increment_artifact_id,
                variant="incremental",
                descriptor=inc_descriptor,
                artifact_relative_path=f"bundles/{bundle_id}/{increment_artifact_id}.zip",
                manifest_relative_path=f"bundles/{bundle_id}/{artifact_id}.manifest.json",
            )

            inc_op = AddBundleOp(
                artifact_id=increment_artifact_id,
                bundle_id=bundle_id,
                variant="incremental",
                fields=inc_entry,
                staged_files=inc_staged,
            )
            todo.operations.append(inc_op)

        self._save_todo()

    def remove(self, *, target_type: str, target_id: str) -> None:
        self._ensure_not_committed()
        todo = self._load_todo()
        op = RemoveOp(target_type=target_type, target_id=target_id)
        todo.operations.append(op)
        self._save_todo()

    def regenerate_merged(
        self,
        channel: Channel,
        resource_root: str,
        *,
        generation: str | None = None,
    ) -> tuple[dict[str, object], dict[str, object], dict[str, object]]:
        index, docs, bundles = _fetch_mod.read_local_remote_state(self.remote_state_dir, channel)
        todo = self._load_todo()
        ops_raw = [op.model_dump(mode="json") for op in todo.operations]
        merged_index, merged_docs, merged_bundles = _catalog_mod.apply_operations_to_catalogs(
            index,
            docs,
            bundles,
            channel,
            ops_raw,  # type: ignore[arg-type]
            generation=generation,
        )

        # Write merged output
        base = self.merged_dir / resource_root
        ch = f"channels/{channel}"

        if generation is not None:
            gen_dir = base / ch / ".generations" / generation
            gen_dir.mkdir(parents=True, exist_ok=True)
            _write_json(gen_dir / "index.json", merged_index)
            (gen_dir / "documents").mkdir(parents=True, exist_ok=True)
            _write_json(gen_dir / "documents" / "catalog.json", merged_docs)
            (gen_dir / "bundles").mkdir(parents=True, exist_ok=True)
            _write_json(gen_dir / "bundles" / "catalog.json", merged_bundles)
            (gen_dir / "app").mkdir(parents=True, exist_ok=True)
            releases = _generate_releases_json(merged_docs, channel, generation)
            _write_json(gen_dir / "app" / "releases.json", releases)
        else:
            (base / ch).mkdir(parents=True, exist_ok=True)
            _write_json(base / ch / "index.json", merged_index)
            (base / ch / "documents").mkdir(parents=True, exist_ok=True)
            _write_json(base / ch / "documents" / "catalog.json", merged_docs)
            (base / ch / "bundles").mkdir(parents=True, exist_ok=True)
            _write_json(base / ch / "bundles" / "catalog.json", merged_bundles)

        # Link document bodies and bundle files from staged -> merged
        _link_staged_to_merged(self.staged_dir, base, todo, channel)

        return merged_index, merged_docs, merged_bundles

    def diff(
        self,
        channel: Channel,
        resource_root: str,
        *,
        generation: str | None = None,
    ) -> dict[str, object]:
        if generation is None:
            generation = _generate_publish_id()
            todo = self._load_todo()
            todo.generation = generation
            _persist_json(self.todo_path, todo)
        r_idx, r_docs, r_bundles = _fetch_mod.read_local_remote_state(
            self.remote_state_dir, channel
        )
        m_idx, m_docs, m_bundles = self.regenerate_merged(
            channel, resource_root, generation=generation
        )

        remote_state: dict[str, object] = {
            "index": r_idx,
            "documents_catalog": r_docs,
            "bundles_catalog": r_bundles,
        }
        merged_state: dict[str, object] = {
            "index": m_idx,
            "documents_catalog": m_docs,
            "bundles_catalog": m_bundles,
        }
        return _catalog_mod.diff_catalogs(remote_state, merged_state)

    def verify(
        self,
        channel: Channel,
        *,
        backend: str | None = None,
        resource_root: str | None = None,
        endpoint: str | None = None,
        bucket: str | None = None,
        access_key: str | None = None,
        secret_key: str | None = None,
        alias_name: str | None = None,
        generation: str | None = None,
    ) -> list[str]:
        if generation is None:
            generation = _generate_publish_id()
            todo = self._load_todo()
            todo.generation = generation
            _persist_json(self.todo_path, todo)
        _, m_docs, m_bundles = self.regenerate_merged(
            channel, resource_root or "efa/v1", generation=generation
        )

        # Collect staged SHA256s
        staged_sha256s: dict[str, str] = {}
        for f in self.staged_dir.rglob("*"):
            if f.is_file():
                rel = str(f.relative_to(self.staged_dir))
                staged_sha256s[rel] = _file_sha256(f)

        merged_state: dict[str, object] = {
            "index": {},
            "documents_catalog": m_docs,
            "bundles_catalog": m_bundles,
        }
        errors = _catalog_mod.verify_merged_state(merged_state, staged_sha256s)

        # Drift check: re-fetch remote state and compare with snapshot
        if backend in ("minio", "s3"):
            drift_errors = self._check_drift(
                resource_root=resource_root or "",
                endpoint=endpoint or "",
                bucket=bucket or "",
                access_key=access_key or "",
                secret_key=secret_key or "",
                alias_name=alias_name or "",
                channel=channel,
            )
            errors.extend(drift_errors)

        return errors

    def _check_drift(
        self,
        *,
        resource_root: str,
        endpoint: str,
        bucket: str,
        access_key: str,
        secret_key: str,
        alias_name: str,
        channel: Channel,
    ) -> list[str]:
        from data.lib.utils import get_command

        mc_bin = get_command("mc")

        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            try:
                _fetch_mod.fetch_remote_state_s3(
                    mc_bin=mc_bin,
                    endpoint=endpoint,
                    bucket=bucket,
                    access_key=access_key,
                    secret_key=secret_key,
                    alias_name=alias_name,
                    resource_root=resource_root,
                    channel=channel,
                    output_dir=tmp_path,
                )
            except Exception as exc:
                return [f"Unable to check drift (fetch failed): {exc}"]

            r_idx, r_docs, r_bundles = _fetch_mod.read_local_remote_state(tmp_path, channel)
            s_idx, s_docs, s_bundles = _fetch_mod.read_local_remote_state(
                self.remote_state_dir, channel
            )

            errors: list[str] = []
            if r_idx != s_idx:
                errors.append("Remote index has changed since session start (drift detected)")
            if r_docs != s_docs:
                errors.append(
                    "Remote document catalog has changed since session start (drift detected)"
                )
            if r_bundles != s_bundles:
                errors.append(
                    "Remote bundle catalog has changed since session start (drift detected)"
                )
            return errors

    def commit(
        self,
        channel: Channel,
        resource_root: str,
    ) -> SessionStatus:
        self._ensure_not_committed()
        todo = self._load_todo()
        generation = todo.generation or _generate_publish_id()
        self.regenerate_merged(channel, resource_root, generation=generation)
        todo.committed = True
        todo.generation = generation
        _persist_json(self.todo_path, todo)
        self.lockfile_path.unlink(missing_ok=True)
        return self.status()

    def abort(self) -> None:
        if self._session_dir.exists():
            shutil.rmtree(self._session_dir, ignore_errors=True)
        _clear_current_session(self.sessions_root, self.session_id)


# ---------------------------------------------------------------------------
# Current session pointer helpers
# ---------------------------------------------------------------------------


def _current_session_path(sessions_root: Path) -> Path:
    return sessions_root / CURRENT_SESSION_FILE


def _read_current_session(sessions_root: Path) -> str | None:
    p = _current_session_path(sessions_root)
    if not p.is_file():
        return None
    session_id = p.read_text(encoding="utf-8").strip()
    if not session_id:
        return None
    if not _session_path(sessions_root, session_id).is_dir():
        return None
    return session_id


def _write_current_session(sessions_root: Path, session_id: str) -> None:
    sessions_root.mkdir(parents=True, exist_ok=True)
    _current_session_path(sessions_root).write_text(session_id + "\n", encoding="utf-8")


def _clear_current_session(sessions_root: Path, session_id: str) -> None:
    p = _current_session_path(sessions_root)
    current = _read_current_session(sessions_root)
    if current == session_id:
        p.unlink(missing_ok=True)


# ---------------------------------------------------------------------------
# Utility helpers
# ---------------------------------------------------------------------------


def _read_zip_json(zip_path: Path, member_name: str) -> dict[str, object]:
    with zipfile.ZipFile(zip_path) as archive, archive.open(member_name) as f:
        payload: dict[str, object] = json.loads(f.read().decode("utf-8"))
    return payload


def _require_string(d: dict[str, object], key: str, label: str) -> str:
    value = d.get(key)
    if not isinstance(value, str) or not value:
        raise ValueError(f"Descriptor is missing or has empty string field '{key}': {label}")
    return value


def _require_int(d: dict[str, object], key: str, label: str, *, default: int | None = None) -> int:
    value = d.get(key)
    if isinstance(value, int):
        return value
    if default is not None:
        return default
    raise ValueError(f"Descriptor is missing int field '{key}': {label}")


def _require_int_list(
    d: dict[str, object], key: str, label: str, *, default: list[int] | None = None
) -> list[int]:
    value = d.get(key)
    if isinstance(value, list) and all(isinstance(v, int) for v in value):
        return value
    if default is not None:
        return list(default)
    raise ValueError(f"Descriptor is missing int list field '{key}': {label}")


def _validate_path_segment(name: str, label: str) -> None:
    if not name:
        raise ValueError(f"{label} must not be empty")
    if ".." in name or "/" in name or "\\" in name:
        raise ValueError(f"{label} {name!r} contains path separators or parent references")


def _copy_or_hardlink(src: Path, dst: Path) -> None:
    if dst.exists():
        dst.unlink()
    try:
        os.link(src, dst)
    except OSError:
        shutil.copyfile(src, dst)


def _generate_publish_id() -> str:
    ts = _utc_timestamp().replace("-", "").replace(":", "") + "Z"
    return f"{ts}-{uuid.uuid4().hex}"


def _derive_artifact_id(descriptor: dict[str, object], *, variant: str) -> str:
    game_server = _require_string(descriptor, "gameServer", "descriptor").lower()
    game_build = _require_string(descriptor, "gameBuild", "descriptor")
    suffix = "-inc" if variant == "incremental" else ""
    return f"data-{game_server}-{game_build}{suffix}"


def _generate_releases_json(
    merged_docs: dict[str, object],
    channel: Channel,
    generation: str,
) -> dict[str, object]:
    releases: list[dict[str, object]] = []
    entries: object = merged_docs.get("entries", [])
    if isinstance(entries, list):
        for entry in entries:
            if not isinstance(entry, dict):
                continue
            if entry.get("kind") == "version" and entry.get("appVer"):
                releases.append(
                    {
                        "platform": "android",
                        "channel": channel.value,
                        "appVersion": entry["appVer"],
                        "buildNumber": None,
                        "publishedAt": entry.get("publishedAt"),
                        "minimumSupportedVersion": "0.0.1",
                        "releaseNoteDocumentId": entry["id"],
                        "downloadUrl": None,
                        "sha256": None,
                        "generation": generation,
                    }
                )
    return {"schemaVersion": 1, "releases": releases}


def _write_json(path: Path, payload: dict[str, object]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=4, ensure_ascii=False) + "\n", encoding="utf-8")


def _utc_timestamp() -> str:
    return (
        datetime.datetime.now(datetime.UTC)
        .replace(microsecond=0)
        .isoformat()
        .replace("+00:00", "Z")
    )


def _bundle_artifact_entry(
    *,
    archive_path: Path,
    manifest_path: Path,
    artifact_id: str,
    variant: str,
    descriptor: dict[str, object],
    artifact_relative_path: str,
    manifest_relative_path: str,
) -> dict[str, object]:
    manifest_hash = descriptor.get("manifestHash")
    if not isinstance(manifest_hash, str) or not manifest_hash:
        manifest_hash = _file_sha256(manifest_path)

    entry: dict[str, object] = {
        "artifactId": artifact_id,
        "bundleId": _require_string(descriptor, "bundleId", str(archive_path)),
        "variant": variant,
        "appVersion": _require_string(descriptor, "appVersion", str(archive_path)),
        "gameVersion": _require_string(descriptor, "gameVersion", str(archive_path)),
        "gameBuild": _require_string(descriptor, "gameBuild", str(archive_path)),
        "gameRegion": _require_string(descriptor, "gameRegion", str(archive_path)),
        "gameBranch": _require_string(descriptor, "gameBranch", str(archive_path)),
        "gameServer": _require_string(descriptor, "gameServer", str(archive_path)),
        "bundleSchemaVersion": _require_int(
            descriptor, "bundleSchemaVersion", str(archive_path), default=1
        ),
        "compatibleBundleSchemaVersions": _require_int_list(
            descriptor, "compatibleBundleSchemaVersions", str(archive_path), default=[1]
        ),
        "generatedAt": _utc_timestamp(),
        "artifactPath": artifact_relative_path,
        "artifactSize": archive_path.stat().st_size,
        "artifactSha256": _file_sha256(archive_path),
        "manifestPath": manifest_relative_path,
        "manifestHash": manifest_hash,
    }
    if variant == "incremental":
        entry["baseBundleId"] = _require_string(descriptor, "baseBundleId", str(archive_path))
        entry["baseManifestHash"] = _require_string(
            descriptor, "baseManifestHash", str(archive_path)
        )
    return entry


def _link_staged_to_merged(
    staged_dir: Path,
    merged_dir: Path,
    todo: TodoList,
    channel: Channel,
) -> None:
    """Create hardlinks from staged files into the merged directory structure."""
    for op in todo.operations:
        if isinstance(op, (AddAnnouncementOp, AddVersionOp)):
            for _lang, staged_rel in op.staged_files.items():
                src = staged_dir / staged_rel
                if not src.is_file():
                    continue
                dst = merged_dir / "documents" / "body" / _lang / f"{op.document_id}.md"
                dst.parent.mkdir(parents=True, exist_ok=True)
                _copy_or_hardlink(src, dst)
        elif isinstance(op, AddBundleOp):
            for _key, staged_rel in op.staged_files.items():
                src = staged_dir / staged_rel
                if not src.is_file():
                    continue
                dst = merged_dir / "bundles" / op.bundle_id / staged_rel.split("/", 1)[-1]
                dst.parent.mkdir(parents=True, exist_ok=True)
                _copy_or_hardlink(src, dst)
