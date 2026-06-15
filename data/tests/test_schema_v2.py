"""Tests for the EFA V2 schema modules (data/lib/remote/).

Covers: hash engine, blob store, snapshot store, generation store,
channel head store, GC reachability, and verification.
"""

from __future__ import annotations

import shutil
import tempfile

from pathlib import Path

import pytest

from data.lib.remote.blob import BlobStore
from data.lib.remote.gc import GarbageCollector
from data.lib.remote.generation import GenerationStore
from data.lib.remote.hash import content_hash
from data.lib.remote.hash import generation_hash
from data.lib.remote.hash import ident_hash
from data.lib.remote.hash import snapshot_hash
from data.lib.remote.head import ChannelHeadStore
from data.lib.remote.models import AnnouncementSnapshotMetadata
from data.lib.remote.models import GenerationMetadata
from data.lib.remote.models import GenerationPointer
from data.lib.remote.models import GenerationResources
from data.lib.remote.models import ReachabilitySet
from data.lib.remote.models import ReleaseSnapshotMetadata
from data.lib.remote.models import ResourceSnapshotMetadata
from data.lib.remote.models import ServerIndex
from data.lib.remote.models import make_resource_index
from data.lib.remote.paths import blob_path
from data.lib.remote.paths import generation_dir
from data.lib.remote.paths import resource_snapshot_dir
from data.lib.remote.snapshot import SnapshotStore
from data.lib.remote.verify import Issue
from data.lib.remote.verify import Verifier


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture
def tmp_root() -> Path:
    d = tempfile.mkdtemp(prefix="efa-test-")
    yield Path(d)
    shutil.rmtree(d, ignore_errors=True)


@pytest.fixture
def blob_store(tmp_root: Path) -> BlobStore:
    return BlobStore(tmp_root)


@pytest.fixture
def snap_store(tmp_root: Path) -> SnapshotStore:
    return SnapshotStore(tmp_root)


@pytest.fixture
def gen_store(tmp_root: Path) -> GenerationStore:
    return GenerationStore(tmp_root)


@pytest.fixture
def head_store(tmp_root: Path) -> ChannelHeadStore:
    return ChannelHeadStore(tmp_root)


# ---------------------------------------------------------------------------
# Hash engine
# ---------------------------------------------------------------------------


