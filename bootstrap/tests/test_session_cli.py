"""Integration tests for the session CLI workflow.

Exercises the full staged-generation-assembly lifecycle through the library
layer (SessionStore + SessionManager + SnapshotStore + GenerationStore +
ChannelHeadStore + Verifier).  The CLI commands in x.py are thin wrappers
around these same classes, so the integration behaviour tested here is
identical to what the CLI produces.
"""

from __future__ import annotations

import json
import shutil
import tempfile

from pathlib import Path

import click
import click.testing
import pytest

from bootstrap.cli.build import _build_release_merge
from bootstrap.cli.remote.session import _add_snapshot_by_file
from bootstrap.cli.remote.session import _build_generation_data
from bootstrap.cli.remote.session import _check_duplicate_server_ids
from bootstrap.cli.remote.session import _compute_diff
from bootstrap.cli.remote.session import _head_resource_snapshot_hashes
from bootstrap.cli.remote.session import _verify_staged
from bootstrap.cli.remote.session import register_remote_session
from bootstrap.remote import SessionManager
from bootstrap.remote.generation import utc_timestamp
from bootstrap.remote.hash import content_hash as _content_hash
from bootstrap.remote.hash import ident_hash
from bootstrap.remote.hash import verify_snapshot_hash as _verify_snapshot_hash
from bootstrap.remote.head import ChannelHeadStore
from bootstrap.remote.models import GenerationMetadata
from bootstrap.remote.models import GenerationPointer
from bootstrap.remote.models import GenerationResources
from bootstrap.remote.models import ReleaseSnapshotMetadata
from bootstrap.remote.models import ResourceSnapshotMetadata
from bootstrap.remote.models import ServerIndex
from bootstrap.remote.models import make_release_index
from bootstrap.remote.models import make_resource_index
from bootstrap.remote.paths import blob_path
from bootstrap.remote.session_model import Session
from bootstrap.remote.session_model import SessionExistsError
from bootstrap.remote.session_model import SessionStore
from bootstrap.remote.snapshot import SnapshotStore
from bootstrap.remote.verify import Issue


def _gen_ptr(snap_hash: str = "") -> GenerationPointer:
    p = GenerationPointer()
    p.schema_version = 1
    p.snapshot_hash = snap_hash
    return p


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture
def tmp_root() -> Path:
    d = tempfile.mkdtemp(prefix="efa-session-cli-")
    yield Path(d)
    shutil.rmtree(d, ignore_errors=True)


@pytest.fixture
def store(tmp_root: Path) -> SessionStore:
    return SessionStore(tmp_root)


@pytest.fixture
def mgr(tmp_root: Path) -> SessionManager:
    return SessionManager(tmp_root)


def _make_resource_snapshot(
    tmp_root: Path,
    server_id: str = "tranquility",
    game_build: str = "12345",
    game_version: str = "21.06",
    resource_count: int = 2,
    resources: list[tuple[str, str, int]] | None = None,
) -> str:
    snap_store = SnapshotStore(tmp_root)

    if resources is None:
        resources = [
            (f"resource://{server_id}/proto/ships.bin", "ab" * 32, 1000),
            (f"resource://{server_id}/proto/skills.bin", "cd" * 32, 2000),
        ]

    resolved_resources: list[tuple[str, str, int]] = []
    for rid, _chash, size in resources:
        ihash = ident_hash(rid)
        blob_content = (rid + str(size)).encode("utf-8").ljust(size, b"\x00")
        real_chash = _content_hash(blob_content)
        bpath = blob_path(tmp_root, ihash, real_chash)
        bpath.parent.mkdir(parents=True, exist_ok=True)
        bpath.write_bytes(blob_content)
        resolved_resources.append((rid, real_chash, size))

    meta = ResourceSnapshotMetadata(
        serverId=server_id,
        gameBuild=game_build,
        gameVersion=game_version,
        resourceCount=resource_count,
        createdAt="2026-06-15T00:00:00Z",
    )
    index = make_resource_index(resolved_resources)
    return snap_store.create_resource_snapshot(meta, index)


def _make_release_snapshot(
    tmp_root: Path,
    release_id: str = "rel-001",
    version: str = "1.0.0",
    offerings: list[str] | None = None,
) -> str:
    snap_store = SnapshotStore(tmp_root)
    if offerings is None:
        offerings = ["android"]

    meta = ReleaseSnapshotMetadata(
        versionMin="1.0.0",
        versionMax="2.0.0",
        offerings=offerings,
        releaseCount=1,
        createdAt="2026-06-15T00:00:00Z",
    )
    index = make_release_index(
        release_id=release_id,
        version=version,
        android={
            "general": {
                "identifier": f"release://{version}/android/general",
                "content_hash": "ab" * 32,
                "size": 12345,
            }
        },
    )
    return snap_store.create_release_snapshot(meta, index)


def _init_session(
    store: SessionStore,
    channel: str = "testing",
) -> Session:
    return store.init(channel=channel)


def _make_full_generation(
    mgr: SessionManager,
    tmp_root: Path,
    channel: str = "testing",
    server_ids: list[str] | None = None,
) -> tuple[str, str]:
    mgr.ensure_channel(channel)
    res_hash = _make_resource_snapshot(tmp_root)
    snap_store = mgr.snap_store
    meta_resource, _ = snap_store.load_resource_snapshot(res_hash)

    if server_ids is None:
        server_ids = [meta_resource.server_id]

    server_index = ServerIndex()
    server_index.schema_version = 1
    gen_resources = GenerationResources()
    gen_resources.schema_version = 1

    for sid in server_ids:
        entry = server_index.servers.add()
        entry.server_id = sid
        entry.name["en"] = sid
        entry.game_build = meta_resource.game_build
        entry.game_version = meta_resource.game_version

        gentry = gen_resources.entries.add()
        gentry.server_id = sid
        gentry.snapshot_hash = res_hash

    release_ptr = _gen_ptr()

    meta = GenerationMetadata(
        channel=channel,
        timestamp=utc_timestamp(),
        parent="",
        subject="",
    )
    gen_hash = mgr.create_generation(
        metadata=meta,
        server_index=server_index,
        resources=gen_resources,
        release_pointer=release_ptr,
    )
    mgr.push(channel, gen_hash)
    return gen_hash, res_hash


def _commit_from_session(
    store: SessionStore,
    mgr: SessionManager,
    tmp_root: Path,
    parent: str = "",
) -> str:
    """Build and create a generation from the current session's staged data.

    Returns the generation hash. Does NOT push the head or mark committed.
    Delegates accumulation to the production _build_generation_data helper.
    """
    session = store.load()
    snap_store = mgr.snap_store

    parent_gen = mgr.gen_store.load(parent) if parent else None

    server_index, gen_resources, release_ptr = _build_generation_data(
        snap_store=snap_store,
        staged_resources=session.staged.resources,
        staged_releases=session.staged.releases,
        parent_gen=parent_gen,
    )

    gen_meta = GenerationMetadata(
        channel=session.channel,
        timestamp=utc_timestamp(),
        parent=parent or "",
        subject="",
    )

    return mgr.create_generation(
        metadata=gen_meta,
        server_index=server_index,
        resources=gen_resources,
        release_pointer=release_ptr,
    )


