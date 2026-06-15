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

import pytest

from data.lib.remote import SessionManager
from data.lib.remote.__init__ import SessionManagerCommittedError
from data.lib.remote.generation import utc_timestamp
from data.lib.remote.hash import content_hash as _content_hash
from data.lib.remote.hash import ident_hash
from data.lib.remote.hash import snapshot_hash as _snapshot_hash
from data.lib.remote.head import ChannelHeadStore
from data.lib.remote.models import AnnouncementSnapshotMetadata
from data.lib.remote.models import GenerationMetadata
from data.lib.remote.models import GenerationPointer
from data.lib.remote.models import GenerationResources
from data.lib.remote.models import ReleaseSnapshotMetadata
from data.lib.remote.models import ResourceSnapshotMetadata
from data.lib.remote.models import ServerIndex
from data.lib.remote.models import make_announcement_index
from data.lib.remote.models import make_release_index
from data.lib.remote.models import make_resource_index
from data.lib.remote.paths import blob_path
from data.lib.remote.session_model import Session
from data.lib.remote.session_model import SessionExistsError
from data.lib.remote.session_model import SessionStore
from data.lib.remote.snapshot import SnapshotStore
from data.lib.remote.verify import Issue


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
        releaseCount=1,
        createdAt="2026-06-15T00:00:00Z",
    )
    index = make_release_index([(release_id, version, offerings, "ab" * 32)])
    return snap_store.create_release_snapshot(meta, index)


def _make_announcement_snapshot(tmp_root: Path) -> str:
    snap_store = SnapshotStore(tmp_root)
    meta = AnnouncementSnapshotMetadata(
        announcementCount=1,
        createdAt="2026-06-15T00:00:00Z",
    )
    index = make_announcement_index(
        [
            {
                "id": "ann-001",
                "first_published_at": "2026-06-15T00:00:00Z",
                "updated_at": "2026-06-15T00:00:00Z",
                "content_hashes": {"en": "ab" * 32},
            }
        ]
    )
    return snap_store.create_announcement_snapshot(meta, index)


def _init_session(
    store: SessionStore,
    channel: str = "testing",
    author: str = "pipeline",
    description: str = "test session",
) -> Session:
    return store.init(channel=channel, author=author, description=description)


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
    announcement_ptr = _gen_ptr()

    meta = GenerationMetadata(
        channel=channel,
        author="pipeline",
        timestamp=utc_timestamp(),
        description="full gen",
        parent="",
        subject="",
    )
    gen_hash = mgr.create_generation(
        metadata=meta,
        server_index=server_index,
        resources=gen_resources,
        release_pointer=release_ptr,
        announcement_pointer=announcement_ptr,
    )
    mgr.push(channel, gen_hash)
    return gen_hash, res_hash


# ===========================================================================
# 1. session init
# ===========================================================================