class TestHashEngine:
    def test_ident_hash_deterministic(self) -> None:
        uri = "resource://tranquility/proto/ships.bin"
        assert ident_hash(uri) == ident_hash(uri)
        assert len(ident_hash(uri)) == 64

    def test_ident_hash_different_uris(self) -> None:
        a = ident_hash("resource://tranquility/proto/ships.bin")
        b = ident_hash("resource://tranquility/proto/items.bin")
        assert a != b

    def test_content_hash(self) -> None:
        data = b"hello world"
        h = content_hash(data)
        assert len(h) == 64
        assert content_hash(data) == content_hash(data)
        assert content_hash(b"different") != h

    def test_snapshot_hash_resource(self) -> None:
        files = {
            "metadata.json": b'{"schemaVersion": 1}',
            "resources.pb2": b"\x00\x01\x02",
        }
        h = snapshot_hash("resource", files)
        assert len(h) == 64

    def test_snapshot_hash_release(self) -> None:
        files = {
            "metadata.json": b'{"schemaVersion": 1}',
            "releases.pb2": b"\x00\x01\x02",
        }
        h = snapshot_hash("release", files)
        assert len(h) == 64

    def test_snapshot_hash_announcement(self) -> None:
        files = {
            "metadata.json": b'{"schemaVersion": 1}',
            "announcements.pb2": b"\x00\x01\x02",
        }
        h = snapshot_hash("announcement", files)
        assert len(h) == 64

    def test_snapshot_hash_deterministic(self) -> None:
        files = {
            "metadata.json": b'{"schemaVersion": 1}',
            "resources.pb2": b"\x00\x01\x02",
        }
        assert snapshot_hash("resource", files) == snapshot_hash("resource", files)

    def test_snapshot_hash_order_independent(self) -> None:
        files1 = {
            "metadata.json": b"md",
            "resources.pb2": b"pb",
        }
        files2 = {
            "resources.pb2": b"pb",
            "metadata.json": b"md",
        }
        assert snapshot_hash("resource", files1) == snapshot_hash("resource", files2)

    def test_generation_hash(self) -> None:
        files = {
            "metadata.json": b'{"schemaVersion": 1}',
            "server.pb2": b"\x00",
            "resources.pb2": b"\x01",
            "releases.pb2": b"\x02",
            "announcements.pb2": b"\x03",
        }
        h = generation_hash(files)
        assert len(h) == 64

    def test_generation_hash_missing_file_raises(self) -> None:
        files = {
            "metadata.json": b"{}",
            "server.pb2": b"",
        }
        with pytest.raises(ValueError, match="Missing"):
            generation_hash(files)

    def test_generation_hash_deterministic(self) -> None:
        files = {
            "metadata.json": b"m",
            "server.pb2": b"s",
            "resources.pb2": b"r",
            "releases.pb2": b"rl",
            "announcements.pb2": b"a",
        }
        assert generation_hash(files) == generation_hash(files)

    def test_generation_hash_order_independent(self) -> None:
        files1 = {
            "metadata.json": b"m",
            "server.pb2": b"s",
            "resources.pb2": b"r",
            "releases.pb2": b"rl",
            "announcements.pb2": b"a",
        }
        # dict order reversed
        keys = list(files1.keys())
        files2 = {k: files1[k] for k in reversed(keys)}
        assert generation_hash(files1) == generation_hash(files2)


# ---------------------------------------------------------------------------
# Blob store
# ---------------------------------------------------------------------------


class TestBlobStore:
    def test_store_returns_content_hash(self, blob_store: BlobStore) -> None:
        data = b"test blob data"
        ihash = ident_hash("resource://test/data.bin")
        chash = blob_store.store(data, ihash)
        assert len(chash) == 64
        assert chash == content_hash(data)

    def test_store_writes_file(self, blob_store: BlobStore, tmp_root: Path) -> None:
        data = b"test blob data"
        ihash = ident_hash("resource://test/data.bin")
        chash = blob_store.store(data, ihash)
        target = blob_path(tmp_root, ihash, chash)
        assert target.is_file()
        assert target.read_bytes() == data

    def test_store_idempotent(self, blob_store: BlobStore) -> None:
        data = b"test blob data"
        ihash = ident_hash("resource://test/data.bin")
        chash1 = blob_store.store(data, ihash)
        chash2 = blob_store.store(data, ihash)
        assert chash1 == chash2

    def test_store_different_content(self, blob_store: BlobStore) -> None:
        ihash = ident_hash("resource://test/data.bin")
        chash1 = blob_store.store(b"content v1", ihash)
        chash2 = blob_store.store(b"content v2", ihash)
        assert chash1 != chash2

    def test_exists(self, blob_store: BlobStore) -> None:
        data = b"test"
        ihash = ident_hash("resource://test/data.bin")
        chash = blob_store.store(data, ihash)
        assert blob_store.exists(ihash, chash)
        assert not blob_store.exists(ihash, "nonexistent")

    def test_read(self, blob_store: BlobStore) -> None:
        data = b"test blob data"
        ihash = ident_hash("resource://test/data.bin")
        chash = blob_store.store(data, ihash)
        assert blob_store.read(ihash, chash) == data

    def test_read_nonexistent_raises(self, blob_store: BlobStore) -> None:
        with pytest.raises(FileNotFoundError):
            blob_store.read("nonexistent", "nonexistent")

    def test_delete(self, blob_store: BlobStore) -> None:
        data = b"test"
        ihash = ident_hash("resource://test/data.bin")
        chash = blob_store.store(data, ihash)
        assert blob_store.exists(ihash, chash)
        blob_store.delete(ihash, chash)
        assert not blob_store.exists(ihash, chash)

    def test_delete_nonexistent_noop(self, blob_store: BlobStore) -> None:
        blob_store.delete("nonexistent", "nonexistent")

    def test_path_for(self, blob_store: BlobStore, tmp_root: Path) -> None:
        ihash = ident_hash("resource://test/data.bin")
        chash = "abc123"
        path = blob_store.path_for(ihash, chash)
        expected = blob_path(tmp_root, ihash, chash)
        assert path == expected

    def test_store_from_path(self, blob_store: BlobStore, tmp_root: Path) -> None:
        data = b"file blob data"
        src = tmp_root / "source.bin"
        src.write_bytes(data)
        ihash = ident_hash("resource://test/source.bin")
        chash = blob_store.store_from_path(src, ihash)
        assert chash == content_hash(data)
        assert blob_store.read(ihash, chash) == data


