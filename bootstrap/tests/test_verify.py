"""Tests for schema V2 verification functionality."""

from __future__ import annotations

import tempfile

from pathlib import Path

from bootstrap.remote.generation import GenerationMetadata
from bootstrap.remote.generation import GenerationStore
from bootstrap.remote.hash import content_hash
from bootstrap.remote.hash import ident_hash
from bootstrap.remote.hash import snapshot_hash
from bootstrap.remote.hash import snapshot_hash_v4
from bootstrap.remote.hash import verify_snapshot_hash
from bootstrap.remote.head import ChannelHeadStore
from bootstrap.remote.models import ResourceIndex
from bootstrap.remote.models import ResourceSnapshotMetadata
from bootstrap.remote.models import make_generation_pointer
from bootstrap.remote.models import make_generation_resources
from bootstrap.remote.models import make_server_index
from bootstrap.remote.models import read_pb2
from bootstrap.remote.models import write_pb2
from bootstrap.remote.paths import blob_path
from bootstrap.remote.paths import generation_dir
from bootstrap.remote.paths import resource_snapshot_dir
from bootstrap.remote.snapshot import SnapshotStore
from bootstrap.remote.verify import Verifier


class TestVerifierBlobs:
    def test_blob_ok(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)

            rid = "resource://test/file.bin"
            ident = ident_hash(rid)
            content = b"hello world"
            chash = content_hash(content)
            bpath = blob_path(root, ident, chash)
            bpath.parent.mkdir(parents=True, exist_ok=True)
            bpath.write_bytes(content)

            snap_store = SnapshotStore(root)

            index = ResourceIndex()
            index.schema_version = 1
            entry = index.entries.add()
            entry.resource_id = rid
            entry.content_hash = chash
            entry.size = len(content)

            meta = ResourceSnapshotMetadata(
                serverId="test",
                gameBuild="1.0",
                gameVersion="Test",
                resourceCount=1,
                createdAt="2026-01-01T00:00:00Z",
            )
            snap_store.create_resource_snapshot(meta, index)

            verifier = Verifier(root)
            issues = verifier.verify_blob_integrity()
            assert len(issues) == 0

    def test_missing_blob_detected(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)

            rid = "resource://test/missing.bin"
            chash = "f" * 64

            snap_store = SnapshotStore(root)

            index = ResourceIndex()
            index.schema_version = 1
            entry = index.entries.add()
            entry.resource_id = rid
            entry.content_hash = chash
            entry.size = 100

            meta = ResourceSnapshotMetadata(
                serverId="test",
                gameBuild="1.0",
                gameVersion="Test",
                resourceCount=1,
                createdAt="2026-01-01T00:00:00Z",
            )
            snap_store.create_resource_snapshot(meta, index)

            verifier = Verifier(root)
            issues = verifier.verify_blob_integrity()
            assert len(issues) == 1
            assert issues[0].entity_type == "blob"
            assert issues[0].severity == "error"
            assert "Missing blob" in issues[0].message

    def test_hash_mismatch_detected(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)

            rid = "resource://test/corrupt.bin"
            ident = ident_hash(rid)
            content = b"correct content"
            chash = content_hash(content)
            bpath = blob_path(root, ident, chash)
            bpath.parent.mkdir(parents=True, exist_ok=True)
            bpath.write_bytes(b"tampered content")

            snap_store = SnapshotStore(root)

            index = ResourceIndex()
            index.schema_version = 1
            entry = index.entries.add()
            entry.resource_id = rid
            entry.content_hash = chash
            entry.size = len(content)

            meta = ResourceSnapshotMetadata(
                serverId="test",
                gameBuild="1.0",
                gameVersion="Test",
                resourceCount=1,
                createdAt="2026-01-01T00:00:00Z",
            )
            snap_store.create_resource_snapshot(meta, index)

            verifier = Verifier(root)
            issues = verifier.verify_blob_integrity()
            assert len(issues) == 1
            assert issues[0].severity == "error"
            assert "hash mismatch" in issues[0].message.lower()


