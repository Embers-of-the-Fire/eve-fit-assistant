"""Tests for GC stage 05 — history reachability root, non-head history
stripping, and generation-retention policy (spec §8.1, §8.2, §8.3)."""

from __future__ import annotations

import shutil
import tempfile

from pathlib import Path

import pytest

from bootstrap.remote.blob import BlobStore
from bootstrap.remote.gc import GarbageCollector
from bootstrap.remote.generation import GenerationStore
from bootstrap.remote.hash import content_hash
from bootstrap.remote.hash import ident_hash
from bootstrap.remote.head import ChannelHeadStore
from bootstrap.remote.models import GenerationMetadata
from bootstrap.remote.models import GenerationPointer
from bootstrap.remote.models import GenerationResources
from bootstrap.remote.models import ResourceSnapshotMetadata
from bootstrap.remote.models import ServerIndex
from bootstrap.remote.models import make_resource_index
from bootstrap.remote.paths import generation_dir
from bootstrap.remote.paths import resource_snapshot_dir
from bootstrap.remote.snapshot import SnapshotStore


@pytest.fixture
def tmp_root() -> Path:
    d = tempfile.mkdtemp(prefix="efa-gc-hist-")
    yield Path(d)
    shutil.rmtree(d, ignore_errors=True)


def _make_resource_snapshot(
    snap_store: SnapshotStore,
    blob_store: BlobStore,
    server_id: str,
    tag: str,
) -> tuple[str, str, str]:
    rid = f"resource://{server_id}/{tag}.bin"
    ihash = ident_hash(rid)
    data = f"blob-{server_id}-{tag}".encode()
    chash = content_hash(data)
    meta = ResourceSnapshotMetadata(
        serverId=server_id,
        gameBuild=f"build-{tag}",
        gameVersion=f"v{tag}",
        resourceCount=1,
        createdAt="2026-06-14T12:00:00Z",
        description=tag,
    )
    index = make_resource_index([(rid, chash, len(data))])
    snap_hash = snap_store.create_resource_snapshot(meta, index)
    blob_store.store(data, ihash)
    return snap_hash, ihash, chash


def _create_generation(
    gen_store: GenerationStore,
    server_id: str,
    snap_hash: str,
    parent: str | None,
    ts: str,
) -> str:
    gen_meta = GenerationMetadata(channel="testing", timestamp=ts, parent=parent)

    server_index = ServerIndex()
    server_index.schema_version = 1
    srv = server_index.servers.add()
    srv.server_id = server_id
    srv.game_build = "1.0.0"
    srv.game_version = "v1.0.0"

    resources = GenerationResources()
    resources.schema_version = 1
    r = resources.entries.add()
    r.server_id = server_id
    r.snapshot_hash = snap_hash

    release_ptr = GenerationPointer()
    release_ptr.schema_version = 1
    release_ptr.snapshot_hash = ""

    return gen_store.create(
        metadata=gen_meta,
        server_index_msg=server_index,
        resources_msg=resources,
        release_pointer=release_ptr,
    )


def _build_chain(
    tmp_root: Path,
    n: int,
    server_id: str = "tranquility",
) -> list[tuple[str, str, str, str]]:
    """Build *n* generations in a parent chain (oldest first), advancing the
    head to the tip. Returns ``(gen_hash, snap_hash, ident_hash, content_hash)``
    per generation in creation order (head last)."""
    snap_store = SnapshotStore(tmp_root)
    blob_store = BlobStore(tmp_root)
    gen_store = GenerationStore(tmp_root)
    head_store = ChannelHeadStore(tmp_root)
    head_store.ensure_channel("testing")

    gens: list[tuple[str, str, str, str]] = []
    parent: str | None = None
    for i in range(n):
        tag = f"{i:02d}"
        snap_hash, ihash, chash = _make_resource_snapshot(snap_store, blob_store, server_id, tag)
        gen_hash = _create_generation(
            gen_store, server_id, snap_hash, parent, f"2026-06-14T12:00:{tag}Z"
        )
        head_store.push("testing", gen_hash)
        parent = gen_hash
        gens.append((gen_hash, snap_hash, ihash, chash))
    return gens


def _remaining_generations(tmp_root: Path) -> set[str]:
    refs = tmp_root / "channels" / "refs"
    return {d.name for d in refs.iterdir() if d.is_dir() and not d.name.startswith("tmp")}