# ---------------------------------------------------------------------------
# Snapshot store
# ---------------------------------------------------------------------------


class TestSnapshotStore:
    def test_create_resource_snapshot(self, snap_store: SnapshotStore) -> None:
        meta = ResourceSnapshotMetadata(
            serverId="tranquility",
            gameBuild="1.0",
            gameVersion="v1.0.0",
            resourceCount=5,
            createdAt="2026-06-14T12:00:00Z",
        )
        index = make_resource_index(
            [
                ("aa" * 32, "bb" * 32, 1024),
                ("cc" * 32, "dd" * 32, 2048),
            ]
        )
        snap_hash = snap_store.create_resource_snapshot(meta, index)
        assert len(snap_hash) == 64

    def test_create_and_load_resource_snapshot(self, snap_store: SnapshotStore) -> None:
        meta = ResourceSnapshotMetadata(
            serverId="tranquility",
            gameBuild="2.0",
            gameVersion="v2.0.0",
            resourceCount=3,
            createdAt="2026-06-14T12:00:00Z",
        )
        index = make_resource_index([("ee" * 32, "ff" * 32, 512)])
        snap_hash = snap_store.create_resource_snapshot(meta, index)

        loaded_meta, loaded_index = snap_store.load_resource_snapshot(snap_hash)
        assert loaded_meta.server_id == "tranquility"
        assert loaded_meta.game_build == "2.0"
        assert loaded_meta.game_version == "v2.0.0"
        assert loaded_meta.resource_count == 3
        assert len(loaded_index.entries) == 1
        assert loaded_index.entries[0].resource_id == "ee" * 32
        assert loaded_index.entries[0].content_hash == "ff" * 32

    def test_create_release_snapshot(self, snap_store: SnapshotStore) -> None:
        meta = ReleaseSnapshotMetadata(releaseCount=1, createdAt="2026-06-14T12:00:00Z")
        from data.lib.remote.models import make_release_index

        index = make_release_index([("rel-001", "1.0.0", ["android"], "aa" * 32)])
        snap_hash = snap_store.create_release_snapshot(meta, index)
        assert len(snap_hash) == 64

        loaded_meta, loaded_index = snap_store.load_release_snapshot(snap_hash)
        assert loaded_meta.release_count == 1
        assert loaded_index.entries[0].id == "rel-001"

    def test_create_announcement_snapshot(self, snap_store: SnapshotStore) -> None:
        meta = AnnouncementSnapshotMetadata(announcementCount=2, createdAt="2026-06-14T12:00:00Z")
        from data.lib.remote.models import make_announcement_index

        index = make_announcement_index(
            [
                {
                    "id": "ann-001",
                    "first_published_at": "2026-06-14T12:00:00Z",
                    "updated_at": "2026-06-14T12:00:00Z",
                    "content_hashes": {"en": "aa" * 32},
                },
                {
                    "id": "ann-002",
                    "first_published_at": "2026-06-14T12:00:00Z",
                    "updated_at": "2026-06-14T12:00:00Z",
                    "content_hashes": {"en": "bb" * 32},
                    "version_min": "1.0.0",
                    "version_max": "2.0.0",
                    "is_version_update": True,
                },
            ]
        )
        snap_hash = snap_store.create_announcement_snapshot(meta, index)
        assert len(snap_hash) == 64

        loaded_meta, loaded_index = snap_store.load_announcement_snapshot(snap_hash)
        assert loaded_meta.announcement_count == 2
        assert len(loaded_index.entries) == 2

    def test_list_snapshots(self, snap_store: SnapshotStore) -> None:
        meta = ResourceSnapshotMetadata(
            serverId="tranquility",
            gameBuild="1.0",
            gameVersion="v1.0.0",
            resourceCount=1,
            createdAt="2026-06-14T12:00:00Z",
        )
        index = make_resource_index([("gg" * 32, "hh" * 32, 100)])
        snap_store.create_resource_snapshot(meta, index)

        snapshots = snap_store.list_resource_snapshots()
        assert len(snapshots) == 1

    def test_delete_snapshot(self, snap_store: SnapshotStore) -> None:
        meta = ResourceSnapshotMetadata(
            serverId="serenity",
            gameBuild="1.0",
            gameVersion="v1.0.0",
            resourceCount=1,
            createdAt="2026-06-14T12:00:00Z",
        )
        index = make_resource_index([("ii" * 32, "jj" * 32, 100)])
        snap_hash = snap_store.create_resource_snapshot(meta, index)

        assert len(snap_store.list_resource_snapshots()) == 1
        snap_store.delete_resource_snapshot(snap_hash)
        assert len(snap_store.list_resource_snapshots()) == 0

    def test_load_nonexistent_snapshot_raises(self, snap_store: SnapshotStore) -> None:
        with pytest.raises(FileNotFoundError):
            snap_store.load_resource_snapshot("nonexistent")

    def test_snapshot_hash_matches_directory(
        self, snap_store: SnapshotStore, tmp_root: Path
    ) -> None:
        meta = ResourceSnapshotMetadata(
            serverId="tranquility",
            gameBuild="1.0",
            gameVersion="v1.0.0",
            resourceCount=1,
            createdAt="2026-06-14T12:00:00Z",
        )
        index = make_resource_index([("kk" * 32, "ll" * 32, 100)])
        snap_hash = snap_store.create_resource_snapshot(meta, index)

        snap_dir = resource_snapshot_dir(tmp_root, snap_hash)
        assert snap_dir.is_dir()
        assert (snap_dir / "metadata.json").is_file()
        assert (snap_dir / "resources.pb2").is_file()