# ===========================================================================
# 1. session init
# ===========================================================================


class TestSessionInit:
    def test_init_creates_session(self, store: SessionStore) -> None:
        _init_session(store)
        assert store.session_path.is_file()
        session = store.load()
        assert session.channel == "testing"
        assert session.committed is False
        assert session.schema_version == 1
        assert session.staged.resources == []
        assert session.staged.releases == []

    def test_init_overwrite_requires_force(self, store: SessionStore) -> None:
        _init_session(store)
        with pytest.raises(SessionExistsError, match="A session already exists"):
            store.init(channel="testing")

    def test_init_overwrite_with_force(self, store: SessionStore) -> None:
        _init_session(store)
        store.init(channel="stable", force_overwrite=True)
        session = store.load()
        assert session.channel == "stable"

    def test_init_overwrite_committed_with_force(self, store: SessionStore) -> None:
        _init_session(store)
        store.mark_committed()
        store.init(channel="stable", force_overwrite=True)
        session = store.load()
        assert session.channel == "stable"
        assert session.committed is False

    def test_init_invalid_channel(self, store: SessionStore) -> None:
        from pydantic import ValidationError

        with pytest.raises(ValidationError, match="Invalid channel"):
            store.init(channel="bogus")

    def test_init_valid_channels(self, store: SessionStore) -> None:
        for ch in ("testing", "stable"):
            store.init(channel=ch, force_overwrite=True)
            session = store.load()
            assert session.channel == ch


# ===========================================================================
# 2. session status
# ===========================================================================


class TestSessionStatus:
    def test_status_no_session(self, store: SessionStore) -> None:
        assert store.exists() is False

    def test_status_with_session(self, store: SessionStore) -> None:
        _init_session(store)
        assert store.exists() is True
        session = store.load()
        assert session.channel == "testing"
        assert session.committed is False

    def test_status_json_serializable(self, store: SessionStore) -> None:
        _init_session(store)
        session = store.load()
        data = json.loads(session.model_dump_json(by_alias=True))
        assert data["schemaVersion"] == 1
        assert data["channel"] == "testing"
        assert data["committed"] is False
        assert "staged" in data


# ===========================================================================
# 3. session discard
# ===========================================================================


class TestSessionDiscard:
    def test_discard_no_session(self, store: SessionStore) -> None:
        from bootstrap.remote import SessionManagerInvalidError

        with pytest.raises(SessionManagerInvalidError, match="No active session"):
            store.discard()

    def test_discard_removes_file(self, store: SessionStore) -> None:
        _init_session(store)
        assert store.session_path.is_file()
        store.discard()
        assert not store.session_path.is_file()

    def test_discard_committed_file_removed(self, store: SessionStore) -> None:
        """After mark_committed, the session file is removed. discard raises
        SessionManagerInvalidError because there is no active session."""
        from bootstrap.remote import SessionManagerInvalidError

        _init_session(store)
        store.mark_committed()
        assert not store.session_path.is_file()
        with pytest.raises(SessionManagerInvalidError, match="No active session"):
            store.discard()

    def test_discard_committed_with_force_raises_no_session(self, store: SessionStore) -> None:
        """After mark_committed, the session file is removed. discard(force=True)
        raises SessionManagerInvalidError because no session exists."""
        from bootstrap.remote import SessionManagerInvalidError

        _init_session(store)
        store.mark_committed()
        assert not store.session_path.is_file()
        with pytest.raises(SessionManagerInvalidError, match="No active session"):
            store.discard(force=True)


# ===========================================================================
# 4. session add
# ===========================================================================


class TestSessionAdd:
    def test_add_by_hash_resource(self, store: SessionStore, tmp_root: Path) -> None:
        _init_session(store)
        res_hash = _make_resource_snapshot(tmp_root)
        store.add_snapshot("resource", res_hash)
        session = store.load()
        assert session.staged.resources == [res_hash]

    def test_add_by_hash_release(self, store: SessionStore, tmp_root: Path) -> None:
        _init_session(store)
        rel_hash = _make_release_snapshot(tmp_root)
        store.add_snapshot("release", rel_hash)
        session = store.load()
        assert session.staged.releases == [rel_hash]

    def test_add_duplicate_allowed(self, store: SessionStore) -> None:
        _init_session(store)
        store.add_snapshot("resource", "aaa")
        store.add_snapshot("resource", "aaa")
        session = store.load()
        assert session.staged.resources == ["aaa", "aaa"]

    def test_add_after_commit_raises(self, store: SessionStore) -> None:
        """After mark_committed, the session file is removed so add_snapshot
        raises FileNotFoundError (no session to add to)."""
        _init_session(store)
        store.mark_committed()
        with pytest.raises(FileNotFoundError):
            store.add_snapshot("resource", "abc")

    def test_add_multiple_resource_hashes(self, store: SessionStore) -> None:
        _init_session(store)
        store.add_snapshot("resource", "hash1")
        store.add_snapshot("resource", "hash2")
        store.add_snapshot("resource", "hash3")
        session = store.load()
        assert session.staged.resources == ["hash1", "hash2", "hash3"]


# ===========================================================================
# 5. session remove
# ===========================================================================


class TestSessionRemove:
    def test_remove_staged(self, store: SessionStore) -> None:
        _init_session(store)
        store.add_snapshot("resource", "aaa")
        store.add_snapshot("resource", "bbb")
        store.remove_snapshot("resource", "aaa")
        session = store.load()
        assert session.staged.resources == ["bbb"]

    def test_remove_not_staged(self, store: SessionStore) -> None:
        _init_session(store)
        with pytest.raises(ValueError, match="not staged"):
            store.remove_snapshot("resource", "missing")

    def test_remove_wrong_type(self, store: SessionStore) -> None:
        _init_session(store)
        store.add_snapshot("resource", "aaa")
        with pytest.raises(ValueError, match="not staged as release"):
            store.remove_snapshot("release", "aaa")

    def test_remove_after_commit_raises(self, store: SessionStore) -> None:
        """After mark_committed, the session file is removed so remove_snapshot
        raises FileNotFoundError (no session to remove from)."""
        _init_session(store)
        store.add_snapshot("resource", "abc")
        store.mark_committed()
        with pytest.raises(FileNotFoundError):
            store.remove_snapshot("resource", "abc")

    def test_remove_only_first_duplicate(self, store: SessionStore) -> None:
        _init_session(store)
        store.add_snapshot("resource", "dup")
        store.add_snapshot("resource", "dup")
        store.remove_snapshot("resource", "dup")
        session = store.load()
        assert session.staged.resources == ["dup"]


# ===========================================================================
# 6. session diff (logical)
# ===========================================================================


def _compute_diff_style(tmp_root: Path, store: SessionStore) -> dict:
    """Accumulation-aware diff — delegates to production _compute_diff."""
    return _compute_diff(tmp_root, store.load())


