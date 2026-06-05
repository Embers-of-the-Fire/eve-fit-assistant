"""Promotion session manager — orchestrates promotion from testing to stable.

Follows the same session lifecycle as ``SessionManager`` (prepare) but
operates on two channels instead of one.  Instead of staging local files,
promotion copies catalog entries from the testing channel into the stable
channel.
"""

from __future__ import annotations

import datetime
import json
import os
import platform
import shutil
import uuid

from typing import TYPE_CHECKING

from data.lib.remote import catalog as _catalog_mod
from data.lib.remote import fetch as _fetch_mod
from data.lib.remote.channel import Channel
from data.lib.remote.models import LockFile
from data.lib.remote.models import PromoteBundleOp
from data.lib.remote.models import PromoteDocumentOp
from data.lib.remote.models import TodoList
from data.lib.remote.models import _load_json_model
from data.lib.remote.models import _persist_json
from data.lib.remote.models import _session_path
from data.lib.remote.session import _generate_publish_id
from data.lib.remote.session import _generate_releases_json


if TYPE_CHECKING:
    from pathlib import Path

    from data.lib.remote.models import SessionStatus


CURRENT_SESSION_FILE = "current-promote"
_SOURCE_CHANNEL = Channel.TESTING
_TARGET_CHANNEL = Channel.STABLE


def _utc_now() -> str:
    return (
        datetime.datetime.now(datetime.UTC)
        .replace(microsecond=0)
        .isoformat()
        .replace("+00:00", "Z")
    )


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
    return f"promote-{stamp}-{short_uuid}"


class PromotionSessionNotActiveError(Exception):
    """Raised when no promotion session is currently active."""


class PromotionSessionCommittedError(Exception):
    """Raised when an operation is attempted on an already-committed session."""