# ---------------------------------------------------------------------------
# Generation store
# ---------------------------------------------------------------------------


class TestGenerationStore:
    def _make_dummy_gen(self, gen_store: GenerationStore, **kwargs) -> str:
        meta = GenerationMetadata(
            channel="testing",
            timestamp="2026-06-14T12:00:00Z",
            **kwargs,
        )
        server_index = ServerIndex()
        server_index.schema_version = 1
        entry = server_index.servers.add()
        entry.server_id = "tranquility"
        entry.game_build = "1.0.0"
        entry.game_version = "v1.0.0"

        resources = GenerationResources()
        resources.schema_version = 1
        r = resources.entries.add()
        r.server_id = "tranquility"
        r.snapshot_hash = "aa" * 32

        release_ptr = GenerationPointer()
        release_ptr.schema_version = 1
        release_ptr.snapshot_hash = "bb" * 32

        announcement_ptr = GenerationPointer()
        announcement_ptr.schema_version = 1
        announcement_ptr.snapshot_hash = "cc" * 32

        return gen_store.create(
            metadata=meta,
            server_index_msg=server_index,
            resources_msg=resources,
            release_pointer=release_ptr,
            announcement_pointer=announcement_ptr,
        )

    def test_create_generation(self, gen_store: GenerationStore) -> None:
        gen_hash = self._make_dummy_gen(gen_store)
        assert len(gen_hash) == 64

    def test_load_generation(self, gen_store: GenerationStore) -> None:
        gen_hash = self._make_dummy_gen(gen_store)
        gen = gen_store.load(gen_hash)

        assert gen.hash == gen_hash
        assert gen.metadata.channel == "testing"
        assert len(gen.server_index.servers) == 1
        assert gen.server_index.servers[0].server_id == "tranquility"
        assert len(gen.resources.entries) == 1
        assert gen.resources.entries[0].server_id == "tranquility"
        assert gen.release_pointer.snapshot_hash == "bb" * 32
        assert gen.announcement_pointer.snapshot_hash == "cc" * 32

    def test_load_nonexistent_raises(self, gen_store: GenerationStore) -> None:
        with pytest.raises(FileNotFoundError):
            gen_store.load("nonexistent")

    def test_list_all(self, gen_store: GenerationStore) -> None:
        assert len(gen_store.list_all()) == 0
        gen_hash = self._make_dummy_gen(gen_store)
        all_gens = gen_store.list_all()
        assert len(all_gens) == 1
        assert gen_hash in all_gens

    def test_walk_parent_chain_single(self, gen_store: GenerationStore) -> None:
        gen_hash = self._make_dummy_gen(gen_store)
        chain = list(gen_store.walk_parent_chain(gen_hash))
        assert len(chain) == 1
        assert chain[0].hash == gen_hash
        assert chain[0].metadata.parent is None

    def test_walk_parent_chain_multiple(self, gen_store: GenerationStore) -> None:
        gen1 = self._make_dummy_gen(gen_store)
        gen2 = self._make_dummy_gen(gen_store, parent=gen1)
        gen3 = self._make_dummy_gen(gen_store, parent=gen2)

        chain = list(gen_store.walk_parent_chain(gen3))
        assert len(chain) == 3
        assert chain[0].hash == gen3
        assert chain[1].hash == gen2
        assert chain[2].hash == gen1

    def test_delete_generation(self, gen_store: GenerationStore) -> None:
        gen_hash = self._make_dummy_gen(gen_store)
        assert len(gen_store.list_all()) == 1
        gen_store.delete(gen_hash)
        assert len(gen_store.list_all()) == 0

    def test_generation_has_all_five_files(
        self, gen_store: GenerationStore, tmp_root: Path
    ) -> None:
        gen_hash = self._make_dummy_gen(gen_store)
        gen_dir = generation_dir(tmp_root, gen_hash)
        assert (gen_dir / "metadata.json").is_file()
        assert (gen_dir / "server.pb2").is_file()
        assert (gen_dir / "resources.pb2").is_file()
        assert (gen_dir / "releases.pb2").is_file()
        assert (gen_dir / "announcements.pb2").is_file()