class TestSessionDiff:
    def test_diff_no_head(self, store: SessionStore, tmp_root: Path) -> None:
        _init_session(store)
        res_hash = _make_resource_snapshot(tmp_root)
        store.add_snapshot("resource", res_hash)

        diff = _compute_diff_style(tmp_root, store)
        assert diff["head"] is None
        assert res_hash in diff["resources"]["added"]

    def test_diff_with_head(self, store: SessionStore, mgr: SessionManager, tmp_root: Path) -> None:
        _init_session(store)
        res_hash1 = _make_resource_snapshot(
            tmp_root, server_id="tranquility", resources=[("aa" * 4, "bb" * 4, 100)]
        )
        mgr.ensure_channel("testing")
        snap_store = mgr.snap_store
        meta, _ = snap_store.load_resource_snapshot(res_hash1)

        server_index = ServerIndex()
        server_index.schema_version = 1
        gen_resources = GenerationResources()
        gen_resources.schema_version = 1

        entry = server_index.servers.add()
        entry.server_id = "tranquility"
        entry.name["en"] = "tranquility"
        entry.game_build = meta.game_build
        entry.game_version = meta.game_version
        gentry = gen_resources.entries.add()
        gentry.server_id = "tranquility"
        gentry.snapshot_hash = res_hash1

        gen_hash = mgr.create_generation(
            metadata=GenerationMetadata(
                channel="testing",
                timestamp=utc_timestamp(),
                parent="",
                subject="",
            ),
            server_index=server_index,
            resources=gen_resources,
            release_pointer=_gen_ptr(),
        )
        mgr.push("testing", gen_hash)

        res_hash2 = _make_resource_snapshot(
            tmp_root, server_id="serenity", resources=[("cc" * 4, "dd" * 4, 200)]
        )
        store.add_snapshot("resource", res_hash2)

        diff = _compute_diff_style(tmp_root, store)
        assert diff["head"] == gen_hash
        assert res_hash2 in diff["resources"]["added"]
        assert res_hash1 not in diff["resources"]["added"]

        assert res_hash1 in diff["resources"]["inherited"]
        assert diff["resources"]["updated"] == []
        assert diff["resources"]["unchanged"] == []

    def test_diff_json_output(self, store: SessionStore, tmp_root: Path) -> None:
        _init_session(store)
        res_hash = _make_resource_snapshot(tmp_root)
        store.add_snapshot("resource", res_hash)
        diff = _compute_diff_style(tmp_root, store)
        output = json.dumps(diff)
        assert diff["channel"] == "testing"
        assert "added" in output
        assert "inherited" in output
        assert "updated" in output
        assert "unchanged" in output
        assert "removed" not in output


# ===========================================================================
# 7. session verify
# ===========================================================================


def _verify_staged_style(tmp_root: Path, store: SessionStore) -> list[Issue]:
    from bootstrap.remote.models import ResourceIndex
    from bootstrap.remote.models import read_pb2 as _read_pb2
    from bootstrap.remote.paths import release_snapshot_dir
    from bootstrap.remote.paths import resource_snapshot_dir

    session = store.load()
    issues: list[Issue] = []

    dir_for_type = {
        "resource": resource_snapshot_dir,
        "release": release_snapshot_dir,
    }
    proto_names = {
        "resource": "resources.pb2",
        "release": "releases.pb2",
    }
    staged_map = {
        "resource": session.staged.resources,
        "release": session.staged.releases,
    }

    for snap_type in ("resource", "release"):
        proto_name = proto_names[snap_type]
        for h in staged_map[snap_type]:
            snap_dir = dir_for_type[snap_type](tmp_root, h)
            if not snap_dir.is_dir():
                issues.append(
                    Issue(
                        entity=h[:12] + "...",
                        entity_type=f"{snap_type}_snapshot",
                        severity="error",
                        message=f"Directory not found: {snap_dir}",
                    )
                )
                continue

            meta_path = snap_dir / "metadata.json"
            proto_path = snap_dir / proto_name
            if not meta_path.is_file():
                issues.append(
                    Issue(
                        entity=h[:12] + "...",
                        entity_type=f"{snap_type}_snapshot",
                        severity="error",
                        message="Missing metadata.json",
                    )
                )
                continue
            if not proto_path.is_file():
                issues.append(
                    Issue(
                        entity=h[:12] + "...",
                        entity_type=f"{snap_type}_snapshot",
                        severity="error",
                        message=f"Missing {proto_name}",
                    )
                )
                continue

            try:
                files = {
                    "metadata.json": meta_path.read_bytes(),
                    proto_name: proto_path.read_bytes(),
                }
                if not _verify_snapshot_hash(snap_type, files, h):
                    issues.append(
                        Issue(
                            entity=h[:12] + "...",
                            entity_type=f"{snap_type}_snapshot",
                            severity="error",
                            message=f"Hash mismatch: {h[:12]}... does not verify (v4/v3)",
                        )
                    )
            except Exception as exc:
                issues.append(
                    Issue(
                        entity=h[:12] + "...",
                        entity_type=f"{snap_type}_snapshot",
                        severity="error",
                        message=f"Hash computation failed: {exc}",
                    )
                )

        if snap_type == "resource":
            head_hashes = _head_resource_snapshot_hashes(tmp_root, session.channel)
            for h in staged_map[snap_type]:
                if h in head_hashes:
                    continue
                snap_dir = dir_for_type[snap_type](tmp_root, h)
                if snap_dir.is_dir() and (snap_dir / proto_name).is_file():
                    proto_path = snap_dir / proto_name
                    try:
                        index = _read_pb2(proto_path, ResourceIndex)
                        for entry in index.entries:
                            ihash = ident_hash(entry.resource_id)
                            bpath = blob_path(tmp_root, ihash, entry.content_hash)
                            if not bpath.is_file():
                                issues.append(
                                    Issue(
                                        entity=entry.resource_id,
                                        entity_type="blob",
                                        severity="error",
                                        message=f"Missing blob: {bpath}",
                                    )
                                )
                                continue
                            actual = _content_hash(bpath.read_bytes())
                            if actual != entry.content_hash:
                                issues.append(
                                    Issue(
                                        entity=entry.resource_id,
                                        entity_type="blob",
                                        severity="error",
                                        message=(
                                            f"Content hash mismatch: expected"
                                            f" {entry.content_hash[:12]}..."
                                            f", got {actual[:12]}..."
                                        ),
                                    )
                                )
                    except Exception as exc:
                        issues.append(
                            Issue(
                                entity=h[:12] + "...",
                                entity_type="resource_snapshot",
                                severity="error",
                                message=str(exc),
                            )
                        )

    try:
        registry = ChannelHeadStore(tmp_root).get_registry()
        if session.channel not in registry.channels:
            issues.append(
                Issue(
                    entity=session.channel,
                    entity_type="channel",
                    severity="warning",
                    message=f"Channel {session.channel!r} not in registry",
                )
            )
    except Exception as exc:
        issues.append(
            Issue(
                entity=session.channel,
                entity_type="channel",
                severity="warning",
                message=f"Channel check failed: {exc}",
            )
        )

    return issues