class TestHistoryReachabilityRoot:
    def test_snapshot_survives_introducer_removal(self, tmp_root: Path) -> None:
        """§8.1: a snapshot listed in head history stays reachable even when its
        introducing generation is removed."""
        gens = _build_chain(tmp_root, 2)
        (g1, s1, ih1, ch1), (_g2, s2, _ih2, _ch2) = gens

        shutil.rmtree(generation_dir(tmp_root, g1))

        reachable = GarbageCollector(tmp_root).collect_reachable()

        assert s1 in reachable.resource_snapshots
        assert s2 in reachable.resource_snapshots
        assert (ih1, ch1) in reachable.blobs

    def test_no_history_head_falls_back_to_full_chain(self, tmp_root: Path) -> None:
        """§8.1 step 4 / §8.3 test 4: a pre-feature head (no history.pb2) falls
        back to the full parent-chain walk so nothing is wrongly pruned."""
        gens = _build_chain(tmp_root, 2)
        head_hash = gens[1][0]
        (generation_dir(tmp_root, head_hash) / "history.pb2").unlink()

        gc = GarbageCollector(tmp_root)
        reachable = gc.collect_reachable()

        assert gens[0][0] in reachable.generations
        assert gens[1][0] in reachable.generations
        assert gens[0][1] in reachable.resource_snapshots
        assert gens[1][1] in reachable.resource_snapshots

        gc.prune()
        assert generation_dir(tmp_root, gens[0][0]).is_dir()
        assert generation_dir(tmp_root, gens[1][0]).is_dir()


class TestNonHeadHistoryStripping:
    def test_strip_nonhead_history(self, tmp_root: Path) -> None:
        """§8.2: after prune only head generations retain history.pb2; non-head
        retained generations do not; dry_run lists but does not delete."""
        gens = _build_chain(tmp_root, 3)
        g_old, g_mid, g_head = gens[0][0], gens[1][0], gens[2][0]

        gc = GarbageCollector(tmp_root, retention_depth=2)  # keep all three

        deleted = gc.prune(dry_run=True)
        for g in (g_mid, g_old):
            path = generation_dir(tmp_root, g) / "history.pb2"
            assert str(path) in deleted
            assert path.is_file()

        gc.prune()
        assert (generation_dir(tmp_root, g_head) / "history.pb2").is_file()
        for g in (g_mid, g_old):
            assert not (generation_dir(tmp_root, g) / "history.pb2").is_file()
            assert generation_dir(tmp_root, g).is_dir()


class TestRetentionPolicy:
    def test_head_only_prunes_intermediates_keeps_snapshots(self, tmp_root: Path) -> None:
        """§8.3 test 1: head-only policy prunes intermediate generations while
        every snapshot in head history (and its blobs) stays reachable."""
        gens = _build_chain(tmp_root, 3)
        gc = GarbageCollector(tmp_root)  # head-only

        reachable = gc.collect_reachable()
        for _g, s, ih, ch in gens:
            assert s in reachable.resource_snapshots
            assert (ih, ch) in reachable.blobs

        gc.prune()
        assert _remaining_generations(tmp_root) == {gens[-1][0]}
        for _g, s, _ih, _ch in gens:
            assert resource_snapshot_dir(tmp_root, s).is_dir()

    def test_head_plus_n_retains_n_plus_one(self, tmp_root: Path) -> None:
        """§8.3 test 2: head + last N keeps exactly N+1 generations."""
        gens = _build_chain(tmp_root, 4)
        GarbageCollector(tmp_root, retention_depth=1).prune()

        remaining = _remaining_generations(tmp_root)
        assert len(remaining) == 2
        assert gens[-1][0] in remaining
        assert gens[-2][0] in remaining
        assert gens[0][0] not in remaining

    def test_orphan_pruned_history_snapshot_kept(self, tmp_root: Path) -> None:
        """§8.3 test 3: a snapshot referenced only by a pruned generation but
        present in head history is kept; one referenced by neither is pruned."""
        gens = _build_chain(tmp_root, 2)
        snap_store = SnapshotStore(tmp_root)
        blob_store = BlobStore(tmp_root)
        orphan, _oih, _och = _make_resource_snapshot(snap_store, blob_store, "tranquility", "zz")

        GarbageCollector(tmp_root).prune()  # head-only

        # gen0 is pruned, but its snapshot lives on in the head history.
        assert gens[0][0] not in _remaining_generations(tmp_root)
        assert resource_snapshot_dir(tmp_root, gens[0][1]).is_dir()
        # the orphan is referenced by neither a generation nor the history.
        assert not resource_snapshot_dir(tmp_root, orphan).is_dir()
