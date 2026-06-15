"""Session manager for the efa/v2/ remote layout.

Orchestrates: prepare → add resources/announcements/releases → publish.
"""

from __future__ import annotations

import hashlib
import json
import os
import platform
import shutil
import subprocess

from pathlib import Path
from typing import TYPE_CHECKING

from data.lib.remote import fetch as _fetch_mod
from data.lib.remote.lifecycle import _BaseSessionManager
from data.lib.remote.models import AddAnnouncementsOp
from data.lib.remote.models import AddReleaseOp
from data.lib.remote.models import AddResourcesOp
from data.lib.remote.models import LockFile
from data.lib.remote.models import SessionStatus
from data.lib.remote.models import TodoList
from data.lib.remote.models import _generate_session_id
from data.lib.remote.models import _load_json_model
from data.lib.remote.models import _persist_json
from data.lib.remote.models import _session_path
from data.lib.remote.models import _utc_timestamp
from data.lib.remote.models import _validate_backend
from data.lib.remote.models import _write_json


if TYPE_CHECKING:
    from data.lib.remote.channel import Channel

_RESOURCE_ROOT = "efa/v2/"


# ---------------------------------------------------------------------------
# Path helpers
# ---------------------------------------------------------------------------


def _file_sha256(path: Path) -> str:
    hasher = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            hasher.update(chunk)
    return hasher.hexdigest()


# ---------------------------------------------------------------------------
# Session manager
# ---------------------------------------------------------------------------


class SessionManagerInvalidError(Exception):
    """Raised when no session is currently active."""


class SessionManagerCommittedError(Exception):
    """Raised when an operation is attempted on an already-committed session."""