class TestSessionInit:
    def test_init_creates_session(self, store: SessionStore) -> None:
        _init_session(store)
        assert store.session_path.is_file()
        session = store.load()
        assert session.channel == "testing"
        assert session.author == "pipeline"
        assert session.description == "test session"
        assert session.committed is False
        assert session.schema_version == 1
        assert session.staged.resources == []
        assert session.staged.releases == []
        assert session.staged.announcements == []

    def test_init_fails_without_author(self, store: SessionStore) -> None:
        from pydantic import ValidationError

        with pytest.raises(ValidationError, match="author must not be empty"):
            store.init(channel="testing", author="", description="test")

    def test_init_fails_without_description(self, store: SessionStore) -> None:
        from pydantic import ValidationError

        with pytest.raises(ValidationError, match="description must not be empty"):
            store.init(channel="testing", author="dev", description="")

    def test_init_overwrite_requires_force(self, store: SessionStore) -> None:
        _init_session(store)
        with pytest.raises(SessionExistsError, match="A session already exists"):
            store.init(channel="testing", author="dev", description="second")

    def test_init_overwrite_with_force(self, store: SessionStore) -> None:
        _init_session(store, author="old")
        store.init(
            channel="stable", author="new", description="second session", force_overwrite=True
        )
        session = store.load()
        assert session.channel == "stable"
        assert session.author == "new"
        assert session.description == "second session"

    def test_init_overwrite_committed_with_force(self, store: SessionStore) -> None:
        _init_session(store)
        store.mark_committed()
        store.init(channel="stable", author="new", description="replacement", force_overwrite=True)
        session = store.load()
        assert session.channel == "stable"
        assert session.committed is False

    def test_init_invalid_channel(self, store: SessionStore) -> None:
        from pydantic import ValidationError

        with pytest.raises(ValidationError, match="Invalid channel"):
            store.init(channel="bogus", author="dev", description="test")

    def test_init_valid_channels(self, store: SessionStore) -> None:
        for ch in ("testing", "stable"):
            store.init(channel=ch, author="dev", description="test", force_overwrite=True)
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
        assert session.author == "pipeline"
        assert session.description == "test session"
        assert session.committed is False

    def test_status_json_serializable(self, store: SessionStore) -> None:
        _init_session(store)
        session = store.load()
        data = json.loads(session.model_dump_json(by_alias=True))
        assert data["schemaVersion"] == 1
        assert data["channel"] == "testing"
        assert data["author"] == "pipeline"
        assert data["committed"] is False
        assert "staged" in data


# ===========================================================================
# 3. session discard
# ===========================================================================


class TestSessionDiscard:
    def test_discard_no_session(self, store: SessionStore) -> None:
        from data.lib.remote.__init__ import SessionManagerInvalidError

        with pytest.raises(SessionManagerInvalidError, match="No active session"):
            store.discard()

    def test_discard_removes_file(self, store: SessionStore) -> None:
        _init_session(store)
        assert store.session_path.is_file()
        store.discard()
        assert not store.session_path.is_file()

    def test_discard_committed_needs_force(self, store: SessionStore) -> None:
        _init_session(store)
        store.mark_committed()
        with pytest.raises(SessionManagerCommittedError, match="Session is committed"):
            store.discard()

    def test_discard_committed_with_force(self, store: SessionStore) -> None:
        _init_session(store)
        store.mark_committed()
        store.discard(force=True)
        assert not store.session_path.is_file()


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

    def test_add_by_hash_announcement(self, store: SessionStore, tmp_root: Path) -> None:
        _init_session(store)
        ann_hash = _make_announcement_snapshot(tmp_root)
        store.add_snapshot("announcement", ann_hash)
        session = store.load()
        assert session.staged.announcements == [ann_hash]

    def test_add_duplicate_allowed(self, store: SessionStore) -> None:
        _init_session(store)
        store.add_snapshot("resource", "aaa")
        store.add_snapshot("resource", "aaa")
        session = store.load()
        assert session.staged.resources == ["aaa", "aaa"]

    def test_add_on_committed_raises(self, store: SessionStore) -> None:
        _init_session(store)
        store.mark_committed()
        with pytest.raises(SessionManagerCommittedError, match="Session is committed"):
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

    def test_remove_on_committed_raises(self, store: SessionStore) -> None:
        _init_session(store)
        store.add_snapshot("resource", "abc")
        store.mark_committed()
        with pytest.raises(SessionManagerCommittedError, match="Session is committed"):
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
    from data.lib.remote.generation import GenerationStore

    head_store = ChannelHeadStore(tmp_root)
    gen_store = GenerationStore(tmp_root)
    session = store.load()

    head_hash: str | None = None
    head_sets: dict[str, set[str]] = {
        "resources": set(),
        "releases": set(),
        "announcements": set(),
    }

    try:
        head = head_store._safe_get_head(session.channel)
        if head and head.generation_hash:
            head_hash = head.generation_hash
            generation = gen_store.load(head.generation_hash)
            for entry in generation.resources.entries:
                head_sets["resources"].add(entry.snapshot_hash)
            if generation.release_pointer.snapshot_hash:
                head_sets["releases"].add(generation.release_pointer.snapshot_hash)
            if generation.announcement_pointer.snapshot_hash:
                head_sets["announcements"].add(generation.announcement_pointer.snapshot_hash)
    except Exception:
        pass

    session_sets = {
        "resources": set(session.staged.resources),
        "releases": set(session.staged.releases),
        "announcements": set(session.staged.announcements),
    }

    diff: dict = {"channel": session.channel, "head": head_hash}
    for snap_type in ("resources", "releases", "announcements"):
        s_set = session_sets[snap_type]
        h_set = head_sets[snap_type]
        diff[snap_type] = {
            "added": sorted(s_set - h_set),
            "removed": sorted(h_set - s_set),
            "unchanged": sorted(s_set & h_set),
        }
    return diff


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
                author="pipeline",
                timestamp=utc_timestamp(),
                description="base",
                parent="",
                subject="",
            ),
            server_index=server_index,
            resources=gen_resources,
            release_pointer=_gen_ptr(),
            announcement_pointer=_gen_ptr(),
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

    def test_diff_json_output(self, store: SessionStore, tmp_root: Path) -> None:
        _init_session(store)
        res_hash = _make_resource_snapshot(tmp_root)
        store.add_snapshot("resource", res_hash)
        diff = _compute_diff_style(tmp_root, store)
        output = json.dumps(diff)
        assert diff["channel"] == "testing"
        assert "added" in output


