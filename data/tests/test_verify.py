"""Tests for schema V2 verification functionality."""

from __future__ import annotations

import tempfile

from pathlib import Path

from data.lib.remote.hash import content_hash
from data.lib.remote.hash import ident_hash
from data.lib.remote.hash import snapshot_hash
from data.lib.remote.models import ResourceIndex
from data.lib.remote.models import ResourceSnapshotMetadata
from data.lib.remote.paths import blob_path
from data.lib.remote.snapshot import SnapshotStore
from data.lib.remote.verify import Verifier


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
            "resources.pb2": b"proto data",
        }
        h = snapshot_hash("resource", files)
        assert len(h) == 64
        assert all(c in "0123456789abcdef" for c in h)

    def test_snapshot_hash_deterministic(self):
        files = {
            "metadata.json": b'{"schemaVersion":1}',
            "resources.pb2": b"data",
        }
        h1 = snapshot_hash("resource", files)
        h2 = snapshot_hash("resource", files)
        assert h1 == h2