class TestSessionVerify:
    def test_verify_clean(self, store: SessionStore, tmp_root: Path, mgr: SessionManager) -> None:
        _init_session(store)
        mgr.ensure_channel("testing")
        res_hash = _make_resource_snapshot(tmp_root)
        store.add_snapshot("resource", res_hash)

        issues = _verify_staged_style(tmp_root, store)
        errors = [i for i in issues if i.severity == "error"]
        assert len(errors) == 0, f"Unexpected errors: {errors}"

    def test_verify_missing_snapshot_directory(self, store: SessionStore, tmp_root: Path) -> None:
        import hashlib

        _init_session(store)
        fake_hash = hashlib.sha256(b"nonexistent").hexdigest()
        store.add_snapshot("resource", fake_hash)

        issues = _verify_staged_style(tmp_root, store)
        dir_issues = [i for i in issues if "Directory not found" in i.message]
        assert len(dir_issues) >= 1

    def test_verify_hash_mismatch(self, store: SessionStore, tmp_root: Path) -> None:
        _init_session(store)
        res_hash = _make_resource_snapshot(tmp_root)
        store.add_snapshot("resource", res_hash)

        from bootstrap.remote.paths import resource_snapshot_dir as _rdir

        snap_dir = _rdir(tmp_root, res_hash)
        (snap_dir / "metadata.json").write_bytes(b'{"corrupted": true}')

        issues = _verify_staged_style(tmp_root, store)
        hash_issues = [i for i in issues if "Hash mismatch" in i.message]
        assert len(hash_issues) >= 1

    def test_verify_missing_metadata_json(self, store: SessionStore, tmp_root: Path) -> None:
        _init_session(store)
        res_hash = _make_resource_snapshot(tmp_root)
        store.add_snapshot("resource", res_hash)

        from bootstrap.remote.paths import resource_snapshot_dir as _rdir

        snap_dir = _rdir(tmp_root, res_hash)
        (snap_dir / "metadata.json").unlink()

        issues = _verify_staged_style(tmp_root, store)
        missing = [i for i in issues if "Missing metadata.json" in i.message]
        assert len(missing) >= 1

    def test_verify_missing_pb2(self, store: SessionStore, tmp_root: Path) -> None:
        _init_session(store)
        res_hash = _make_resource_snapshot(tmp_root)
        store.add_snapshot("resource", res_hash)

        from bootstrap.remote.paths import resource_snapshot_dir as _rdir

        snap_dir = _rdir(tmp_root, res_hash)
        (snap_dir / "resources.pb2").unlink()

        issues = _verify_staged_style(tmp_root, store)
        missing = [i for i in issues if "Missing resources.pb2" in i.message]
        assert len(missing) >= 1

    def test_verify_blob_missing_detected(self, store: SessionStore, tmp_root: Path) -> None:
        _init_session(store)
        res_hash = _make_resource_snapshot(tmp_root)
        store.add_snapshot("resource", res_hash)

        from bootstrap.remote.models import ResourceIndex
        from bootstrap.remote.models import read_pb2 as _read_pb2
        from bootstrap.remote.paths import resource_snapshot_dir as _rdir

        snap_dir = _rdir(tmp_root, res_hash)
        index = _read_pb2(snap_dir / "resources.pb2", ResourceIndex)
        if index.entries:
            entry = index.entries[0]
            ihash = ident_hash(entry.resource_id)
            bpath = blob_path(tmp_root, ihash, entry.content_hash)
            bpath.unlink()

        issues = _verify_staged_style(tmp_root, store)
        missing_blobs = [i for i in issues if "Missing blob" in i.message]
        assert len(missing_blobs) >= 1

    def test_verify_blob_hash_mismatch_detected(self, store: SessionStore, tmp_root: Path) -> None:
        _init_session(store)
        res_hash = _make_resource_snapshot(tmp_root)
        store.add_snapshot("resource", res_hash)

        from bootstrap.remote.models import ResourceIndex
        from bootstrap.remote.models import read_pb2 as _read_pb2
        from bootstrap.remote.paths import resource_snapshot_dir as _rdir

        snap_dir = _rdir(tmp_root, res_hash)
        index = _read_pb2(snap_dir / "resources.pb2", ResourceIndex)
        if index.entries:
            entry = index.entries[0]
            ihash = ident_hash(entry.resource_id)
            bpath = blob_path(tmp_root, ihash, entry.content_hash)
            bpath.write_bytes(b"tampered blob content")

        issues = _verify_staged_style(tmp_root, store)
        hash_issues = [i for i in issues if "hash mismatch" in i.message.lower()]
        assert len(hash_issues) >= 1

    def test_verify_release_snapshot(self, store: SessionStore, tmp_root: Path) -> None:
        _init_session(store)
        rel_hash = _make_release_snapshot(tmp_root)
        store.add_snapshot("release", rel_hash)

        issues = _verify_staged_style(tmp_root, store)
        errors = [i for i in issues if i.severity == "error"]
        assert len(errors) == 0

    def test_verify_skips_blobs_for_head_unchanged_snapshot(
        self, store: SessionStore, tmp_root: Path, mgr: SessionManager
    ) -> None:
        _, res_hash = _make_full_generation(mgr, tmp_root)

        from bootstrap.remote.models import ResourceIndex
        from bootstrap.remote.models import read_pb2 as _read_pb2
        from bootstrap.remote.paths import resource_snapshot_dir as _rdir

        snap_dir = _rdir(tmp_root, res_hash)
        index = _read_pb2(snap_dir / "resources.pb2", ResourceIndex)
        assert index.entries
        for entry in index.entries:
            bpath = blob_path(tmp_root, ident_hash(entry.resource_id), entry.content_hash)
            bpath.unlink()

        _init_session(store)
        store.add_snapshot("resource", res_hash)

        issues = _verify_staged(tmp_root, store.load())
        errors = [i for i in issues if i.severity == "error"]
        assert len(errors) == 0, f"Unexpected errors: {errors}"

    def test_verify_flags_missing_blobs_for_new_snapshot(
        self, store: SessionStore, tmp_root: Path, mgr: SessionManager
    ) -> None:
        _make_full_generation(mgr, tmp_root)

        new_hash = _make_resource_snapshot(tmp_root, server_id="serenity")

        from bootstrap.remote.models import ResourceIndex
        from bootstrap.remote.models import read_pb2 as _read_pb2
        from bootstrap.remote.paths import resource_snapshot_dir as _rdir

        snap_dir = _rdir(tmp_root, new_hash)
        index = _read_pb2(snap_dir / "resources.pb2", ResourceIndex)
        assert index.entries
        entry = index.entries[0]
        blob_path(tmp_root, ident_hash(entry.resource_id), entry.content_hash).unlink()

        _init_session(store)
        store.add_snapshot("resource", new_hash)

        issues = _verify_staged(tmp_root, store.load())
        missing_blobs = [i for i in issues if "Missing blob" in i.message]
        assert len(missing_blobs) >= 1


# ===========================================================================
# 8. session commit
# ===========================================================================