# ===========================================================================
# 7. session verify
# ===========================================================================


def _verify_staged_style(tmp_root: Path, store: SessionStore) -> list[Issue]:
    from data.lib.remote.models import ResourceIndex
    from data.lib.remote.models import read_pb2 as _read_pb2
    from data.lib.remote.paths import announcement_snapshot_dir
    from data.lib.remote.paths import release_snapshot_dir
    from data.lib.remote.paths import resource_snapshot_dir

    session = store.load()
    issues: list[Issue] = []

    dir_for_type = {
        "resource": resource_snapshot_dir,
        "release": release_snapshot_dir,
        "announcement": announcement_snapshot_dir,
    }
    proto_names = {
        "resource": "resources.pb2",
        "release": "releases.pb2",
        "announcement": "announcements.pb2",
    }
    staged_map = {
        "resource": session.staged.resources,
        "release": session.staged.releases,
        "announcement": session.staged.announcements,
    }

    for snap_type in ("resource", "release", "announcement"):
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
                computed = _snapshot_hash(snap_type, files)
                if computed != h:
                    issues.append(
                        Issue(
                            entity=h[:12] + "...",
                            entity_type=f"{snap_type}_snapshot",
                            severity="error",
                            message=f"Hash mismatch: expected {h[:12]}..., computed {computed[:12]}...",
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
            for h in staged_map[snap_type]:
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

        from data.lib.remote.paths import resource_snapshot_dir as _rdir

        snap_dir = _rdir(tmp_root, res_hash)
        (snap_dir / "resources.pb2").write_bytes(b"corrupted data")

        issues = _verify_staged_style(tmp_root, store)
        hash_issues = [i for i in issues if "Hash mismatch" in i.message]
        assert len(hash_issues) >= 1

    def test_verify_missing_metadata_json(self, store: SessionStore, tmp_root: Path) -> None:
        _init_session(store)
        res_hash = _make_resource_snapshot(tmp_root)
        store.add_snapshot("resource", res_hash)

        from data.lib.remote.paths import resource_snapshot_dir as _rdir

        snap_dir = _rdir(tmp_root, res_hash)
        (snap_dir / "metadata.json").unlink()

        issues = _verify_staged_style(tmp_root, store)
        missing = [i for i in issues if "Missing metadata.json" in i.message]
        assert len(missing) >= 1

    def test_verify_missing_pb2(self, store: SessionStore, tmp_root: Path) -> None:
        _init_session(store)
        res_hash = _make_resource_snapshot(tmp_root)
        store.add_snapshot("resource", res_hash)

        from data.lib.remote.paths import resource_snapshot_dir as _rdir

        snap_dir = _rdir(tmp_root, res_hash)
        (snap_dir / "resources.pb2").unlink()

        issues = _verify_staged_style(tmp_root, store)
        missing = [i for i in issues if "Missing resources.pb2" in i.message]
        assert len(missing) >= 1

    def test_verify_blob_missing_detected(self, store: SessionStore, tmp_root: Path) -> None:
        _init_session(store)
        res_hash = _make_resource_snapshot(tmp_root)
        store.add_snapshot("resource", res_hash)

        from data.lib.remote.models import ResourceIndex
        from data.lib.remote.models import read_pb2 as _read_pb2
        from data.lib.remote.paths import resource_snapshot_dir as _rdir

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

        from data.lib.remote.models import ResourceIndex
        from data.lib.remote.models import read_pb2 as _read_pb2
        from data.lib.remote.paths import resource_snapshot_dir as _rdir

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

    def test_verify_announcement_snapshot(self, store: SessionStore, tmp_root: Path) -> None:
        _init_session(store)
        ann_hash = _make_announcement_snapshot(tmp_root)
        store.add_snapshot("announcement", ann_hash)

        issues = _verify_staged_style(tmp_root, store)
        errors = [i for i in issues if i.severity == "error"]
        assert len(errors) == 0


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
            author=store.load().author,
            timestamp=utc_timestamp(),
            description=store.load().description,
            parent="",
            subject="",
        )

        gen_hash = mgr.create_generation(
            metadata=gen_meta,
            server_index=server_index,
            resources=gen_resources,
            release_pointer=_gen_ptr(),
            announcement_pointer=_gen_ptr(),
        )
        mgr.push("testing", gen_hash)
        store.mark_committed()

        head = mgr.get_head("testing")
        assert head.generation_hash == gen_hash
        assert store.is_committed() is True

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
            author=store.load().author,
            timestamp=utc_timestamp(),
            description=store.load().description,
            parent="",
            subject="",
        )

        mgr.create_generation(
            metadata=gen_meta,
            server_index=server_index,
            resources=gen_resources,
            release_pointer=_gen_ptr(),
            announcement_pointer=_gen_ptr(),
        )
        # Do NOT push — head stays uninitialized
        store.mark_committed()

        head = mgr.get_head("testing")
        assert not head.generation_hash

    def test_commit_no_snapshots(self, store: SessionStore) -> None:
        _init_session(store)
        session = store.load()
        has_snapshots = any(
            [session.staged.resources, session.staged.releases, session.staged.announcements]
        )
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

        assert store.is_committed() is True
        session = store.load()
        assert session.committed is True

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
            author="pipeline",
            timestamp=utc_timestamp(),
            description="idempotent test",
            parent="",
            subject="",
        )

        gen_hash1 = mgr.create_generation(
            metadata=gen_meta,
            server_index=server_index,
            resources=gen_resources,
            release_pointer=_gen_ptr(),
            announcement_pointer=_gen_ptr(),
        )

        gen_hash2 = mgr.create_generation(
            metadata=gen_meta,
            server_index=server_index,
            resources=gen_resources,
            release_pointer=_gen_ptr(),
            announcement_pointer=_gen_ptr(),
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
            author=store.load().author,
            timestamp=utc_timestamp(),
            description=store.load().description,
            parent="",
            subject="",
        )
        gen_hash = mgr.create_generation(
            metadata=gen_meta,
            server_index=server_index,
            resources=gen_resources,
            release_pointer=release_ptr,
            announcement_pointer=_gen_ptr(),
        )
        mgr.push("testing", gen_hash)

        gen = mgr.load_generation(gen_hash)
        assert gen.release_pointer.snapshot_hash == rel_hash

    def test_commit_with_announcement_snapshot(
        self, store: SessionStore, mgr: SessionManager, tmp_root: Path
    ) -> None:
        _init_session(store)
        mgr.ensure_channel("testing")
        res_hash = _make_resource_snapshot(tmp_root)
        ann_hash = _make_announcement_snapshot(tmp_root)
        store.add_snapshot("resource", res_hash)
        store.add_snapshot("announcement", ann_hash)

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

        announcement_ptr = _gen_ptr(ann_hash)

        gen_meta = GenerationMetadata(
            channel="testing",
            author=store.load().author,
            timestamp=utc_timestamp(),
            description=store.load().description,
            parent="",
            subject="",
        )
        gen_hash = mgr.create_generation(
            metadata=gen_meta,
            server_index=server_index,
            resources=gen_resources,
            release_pointer=_gen_ptr(),
            announcement_pointer=announcement_ptr,
        )
        mgr.push("testing", gen_hash)

        gen = mgr.load_generation(gen_hash)
        assert gen.announcement_pointer.snapshot_hash == ann_hash

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
            author=store.load().author,
            timestamp=utc_timestamp(),
            description=store.load().description,
            parent="",
            subject="",
        )
        gen_hash = mgr.create_generation(
            metadata=gen_meta,
            server_index=server_index,
            resources=gen_resources,
            release_pointer=_gen_ptr(),
            announcement_pointer=_gen_ptr(),
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
        _init_session(store, channel="stable", author="admin", description="E2E workflow test")
        mgr.ensure_channel("stable")
        session = store.load()
        assert session.channel == "stable"
        assert session.author == "admin"

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
            author=store.load().author,
            timestamp=utc_timestamp(),
            description=store.load().description,
            parent="",
            subject="",
        )
        gen_hash = mgr.create_generation(
            metadata=gen_meta,
            server_index=server_index,
            resources=gen_resources,
            release_pointer=release_ptr,
            announcement_pointer=_gen_ptr(),
        )
        mgr.push("stable", gen_hash)
        store.mark_committed()

        assert store.is_committed() is True
        session = store.load()
        assert session.committed is True

        head = mgr.get_head("stable")
        assert head.generation_hash == gen_hash

        store.discard(force=True)
        assert not store.session_path.is_file()


