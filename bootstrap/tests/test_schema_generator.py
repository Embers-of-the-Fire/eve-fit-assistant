"""Tests for schema V2 resource snapshot generator."""

from __future__ import annotations

import hashlib
import tempfile

from configparser import ConfigParser
from pathlib import Path

import pytest

from bootstrap.data.workspace.config import WorkspaceConfig
from bootstrap.data.workspace.config import WorkspaceMetadata
from bootstrap.data.workspace.config import WorkspacePaths
from bootstrap.data.workspace.config import WorkspaceResources
from bootstrap.data.workspace.config import WorkspaceServices
from bootstrap.data.workspace.generate.schema import _normalize_path
from bootstrap.data.workspace.generate.schema import generate_schema_checkout
from bootstrap.remote.hash import content_hash
from bootstrap.remote.hash import generation_hash
from bootstrap.remote.hash import ident_hash
from bootstrap.remote.hash import snapshot_hash


def _make_start_ini(dir_path: Path) -> Path:
    start_ini = dir_path / "start.ini"
    cfg = ConfigParser()
    cfg["main"] = {
        "version": "23.02",
        "build": "3378101",
        "server": "Tranquility",
        "region": "ccp",
        "branch": "//eve/branches/release/V23.02",
    }
    with start_ini.open("w") as f:
        cfg.write(f)
    return start_ini


def _make_workspace_config(start_ini: Path) -> WorkspaceConfig:
    return WorkspaceConfig.model_construct(
        metadata=WorkspaceMetadata.model_construct(
            start_cfg=start_ini,
            name={"en": "Test", "zh": "测试"},
            identifier="test",
        ),
        paths=WorkspacePaths.model_construct(
            cache=Path("/tmp"),
            generated=Path("/tmp"),
            output=Path("/tmp"),
        ),
        resources=WorkspaceResources.model_construct(
            resource_index=Path("/dev/null"),
            application_index=Path("/dev/null"),
            fsd=Path("/tmp"),
            patches=Path("/tmp"),
        ),
        services=WorkspaceServices.model_construct(
            resource_url="https://{resource_type}.example.com/{resource_url}",
        ),
    )


class TestNormalizePath:
    def test_simple_path(self):
        assert _normalize_path("static/collection.pb2") == "static/collection.pb2"

    def test_dot_prefix(self):
        assert _normalize_path("./static/collection.pb2") == "static/collection.pb2"

    def test_double_dot(self):
        assert _normalize_path("static/../localization/en.pb2") == "localization/en.pb2"

    def test_absolute_raises(self):
        with pytest.raises(ValueError, match="must be relative"):
            _normalize_path("/absolute/path")

    def test_empty_path(self):
        assert _normalize_path("") == "."


class TestContentHash:
    def test_known_value(self):
        result = content_hash(b"hello")
        expected = hashlib.sha256(b"hello").hexdigest()
        assert result == expected
        assert len(result) == 64

    def test_different_content_different_hash(self):
        h1 = content_hash(b"hello")
        h2 = content_hash(b"world")
        assert h1 != h2


class TestIdentHash:
    def test_resource_uri(self):
        h = ident_hash("resource://proto/ships.bin")
        assert len(h) == 64
        assert all(c in "0123456789abcdef" for c in h)

    def test_different_uri_different_hash(self):
        h1 = ident_hash("resource://a.bin")
        h2 = ident_hash("resource://b.bin")
        assert h1 != h2


class TestSnapshotHash:
    def test_deterministic_resource(self):
        files = {
            "metadata.json": b'{"schemaVersion":1}',
        }
        h1 = snapshot_hash("resource", files)
        h2 = snapshot_hash("resource", files)
        assert h1 == h2
        assert len(h1) == 64

    def test_different_type_different_hash(self):
        files = {
            "metadata.json": b'{"schemaVersion":1}',
        }
        h1 = snapshot_hash("resource", files)
        h2 = snapshot_hash("release", files)
        assert h1 != h2


class TestGenerationHash:
    def test_deterministic(self):
        files = {"metadata.json": b"data"}
        h1 = generation_hash(files)
        h2 = generation_hash(files)
        assert h1 == h2
        assert len(h1) == 64

    def test_missing_file_raises(self):
        with pytest.raises(ValueError, match="Missing required"):
            generation_hash({})


class TestGenerateSchemaCheckout:
    def test_basic_generation(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            start_ini = _make_start_ini(tmp)

            build_dir = tmp / "build"
            static_dir = build_dir / "static"
            static_dir.mkdir(parents=True)
            (static_dir / "collection.pb2").write_bytes(b"fake collection data")

            schema_root = tmp / "output"
            config = _make_workspace_config(start_ini)
            snapshot_hash = generate_schema_checkout(
                config, build_dir=build_dir, schema_root=schema_root
            )

            assert snapshot_hash is not None
            assert len(snapshot_hash) == 64

            assets_dir = schema_root / "assets"
            assert assets_dir.is_dir()

            blobs_dir = assets_dir / "blobs"
            assert blobs_dir.is_dir()

            resources_dir = assets_dir / "resources"
            assert resources_dir.is_dir()
            snap_dir = resources_dir / snapshot_hash
            assert snap_dir.is_dir()
            assert (snap_dir / "metadata.json").is_file()
            assert (snap_dir / "resources.pb2").is_file()

    def test_deterministic_hash(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            start_ini = _make_start_ini(tmp)

            build_dir = tmp / "build"
            build_dir.mkdir()
            (build_dir / "file.txt").write_text("same content")

            config = _make_workspace_config(start_ini)
            h1 = generate_schema_checkout(config, build_dir=build_dir, schema_root=tmp / "out1")
            h2 = generate_schema_checkout(config, build_dir=build_dir, schema_root=tmp / "out2")

            assert h1 is not None
            assert h2 is not None
            assert h1 == h2

    def test_content_deduplication(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            start_ini = _make_start_ini(tmp)

            build_dir = tmp / "build"
            sub_a = build_dir / "a"
            sub_a.mkdir(parents=True)
            sub_b = build_dir / "b"
            sub_b.mkdir(parents=True)

            identical = b"same content"
            (sub_a / "f1.bin").write_bytes(identical)
            (sub_b / "f2.bin").write_bytes(identical)

            schema_root = tmp / "out"
            config = _make_workspace_config(start_ini)
            snapshot_hash = generate_schema_checkout(
                config, build_dir=build_dir, schema_root=schema_root
            )

            assert snapshot_hash is not None
            chash = content_hash(identical)
            ihash_a = ident_hash("resource://a/f1.bin")
            ihash_b = ident_hash("resource://b/f2.bin")

            assert (schema_root / "assets" / "blobs" / ihash_a[:2] / ihash_a / chash).is_file()
            assert (schema_root / "assets" / "blobs" / ihash_b[:2] / ihash_b / chash).is_file()

    def test_empty_build_dir(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            start_ini = _make_start_ini(tmp)

            build_dir = tmp / "build"
            build_dir.mkdir()

            config = _make_workspace_config(start_ini)
            result = generate_schema_checkout(config, build_dir=build_dir, schema_root=tmp / "out")
            assert result is None

    def test_nonexistent_build_dir(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            start_ini = _make_start_ini(tmp)

            config = _make_workspace_config(start_ini)
            result = generate_schema_checkout(
                config, build_dir=tmp / "nonexistent", schema_root=tmp / "out"
            )
            assert result is None