class TestSessionCommit:
    def test_commit_full_workflow(
        self, store: SessionStore, mgr: SessionManager, tmp_root: Path
    ) -> None:
        _init_session(store)
        mgr.ensure_channel("testing")
        res_hash = _make_resource_snapshot(tmp_root)
        store.add_snapshot("resource", res_hash)

        snap_store = mgr.snap_store
        meta_resource, _ = snap_store.load_resource_snapshot(res_hash)

        server_index = ServerIndex()
        server_index.schema_version = 1
        gen_resources = GenerationResources()
        gen_resources.schema_version = 1

        entry = server_index.servers.add()
        entry.server_id = meta_resource.server_id
        entry.name["en"] = meta_resource.server_id
        entry.game_build = meta_resource.game_build
        entry.game_version = meta_resource.game_version
        gentry = gen_resources.entries.add()
        gentry.server_id = meta_resource.server_id
        gentry.snapshot_hash = res_hash

        gen_meta = GenerationMetadata(
            channel="testing",
            timestamp=utc_timestamp(),
            parent="",
            subject="",
        )

        gen_hash = mgr.create_generation(
            metadata=gen_meta,
            server_index=server_index,
            resources=gen_resources,
            release_pointer=_gen_ptr(),
        )
        mgr.push("testing", gen_hash)
        store.mark_committed()

        head = mgr.get_head("testing")
        assert head.generation_hash == gen_hash
        assert not store.session_path.is_file()
        assert store.is_committed() is False

    def test_commit_no_push(self, store: SessionStore, mgr: SessionManager, tmp_root: Path) -> None:
        _init_session(store)
        mgr.ensure_channel("testing")
        res_hash = _make_resource_snapshot(tmp_root)
        store.add_snapshot("resource", res_hash)

        snap_store = mgr.snap_store
        meta_resource, _ = snap_store.load_resource_snapshot(res_hash)

        server_index = ServerIndex()
        server_index.schema_version = 1
        gen_resources = GenerationResources()
        gen_resources.schema_version = 1

        entry = server_index.servers.add()
        entry.server_id = meta_resource.server_id
        entry.name["en"] = meta_resource.server_id
        entry.game_build = meta_resource.game_build
        entry.game_version = meta_resource.game_version
        gentry = gen_resources.entries.add()
        gentry.server_id = meta_resource.server_id
        gentry.snapshot_hash = res_hash

        gen_meta = GenerationMetadata(
            channel="testing",
            timestamp=utc_timestamp(),
            parent="",
            subject="",
        )

        mgr.create_generation(
            metadata=gen_meta,
            server_index=server_index,
            resources=gen_resources,
            release_pointer=_gen_ptr(),
        )
        # Do NOT push — head stays uninitialized
        store.mark_committed()

        head = mgr.get_head("testing")
        assert not head.generation_hash

    def test_commit_no_snapshots(self, store: SessionStore) -> None:
        _init_session(store)
        session = store.load()
        has_snapshots = any([session.staged.resources, session.staged.releases])
        assert has_snapshots is False

    def test_commit_marks_session_committed(
        self, store: SessionStore, mgr: SessionManager, tmp_root: Path
    ) -> None:
        _init_session(store)
        mgr.ensure_channel("testing")
        res_hash = _make_resource_snapshot(tmp_root)
        store.add_snapshot("resource", res_hash)

        _make_full_generation(mgr, tmp_root)  # includes push
        store.mark_committed()

        assert not store.session_path.is_file()
        assert store.is_committed() is False

    def test_commit_idempotent_generation_reuse(
        self, store: SessionStore, mgr: SessionManager, tmp_root: Path
    ) -> None:
        _init_session(store)
        mgr.ensure_channel("testing")
        res_hash = _make_resource_snapshot(tmp_root=tmp_root, server_id="tranquility")

        snap_store = mgr.snap_store
        meta_resource, _ = snap_store.load_resource_snapshot(res_hash)

        server_index = ServerIndex()
        server_index.schema_version = 1
        gen_resources = GenerationResources()
        gen_resources.schema_version = 1

        entry = server_index.servers.add()
        entry.server_id = meta_resource.server_id
        entry.name["en"] = meta_resource.server_id
        entry.game_build = meta_resource.game_build
        entry.game_version = meta_resource.game_version
        gentry = gen_resources.entries.add()
        gentry.server_id = meta_resource.server_id
        gentry.snapshot_hash = res_hash

        gen_meta = GenerationMetadata(
            channel="testing",
            timestamp=utc_timestamp(),
            parent="",
            subject="",
        )

        gen_hash1 = mgr.create_generation(
            metadata=gen_meta,
            server_index=server_index,
            resources=gen_resources,
            release_pointer=_gen_ptr(),
        )

        gen_hash2 = mgr.create_generation(
            metadata=gen_meta,
            server_index=server_index,
            resources=gen_resources,
            release_pointer=_gen_ptr(),
        )

        assert gen_hash1 == gen_hash2

    def test_commit_with_release_snapshot(
        self, store: SessionStore, mgr: SessionManager, tmp_root: Path
    ) -> None:
        _init_session(store)
        mgr.ensure_channel("testing")
        res_hash = _make_resource_snapshot(tmp_root)
        rel_hash = _make_release_snapshot(tmp_root)
        store.add_snapshot("resource", res_hash)
        store.add_snapshot("release", rel_hash)

        snap_store = mgr.snap_store
        meta_resource, _ = snap_store.load_resource_snapshot(res_hash)

        server_index = ServerIndex()
        server_index.schema_version = 1
        gen_resources = GenerationResources()
        gen_resources.schema_version = 1

        entry = server_index.servers.add()
        entry.server_id = meta_resource.server_id
        entry.name["en"] = meta_resource.server_id
        entry.game_build = meta_resource.game_build
        entry.game_version = meta_resource.game_version
        gentry = gen_resources.entries.add()
        gentry.server_id = meta_resource.server_id
        gentry.snapshot_hash = res_hash

        release_ptr = _gen_ptr(rel_hash)

        gen_meta = GenerationMetadata(
            channel="testing",
            timestamp=utc_timestamp(),
            parent="",
            subject="",
        )
        gen_hash = mgr.create_generation(
            metadata=gen_meta,
            server_index=server_index,
            resources=gen_resources,
            release_pointer=release_ptr,
        )
        mgr.push("testing", gen_hash)

        gen = mgr.load_generation(gen_hash)
        assert gen.release_pointer.snapshot_hash == rel_hash

    def test_commit_with_multiple_resources(
        self, store: SessionStore, mgr: SessionManager, tmp_root: Path
    ) -> None:
        _init_session(store)
        mgr.ensure_channel("testing")

        res_hash1 = _make_resource_snapshot(
            tmp_root, server_id="tranquility", resources=[("aa" * 4, "bb" * 4, 100)]
        )
        res_hash2 = _make_resource_snapshot(
            tmp_root, server_id="serenity", resources=[("cc" * 4, "dd" * 4, 200)]
        )
        store.add_snapshot("resource", res_hash1)
        store.add_snapshot("resource", res_hash2)

        snap_store = mgr.snap_store
        meta1, _ = snap_store.load_resource_snapshot(res_hash1)
        meta2, _ = snap_store.load_resource_snapshot(res_hash2)

        server_index = ServerIndex()
        server_index.schema_version = 1
        gen_resources = GenerationResources()
        gen_resources.schema_version = 1

        for meta, r_hash in [(meta1, res_hash1), (meta2, res_hash2)]:
            entry = server_index.servers.add()
            entry.server_id = meta.server_id
            entry.name["en"] = meta.server_id
            entry.game_build = meta.game_build
            entry.game_version = meta.game_version
            gentry = gen_resources.entries.add()
            gentry.server_id = meta.server_id
            gentry.snapshot_hash = r_hash

        gen_meta = GenerationMetadata(
            channel="testing",
            timestamp=utc_timestamp(),
            parent="",
            subject="",
        )
        gen_hash = mgr.create_generation(
            metadata=gen_meta,
            server_index=server_index,
            resources=gen_resources,
            release_pointer=_gen_ptr(),
        )
        mgr.push("testing", gen_hash)

        gen = mgr.load_generation(gen_hash)
        assert len(gen.resources.entries) == 2
        server_ids = {e.server_id for e in gen.resources.entries}
        assert server_ids == {"tranquility", "serenity"}