# ===========================================================================
# 10. Edge case / regression tests
# ===========================================================================


class TestSessionEdgeCases:
    def test_double_init_force_overwrite_clears_staged(self, store: SessionStore) -> None:
        _init_session(store)
        store.add_snapshot("resource", "aaa")
        store.add_snapshot("release", "bbb")

        store.init(channel="testing", author="dev", description="fresh", force_overwrite=True)
        session = store.load()
        assert session.staged.resources == []
        assert session.staged.releases == []
        assert session.staged.announcements == []

    def test_session_roundtrip_json_alias(self, store: SessionStore) -> None:
        _init_session(store, channel="stable", author="bot", description="alias test")
        store.add_snapshot("resource", "res-hash")
        store.add_snapshot("announcement", "ann-hash")

        raw = store.session_path.read_text(encoding="utf-8")
        data = json.loads(raw)

        assert data["schemaVersion"] == 1
        assert data["channel"] == "stable"
        assert data["author"] == "bot"
        assert data["committed"] is False
        assert "resources" in data["staged"]

        revalidated = Session.model_validate_json(raw)
        assert revalidated.staged.resources == ["res-hash"]
        assert revalidated.staged.announcements == ["ann-hash"]

    def test_corrupt_session_file_handling(self, store: SessionStore) -> None:
        _init_session(store)
        store.session_path.write_text("{{{ invalid json", encoding="utf-8")
        assert store.exists() is False

    def test_ensure_editable_after_mark_committed(self, store: SessionStore) -> None:
        _init_session(store)
        store.mark_committed()
        with pytest.raises(SessionManagerCommittedError):
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
