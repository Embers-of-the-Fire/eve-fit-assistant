from __future__ import annotations

import hashlib
import json
import tempfile

from configparser import ConfigParser
from pathlib import Path

import pytest

from data.lib.workspace.config import WorkspaceConfig
from data.lib.workspace.config import WorkspaceMetadata
from data.lib.workspace.config import WorkspacePaths
from data.lib.workspace.config import WorkspaceResources
from data.lib.workspace.config import WorkspaceServices
from data.lib.workspace.generate.schema import _compute_checkout_hash
from data.lib.workspace.generate.schema import _normalize_path
from data.lib.workspace.generate.schema import _sha256_hex
from data.lib.workspace.generate.schema import generate_schema_checkout
from data.lib.workspace.generate.schema import verify_checkout_hash


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


class TestComputeCheckoutHash:
    def test_deterministic(self):
        files = {
            "a.txt": {"hash": "abc123", "size": 100},
            "b.txt": {"hash": "def456", "size": 200},
        }
        h1 = _compute_checkout_hash(files)
        h2 = _compute_checkout_hash(files)
        assert h1 == h2

    def test_order_independent(self):
        files1 = {
            "b.txt": {"hash": "def456", "size": 200},
            "a.txt": {"hash": "abc123", "size": 100},
        }
        files2 = {
            "a.txt": {"hash": "abc123", "size": 100},
            "b.txt": {"hash": "def456", "size": 200},
        }
        assert _compute_checkout_hash(files1) == _compute_checkout_hash(files2)

    def test_different_content_produces_different_hash(self):
        files1 = {"a.txt": {"hash": "abc123", "size": 100}}
        files2 = {"a.txt": {"hash": "xyz789", "size": 100}}
        assert _compute_checkout_hash(files1) != _compute_checkout_hash(files2)

    def test_empty_files_produces_hash(self):
        files: dict[str, dict[str, object]] = {}
        result = _compute_checkout_hash(files)
        assert isinstance(result, str)
        assert len(result) == 64


class TestSha256Hex:
    def test_known_value(self):
        result = _sha256_hex(b"hello")
        expected = hashlib.sha256(b"hello").hexdigest()
        assert result == expected
        assert len(result) == 64


class TestGenerateSchemaCheckout:
    def test_basic_generation(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)

            start_ini = _make_start_ini(tmp)

            build_dir = tmp / "build"
            static_dir = build_dir / "static"
            static_dir.mkdir(parents=True)
            (static_dir / "collection.pb2").write_bytes(b"fake collection data")
            (static_dir / "types.json").write_text("[]")

            localization_dir = build_dir / "localization"
            localization_dir.mkdir(parents=True)
            (localization_dir / "localization_en.pb2").write_bytes(b"en data")

            schema_root = tmp / "output"
            config = _make_workspace_config(start_ini)
            checkout_hash = generate_schema_checkout(
                config, build_dir=build_dir, schema_root=schema_root
            )

            assert checkout_hash is not None
            assets_dir = schema_root / "assets"
            assert assets_dir.is_dir()

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

    def test_file_deduplication(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            start_ini = _make_start_ini(tmp)

            build_dir = tmp / "build"
            sub_a = build_dir / "a"
            sub_a.mkdir(parents=True)
            sub_b = build_dir / "b"
            sub_b.mkdir(parents=True)

            identical_content = b"same content"
            (sub_a / "f1.bin").write_bytes(identical_content)
            (sub_b / "f2.bin").write_bytes(identical_content)

            schema_root = tmp / "out"
            config = _make_workspace_config(start_ini)
            checkout_hash = generate_schema_checkout(
                config, build_dir=build_dir, schema_root=schema_root
            )

            assert checkout_hash is not None
            catalog_path = schema_root / "checkouts" / f"{checkout_hash}.json"
            with catalog_path.open("r") as f:
                catalog = json.load(f)

            assert len(catalog["files"]) == 2
            hash1 = catalog["files"]["a/f1.bin"]["hash"]
            hash2 = catalog["files"]["b/f2.bin"]["hash"]
            assert hash1 == hash2

            assets_dir = schema_root / "assets"
            entry = catalog["files"]["a/f1.bin"]
            path_hash = entry["pathHash"]
            prefix = path_hash[:2]
            dest = assets_dir / prefix / path_hash / hash1
            assert dest.is_file()

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


class TestVerifyCheckoutHash:
    def test_valid_catalog(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            start_ini = _make_start_ini(tmp)

            build_dir = tmp / "build"
            build_dir.mkdir()
            (build_dir / "data.bin").write_bytes(b"test data")

            schema_root = tmp / "out"
            config = _make_workspace_config(start_ini)
            checkout_hash = generate_schema_checkout(
                config, build_dir=build_dir, schema_root=schema_root
            )
            assert checkout_hash is not None

            catalog_path = schema_root / "checkouts" / f"{checkout_hash}.json"
            assert verify_checkout_hash(catalog_path) is True

    def test_tampered_catalog(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            start_ini = _make_start_ini(tmp)

            build_dir = tmp / "build"
            build_dir.mkdir()
            (build_dir / "data.bin").write_bytes(b"test data")

            schema_root = tmp / "out"
            config = _make_workspace_config(start_ini)
            checkout_hash = generate_schema_checkout(
                config, build_dir=build_dir, schema_root=schema_root
            )
            assert checkout_hash is not None

            catalog_path = schema_root / "checkouts" / f"{checkout_hash}.json"
            with catalog_path.open("r") as f:
                catalog = json.load(f)

            orig_id = catalog["id"]
            catalog["id"] = "0000000000000000000000000000000000000000000000000000000000000000"
            with catalog_path.open("w") as f:
                json.dump(catalog, f)

            assert verify_checkout_hash(catalog_path) is False
            assert orig_id != "0000000000000000000000000000000000000000000000000000000000000000"


class TestAssetPathResolution:
    def test_asset_path_matches_catalog(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            start_ini = _make_start_ini(tmp)

            build_dir = tmp / "build"
            build_dir.mkdir()
            file_path = build_dir / "icons" / "test.png"
            file_path.parent.mkdir(parents=True)
            file_path.write_bytes(b"image data")

            schema_root = tmp / "out"
            config = _make_workspace_config(start_ini)
            checkout_hash = generate_schema_checkout(
                config, build_dir=build_dir, schema_root=schema_root
            )
            assert checkout_hash is not None

            catalog_path = schema_root / "checkouts" / f"{checkout_hash}.json"
            with catalog_path.open("r") as f:
                catalog = json.load(f)

            entry = catalog["files"]["icons/test.png"]
            path_hash = entry["pathHash"]
            content_hash = entry["hash"]

            prefix = path_hash[:2]
            asset_path = schema_root / "assets" / prefix / path_hash / content_hash
            assert asset_path.is_file()
            assert asset_path.read_bytes() == b"image data"