# ===========================================================================
# 9. Full end-to-end workflow
# ===========================================================================


class TestFullWorkflow:
    def test_full_workflow_end_to_end(
        self, store: SessionStore, mgr: SessionManager, tmp_root: Path
    ) -> None:
        _init_session(store, channel="stable")
        mgr.ensure_channel("stable")
        session = store.load()
        assert session.channel == "stable"

        res_hash = _make_resource_snapshot(tmp_root)
        store.add_snapshot("resource", res_hash)
        session = store.load()
        assert len(session.staged.resources) == 1

        rel_hash = _make_release_snapshot(tmp_root)
        store.add_snapshot("release", rel_hash)
        session = store.load()
        assert len(session.staged.releases) == 1

        snap_store = mgr.snap_store
        meta_resource, _ = snap_store.load_resource_snapshot(res_hash)

        server_index = ServerIndex()
        server_index.schema_version = 1
        gen_resources = GenerationResources()
        gen_resources.schema_version = 1

        entry = server_index.servers.add()
        entry.server_id = meta_resource.server_id
        entry.name["en"] = meta_resource.server_id
        entry.game_build = meta_resource.game_build
        entry.game_version = meta_resource.game_version
        gentry = gen_resources.entries.add()
        gentry.server_id = meta_resource.server_id
        gentry.snapshot_hash = res_hash

        release_ptr = _gen_ptr(rel_hash)

        gen_meta = GenerationMetadata(
            channel="stable",
            timestamp=utc_timestamp(),
            parent="",
            subject="",
        )
        gen_hash = mgr.create_generation(
            metadata=gen_meta,
            server_index=server_index,
            resources=gen_resources,
            release_pointer=release_ptr,
        )
        mgr.push("stable", gen_hash)
        store.mark_committed()

        assert not store.session_path.is_file()
        assert store.is_committed() is False

        head = mgr.get_head("stable")
        assert head.generation_hash == gen_hash


# ===========================================================================
# 10. Edge case / regression tests
# ===========================================================================


class TestSessionEdgeCases:
    def test_double_init_force_overwrite_clears_staged(self, store: SessionStore) -> None:
        _init_session(store)
        store.add_snapshot("resource", "aaa")
        store.add_snapshot("release", "bbb")

        store.init(channel="testing", force_overwrite=True)
        session = store.load()
        assert session.staged.resources == []
        assert session.staged.releases == []

    def test_session_roundtrip_json_alias(self, store: SessionStore) -> None:
        _init_session(store, channel="stable")
        store.add_snapshot("resource", "res-hash")

        raw = store.session_path.read_text(encoding="utf-8")
        data = json.loads(raw)

        assert data["schemaVersion"] == 1
        assert data["channel"] == "stable"
        assert data["committed"] is False
        assert "resources" in data["staged"]

        revalidated = Session.model_validate_json(raw)
        assert revalidated.staged.resources == ["res-hash"]

    def test_corrupt_session_file_handling(self, store: SessionStore) -> None:
        _init_session(store)
        store.session_path.write_text("{{{ invalid json", encoding="utf-8")
        assert store.exists() is False

    def test_ensure_editable_after_mark_committed(self, store: SessionStore) -> None:
        _init_session(store)
        store.mark_committed()
        assert not store.session_path.is_file()
        # ensure_editable does not raise — no session file exists
        store.ensure_editable()

    def test_reflog_after_commit(
        self, store: SessionStore, mgr: SessionManager, tmp_root: Path
    ) -> None:
        _init_session(store)
        mgr.ensure_channel("testing")

        _make_full_generation(mgr, tmp_root)
        store.mark_committed()

        reflog = mgr.get_reflog("testing")
        assert len(reflog.entries) >= 1
        last_entry = reflog.entries[-1]
        assert last_entry.op == "push"


# ===========================================================================
# 11. Generation accumulation
# ===========================================================================