class PromotionSessionManager:
    """Lifecycle manager for a promotion session (testing -> stable)."""

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
        self._lockfile: LockFile | None = lockfile
        self._todo: TodoList | None = todo

    @property
    def session_dir(self) -> Path:
        return self._session_dir

    @property
    def remote_state_dir(self) -> Path:
        return self._session_dir / "remote-state"

    @property
    def merged_dir(self) -> Path:
        return self._session_dir / "merged"

    @property
    def todo_path(self) -> Path:
        return self._session_dir / "todo.json"

    @property
    def lockfile_path(self) -> Path:
        return self._session_dir / "lockfile.json"

    # ---- factory: start ----------------------------------------------------

    @classmethod
    def start(
        cls,
        sessions_root: Path,
        *,
        backend: str,
        origin_dir: Path | None,
        resource_root: str,
        mc_bin: str | None = None,
        endpoint: str | None = None,
        bucket: str | None = None,
        access_key: str | None = None,
        secret_key: str | None = None,
        alias_name: str | None = None,
    ) -> PromotionSessionManager:
        from data.lib.remote.models import LockFile

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
            backend=backend,  # type: ignore[arg-type]
            origin_dir=str(origin_dir) if origin_dir is not None else None,
            resource_root=resource_root,
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
            (session_dir / "merged").mkdir(parents=True, exist_ok=True)

            remote_state_dir = session_dir / "remote-state"

            for ch in (_SOURCE_CHANNEL, _TARGET_CHANNEL):
                if origin_dir is not None:
                    _fetch_mod.fetch_remote_state_local(
                        origin_dir=origin_dir,
                        resource_root=resource_root,
                        channel=ch,
                        output_dir=remote_state_dir,
                    )
                elif backend in ("minio", "s3"):
                    if mc_bin is None:
                        from data.lib.utils import get_command

                        mc_bin = get_command("mc")
                    if endpoint is None or bucket is None or access_key is None:
                        raise ValueError(
                            "endpoint, bucket, access_key, and secret_key are required for"
                            f" backend {backend!r}"
                        )
                    _fetch_mod.fetch_remote_state_s3(
                        mc_bin=mc_bin,
                        endpoint=endpoint,
                        bucket=bucket,
                        access_key=access_key,
                        secret_key=secret_key or "",
                        alias_name=alias_name or "promote-remote",
                        resource_root=resource_root,
                        channel=ch,
                        output_dir=remote_state_dir,
                    )

            _write_current_session(sessions_root, session_id)

        except Exception:
            if session_dir.exists():
                shutil.rmtree(session_dir, ignore_errors=True)
            raise

        return cls(sessions_root, session_id, lockfile=lockfile, todo=todo)

    # ---- factory: from existing session ------------------------------------

    @classmethod
    def from_current(cls, sessions_root: Path) -> PromotionSessionManager:
        session_id = _read_current_session(sessions_root)
        if session_id is None:
            raise PromotionSessionNotActiveError(
                "No promotion session is active. Run `./x remote promote start`."
            )
        return cls.from_session_id(sessions_root, session_id)

    @classmethod
    def from_session_id(cls, sessions_root: Path, session_id: str) -> PromotionSessionManager:
        session_dir = _session_path(sessions_root, session_id)
        if not session_dir.is_dir():
            raise FileNotFoundError(f"Session directory does not exist: {session_dir}")

        from data.lib.remote.models import LockFile

        lockfile: LockFile | None = None
        lockfile_path = session_dir / "lockfile.json"
        if lockfile_path.is_file():
            lockfile = _load_json_model(lockfile_path, LockFile)

        todo: TodoList | None = None
        todo_path = session_dir / "todo.json"
        if todo_path.is_file():
            todo = _load_json_model(todo_path, TodoList)

        return cls(sessions_root, session_id, lockfile=lockfile, todo=todo)

    # ---- lock / todo helpers -----------------------------------------------

    def _ensure_not_committed(self) -> None:
        self._load_todo()
        if self._todo and self._todo.committed:
            raise PromotionSessionCommittedError(
                f"Session {self.session_id} has already been committed and is immutable."
            )

    def _load_todo(self) -> TodoList:
        if self._todo is None:
            self._todo = _load_json_model(self.todo_path, TodoList)
        return self._todo

    def _load_lockfile(self) -> LockFile:
        if self._lockfile is None:
            from data.lib.remote.models import LockFile as _LockFile

            if self.lockfile_path.is_file():
                self._lockfile = _load_json_model(self.lockfile_path, _LockFile)
            else:
                todo = self._load_todo()
                if todo.lock_snapshot:
                    self._lockfile = _LockFile(
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

    def _save_todo(self) -> None:
        if self._todo is not None:
            _persist_json(self.todo_path, self._todo)

    # ---- status ------------------------------------------------------------

    def status(self) -> SessionStatus:
        from data.lib.remote.models import SessionStatus

        todo = self._load_todo()
        return SessionStatus(
            session_id=self.session_id,
            backend="promote",
            timestamp="",
            host="",
            pid=0,
            operation_count=len(todo.operations),
            committed=todo.committed,
        )

    # ---- available items ---------------------------------------------------

    def available_items(
        self,
    ) -> dict[str, list[dict[str, object]]]:
        """Return entries on testing that are not yet on stable.

        Returns ``{"bundles": [...], "documents": [...]}`` where each item
        is the catalog entry dict from the testing channel's catalog.
        """
        _s_idx, _s_docs, _s_bundles = _fetch_mod.read_local_remote_state(
            self.remote_state_dir, _TARGET_CHANNEL
        )
        _t_idx, t_docs, t_bundles = _fetch_mod.read_local_remote_state(
            self.remote_state_dir, _SOURCE_CHANNEL
        )

        stable_doc_ids: set[str] = {
            e["id"]  # type: ignore[index]
            for e in t_docs.get("entries", [])
            if isinstance(e, dict) and "id" in e
        }
        stable_doc_ids &= {
            e["id"]  # type: ignore[index]
            for e in _s_docs.get("entries", [])
            if isinstance(e, dict) and "id" in e
        }

        stable_artifact_ids: set[str] = {
            a["artifactId"]  # type: ignore[index]
            for a in _s_bundles.get("artifacts", [])
            if isinstance(a, dict) and "artifactId" in a
        }

        docs: list[dict[str, object]] = [
            e
            for e in t_docs.get("entries", [])  # type: ignore[assignment]
            if isinstance(e, dict) and e.get("id") not in stable_doc_ids
        ]
        bundles: list[dict[str, object]] = [
            a
            for a in t_bundles.get("artifacts", [])  # type: ignore[assignment]
            if isinstance(a, dict) and a.get("artifactId") not in stable_artifact_ids
        ]

        return {"documents": docs, "bundles": bundles}

    def _get_testing_entry(self, artifact_id: str) -> dict[str, object]:
        _t_idx, _t_docs, t_bundles = _fetch_mod.read_local_remote_state(
            self.remote_state_dir, _SOURCE_CHANNEL
        )
        for a in t_bundles.get("artifacts", []):  # type: ignore[assignment]
            if isinstance(a, dict) and a.get("artifactId") == artifact_id:
                return a
        raise ValueError(f"Artifact {artifact_id!r} not found in testing catalog")

    def _get_testing_document(self, document_id: str) -> dict[str, object]:
        _t_idx, t_docs, _t_bundles = _fetch_mod.read_local_remote_state(
            self.remote_state_dir, _SOURCE_CHANNEL
        )
        for e in t_docs.get("entries", []):  # type: ignore[assignment]
            if isinstance(e, dict) and e.get("id") == document_id:
                return e
        raise ValueError(f"Document {document_id!r} not found in testing catalog")

    def _find_associated_increments(self, entry: dict[str, object]) -> list[dict[str, object]]:
        """Find incremental artifacts that share the same bundleId as the given entry."""
        bundle_id = entry.get("bundleId")
        if not isinstance(bundle_id, str):
            return []

        _t_idx, _t_docs, t_bundles = _fetch_mod.read_local_remote_state(
            self.remote_state_dir, _SOURCE_CHANNEL
        )
        increments: list[dict[str, object]] = []
        for a in t_bundles.get("artifacts", []):  # type: ignore[assignment]
            if (
                isinstance(a, dict)
                and a.get("bundleId") == bundle_id
                and a.get("variant") == "incremental"
                and a.get("artifactId") != entry.get("artifactId")
            ):
                increments.append(a)
        return increments

    # ---- add operations ----------------------------------------------------

    def add_bundle(
        self,
        artifact_id: str,
        *,
        no_increment: bool = False,
    ) -> None:
        """Stage a bundle for promotion from testing to stable.

        Associated incremental artifacts are included by default.
        Pass ``no_increment=True`` to skip them.
        """
        self._ensure_not_committed()
        todo = self._load_todo()

        for op in todo.operations:
            if isinstance(op, PromoteBundleOp) and op.artifact_id == artifact_id:
                raise ValueError(
                    f"Bundle {artifact_id!r} already staged in session {self.session_id}"
                )

        entry = dict(self._get_testing_entry(artifact_id))
        entry["generatedAt"] = _utc_now()
        bundle_id = entry.get("bundleId", "")
        if not isinstance(bundle_id, str):
            raise ValueError("Entry missing bundleId")

        op = PromoteBundleOp(
            artifact_id=artifact_id,
            bundle_id=bundle_id,
            variant=str(entry.get("variant", "full")),  # type: ignore[arg-type]
            fields=entry,
        )
        todo.operations.append(op)

        if not no_increment:
            increments = self._find_associated_increments(entry)
            for inc in increments:
                inc_artifact_id = inc.get("artifactId", "")
                if not isinstance(inc_artifact_id, str):
                    continue
                already_staged = any(
                    isinstance(o, PromoteBundleOp) and o.artifact_id == inc_artifact_id
                    for o in todo.operations
                )
                if already_staged:
                    continue
                inc_entry = dict(inc)
                inc_entry["generatedAt"] = _utc_now()
                inc_op = PromoteBundleOp(
                    artifact_id=inc_artifact_id,
                    bundle_id=bundle_id,
                    variant="incremental",
                    fields=inc_entry,
                )
                todo.operations.append(inc_op)

        self._save_todo()

    def add_document(self, document_id: str) -> None:
        """Stage a document for promotion from testing to stable."""
        self._ensure_not_committed()
        todo = self._load_todo()

        for op in todo.operations:
            if isinstance(op, PromoteDocumentOp) and op.document_id == document_id:
                raise ValueError(
                    f"Document {document_id!r} already staged in session {self.session_id}"
                )

        entry = dict(self._get_testing_document(document_id))
        entry["publishedAt"] = _utc_now()
        op = PromoteDocumentOp(document_id=document_id, fields=entry)
        todo.operations.append(op)
        self._save_todo()

    def add_all(self) -> None:
        """Stage all eligible items for promotion."""
        available = self.available_items()
        for entry in available.get("bundles", []):
            aid = entry.get("artifactId")
            if isinstance(aid, str):
                try:
                    self.add_bundle(aid)
                except ValueError:
                    continue
        for entry in available.get("documents", []):
            did = entry.get("id")
            if isinstance(did, str):
                try:
                    self.add_document(did)
                except ValueError:
                    continue

    # ---- remove ------------------------------------------------------------

    def remove(self, *, target_type: str, target_id: str) -> None:
        """Remove a staged promotion operation."""
        self._ensure_not_committed()
        todo = self._load_todo()
        if target_type == "document":
            todo.operations = [
                op
                for op in todo.operations
                if not (isinstance(op, PromoteDocumentOp) and op.document_id == target_id)
            ]
        elif target_type == "artifact":
            todo.operations = [
                op
                for op in todo.operations
                if not (isinstance(op, PromoteBundleOp) and op.artifact_id == target_id)
            ]
        self._save_todo()

    # ---- regenerate merged -------------------------------------------------

    def regenerate_merged(
        self,
        resource_root: str,
        *,
        generation: str | None = None,
    ) -> tuple[dict[str, object], dict[str, object], dict[str, object]]:
        """Apply staged promotions to the stable channel's catalogs."""
        index, docs, bundles = _fetch_mod.read_local_remote_state(
            self.remote_state_dir, _TARGET_CHANNEL
        )
        todo = self._load_todo()
        ops_raw = [op.model_dump(mode="json") for op in todo.operations]
        merged_index, merged_docs, merged_bundles = _catalog_mod.apply_operations_to_catalogs(
            index,
            docs,
            bundles,
            _TARGET_CHANNEL,
            ops_raw,  # type: ignore[arg-type]
            generation=generation,
        )

        base = self.merged_dir / resource_root
        ch = f"channels/{_TARGET_CHANNEL}"

        if generation is not None:
            gen_dir = base / ch / ".generations" / generation
            gen_dir.mkdir(parents=True, exist_ok=True)
            _write_json(gen_dir / "index.json", merged_index)
            (gen_dir / "documents").mkdir(parents=True, exist_ok=True)
            _write_json(gen_dir / "documents" / "catalog.json", merged_docs)
            (gen_dir / "bundles").mkdir(parents=True, exist_ok=True)
            _write_json(gen_dir / "bundles" / "catalog.json", merged_bundles)
            (gen_dir / "app").mkdir(parents=True, exist_ok=True)
            releases = _generate_releases_json(merged_docs, _TARGET_CHANNEL, generation)
            _write_json(gen_dir / "app" / "releases.json", releases)
        else:
            (base / ch).mkdir(parents=True, exist_ok=True)
            _write_json(base / ch / "index.json", merged_index)
            (base / ch / "documents").mkdir(parents=True, exist_ok=True)
            _write_json(base / ch / "documents" / "catalog.json", merged_docs)
            (base / ch / "bundles").mkdir(parents=True, exist_ok=True)
            _write_json(base / ch / "bundles" / "catalog.json", merged_bundles)

        return merged_index, merged_docs, merged_bundles

    # ---- diff --------------------------------------------------------------

    def diff(
        self,
        resource_root: str,
        *,
        generation: str | None = None,
    ) -> dict[str, object]:
        """Diff the current stable state against the promoted (merged) state."""
        if generation is None:
            generation = _generate_publish_id()
        r_idx, r_docs, r_bundles = _fetch_mod.read_local_remote_state(
            self.remote_state_dir, _TARGET_CHANNEL
        )
        m_idx, m_docs, m_bundles = self.regenerate_merged(resource_root, generation=generation)

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

    # ---- verify ------------------------------------------------------------

    def verify(
        self,
        resource_root: str | None = None,
        *,
        generation: str | None = None,
    ) -> list[str]:
        """Validate that promoted entries reference existing objects."""
        resolved_root = resource_root
        if resolved_root is None:
            if self._lockfile is not None and self._lockfile.resource_root:
                resolved_root = self._lockfile.resource_root
            else:
                resolved_root = "efa/v1"

        if generation is None:
            generation = _generate_publish_id()
        _m_idx, m_docs, m_bundles = self.regenerate_merged(resolved_root, generation=generation)

        errors: list[str] = []

        # Catalog-integrity checks (duplicate entries)
        merged_state: dict[str, object] = {
            "documents_catalog": m_docs,
            "bundles_catalog": m_bundles,
        }
        errors.extend(_catalog_mod.verify_merged_state(merged_state, {}))

        # File-existence checks against the origin (local backend only)
        if self._lockfile is not None and self._lockfile.backend == "local":
            origin_dir = self._lockfile.origin_dir
            if origin_dir:
                from pathlib import Path

                origin_base = Path(origin_dir) / resolved_root
                if not origin_base.is_dir():
                    return errors

                for entry in m_docs.get("entries", []):  # type: ignore[assignment]
                    if not isinstance(entry, dict):
                        continue
                    localizations = entry.get("localizations")
                    if isinstance(localizations, dict):
                        for _lang, loc in localizations.items():
                            if isinstance(loc, dict):
                                body_path = loc.get("bodyPath")
                                if isinstance(body_path, str):
                                    body_file = origin_base / body_path
                                    if not body_file.is_file():
                                        errors.append(f"Missing document body: {body_path}")

                for artifact in m_bundles.get("artifacts", []):  # type: ignore[assignment]
                    if not isinstance(artifact, dict):
                        continue
                    for path_key in ("artifactPath", "manifestPath"):
                        relative = artifact.get(path_key)
                        if isinstance(relative, str):
                            local = origin_base / relative
                            if not local.is_file():
                                errors.append(f"Missing {path_key}: {relative}")

        return errors

    # ---- commit ------------------------------------------------------------

    def commit(self) -> SessionStatus:
        """Mark the session as committed."""
        self._ensure_not_committed()
        lock = self._load_lockfile()
        todo = self._load_todo()
        generation = todo.generation or _generate_publish_id()
        self.regenerate_merged(lock.resource_root or "efa/v1", generation=generation)
        todo.committed = True
        todo.generation = generation
        _persist_json(self.todo_path, todo)
        self.lockfile_path.unlink(missing_ok=True)
        return self.status()

    # ---- abort -------------------------------------------------------------

    def abort(self) -> None:
        """Delete the session directory."""
        if self._session_dir.exists():
            shutil.rmtree(self._session_dir, ignore_errors=True)
        _clear_current_session(self.sessions_root, self.session_id)


# ---------------------------------------------------------------------------
# Session pointer helpers
# ---------------------------------------------------------------------------


def _current_session_path(sessions_root: Path) -> Path:
    return sessions_root / CURRENT_SESSION_FILE


def _read_current_session(sessions_root: Path) -> str | None:
    path = _current_session_path(sessions_root)
    if path.is_file():
        return path.read_text(encoding="utf-8").strip()
    return None


def _write_current_session(sessions_root: Path, session_id: str) -> None:
    _current_session_path(sessions_root).write_text(session_id, encoding="utf-8")


def _clear_current_session(sessions_root: Path, session_id: str) -> None:
    path = _current_session_path(sessions_root)
    if path.is_file() and path.read_text(encoding="utf-8").strip() == session_id:
        path.unlink(missing_ok=True)


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------


def _write_json(path: Path, data: dict[str, object]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(data, indent=4, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