# ---------------------------------------------------------------------------
# Channel head store
# ---------------------------------------------------------------------------


class TestChannelHeadStore:
    def test_ensure_channel_creates_registry(self, head_store: ChannelHeadStore) -> None:
        head_store.ensure_channel("testing", {"en": "Testing"})
        registry = head_store.get_registry()
        assert "testing" in registry.channels
        assert registry.channels["testing"].label == {"en": "Testing"}

    def test_ensure_channel_idempotent(self, head_store: ChannelHeadStore) -> None:
        head_store.ensure_channel("testing", {"en": "Testing"})
        head_store.ensure_channel("testing", {"en": "Updated"})
        registry = head_store.get_registry()
        assert registry.channels["testing"].label == {"en": "Testing"}

    def test_set_default(self, head_store: ChannelHeadStore) -> None:
        head_store.ensure_channel("testing", {"en": "Testing"})
        head_store.ensure_channel("stable", {"en": "Stable"})
        head_store.set_default("stable")
        registry = head_store.get_registry()
        assert registry.default_channel == "stable"

    def test_set_default_nonexistent_raises(self, head_store: ChannelHeadStore) -> None:
        with pytest.raises(ValueError, match="not in registry"):
            head_store.set_default("nonexistent")

    def test_get_head_after_ensure(self, head_store: ChannelHeadStore) -> None:
        head_store.ensure_channel("testing")
        head = head_store.get_head("testing")
        assert head.generation_hash == ""

    def test_get_head_nonexistent_raises(self, head_store: ChannelHeadStore) -> None:
        with pytest.raises(FileNotFoundError):
            head_store.get_head("nonexistent")

    def test_push_advances_head(self, head_store: ChannelHeadStore) -> None:
        head_store.ensure_channel("testing")
        gen_hash = "aa" * 32
        head_store.push("testing", gen_hash)
        head = head_store.get_head("testing")
        assert head.generation_hash == gen_hash

    def test_revert_moves_head(self, head_store: ChannelHeadStore) -> None:
        head_store.ensure_channel("testing")
        gen1 = "aa" * 32
        gen2 = "bb" * 32
        head_store.push("testing", gen1)
        head_store.push("testing", gen2)
        head_store.revert("testing", gen1)
        head = head_store.get_head("testing")
        assert head.generation_hash == gen1

    def test_get_reflog(self, head_store: ChannelHeadStore) -> None:
        head_store.ensure_channel("testing")
        gen1 = "aa" * 32
        gen2 = "bb" * 32
        head_store.push("testing", gen1)
        head_store.push("testing", gen2)

        reflog = head_store.get_reflog("testing")
        assert len(reflog.entries) == 2
        assert getattr(reflog.entries[0], "from") == ""
        assert reflog.entries[0].to == gen1
        assert reflog.entries[0].op == "push"
        assert getattr(reflog.entries[1], "from") == gen1
        assert reflog.entries[1].to == gen2
        assert reflog.entries[1].op == "push"

    def test_reflog_records_revert(self, head_store: ChannelHeadStore) -> None:
        head_store.ensure_channel("testing")
        gen1 = "aa" * 32
        gen2 = "bb" * 32
        head_store.push("testing", gen1)
        head_store.push("testing", gen2)
        head_store.revert("testing", gen1)

        reflog = head_store.get_reflog("testing")
        assert len(reflog.entries) == 3
        assert reflog.entries[2].op == "revert"
        assert reflog.entries[2].to == gen1

    def test_get_reflog_empty_for_new_channel(self, head_store: ChannelHeadStore) -> None:
        head_store.ensure_channel("testing")
        reflog = head_store.get_reflog("testing")
        assert len(reflog.entries) == 0