class TestSessionCommitAccumulation:
    """Accumulation: commit seeds from parent, overlays staged."""

    def test_root_commit_no_seeding(
        self, store: SessionStore, mgr: SessionManager, tmp_root: Path
    ) -> None:
        """First commit with no parent — same as current behavior."""
        _init_session(store)
        mgr.ensure_channel("testing")
        res_a = _make_resource_snapshot(
            tmp_root,
            server_id="tranquility",
            resources=[("aa" * 4, "bb" * 4, 100)],
        )
        store.add_snapshot("resource", res_a)

        gen_a = _commit_from_session(store, mgr, tmp_root, parent="")
        mgr.push("testing", gen_a)
        store.mark_committed()

        gen = mgr.load_generation(gen_a)
        assert len(gen.resources.entries) == 1
        assert gen.resources.entries[0].server_id == "tranquility"
        assert gen.resources.entries[0].snapshot_hash == res_a
        assert len(gen.server_index.servers) == 1
        assert gen.server_index.servers[0].server_id == "tranquility"

    def test_accumulate_new_server(
        self, store: SessionStore, mgr: SessionManager, tmp_root: Path
    ) -> None:
        """Commit A1, then commit B1 → B1 gen has both A and B."""
        _init_session(store)
        mgr.ensure_channel("testing")

        res_a = _make_resource_snapshot(
            tmp_root,
            server_id="tranquility",
            resources=[("aa" * 4, "bb" * 4, 100)],
        )
        store.add_snapshot("resource", res_a)
        gen_a = _commit_from_session(store, mgr, tmp_root)
        mgr.push("testing", gen_a)
        store.mark_committed()

        store.init("testing", force_overwrite=True)
        res_b = _make_resource_snapshot(
            tmp_root,
            server_id="serenity",
            resources=[("cc" * 4, "dd" * 4, 200)],
        )
        store.add_snapshot("resource", res_b)
        gen_b = _commit_from_session(store, mgr, tmp_root, parent=gen_a)
        mgr.push("testing", gen_b)
        store.mark_committed()

        gen = mgr.load_generation(gen_b)
        assert len(gen.resources.entries) == 2
        server_hashes = {e.server_id: e.snapshot_hash for e in gen.resources.entries}
        assert server_hashes["tranquility"] == res_a
        assert server_hashes["serenity"] == res_b
        assert len(gen.server_index.servers) == 2
        server_ids = {e.server_id for e in gen.server_index.servers}
        assert server_ids == {"tranquility", "serenity"}

    def test_update_existing_server(
        self, store: SessionStore, mgr: SessionManager, tmp_root: Path
    ) -> None:
        """Commit A1, then commit A2 → A2 replaces A1 for same server_id."""
        _init_session(store)
        mgr.ensure_channel("testing")

        res_a1 = _make_resource_snapshot(
            tmp_root,
            server_id="tranquility",
            resources=[("aa" * 4, "bb" * 4, 100)],
        )
        store.add_snapshot("resource", res_a1)
        gen_a = _commit_from_session(store, mgr, tmp_root)
        mgr.push("testing", gen_a)
        store.mark_committed()

        store.init("testing", force_overwrite=True)
        res_a2 = _make_resource_snapshot(
            tmp_root,
            server_id="tranquility",
            resources=[("ee" * 4, "ff" * 4, 300)],
        )
        store.add_snapshot("resource", res_a2)
        gen_b = _commit_from_session(store, mgr, tmp_root, parent=gen_a)
        mgr.push("testing", gen_b)
        store.mark_committed()

        gen = mgr.load_generation(gen_b)
        assert len(gen.resources.entries) == 1
        assert gen.resources.entries[0].server_id == "tranquility"
        assert gen.resources.entries[0].snapshot_hash == res_a2

    def test_mixed_add_and_update(
        self, store: SessionStore, mgr: SessionManager, tmp_root: Path
    ) -> None:
        """Commit {A, B}, then stage {C, B2} → new gen has A(keep), B(B2), C(C)."""
        _init_session(store)
        mgr.ensure_channel("testing")

        res_a = _make_resource_snapshot(
            tmp_root,
            server_id="tranquility",
            resources=[("a1" * 4, "a2" * 4, 100)],
        )
        res_b = _make_resource_snapshot(
            tmp_root,
            server_id="serenity",
            resources=[("b1" * 4, "b2" * 4, 200)],
        )
        store.add_snapshot("resource", res_a)
        store.add_snapshot("resource", res_b)
        gen_ab = _commit_from_session(store, mgr, tmp_root)
        mgr.push("testing", gen_ab)
        store.mark_committed()

        store.init("testing", force_overwrite=True)
        res_c = _make_resource_snapshot(
            tmp_root,
            server_id="singularity",
            resources=[("c1" * 4, "c2" * 4, 300)],
        )
        res_b2 = _make_resource_snapshot(
            tmp_root,
            server_id="serenity",
            resources=[("b3" * 4, "b4" * 4, 400)],
        )
        store.add_snapshot("resource", res_c)
        store.add_snapshot("resource", res_b2)
        gen_cb2 = _commit_from_session(store, mgr, tmp_root, parent=gen_ab)
        mgr.push("testing", gen_cb2)
        store.mark_committed()

        gen = mgr.load_generation(gen_cb2)
        assert len(gen.resources.entries) == 3
        server_hashes = {e.server_id: e.snapshot_hash for e in gen.resources.entries}
        assert server_hashes["tranquility"] == res_a
        assert server_hashes["serenity"] == res_b2
        assert server_hashes["singularity"] == res_c

    def test_preserves_release_ptr_from_parent(
        self, store: SessionStore, mgr: SessionManager, tmp_root: Path
    ) -> None:
        """Commit with release, then commit without → new gen carries release."""
        _init_session(store)
        mgr.ensure_channel("testing")

        res_a = _make_resource_snapshot(tmp_root, server_id="tranquility")
        rel = _make_release_snapshot(tmp_root, version="1.0.0")
        store.add_snapshot("resource", res_a)
        store.add_snapshot("release", rel)
        gen_a = _commit_from_session(store, mgr, tmp_root)
        mgr.push("testing", gen_a)
        store.mark_committed()

        store.init("testing", force_overwrite=True)
        res_b = _make_resource_snapshot(
            tmp_root,
            server_id="serenity",
            resources=[("cc" * 4, "dd" * 4, 200)],
        )
        store.add_snapshot("resource", res_b)
        gen_b = _commit_from_session(store, mgr, tmp_root, parent=gen_a)
        mgr.push("testing", gen_b)
        store.mark_committed()

        gen = mgr.load_generation(gen_b)
        assert gen.release_pointer.snapshot_hash == rel

    def test_release_override(
        self, store: SessionStore, mgr: SessionManager, tmp_root: Path
    ) -> None:
        """Commit R1, then commit R2 → new gen uses R2."""
        _init_session(store)
        mgr.ensure_channel("testing")

        res_a = _make_resource_snapshot(tmp_root, server_id="tranquility")
        rel1 = _make_release_snapshot(tmp_root, version="1.0.0")
        store.add_snapshot("resource", res_a)
        store.add_snapshot("release", rel1)
        gen_a = _commit_from_session(store, mgr, tmp_root)
        mgr.push("testing", gen_a)
        store.mark_committed()

        store.init("testing", force_overwrite=True)
        rel2 = _make_release_snapshot(tmp_root, version="1.1.0")
        store.add_snapshot("release", rel2)
        gen_b = _commit_from_session(store, mgr, tmp_root, parent=gen_a)
        mgr.push("testing", gen_b)
        store.mark_committed()

        gen = mgr.load_generation(gen_b)
        assert gen.release_pointer.snapshot_hash == rel2

    def test_diff_shows_inherited(
        self, store: SessionStore, mgr: SessionManager, tmp_root: Path
    ) -> None:
        """After committing A+B, staging only C → diff shows A, B inherited."""
        _init_session(store)
        mgr.ensure_channel("testing")

        res_a = _make_resource_snapshot(
            tmp_root,
            server_id="tranquility",
            resources=[("a1" * 4, "a2" * 4, 100)],
        )
        res_b = _make_resource_snapshot(
            tmp_root,
            server_id="serenity",
            resources=[("b1" * 4, "b2" * 4, 200)],
        )
        store.add_snapshot("resource", res_a)
        store.add_snapshot("resource", res_b)
        gen_hash = _commit_from_session(store, mgr, tmp_root)
        mgr.push("testing", gen_hash)
        store.mark_committed()

        store.init("testing", force_overwrite=True)
        res_c = _make_resource_snapshot(
            tmp_root,
            server_id="singularity",
            resources=[("c1" * 4, "c2" * 4, 300)],
        )
        store.add_snapshot("resource", res_c)

        diff = _compute_diff_style(tmp_root, store)
        assert res_c in diff["resources"]["added"]
        assert res_a in diff["resources"]["inherited"]
        assert res_b in diff["resources"]["inherited"]
        assert len(diff["resources"]["updated"]) == 0
        assert len(diff["resources"]["unchanged"]) == 0


# ===========================================================================
# 12. One-snapshot-per-server enforcement
# ===========================================================================


