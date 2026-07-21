"""Tests for the V2 ResourceManager — cross-snapshot blob dedup + differential upload.

Locks in the spec §8 behavioral guarantees: dedup, existing-skip, summary math,
progress no-op equivalence, and parallel safety. All tests run with
``Publisher(origin_dir=...)`` (local filesystem transport) so no ``mc`` binary, S3,
or network is required — ``_remote_exists`` and ``_upload_file`` both resolve to
local-fs operations in this mode.
"""

from __future__ import annotations

import random
import threading

from concurrent.futures import ThreadPoolExecutor
from concurrent.futures import as_completed
from typing import TYPE_CHECKING
from unittest import mock

import pytest

from bootstrap.remote.generation import GenerationMetadata
from bootstrap.remote.generation import GenerationStore
from bootstrap.remote.hash import content_hash
from bootstrap.remote.hash import ident_hash
from bootstrap.remote.head import ChannelHeadStore
from bootstrap.remote.models import ReleaseSnapshotMetadata
from bootstrap.remote.models import ResourceIndex
from bootstrap.remote.models import ResourceSnapshotMetadata
from bootstrap.remote.models import make_generation_pointer
from bootstrap.remote.models import make_generation_resources
from bootstrap.remote.models import make_release_index
from bootstrap.remote.models import make_server_index
from bootstrap.remote.paths import blob_path
from bootstrap.remote.publish import Publisher
from bootstrap.remote.resource_manager import ResourceManager
from bootstrap.remote.snapshot import SnapshotStore


if TYPE_CHECKING:
    from pathlib import Path


_PREFIX = "efa/v2/"


# ---------------------------------------------------------------------------
# Helpers / fixtures
# ---------------------------------------------------------------------------


def make_origin(tmp_path: Path) -> Path:
    """Return an empty origin (remote) dir."""
    origin = tmp_path / "origin"
    origin.mkdir(parents=True, exist_ok=True)
    return origin


def make_publisher(tmp_path: Path) -> tuple[Publisher, Path, Path]:
    """Build a Publisher in origin mode; return (publisher, local_root, origin_dir)."""
    local_root = tmp_path / "local"
    local_root.mkdir(parents=True, exist_ok=True)
    origin = make_origin(tmp_path)
    return Publisher(local_root, origin_dir=origin), local_root, origin


def make_blob(local_root: Path, resource_id: str, chash: str, data: bytes) -> Path:
    """Write ``blob_path(local_root, ident_hash(resource_id), chash)`` and return it."""
    bpath = blob_path(local_root, ident_hash(resource_id), chash)
    bpath.parent.mkdir(parents=True, exist_ok=True)
    bpath.write_bytes(data)
    return bpath


def remote_blob_path(resource_id: str, chash: str) -> str:
    """The content-addressed remote key for a blob (matches the publisher)."""
    ihash = ident_hash(resource_id)
    return _PREFIX + f"assets/blobs/{ihash[:2]}/{ihash}/{chash}"


def seed_remote_blob(origin_dir: Path, remote_path: str, data: bytes) -> None:
    """Pre-create a blob under the origin so ``_remote_exists`` returns True."""
    dst = origin_dir / remote_path
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_bytes(data)


def blob_puts(spy: mock.MagicMock) -> list[str]:
    """Remote paths of blob PUTs recorded by a wrapped ``_upload_file`` spy."""
    return [c.args[1] for c in spy.call_args_list if "/assets/blobs/" in c.args[1]]


# ---------------------------------------------------------------------------
# Unit tests — ResourceManager
# ---------------------------------------------------------------------------