class SessionManager(_BaseSessionManager):
    """Lifecycle manager for a single remote content preparation session
    targeting a configurable resource root."""

    CURRENT_SESSION_FILE = "current"
    _NOT_ACTIVE_ERROR = SessionManagerInvalidError
    _COMMITTED_ERROR = SessionManagerCommittedError

    @property
    def staged_dir(self) -> Path:
        return self._session_dir / "staged"

    @property
    def channel(self) -> str:
        todo = self._load_todo()
        return str(todo.lock_snapshot.get("channel", ""))

    @property
    def resource_root(self) -> str:
        lockfile = self._load_lockfile()
        if lockfile.resource_root:
            return lockfile.resource_root
        return _RESOURCE_ROOT

    # ---- status -------------------------------------------------------------

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

    # ---- factory: find latest committed ------------------------------------

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
            if entry.name in (cls.CURRENT_SESSION_FILE,):
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

    # ---- factory: prepare --------------------------------------------------

    @classmethod
    def prepare(
        cls,
        sessions_root: Path,
        *,
        backend: str,
        description: str,
        channel: Channel,
        resource_root: str = _RESOURCE_ROOT,
        origin_dir: Path | None = None,
        parent_session_id: str | None = None,
        mc_bin: str | None = None,
        endpoint: str | None = None,
        bucket: str | None = None,
        access_key: str | None = None,
        secret_key: str | None = None,
        alias_name: str | None = None,
    ) -> SessionManager:
        """Start a new session.

        Creates session directory, snapshots current remote state, and writes
        initial lockfile + todo.
        """
        session_id = _generate_session_id("session")
        session_dir = _session_path(sessions_root, session_id)

        if session_dir.exists():
            raise FileExistsError(f"Session directory already exists: {session_dir}")

        session_dir.mkdir(parents=True, exist_ok=False)

        lockfile = LockFile(
            session_id=session_id,
            timestamp=_utc_timestamp(),
            host=platform.node(),
            pid=os.getpid(),
            backend=_validate_backend(backend),
            origin_dir=str(origin_dir) if origin_dir is not None else None,
            resource_root=resource_root,
        )

        generation_id = _generate_session_id("gen")
        todo = TodoList(
            session_id=session_id,
            generation=generation_id,
            parent_session_id=parent_session_id,
            lock_snapshot={
                "backend": lockfile.backend,
                "timestamp": lockfile.timestamp,
                "host": lockfile.host,
                "pid": lockfile.pid,
                "description": description,
                "channel": channel.value,
            },
        )

        try:
            _persist_json(session_dir / "lockfile.json", lockfile)
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

            cls._write_current_session(sessions_root, session_id)

        except Exception:
            if session_dir.exists():
                shutil.rmtree(session_dir, ignore_errors=True)
            raise

        return cls(sessions_root, session_id, lockfile=lockfile, todo=todo)

    # ---- operations ---------------------------------------------------------

    def add_resources(
        self,
        *,
        server_catalogs: list[dict[str, object]],
        checkout_catalogs: list[dict[str, object]],
        description: str = "",
    ) -> None:
        """Register server and checkout catalogs.

        Each server catalog conforms to GenerationServer. Each checkout catalog
        conforms to GenerationCheckoutCatalog.

        Written under:
          manifest/.generations/<gen>/resources/servers/<id>.json
          manifest/.generations/<gen>/resources/checkouts/<hash>.json
        And flat-registry copies in:
          manifest/checkouts/<2c>/<hash>.json
        """
        self._ensure_not_committed()
        todo = self._load_todo()
        gen_id = todo.generation or "unknown"

        staged = self.staged_dir

        for sc in server_catalogs:
            server_id = sc.get("id")
            if not isinstance(server_id, str) or not server_id:
                raise ValueError("Server catalog missing non-empty string 'id' field")
            _validate_path_segment(server_id, "server_id")
            path = (
                staged
                / "manifest"
                / ".generations"
                / gen_id
                / "resources"
                / "servers"
                / f"{server_id}.json"
            )
            _write_json(path, sc)

        for cc in checkout_catalogs:
            checkout_id = cc.get("id")
            if not isinstance(checkout_id, str) or not checkout_id:
                raise ValueError("Checkout catalog missing non-empty string 'id' field")
            _validate_path_segment(checkout_id, "checkout_id")

            prefix = checkout_id[:2]
            per_gen_path = (
                staged
                / "manifest"
                / ".generations"
                / gen_id
                / "resources"
                / "checkouts"
                / f"{checkout_id}.json"
            )
            flat_path = staged / "manifest" / "checkouts" / prefix / f"{checkout_id}.json"

            _write_json(per_gen_path, cc)
            _write_json(flat_path, cc)

        catalog_path = staged / "manifest" / ".generations" / gen_id / "resources" / "catalog.json"
        _write_json(catalog_path, _build_resources_catalog(server_catalogs))

        from data.lib.config import DEV_CONFIGURATION

        schema_assets = DEV_CONFIGURATION.paths.schema_dir / "assets"
        staged_assets = staged / "resources" / "assets"

        for cc in checkout_catalogs:
            files_entries = cc.get("files", {})
            if not isinstance(files_entries, dict):
                continue
            for _file_path, info in files_entries.items():
                ph = info["pathHash"]
                ch = info["hash"]
                src = schema_assets / ph[:2] / ph / ch
                dst = staged_assets / ph[:2] / ph / ch
                if not dst.exists():
                    if not src.exists():
                        raise FileNotFoundError(
                            f"Asset not found in schema store: {src}\n"
                            f"  Run './x build data' to regenerate."
                        )
                    dst.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(src, dst)

        op = AddResourcesOp(
            generation_id=gen_id,
            description=description,
            checkout_catalogs=checkout_catalogs,
            server_catalogs=server_catalogs,
        )
        todo.operations.append(op)
        self._save_todo()

    def add_announcements(self, *, source_dir: Path) -> None:
        """Copy announcement files from source_dir into the session.

        source_dir must contain:
          announcements/
            files/<locale>/<id>       (markdown content)
            registry/<id>.json         (AnnouncementRecord)

        The announcement catalog (announcements/catalog.json) is regenerated
        from the registry files during merge.
        """
        self._ensure_not_committed()
        todo = self._load_todo()
        gen_id = todo.generation or "unknown"

        source = Path(source_dir)
        files_src = source / "announcements" / "files"
        registry_src = source / "announcements" / "registry"

        if not files_src.is_dir():
            raise FileNotFoundError(f"Announcement files directory not found: {files_src}")
        if not registry_src.is_dir():
            raise FileNotFoundError(f"Announcement registry directory not found: {registry_src}")

        # Validate content hashes for each registry entry
        for reg_file in sorted(registry_src.iterdir()):
            if reg_file.suffix != ".json":
                continue
            record = json.loads(reg_file.read_text(encoding="utf-8"))
            _validate_announcement_record(record, files_src, reg_file.stem)

        # Copy entire announcements subtree into staged
        staged_ann = self.staged_dir / "announcements"
        if staged_ann.exists():
            shutil.rmtree(staged_ann, ignore_errors=True)
        shutil.copytree(source / "announcements", staged_ann, dirs_exist_ok=True)

        op = AddAnnouncementsOp(
            generation_id=gen_id,
            source_dir=str(source),
        )
        todo.operations.append(op)
        self._save_todo()

    def add_release(
        self,
        *,
        version: str,
        apk_path: Path,
        announcement_id: str | None = None,
    ) -> None:
        """Register an APK release.

        Hashes the APK, writes it to the staged area, and records the release
        entry for inclusion in releases/catalog.json and
        resources/releases/<2c>/<hash>.
        """
        self._ensure_not_committed()
        todo = self._load_todo()
        gen_id = todo.generation or "unknown"

        apk_hash = _file_sha256(apk_path)
        prefix = apk_hash[:2]

        release_dir = self.staged_dir / "resources" / "releases" / prefix
        release_dir.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(apk_path, release_dir / apk_hash)

        op = AddReleaseOp(
            generation_id=gen_id,
            version=version,
            apk_hash=apk_hash,
            announcement_id=announcement_id,
        )
        todo.operations.append(op)
        self._save_todo()

    # ---- merge --------------------------------------------------------------

    def regenerate_merged(
        self,
        channel: Channel,
    ) -> Path:
        """Apply all operations to produce the merged tree.

        Returns the path to the merged root directory.
        """
        todo = self._load_todo()
        gen_id = todo.generation or "unknown"

        merged_root = self.merged_dir
        resource_root = self.resource_root
        channel_dir = merged_root / resource_root / channel.value

        # Clear merged
        if merged_root.exists():
            shutil.rmtree(merged_root, ignore_errors=True)
        merged_root.mkdir(parents=True, exist_ok=True)

        # Base layer: copy remote state
        remote_channel = self.remote_state_dir / channel.value
        if remote_channel.exists():
            shutil.copytree(remote_channel, channel_dir, dirs_exist_ok=True)

        # Ensure manifest directory
        (channel_dir / "manifest").mkdir(parents=True, exist_ok=True)

        # Overlay staged files
        staged = self.staged_dir
        if staged.exists():
            for item in staged.iterdir():
                dst = channel_dir / item.name
                if item.is_dir():
                    shutil.copytree(item, dst, dirs_exist_ok=True)
                else:
                    shutil.copy2(item, dst)

        # --- Build generation catalog ----------------------------------------
        gen_catalog: dict[str, object] = {
            "id": gen_id,
            "createdAt": _utc_timestamp(),
        }
        description = _extract_description_from_todo(todo)
        if description:
            gen_catalog["description"] = description

        gen_dir = channel_dir / "manifest" / ".generations" / gen_id
        gen_dir.mkdir(parents=True, exist_ok=True)
        _write_json(gen_dir / "catalog.json", gen_catalog)

        # --- Build resources catalog (if servers exist) ----------------------
        servers_dir = gen_dir / "resources" / "servers"
        if servers_dir.is_dir():
            server_ids = sorted(f.stem for f in servers_dir.iterdir() if f.suffix == ".json")
            if server_ids:
                _write_json(
                    gen_dir / "resources" / "catalog.json",
                    {"servers": server_ids},
                )

        # --- Build announcements catalog ------------------------------------
        registry_dir = channel_dir / "announcements" / "registry"
        if registry_dir.is_dir():
            ann_catalog = _build_announcements_catalog(registry_dir)
            (gen_dir / "announcements").mkdir(parents=True, exist_ok=True)
            _write_json(gen_dir / "announcements" / "catalog.json", ann_catalog)

        # --- Build releases catalog ------------------------------------------
        releases_dir = channel_dir / "resources" / "releases"
        if releases_dir.is_dir():
            release_catalog = _build_releases_catalog(todo)
            (gen_dir / "releases").mkdir(parents=True, exist_ok=True)
            _write_json(gen_dir / "releases" / "catalog.json", release_catalog)

        # --- Write manifest/index.json --------------------------------------
        index: dict[str, object] = {"manifestVersion": 1, "activatedGeneration": gen_id}
        remote_index_path = channel_dir / "manifest" / "index.json"
        if remote_index_path.is_file():
            existing = json.loads(remote_index_path.read_text(encoding="utf-8"))
            if isinstance(existing, dict):
                existing["activatedGeneration"] = gen_id
                index = existing
        _write_json(channel_dir / "manifest" / "index.json", index)

        # --- Write manifest/generations.json ---------------------------------
        generations: dict[str, object] = {}
        remote_gens_path = channel_dir / "manifest" / "generations.json"
        if remote_gens_path.is_file():
            existing = json.loads(remote_gens_path.read_text(encoding="utf-8"))
            if isinstance(existing, dict):
                generations.update(existing)
        generations[gen_id] = {
            "id": gen_id,
            "createdAt": _utc_timestamp(),
            "description": description,
        }
        _write_json(channel_dir / "manifest" / "generations.json", generations)

        return merged_root

    # ---- commit -------------------------------------------------------------

    def commit(
        self,
        channel: Channel,
    ) -> Path:
        """Regenerate merged tree and freeze the session locally.

        The merged tree is cached at ``merged/``.  The session is marked
        committed and its lockfile is removed so that downstream commands
        recognise it as immutable.
        """
        self._ensure_not_committed()
        merged_root = self.regenerate_merged(channel)
        todo = self._load_todo()
        todo.committed = True
        _persist_json(self.todo_path, todo)
        self.lockfile_path.unlink(missing_ok=True)
        return merged_root

    # ---- publish ------------------------------------------------------------

    def publish(
        self,
        channel: Channel,
        *,
        mc_bin: str,
        endpoint: str,
        bucket: str,
        access_key: str,
        secret_key: str,
        alias_name: str,
        squash: bool = True,
    ) -> None:
        """Upload the merged tree to S3/R2.

        Requires the session to already be committed.  By default
        (``squash=True``) rewrites the manifest so the remote sees a single
        squashed generation.  Pass ``squash=False`` to preserve individual
        generation entries (used by ``--all-generations``).
        """
        todo = self._load_todo()
        if not todo.committed:
            raise self._COMMITTED_ERROR(
                "Session must be committed before publishing.  Run `prepare commit` first."
            )

        merged_root = self.merged_dir
        if not merged_root.is_dir():
            raise FileNotFoundError(f"Merged tree does not exist: {merged_root}")

        resource_root = self.resource_root
        channel_dir = merged_root / resource_root / channel.value

        if squash:
            self._squash_merged(channel_dir)

        bucket_target = f"{alias_name}/{bucket}"
        remote_prefix = f"{resource_root}/{channel.value}"

        redacted = "<redacted>"
        _run_mc(
            [mc_bin, "alias", "set", alias_name, endpoint, access_key, secret_key, "--api", "s3v4"],
            [mc_bin, "alias", "set", alias_name, endpoint, redacted, redacted, "--api", "s3v4"],
            "PUBLISH ALIAS",
        )

        _run_mc(
            [
                mc_bin,
                "mirror",
                "--overwrite",
                str(channel_dir) + "/",
                f"{bucket_target}/{remote_prefix}/",
            ],
            [
                mc_bin,
                "mirror",
                "--overwrite",
                str(channel_dir) + "/",
                f"{bucket_target}/{remote_prefix}/",
            ],
            "PUBLISH MIRROR",
        )

    # ---- squash -------------------------------------------------------------

    @staticmethod
    def _squash_merged(channel_dir: Path) -> None:
        """Rewrite ``channel_dir`` manifest so only a single squashed generation
        exists.  Combines catalog data from every ``.generations/<id>/`` subdir
        into a new ``.generations/<squashed_id>/``."""
        gen_root = channel_dir / "manifest" / ".generations"
        if not gen_root.is_dir():
            return

        squashed_id = _generate_session_id("gen")
        squashed_dir = gen_root / squashed_id
        squashed_dir.mkdir(parents=True, exist_ok=True)

        # Collect all generation directories sorted by name (which is
        # chronological because ids embed timestamps).
        gen_dirs = sorted(
            [d for d in gen_root.iterdir() if d.is_dir()],
            key=lambda d: d.name,
        )

        combined_description = ""
        for gen_dir in gen_dirs:
            catalog_path = gen_dir / "catalog.json"
            if catalog_path.is_file():
                catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
                if isinstance(catalog.get("description"), str) and catalog["description"]:
                    if combined_description:
                        combined_description += "; "
                    combined_description += str(catalog["description"])

            # Merge resources, announcements, releases subdirs
            for child in gen_dir.iterdir():
                if child.name == "catalog.json":
                    continue
                dst = squashed_dir / child.name
                if child.is_dir():
                    shutil.copytree(child, dst, dirs_exist_ok=True)
                else:
                    shutil.copy2(child, dst)

        # Write squashed catalog
        squashed_catalog: dict[str, object] = {
            "id": squashed_id,
            "createdAt": _utc_timestamp(),
        }
        if combined_description:
            squashed_catalog["description"] = combined_description
        _write_json(squashed_dir / "catalog.json", squashed_catalog)

        # Remove old generation directories
        for gen_dir in gen_dirs:
            shutil.rmtree(gen_dir, ignore_errors=True)

        # Rewrite generations.json
        generations: dict[str, object] = {
            squashed_id: {
                "id": squashed_id,
                "createdAt": _utc_timestamp(),
            },
        }
        if combined_description:
            generations[squashed_id]["description"] = combined_description
        _write_json(channel_dir / "manifest" / "generations.json", generations)

        # Rewrite index.json
        index: dict[str, object] = {
            "manifestVersion": 1,
            "activatedGeneration": squashed_id,
        }
        _write_json(channel_dir / "manifest" / "index.json", index)

    # ---- chain helpers (classmethods) ---------------------------------------

    @classmethod
    def find_committed_chain(
        cls,
        sessions_root: Path,
    ) -> list[SessionManager]:
        """Return committed sessions in root→tip order (oldest→newest).

        Walks ``parent_session_id`` links backward from the tip (latest
        committed) to the root, then reverses so callers get oldest first.
        """
        if not sessions_root.is_dir():
            return []

        # Build an id → manager map for committed sessions
        committed: dict[str, SessionManager] = {}
        for entry in sorted(sessions_root.iterdir()):
            if not entry.is_dir():
                continue
            if entry.name in (cls.CURRENT_SESSION_FILE,):
                continue
            todo_path = entry / "todo.json"
            if not todo_path.is_file():
                continue
            try:
                todo = _load_json_model(todo_path, TodoList)
            except Exception:
                continue
            if not todo.committed:
                continue
            mgr = cls.from_session_id(sessions_root, entry.name)
            committed[entry.name] = mgr

        if not committed:
            return []

        # Find the tip: committed session with no child pointing to it
        parent_ids = {
            m._load_todo().parent_session_id
            for m in committed.values()
            if m._load_todo().parent_session_id is not None
        }
        tip_candidates = set(committed.keys()) - parent_ids
        if not tip_candidates:
            # Degenerate case: pick the latest by name
            tip_id = sorted(committed.keys(), reverse=True)[0]
        else:
            tip_id = sorted(tip_candidates, reverse=True)[0]

        # Walk backward from tip to root
        chain: list[SessionManager] = []
        current_id: str | None = tip_id
        visited: set[str] = set()
        while current_id and current_id not in visited:
            visited.add(current_id)
            mgr = committed.get(current_id)
            if mgr is None:
                break
            chain.append(mgr)
            current_id = mgr._load_todo().parent_session_id

        chain.reverse()
        return chain

    @classmethod
    def cleanup_committed_sessions(cls, sessions_root: Path) -> int:
        """Remove all committed session directories.

        Returns the number of sessions removed.
        """
        if not sessions_root.is_dir():
            return 0

        removed = 0
        for entry in sorted(sessions_root.iterdir()):
            if not entry.is_dir():
                continue
            if entry.name in (cls.CURRENT_SESSION_FILE,):
                continue
            todo_path = entry / "todo.json"
            if not todo_path.is_file():
                continue
            try:
                todo = _load_json_model(todo_path, TodoList)
            except Exception:
                continue
            if todo.committed:
                shutil.rmtree(entry, ignore_errors=True)
                removed += 1

        return removed


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------