class TestSessionOneSnapshotPerServer:
    """Enforcement: a session may stage at most one resource per server_id."""

    def test_add_rejects_second_snapshot_same_server(
        self, store: SessionStore, tmp_root: Path
    ) -> None:
        """add --hash of a second snapshot for the same server_id raises."""
        _init_session(store)
        res_a = _make_resource_snapshot(tmp_root, server_id="tranquility")
        res_b = _make_resource_snapshot(tmp_root, server_id="tranquility", game_build="22222")
        store.add_snapshot("resource", res_a)

        from bootstrap.cli.remote.session import _add_snapshot_by_hash

        with pytest.raises(click.ClickException, match="already has a staged snapshot"):
            _add_snapshot_by_hash(store, tmp_root, "resource", res_b)

    def test_add_replace_valid_swap(self, store: SessionStore, tmp_root: Path) -> None:
        """add --replace <hash> of same server_id succeeds."""
        _init_session(store)
        res_a = _make_resource_snapshot(tmp_root, server_id="tranquility", game_build="11111")
        res_b = _make_resource_snapshot(tmp_root, server_id="tranquility", game_build="22222")
        store.add_snapshot("resource", res_a)

        from bootstrap.cli.remote.session import _add_snapshot_by_hash

        _add_snapshot_by_hash(store, tmp_root, "resource", res_b, replace_hash=res_a)
        session = store.load()
        assert res_b in session.staged.resources
        assert res_a not in session.staged.resources

    def test_add_replace_wrong_hash_raises(self, store: SessionStore, tmp_root: Path) -> None:
        """add --replace <wrong-hash> where target is not staged raises."""
        _init_session(store)
        res_a = _make_resource_snapshot(tmp_root, server_id="tranquility")
        res_b = _make_resource_snapshot(tmp_root, server_id="tranquility")

        from bootstrap.cli.remote.session import _add_snapshot_by_hash

        with pytest.raises(click.ClickException, match="not currently staged"):
            _add_snapshot_by_hash(store, tmp_root, "resource", res_b, replace_hash=res_a)

    def test_add_replace_server_mismatch_raises(self, store: SessionStore, tmp_root: Path) -> None:
        """add --replace where replace-target server differs from new raises."""
        _init_session(store)
        res_a = _make_resource_snapshot(tmp_root, server_id="tranquility")
        res_b = _make_resource_snapshot(tmp_root, server_id="serenity")
        store.add_snapshot("resource", res_a)

        from bootstrap.cli.remote.session import _add_snapshot_by_hash

        with pytest.raises(click.ClickException, match="Server mismatch"):
            _add_snapshot_by_hash(store, tmp_root, "resource", res_b, replace_hash=res_a)

    def test_diff_reports_duplicate_servers(self, store: SessionStore, tmp_root: Path) -> None:
        """diff includes duplicate_servers when staged hashes collide on server_id."""
        _init_session(store)
        res_a = _make_resource_snapshot(tmp_root, server_id="tranquility")
        res_b = _make_resource_snapshot(tmp_root, server_id="tranquility", game_build="22222")
        store.add_snapshot("resource", res_a)

        session = store.load()
        diff = _compute_diff(tmp_root, session)
        assert "duplicate_servers" not in diff

        session.staged.resources.append(res_b)
        store.save(session)
        diff = _compute_diff(tmp_root, store.load())
        assert "duplicate_servers" in diff
        assert "tranquility" in diff["duplicate_servers"]

    def test_check_duplicate_server_ids_detects_collision(
        self, store: SessionStore, tmp_root: Path
    ) -> None:
        """_check_duplicate_server_ids appends error Issue for duplicated server_id."""
        _init_session(store)
        res_a = _make_resource_snapshot(tmp_root, server_id="tranquility")
        res_b = _make_resource_snapshot(tmp_root, server_id="tranquility", game_build="22222")
        store.add_snapshot("resource", res_a)

        session = store.load()
        issues: list[Issue] = []
        _check_duplicate_server_ids(tmp_root, session, issues)
        assert len(issues) == 0

        session.staged.resources.append(res_b)
        store.save(session)
        issues = []
        _check_duplicate_server_ids(tmp_root, store.load(), issues)
        assert len(issues) == 1
        assert issues[0].severity == "error"
        assert "Duplicate server" in issues[0].message


# ===========================================================================
# 13. Release snapshot creation from registry files
# ===========================================================================


class TestSessionAddByFileRelease:
    def test_add_release_snapshot_by_relative_path(
        self, store: SessionStore, tmp_root: Path
    ) -> None:
        """Relative paths in a release registry are resolved against the registry file."""
        _init_session(store)

        version = "1.0.0"
        apk_dir = tmp_root / "apk" / version
        apk_dir.mkdir(parents=True, exist_ok=True)
        apk_file = apk_dir / f"{version}-android.apk"
        apk_file.write_bytes(b"fake apk content")

        registry_dir = tmp_root / "merge"
        registry_dir.mkdir(parents=True, exist_ok=True)
        registry_file = registry_dir / f"{version}.json"
        registry_file.write_text(
            json.dumps(
                {
                    "metadata": {
                        "versionMin": version,
                        "versionMax": version,
                        "offerings": ["android"],
                        "releaseCount": 1,
                        "createdAt": "2026-01-01T00:00:00Z",
                    },
                    "release": {
                        "id": f"rel-{version}",
                        "version": version,
                        "android": {"general": str(Path("..") / apk_file.relative_to(tmp_root))},
                    },
                }
            ),
            encoding="utf-8",
        )

        _add_snapshot_by_file(store, tmp_root, "release", registry_file)

        session = store.load()
        assert len(session.staged.releases) == 1

        mgr = SessionManager(tmp_root)
        snap_store = mgr.snap_store
        rel_hash = session.staged.releases[0]
        meta, index = snap_store.load_release_snapshot(rel_hash)
        assert meta.release_count == 1
        assert index.android.general.identifier == f"release://{version}/android/general"
        assert index.android.general.size == apk_file.stat().st_size
        assert index.android.general.content_hash

    def test_build_release_merge_emits_self_relative_paths(
        self, store: SessionStore, tmp_root: Path
    ) -> None:
        """Merged release registry paths are relative to the merge JSON file."""
        _init_session(store)

        version = "1.0.0"
        release_root = tmp_root / "releases"
        apk_dir = release_root / "apk" / version
        apk_dir.mkdir(parents=True, exist_ok=True)
        apk_file = apk_dir / f"{version}-android.apk"
        apk_file.write_bytes(b"fake apk content")

        fragment_file = apk_dir / f"{version}-android.json"
        fragment_file.write_text(
            json.dumps(
                {
                    "metadata": {
                        "versionMin": version,
                        "versionMax": version,
                        "offerings": ["android"],
                        "releaseCount": 1,
                        "createdAt": "2026-01-01T00:00:00Z",
                    },
                    "release": {
                        "id": f"rel-{version}",
                        "version": version,
                        "android": {"general": str(apk_file.relative_to(release_root))},
                    },
                }
            ),
            encoding="utf-8",
        )

        _build_release_merge([fragment_file], version, None, release_root)

        merge_file = release_root / "merge" / f"{version}.json"
        assert merge_file.is_file()
        data = json.loads(merge_file.read_text(encoding="utf-8"))
        assert data["release"]["android"]["general"] == "../apk/1.0.0/1.0.0-android.apk"

        _add_snapshot_by_file(store, tmp_root, "release", merge_file)

        session = store.load()
        assert len(session.staged.releases) == 1


# ===========================================================================
# 14. CLI commit --json output
# ===========================================================================


class TestSessionCommitJson:
    def test_commit_json_output_is_single_valid_json(
        self, store: SessionStore, mgr: SessionManager, tmp_root: Path
    ) -> None:
        """commit --json must emit a single parseable JSON document and no human-readable text."""
        _init_session(store)
        res_hash = _make_resource_snapshot(tmp_root)
        store.add_snapshot("resource", res_hash)

        remote_group = click.Group()
        register_remote_session(remote_group)
        session_group = remote_group.commands["session"]

        result = click.testing.CliRunner().invoke(
            session_group,
            ["commit", "--json", "--schema-root", str(tmp_root)],
        )

        assert result.exit_code == 0
        output = result.output.strip()
        data = json.loads(output)
        assert isinstance(data, dict)
        assert "generation_hash" in data
        assert len(data["generation_hash"]) > 0
        assert data["reused"] is False
        assert data["head_advanced"] is True
        assert output == json.dumps(data)