class TestSnapshotHash:
    def test_snapshot_hash_valid(self):
        files = {
            "metadata.json": b'{"schemaVersion":1,"serverId":"test"}',
        }
        h = snapshot_hash("resource", files)
        assert len(h) == 64
        assert all(c in "0123456789abcdef" for c in h)

    def test_snapshot_hash_deterministic(self):
        files = {
            "metadata.json": b'{"schemaVersion":1}',
        }
        h1 = snapshot_hash("resource", files)
        h2 = snapshot_hash("resource", files)
        assert h1 == h2


class TestSnapshotHashV4:
    """v4 binds the typed .pb2 index in addition to metadata.json (spec §7)."""

    _META = b'{"schemaVersion":1,"serverId":"test"}'
    _PROTO = b"\x08\x01proto-index-bytes"

    def test_deterministic_and_hex(self):
        files = {"metadata.json": self._META, "resources.pb2": self._PROTO}
        h1 = snapshot_hash_v4("resource", files)
        h2 = snapshot_hash_v4("resource", files)
        assert h1 == h2
        assert len(h1) == 64
        assert all(c in "0123456789abcdef" for c in h1)

    def test_known_value_parity(self):
        # Cross-language parity anchor: a payload built from fixed component
        # hashes must produce the same digest as the Dart mirror.
        from bootstrap.remote.hash import HASH_ALGORITHM

        a, b = "a" * 64, "b" * 64
        resource = HASH_ALGORITHM(
            f"efa:resource:v4\nmetadata.json {a}\nresources.pb2 {b}\n".encode()
        ).hexdigest()
        release = HASH_ALGORITHM(
            f"efa:release:v4\nmetadata.json {a}\nreleases.pb2 {b}\n".encode()
        ).hexdigest()
        assert resource == "a76dfbcd80a9457f09b32241c7a9b239de581d1db784786279e59b90a3891c69"
        assert release == "8e3558913730e810d6bcf65fe1ae9b6a859f4166976cc69e94dc60953ee665cd"

    def test_v4_differs_from_v3(self):
        files = {"metadata.json": self._META, "resources.pb2": self._PROTO}
        assert snapshot_hash_v4("resource", files) != snapshot_hash("resource", files)

    def test_tampering_proto_changes_v4_but_not_v3(self):
        base = {"metadata.json": self._META, "resources.pb2": self._PROTO}
        tampered = {"metadata.json": self._META, "resources.pb2": self._PROTO + b"!"}
        # v4 is sensitive to the index; v3 (metadata-only) is not.
        assert snapshot_hash_v4("resource", base) != snapshot_hash_v4("resource", tampered)
        assert snapshot_hash("resource", base) == snapshot_hash("resource", tampered)

    def test_missing_proto_raises(self):
        import pytest

        with pytest.raises(ValueError):
            snapshot_hash_v4("resource", {"metadata.json": self._META})

    def test_domain_separation_between_types(self):
        files = {"metadata.json": self._META}
        res = snapshot_hash_v4("resource", {**files, "resources.pb2": self._PROTO})
        rel = snapshot_hash_v4("release", {**files, "releases.pb2": self._PROTO})
        assert res != rel

    def test_verify_dual_read_accepts_v4_and_v3(self):
        files = {"metadata.json": self._META, "resources.pb2": self._PROTO}
        v4 = snapshot_hash_v4("resource", files)
        v3 = snapshot_hash("resource", files)
        assert verify_snapshot_hash("resource", files, v4)
        assert verify_snapshot_hash("resource", files, v3)
        assert not verify_snapshot_hash("resource", files, "0" * 64)

    def test_verify_v3_only_when_proto_absent(self):
        files = {"metadata.json": self._META}
        v3 = snapshot_hash("resource", files)
        assert verify_snapshot_hash("resource", files, v3)