def _validate_path_segment(name: str, label: str) -> None:
    if not name:
        raise ValueError(f"{label} must not be empty")
    if ".." in name or "/" in name or "\\" in name:
        raise ValueError(f"{label} {name!r} contains path separators or parent references")


def _build_resources_catalog(
    server_catalogs: list[dict[str, object]],
) -> dict[str, object]:
    servers: list[str] = []
    for sc in server_catalogs:
        server_id = sc.get("id")
        if isinstance(server_id, str):
            servers.append(server_id)
    return {"servers": sorted(servers)}


def _validate_announcement_record(
    record: dict[str, object],
    files_src: Path,
    record_id: str,
) -> None:
    content_hash = record.get("contentHash")
    if not isinstance(content_hash, str) or not content_hash:
        return  # skip validation if no hash

    actual = _compute_announcement_xor(files_src, record_id)
    if actual and actual != content_hash:
        raise ValueError(
            f"Announcement {record_id}: contentHash mismatch."
            f" Expected {content_hash}, computed {actual}"
        )


def _compute_announcement_xor(files_src: Path, record_id: str) -> str | None:
    """Compute XOR composite hash across all locale files for an announcement."""
    file_hashes: list[str] = []
    for locale_dir in sorted(files_src.iterdir()):
        if not locale_dir.is_dir():
            continue
        content_file = locale_dir / record_id
        if content_file.is_file():
            file_hashes.append(_file_sha256(content_file))

    if not file_hashes:
        return None

    # XOR all hashes byte-by-byte
    hash_bytes = bytes.fromhex(file_hashes[0])
    for fh in file_hashes[1:]:
        other = bytes.fromhex(fh)
        hash_bytes = bytes(a ^ b for a, b in zip(hash_bytes, other, strict=True))
    return hash_bytes.hex()