# ---------------------------------------------------------------------------
# Garbage collector
# ---------------------------------------------------------------------------


class TestGarbageCollector:
    def _setup_channel_with_data(self, tmp_root: Path) -> GarbageCollector:
        head_store = ChannelHeadStore(tmp_root)
        gen_store = GenerationStore(tmp_root)
        snap_store = SnapshotStore(tmp_root)
        blob_store = BlobStore(tmp_root)

        # Create resource snapshot with blobs
        rid_a = "resource://a.bin"
        rid_c = "resource://c.bin"
        ihash_a = ident_hash(rid_a)
        ihash_c = ident_hash(rid_c)
        chash_a = content_hash(b"blob data aa")
        chash_c = content_hash(b"blob data cc")

        meta = ResourceSnapshotMetadata(
            serverId="tranquility",
            gameBuild="1.0",
            gameVersion="v1.0.0",
            resourceCount=2,
            createdAt="2026-06-14T12:00:00Z",
        )
        index = make_resource_index(
            [
                (rid_a, chash_a, 100),
                (rid_c, chash_c, 200),
            ]
        )
        snap_hash = snap_store.create_resource_snapshot(meta, index)

        # Store blob data
        blob_store.store(b"blob data aa", ihash_a)
        blob_store.store(b"blob data cc", ihash_c)

        # Create generation
        gen_meta = GenerationMetadata(
            channel="testing",
            timestamp="2026-06-14T12:00:00Z",
        )
        server_index = ServerIndex()
        server_index.schema_version = 1
        srv = server_index.servers.add()
        srv.server_id = "tranquility"
        srv.game_build = "1.0.0"
        srv.game_version = "v1.0.0"

        resources = GenerationResources()
        resources.schema_version = 1
        r = resources.entries.add()
        r.server_id = "tranquility"
        r.snapshot_hash = snap_hash

        release_ptr = GenerationPointer()
        release_ptr.schema_version = 1
        release_ptr.snapshot_hash = "00" * 32

        announcement_ptr = GenerationPointer()
        announcement_ptr.schema_version = 1
        announcement_ptr.snapshot_hash = "00" * 32

        gen_hash = gen_store.create(
            metadata=gen_meta,
            server_index_msg=server_index,
            resources_msg=resources,
            release_pointer=release_ptr,
            announcement_pointer=announcement_ptr,
        )

        # Set up channel head
        head_store.ensure_channel("testing")
        head_store.push("testing", gen_hash)
        return GarbageCollector(tmp_root)

    def test_collect_reachable_finds_entities(self, tmp_root: Path) -> None:
        gc = self._setup_channel_with_data(tmp_root)
        reachable = gc.collect_reachable()
        assert len(reachable.generations) >= 1
        assert len(reachable.resource_snapshots) >= 1
        assert len(reachable.blobs) >= 2

    def test_prune_dry_run_returns_paths(self, tmp_root: Path) -> None:
        gc = self._setup_channel_with_data(tmp_root)
        deleted = gc.prune(dry_run=True)

        # Blob data referenced by the resource index should NOT be pruned
        from data.lib.remote.hash import content_hash

        chash_a = content_hash(b"blob data aa")
        chash_c = content_hash(b"blob data cc")
        for d in deleted:
            assert chash_a not in d
            assert chash_c not in d

    def test_prune_empty_root(self, tmp_root: Path) -> None:
        gc = GarbageCollector(tmp_root)
        deleted = gc.prune()
        assert deleted == []

    def test_collect_reachable_handles_missing_head(self, tmp_root: Path) -> None:
        head_store = ChannelHeadStore(tmp_root)
        head_store.ensure_channel("testing")
        gc = GarbageCollector(tmp_root)
        reachable = gc.collect_reachable()
        assert len(reachable.generations) == 0