class TestResourceManager:
    def test_dedup_single_pass(self, tmp_path: Path) -> None:
        pub, local_root, _origin = make_publisher(tmp_path)
        data = b"shared-bytes"
        chash = content_hash(data)
        make_blob(local_root, "resource://dup.bin", chash, data)
        remote = remote_blob_path("resource://dup.bin", chash)
        local = blob_path(local_root, ident_hash("resource://dup.bin"), chash)

        rm = ResourceManager(pub, show_progress=False)
        with mock.patch.object(pub, "_upload_file", wraps=pub._upload_file) as spy:
            rm.process_blob(local, remote)
            rm.process_blob(local, remote)

        assert rm.total_registered == 2
        assert rm.unique_count == 1
        assert spy.call_count == 1

    def test_existing_skip(self, tmp_path: Path) -> None:
        pub, local_root, origin = make_publisher(tmp_path)
        data = b"already-there"
        chash = content_hash(data)
        make_blob(local_root, "resource://exists.bin", chash, data)
        remote = remote_blob_path("resource://exists.bin", chash)
        local = blob_path(local_root, ident_hash("resource://exists.bin"), chash)
        seed_remote_blob(origin, remote, data)

        rm = ResourceManager(pub, show_progress=False)
        with mock.patch.object(pub, "_upload_file", wraps=pub._upload_file) as spy:
            rm.process_blob(local, remote)

        assert spy.call_count == 0
        assert rm.existing == 1
        assert rm.uploaded == 1

    def test_new_upload(self, tmp_path: Path) -> None:
        pub, local_root, origin = make_publisher(tmp_path)
        data = b"fresh-bytes"
        chash = content_hash(data)
        make_blob(local_root, "resource://new.bin", chash, data)
        remote = remote_blob_path("resource://new.bin", chash)
        local = blob_path(local_root, ident_hash("resource://new.bin"), chash)

        rm = ResourceManager(pub, show_progress=False)
        rm.process_blob(local, remote)

        assert rm.existing == 0
        assert rm.uploaded == 1
        dst = origin / remote
        assert dst.is_file()
        assert dst.read_bytes() == data

    def test_summary_math(self, tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
        pub, local_root, origin = make_publisher(tmp_path)

        for i in range(2):
            data = f"existing-{i}".encode()
            chash = content_hash(data)
            rid = f"resource://exist-{i}.bin"
            make_blob(local_root, rid, chash, data)
            remote = remote_blob_path(rid, chash)
            seed_remote_blob(origin, remote, data)
        for i in range(3):
            data = f"new-{i}".encode()
            chash = content_hash(data)
            rid = f"resource://new-{i}.bin"
            make_blob(local_root, rid, chash, data)

        rm = ResourceManager(pub, show_progress=False)
        for i in range(2):
            data = f"existing-{i}".encode()
            chash = content_hash(data)
            rid = f"resource://exist-{i}.bin"
            local = blob_path(local_root, ident_hash(rid), chash)
            rm.process_blob(local, remote_blob_path(rid, chash))
        for i in range(3):
            data = f"new-{i}".encode()
            chash = content_hash(data)
            rid = f"resource://new-{i}.bin"
            local = blob_path(local_root, ident_hash(rid), chash)
            rm.process_blob(local, remote_blob_path(rid, chash))

        capsys.readouterr()
        rm.log_summary()
        out = capsys.readouterr().out

        parsed = _parse_summary(out)
        assert parsed["unique"] == rm.unique_count == 5
        assert parsed["existing"] == rm.existing == 2
        assert parsed["uploaded"] == rm.uploaded - rm.existing == 3

    def test_progress_noop_equiv(self, tmp_path: Path) -> None:
        _pub, local_root, _origin = make_publisher(tmp_path)
        blobs: list[tuple[Path, str]] = []
        for i in range(6):
            data = f"blob-{i}".encode()
            chash = content_hash(data)
            rid = f"resource://p-{i}.bin"
            local = make_blob(local_root, rid, chash, data)
            blobs.append((local, remote_blob_path(rid, chash)))

        def run(show: bool) -> tuple[int, int, int, int]:
            pub2, _root, _orig = make_publisher(tmp_path / f"run-{show}")
            rm = ResourceManager(pub2, expected_total=len(blobs), show_progress=show)
            with rm.progress():
                for local, remote in blobs:
                    rm.process_blob(local, remote)
            return (rm.total_registered, rm.unique_count, rm.existing, rm.uploaded)

        assert run(False) == run(True)

    def test_progress_closes_on_error(self, tmp_path: Path) -> None:
        pub, local_root, _origin = make_publisher(tmp_path)
        data = b"boom"
        chash = content_hash(data)
        rid = "resource://boom.bin"
        local = make_blob(local_root, rid, chash, data)
        remote = remote_blob_path(rid, chash)

        rm = ResourceManager(pub, show_progress=True)
        with (
            mock.patch.object(pub, "_upload_file", side_effect=RuntimeError("forced")),
            pytest.raises(RuntimeError, match="forced"),
            rm.progress(),
        ):
            rm.process_blob(local, remote)

        assert rm._bar is None

    def test_parallel_safety(self, tmp_path: Path) -> None:
        pub, _local_root, _origin = make_publisher(tmp_path)

        unique_paths = [remote_blob_path(f"resource://par-{i}.bin", "0" * 64) for i in range(250)]
        existing = {p for idx, p in enumerate(unique_paths) if idx % 2 == 0}

        put_count = 0
        put_lock = threading.Lock()

        def fake_remote_exists(remote_path: str) -> bool:
            return remote_path in existing

        def fake_upload_file(src: Path, remote_path: str, **kwargs: object) -> None:
            nonlocal put_count
            with put_lock:
                put_count += 1

        pub._remote_exists = fake_remote_exists  # type: ignore[method-assign]
        pub._upload_file = fake_upload_file  # type: ignore[method-assign]

        dispatch = unique_paths * 2
        random.Random(1234).shuffle(dispatch)

        rm = ResourceManager(pub, show_progress=False)
        dummy = tmp_path / "dummy"
        with ThreadPoolExecutor(max_workers=8) as ex:
            futures = [ex.submit(rm.process_blob, dummy, remote) for remote in dispatch]
            for fut in as_completed(futures):
                fut.result()

        assert rm.total_registered == 500
        assert rm.unique_count == 250
        assert rm.uploaded == rm.unique_count
        assert rm.existing == 125
        assert put_count == 125
        assert rm.existing + put_count == rm.unique_count


# ---------------------------------------------------------------------------
# Integration tests — Publisher end-to-end (origin mode)
# ---------------------------------------------------------------------------


def _build_shared_blob_generation(root: Path) -> dict[str, str]:
    """Generation with two resource snapshots sharing one blob + a release APK blob."""
    snap_store = SnapshotStore(root)
    gen_store = GenerationStore(root)
    head_store = ChannelHeadStore(root)

    shared_data = b"shared-resource-bytes"
    shared_chash = content_hash(shared_data)
    make_blob(root, "resource://shared.bin", shared_chash, shared_data)

    a_data = b"unique-a-bytes"
    a_chash = content_hash(a_data)
    make_blob(root, "resource://a.bin", a_chash, a_data)

    b_data = b"unique-b-bytes"
    b_chash = content_hash(b_data)
    make_blob(root, "resource://b.bin", b_chash, b_data)

    apk_data = b"apk-artifact-bytes"
    apk_chash = content_hash(apk_data)
    apk_id = "release://1.0.0/android/general"
    make_blob(root, apk_id, apk_chash, apk_data)

    idx_a = ResourceIndex()
    idx_a.schema_version = 1
    for rid, ch, data in (
        ("resource://shared.bin", shared_chash, shared_data),
        ("resource://a.bin", a_chash, a_data),
    ):
        e = idx_a.entries.add()
        e.resource_id = rid
        e.content_hash = ch
        e.size = len(data)

    idx_b = ResourceIndex()
    idx_b.schema_version = 1
    for rid, ch, data in (
        ("resource://shared.bin", shared_chash, shared_data),
        ("resource://b.bin", b_chash, b_data),
    ):
        e = idx_b.entries.add()
        e.resource_id = rid
        e.content_hash = ch
        e.size = len(data)

    meta = ResourceSnapshotMetadata(
        serverId="srvA",
        gameBuild="1.0",
        gameVersion="Test",
        resourceCount=2,
        createdAt="2026-01-01T00:00:00Z",
    )
    snap_a = snap_store.create_resource_snapshot(meta, idx_a)
    meta_b = ResourceSnapshotMetadata(
        serverId="srvB",
        gameBuild="1.0",
        gameVersion="Test",
        resourceCount=2,
        createdAt="2026-01-01T00:00:00Z",
    )
    snap_b = snap_store.create_resource_snapshot(meta_b, idx_b)

    rel_index = make_release_index(
        release_id="rel-001",
        version="1.0.0",
        android={
            "general": {"identifier": apk_id, "content_hash": apk_chash, "size": len(apk_data)}
        },
    )
    rel_meta = ReleaseSnapshotMetadata(
        releaseCount=1,
        createdAt="2026-01-01T00:00:00Z",
    )
    release_snap = snap_store.create_release_snapshot(rel_meta, rel_index)

    server_index = make_server_index(
        [
            ("srvA", {"en": "Server A"}, "1.0", "Test", "", "", ""),
            ("srvB", {"en": "Server B"}, "1.0", "Test", "", "", ""),
        ]
    )
    resources = make_generation_resources([("srvA", snap_a), ("srvB", snap_b)])
    release_ptr = make_generation_pointer(release_snap)
    gen_meta = GenerationMetadata(channel="stable", timestamp="2026-01-01T00:00:00Z")
    gen_hash = gen_store.create(gen_meta, server_index, resources, release_ptr)

    head_store.ensure_channel("stable")
    head_store.push("stable", gen_hash)

    return {
        "snap_a": snap_a,
        "snap_b": snap_b,
        "release_snap": release_snap,
        "gen_hash": gen_hash,
        "apk_remote": remote_blob_path(apk_id, apk_chash),
        "shared_remote": remote_blob_path("resource://shared.bin", shared_chash),
    }


def _build_apk_dedup_generation(root: Path) -> dict[str, str]:
    """Generation where a resource blob is byte-identical to the release APK blob."""
    snap_store = SnapshotStore(root)
    gen_store = GenerationStore(root)
    head_store = ChannelHeadStore(root)

    apk_data = b"apk-and-resource-identical"
    apk_chash = content_hash(apk_data)
    apk_id = "release://2.0.0/android/general"
    make_blob(root, apk_id, apk_chash, apk_data)

    idx = ResourceIndex()
    idx.schema_version = 1
    e = idx.entries.add()
    e.resource_id = apk_id
    e.content_hash = apk_chash
    e.size = len(apk_data)

    meta = ResourceSnapshotMetadata(
        serverId="srvA",
        gameBuild="1.0",
        gameVersion="Test",
        resourceCount=1,
        createdAt="2026-01-01T00:00:00Z",
    )
    snap = snap_store.create_resource_snapshot(meta, idx)

    rel_index = make_release_index(
        release_id="rel-002",
        version="2.0.0",
        android={
            "general": {"identifier": apk_id, "content_hash": apk_chash, "size": len(apk_data)}
        },
    )
    rel_meta = ReleaseSnapshotMetadata(releaseCount=1, createdAt="2026-01-01T00:00:00Z")
    release_snap = snap_store.create_release_snapshot(rel_meta, rel_index)

    server_index = make_server_index([("srvA", {"en": "Server A"}, "1.0", "Test", "", "", "")])
    resources = make_generation_resources([("srvA", snap)])
    release_ptr = make_generation_pointer(release_snap)
    gen_meta = GenerationMetadata(channel="stable", timestamp="2026-01-01T00:00:00Z")
    gen_hash = gen_store.create(gen_meta, server_index, resources, release_ptr)

    head_store.ensure_channel("stable")
    head_store.push("stable", gen_hash)

    return {"apk_remote": remote_blob_path(apk_id, apk_chash)}


def _build_inherited_release_generation(root: Path) -> dict[str, str]:
    """Parent generation with resources only; child generation adds a release."""
    snap_store = SnapshotStore(root)
    gen_store = GenerationStore(root)
    head_store = ChannelHeadStore(root)

    a_data = b"unique-a-bytes"
    a_chash = content_hash(a_data)
    b_data = b"unique-b-bytes"
    b_chash = content_hash(b_data)
    make_blob(root, "resource://a.bin", a_chash, a_data)
    make_blob(root, "resource://b.bin", b_chash, b_data)

    idx_a = ResourceIndex()
    idx_a.schema_version = 1
    e = idx_a.entries.add()
    e.resource_id = "resource://a.bin"
    e.content_hash = a_chash
    e.size = len(a_data)
    meta_a = ResourceSnapshotMetadata(
        serverId="srvA",
        gameBuild="1.0",
        gameVersion="Test",
        resourceCount=1,
        createdAt="2026-01-01T00:00:00Z",
    )
    snap_a = snap_store.create_resource_snapshot(meta_a, idx_a)

    idx_b = ResourceIndex()
    idx_b.schema_version = 1
    e = idx_b.entries.add()
    e.resource_id = "resource://b.bin"
    e.content_hash = b_chash
    e.size = len(b_data)
    meta_b = ResourceSnapshotMetadata(
        serverId="srvB",
        gameBuild="1.0",
        gameVersion="Test",
        resourceCount=1,
        createdAt="2026-01-01T00:00:00Z",
    )
    snap_b = snap_store.create_resource_snapshot(meta_b, idx_b)

    server_index = make_server_index(
        [
            ("srvA", {"en": "Server A"}, "1.0", "Test", "", "", ""),
            ("srvB", {"en": "Server B"}, "1.0", "Test", "", "", ""),
        ]
    )
    resources = make_generation_resources([("srvA", snap_a), ("srvB", snap_b)])

    parent_release_ptr = make_generation_pointer("")
    parent_meta = GenerationMetadata(channel="stable", timestamp="2026-01-01T00:00:00Z")
    parent_hash = gen_store.create(parent_meta, server_index, resources, parent_release_ptr)

    apk_data = b"apk-bytes"
    apk_chash = content_hash(apk_data)
    apk_id = "release://1.0.0/android/general"
    make_blob(root, apk_id, apk_chash, apk_data)
    rel_index = make_release_index(
        release_id="rel-001",
        version="1.0.0",
        android={
            "general": {
                "identifier": apk_id,
                "content_hash": apk_chash,
                "size": len(apk_data),
            }
        },
    )
    rel_meta = ReleaseSnapshotMetadata(releaseCount=1, createdAt="2026-01-01T00:00:00Z")
    release_snap = snap_store.create_release_snapshot(rel_meta, rel_index)

    child_release_ptr = make_generation_pointer(release_snap)
    child_meta = GenerationMetadata(
        channel="stable",
        timestamp="2026-01-01T01:00:00Z",
        parent=parent_hash,
    )
    child_hash = gen_store.create(child_meta, server_index, resources, child_release_ptr)

    head_store.ensure_channel("stable")
    head_store.push("stable", child_hash)

    return {
        "parent_hash": parent_hash,
        "child_hash": child_hash,
        "snap_a": snap_a,
        "snap_b": snap_b,
        "release_snap": release_snap,
        "a_remote": remote_blob_path("resource://a.bin", a_chash),
        "b_remote": remote_blob_path("resource://b.bin", b_chash),
        "apk_remote": remote_blob_path(apk_id, apk_chash),
    }


class TestPublisherIntegration:
    def test_publish_only_uploads_changed_snapshots(self, tmp_path: Path) -> None:
        root = tmp_path / "local"
        root.mkdir(parents=True, exist_ok=True)
        origin = make_origin(tmp_path)
        info = _build_inherited_release_generation(root)
        pub = Publisher(root, origin_dir=origin)
        head_store = ChannelHeadStore(root)

        head_store.push("stable", info["parent_hash"])
        with mock.patch.object(pub, "_upload_file", wraps=pub._upload_file) as spy:
            pub.publish_all_for_head("stable")
        parent_puts = blob_puts(spy)
        assert info["a_remote"] in parent_puts
        assert info["b_remote"] in parent_puts
        assert info["apk_remote"] not in parent_puts

        head_store.push("stable", info["child_hash"])
        with mock.patch.object(pub, "_upload_file", wraps=pub._upload_file) as spy:
            pub.publish_all_for_head("stable")
        child_puts = blob_puts(spy)
        assert info["a_remote"] not in child_puts
        assert info["b_remote"] not in child_puts
        assert info["apk_remote"] in child_puts

    def test_publish_dedups_shared_blob(self, tmp_path: Path) -> None:
        root = tmp_path / "local"
        root.mkdir(parents=True, exist_ok=True)
        origin = make_origin(tmp_path)
        info = _build_shared_blob_generation(root)
        pub = Publisher(root, origin_dir=origin)

        with mock.patch.object(pub, "_upload_file", wraps=pub._upload_file) as spy:
            pub.publish_all_for_head("stable")

        puts = blob_puts(spy)
        assert len(puts) == 4
        assert len(set(puts)) == 4
        assert puts.count(info["shared_remote"]) == 1

    def test_publish_uploads_dirs_unchanged(self, tmp_path: Path) -> None:
        root = tmp_path / "local"
        root.mkdir(parents=True, exist_ok=True)
        origin = make_origin(tmp_path)
        info = _build_shared_blob_generation(root)
        pub = Publisher(root, origin_dir=origin)

        pub.publish_all_for_head("stable")

        base = origin / "efa" / "v2"
        assert (base / "assets" / "resources" / info["snap_a"] / "metadata.json").is_file()
        assert (base / "assets" / "resources" / info["snap_b"] / "metadata.json").is_file()
        assert (base / "assets" / "releases" / info["release_snap"] / "metadata.json").is_file()
        assert (base / "channels" / "refs" / info["gen_hash"] / "metadata.json").is_file()
        assert (base / "channels" / "heads" / "stable" / "metadata.json").is_file()

    def test_publish_skips_missing_local_blob_when_remote_exists(self, tmp_path: Path) -> None:
        root = tmp_path / "local"
        root.mkdir(parents=True, exist_ok=True)
        origin = make_origin(tmp_path)
        _build_shared_blob_generation(root)
        pub = Publisher(root, origin_dir=origin)

        pub.publish_all_for_head("stable")

        local_shared = blob_path(
            root,
            ident_hash("resource://shared.bin"),
            content_hash(b"shared-resource-bytes"),
        )
        assert local_shared.is_file()
        local_shared.unlink()

        with mock.patch.object(pub, "_upload_file", wraps=pub._upload_file) as spy:
            pub.publish_all_for_head("stable")

        puts = blob_puts(spy)
        shared_remote = remote_blob_path(
            "resource://shared.bin", content_hash(b"shared-resource-bytes")
        )
        assert shared_remote not in puts

    def test_publish_skips_missing_local_release_blob_when_remote_exists(
        self, tmp_path: Path
    ) -> None:
        root = tmp_path / "local"
        root.mkdir(parents=True, exist_ok=True)
        origin = make_origin(tmp_path)
        _build_apk_dedup_generation(root)
        pub = Publisher(root, origin_dir=origin)

        pub.publish_all_for_head("stable")

        apk_id = "release://2.0.0/android/general"
        apk_chash = content_hash(b"apk-and-resource-identical")
        local_apk = blob_path(root, ident_hash(apk_id), apk_chash)
        assert local_apk.is_file()
        local_apk.unlink()

        with mock.patch.object(pub, "_upload_file", wraps=pub._upload_file) as spy:
            pub.publish_all_for_head("stable")

        puts = blob_puts(spy)
        assert remote_blob_path(apk_id, apk_chash) not in puts

    def test_publish_fails_when_blob_missing_everywhere(self, tmp_path: Path) -> None:
        root = tmp_path / "local"
        root.mkdir(parents=True, exist_ok=True)
        origin = make_origin(tmp_path)
        _build_shared_blob_generation(root)
        pub = Publisher(root, origin_dir=origin)

        local_shared = blob_path(
            root,
            ident_hash("resource://shared.bin"),
            content_hash(b"shared-resource-bytes"),
        )
        local_shared.unlink()

        with pytest.raises(FileNotFoundError, match="Resource blob missing"):
            pub.publish_all_for_head("stable")

    def test_republish_is_noop(self, tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
        root = tmp_path / "local"
        root.mkdir(parents=True, exist_ok=True)
        origin = make_origin(tmp_path)
        _build_shared_blob_generation(root)
        pub = Publisher(root, origin_dir=origin)

        pub.publish_all_for_head("stable")

        capsys.readouterr()
        with mock.patch.object(pub, "_upload_file", wraps=pub._upload_file) as spy:
            pub.publish_all_for_head("stable")
        out = capsys.readouterr().out

        assert blob_puts(spy) == []
        parsed = _parse_summary(out)
        assert parsed["uploaded"] == 0
        assert parsed["existing"] == parsed["unique"] == 4

    def test_release_blob_via_rm(self, tmp_path: Path) -> None:
        root = tmp_path / "local"
        root.mkdir(parents=True, exist_ok=True)
        origin = make_origin(tmp_path)
        info = _build_apk_dedup_generation(root)
        pub = Publisher(root, origin_dir=origin)

        with mock.patch.object(pub, "_upload_file", wraps=pub._upload_file) as spy:
            pub.publish_all_for_head("stable")

        puts = blob_puts(spy)
        assert puts.count(info["apk_remote"]) == 1
        assert len(puts) == 1
        assert (origin / info["apk_remote"]).is_file()


# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------


def _parse_summary(out: str) -> dict[str, int]:
    """Extract the integer fields from a ``log_summary`` block."""
    result: dict[str, int] = {}
    for line in out.splitlines():
        stripped = line.strip()
        if stripped.startswith("Unique blobs after dedup:"):
            result["unique"] = int(stripped.rsplit(maxsplit=1)[-1])
        elif stripped.startswith("Existing on remote:"):
            result["existing"] = int(stripped.rsplit(maxsplit=1)[-1])
        elif stripped.startswith("Uploaded:"):
            result["uploaded"] = int(stripped.rsplit(maxsplit=1)[-1])
    return result