def _build_announcements_catalog(registry_dir: Path) -> dict[str, object]:
    entries: list[dict[str, object]] = []
    for reg_file in sorted(registry_dir.iterdir()):
        if reg_file.suffix != ".json":
            continue
        record = json.loads(reg_file.read_text(encoding="utf-8"))
        entry: dict[str, object] = {
            "id": reg_file.stem,
            "contentHash": record.get("contentHash", ""),
            "firstPublishedAt": record.get("firstPublishedAt", ""),
            "updatedAt": record.get("updatedAt", ""),
            "isVersionUpdate": record.get("isVersionUpdate", False),
        }
        version_range = record.get("versionRange")
        if version_range is not None:
            entry["versionRange"] = version_range
        entries.append(entry)
    return {"generatedAt": _utc_timestamp(), "entries": entries}


def _build_releases_catalog(todo: TodoList) -> dict[str, object]:
    entries: list[dict[str, object]] = []
    for op_data in todo.operations:
        if isinstance(op_data, AddReleaseOp):
            entries.append(
                {
                    "id": op_data.apk_hash,
                    "version": op_data.version,
                    "createdAt": _utc_timestamp(),
                    "versionUpdateAnnouncement": op_data.announcement_id or "",
                    "files": {"apk": op_data.apk_hash},
                }
            )
    return {"entries": entries}


def _extract_description_from_todo(todo: TodoList) -> str:
    """Extract generation description from operations, falling back to snapshot."""
    for op_data in todo.operations:
        if isinstance(op_data, AddResourcesOp) and op_data.description:
            return op_data.description
    snapshot = todo.lock_snapshot
    if isinstance(snapshot.get("description"), str) and snapshot["description"]:
        return str(snapshot["description"])
    return ""


def _run_mc(
    cmd: list[str],
    redacted_cmd: list[str],
    title: str,
    timeout: float = 600,
) -> None:
    try:
        out = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=timeout,
        )
    except subprocess.TimeoutExpired:
        raise OSError(f"{title} timed out after {timeout}s: {' '.join(redacted_cmd)}") from None
    if out.returncode != 0:
        msg = f"Failed to execute [{out.returncode}]: {' '.join(redacted_cmd)}"
        stderr = (out.stderr or "").strip()
        if stderr:
            msg += f"\n{stderr}"
        raise OSError(msg)