# ---------------------------------------------------------------------------
# Verifier
# ---------------------------------------------------------------------------


class TestVerifier:
    def _setup_with_data(self, tmp_root: Path) -> tuple[Verifier, str]:
        snap_store = SnapshotStore(tmp_root)
        gen_store = GenerationStore(tmp_root)
        head_store = ChannelHeadStore(tmp_root)
        blob_store = BlobStore(tmp_root)

        # Store blob first to get real content_hash
        blob_data = b"verifier test blob data"
        blob_rid = "resource://test/verify.bin"
        blob_ihash = ident_hash(blob_rid)
        blob_chash = blob_store.store(blob_data, blob_ihash)

        meta = ResourceSnapshotMetadata(
            serverId="tranquility",
            gameBuild="1.0",
            gameVersion="v1.0.0",
            resourceCount=1,
            createdAt="2026-06-14T12:00:00Z",
        )
        index = make_resource_index([(blob_rid, blob_chash, len(blob_data))])
        snap_hash = snap_store.create_resource_snapshot(meta, index)

        gen_meta = GenerationMetadata(
            channel="testing",
            timestamp="2026-06-14T12:00:00Z",
        )
        server_index = ServerIndex()
        server_index.schema_version = 1
        srv = server_index.servers.add()
        srv.server_id = "tranquility"
        srv.game_build = "1.0.0"
        srv.game_version = "v1.0.0"

        resources = GenerationResources()
        resources.schema_version = 1
        r = resources.entries.add()
        r.server_id = "tranquility"
        r.snapshot_hash = snap_hash

        release_ptr = GenerationPointer()
        release_ptr.schema_version = 1
        release_ptr.snapshot_hash = "00" * 32

        announcement_ptr = GenerationPointer()
        announcement_ptr.schema_version = 1
        announcement_ptr.snapshot_hash = "00" * 32

        gen_hash = gen_store.create(
            metadata=gen_meta,
            server_index_msg=server_index,
            resources_msg=resources,
            release_pointer=release_ptr,
            announcement_pointer=announcement_ptr,
        )
        head_store.ensure_channel("testing")
        head_store.push("testing", gen_hash)

        verifier = Verifier(tmp_root)
        return verifier, gen_hash

    def test_verify_all_passes(self, tmp_root: Path) -> None:
        verifier, _gen_hash = self._setup_with_data(tmp_root)
        result = verifier.verify_all()
        all_issues = result["heads"] + result["generations"] + result["snapshots"] + result["blobs"]
        assert len(all_issues) == 0

    def test_verify_head_integrity(self, tmp_root: Path) -> None:
        verifier, _gen_hash = self._setup_with_data(tmp_root)
        issues = verifier.verify_head_integrity()
        assert len(issues) == 0

    def test_verify_generation_integrity(self, tmp_root: Path) -> None:
        verifier, _gen_hash = self._setup_with_data(tmp_root)
        issues = verifier.verify_generation_integrity()
        assert len(issues) == 0

    def test_verify_snapshot_integrity(self, tmp_root: Path) -> None:
        verifier, _gen_hash = self._setup_with_data(tmp_root)
        issues = verifier.verify_snapshot_integrity()
        assert len(issues) == 0

    def test_issue_dataclass(self) -> None:
        issue = Issue(
            entity="test",
            entity_type="blob",
            severity="error",
            message="test error",
        )
        assert issue.entity == "test"
        assert issue.entity_type == "blob"
        assert issue.severity == "error"

    def test_repair_without_workspace_root_returns_zero(self, tmp_root: Path) -> None:
        verifier = Verifier(tmp_root)
        assert verifier.repair() == 0


# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------


class TestPaths:
    def test_blob_path(self) -> None:
        root = Path("/data")
        ihash = "aabbccddeeff00112233445566778899" * 2
        chash = "ff" * 32
        path = blob_path(root, ihash, chash)
        assert path == root / "assets" / "blobs" / "aa" / ihash / chash

    def test_generation_dir_skips_tmp(self) -> None:
        root = Path("/data")
        path = generation_dir(root, "abc" * 21 + "123")
        assert str(path).startswith(str(root / "channels" / "refs"))


# ---------------------------------------------------------------------------
# ReachabilitySet
# ---------------------------------------------------------------------------


class TestReachabilitySet:
    def test_defaults_empty(self) -> None:
        rs = ReachabilitySet()
        assert rs.generations == set()
        assert rs.resource_snapshots == set()
        assert rs.release_snapshots == set()
        assert rs.announcement_snapshots == set()
        assert rs.blobs == set()

    def test_can_add(self) -> None:
        rs = ReachabilitySet()
        rs.generations.add("gen1")
        rs.resource_snapshots.add("snap1")
        rs.blobs.add(("ihash1", "chash1"))
        assert "gen1" in rs.generations
        assert "snap1" in rs.resource_snapshots
        assert ("ihash1", "chash1") in rs.blobs