class TestSnapshotStoreV4RoundTrip:
    """Snapshots created by SnapshotStore are v4-addressed and verify cleanly."""

    def test_create_then_verify(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            snap_store = SnapshotStore(root)

            index = ResourceIndex()
            index.schema_version = 1
            entry = index.entries.add()
            entry.resource_id = "resource://test/file.bin"
            entry.content_hash = "a" * 64
            entry.size = 1

            meta = ResourceSnapshotMetadata(
                serverId="test",
                gameBuild="1.0",
                gameVersion="Test",
                resourceCount=1,
                createdAt="2026-01-01T00:00:00Z",
            )
            snap_hash = snap_store.create_resource_snapshot(meta, index)

            snap_dir = resource_snapshot_dir(root, snap_hash)
            files = {
                "metadata.json": (snap_dir / "metadata.json").read_bytes(),
                "resources.pb2": (snap_dir / "resources.pb2").read_bytes(),
            }
            # Directory name is the v4 hash.
            assert snapshot_hash_v4("resource", files) == snap_hash
            assert verify_snapshot_hash("resource", files, snap_hash)

            verifier = Verifier(root)
            assert verifier.verify_snapshot_integrity() == []


class TestVerifierHistory:
    """Tests for history consistency (§4.3) and reachability (§8.5)."""

    _SERVER_ID = "test-server"

    def _setup(self, root: Path, server_id: str | None = None) -> tuple[str, str]:
        sid = server_id or self._SERVER_ID
        snap_store = SnapshotStore(root)

        meta = ResourceSnapshotMetadata(
            serverId=sid,
            gameBuild="1.0",
            gameVersion="1.0",
            resourceCount=0,
            createdAt="2026-01-01T00:00:00Z",
        )
        index = ResourceIndex()
        index.schema_version = 1
        snap_hash = snap_store.create_resource_snapshot(meta, index)

        gen_store = GenerationStore(root)
        gen_meta = GenerationMetadata(
            channel="stable",
            timestamp="2026-01-01T00:00:00Z",
        )
        server_index = make_server_index(
            [
                (sid, {"en": "Test"}, "1.0", "1.0", "", "", ""),
            ]
        )
        resources = make_generation_resources([(sid, snap_hash)])
        release_ptr = make_generation_pointer("0" * 64)
        gen_hash = gen_store.create(gen_meta, server_index, resources, release_ptr)

        head_store = ChannelHeadStore(root)
        head_store.ensure_channel("stable")
        head_store.push("stable", gen_hash)

        return snap_hash, gen_hash

    # -- History consistency (§4.3) --

    def test_consistent_history(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            self._setup(root)
            verifier = Verifier(root)
            issues = verifier.verify_history_consistency()
            assert len(issues) == 0

    def test_tampered_history(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            _snap_hash, gen_hash = self._setup(root)

            from bootstrap.remote.models import ServerHistory

            history_path = generation_dir(root, gen_hash) / "history.pb2"
            history = read_pb2(history_path, ServerHistory)
            history.servers[0].snapshots[0].snapshot_hash = "a" * 64
            write_pb2(history_path, history)

            verifier = Verifier(root)
            issues = verifier.verify_history_consistency()
            assert len(issues) == 1
            assert issues[0].entity_type == "history"
            assert issues[0].severity == "warning"

    # -- Head history reachability (§8.5) --

    def test_reachable_snapshot(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            self._setup(root)
            verifier = Verifier(root)
            issues = verifier.verify_history_reachability()
            assert len(issues) == 0

    def test_deleted_snapshot(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            snap_hash, _gen_hash = self._setup(root)

            import shutil

            shutil.rmtree(resource_snapshot_dir(root, snap_hash))

            verifier = Verifier(root)
            issues = verifier.verify_history_reachability()
            assert len(issues) == 1
            assert issues[0].entity_type == "history_reachability"
            assert issues[0].severity == "error"

    def test_pre_backfill_head(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            _snap_hash, gen_hash = self._setup(root)

            history_path = generation_dir(root, gen_hash) / "history.pb2"
            history_path.unlink()

            verifier = Verifier(root)
            issues = verifier.verify_history_reachability()
            assert len(issues) == 1
            assert issues[0].entity_type == "history_reachability"
            assert issues[0].severity == "warning"
            assert "backfill" in issues[0].message.lower()
