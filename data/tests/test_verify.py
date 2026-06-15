from __future__ import annotations

import tempfile

from pathlib import Path

from data.lib.workspace.generate.schema import _compute_checkout_hash
from data.lib.workspace.generate.schema import _sha256_hex
from data.lib.workspace.generate.schema import verify_checkout_assets


def _make_asset_file(schema_root: Path, path_hash: str, content_hash: str, content: bytes) -> Path:
    prefix = path_hash[:2]
    dest_dir = schema_root / "assets" / prefix / path_hash
    dest_dir.mkdir(parents=True, exist_ok=True)
    dest_file = dest_dir / content_hash
    dest_file.write_bytes(content)
    return dest_file


def _make_catalog(files: dict[str, dict], *, catalog_id: str | None = None) -> dict:
    cid = catalog_id or _compute_checkout_hash(files)
    return {"id": cid, "files": files}


class TestVerifyCheckoutAssets:
    def test_all_ok(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            schema_root = Path(tmpdir)
            content = b"hello world"
            normalized = "data/file.txt"
            content_hash = _sha256_hex(content)
            path_hash = _sha256_hex(normalized.encode("utf-8"))

            _make_asset_file(schema_root, path_hash, content_hash, content)

            files = {
                normalized: {
                    "pathHash": path_hash,
                    "hash": content_hash,
                    "size": len(content),
                }
            }
            catalog = _make_catalog(files)

            results = verify_checkout_assets(catalog, schema_root)
            assert len(results) == 2
            assert results[0].status == "OK"
            assert results[0].path == normalized
            assert results[0].size == len(content)
            assert results[1].path == "[catalog integrity]"
            assert results[1].status == "OK"

    def test_missing_asset(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            schema_root = Path(tmpdir)
            normalized = "data/missing.txt"
            path_hash = _sha256_hex(normalized.encode("utf-8"))
            content_hash = "d" * 64

            files = {
                normalized: {
                    "pathHash": path_hash,
                    "hash": content_hash,
                    "size": 100,
                }
            }
            catalog = _make_catalog(files)

            results = verify_checkout_assets(catalog, schema_root)
            assert results[0].status == "MISSING"
            assert "not found" in (results[0].details or "")

    def test_hash_mismatch(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            schema_root = Path(tmpdir)
            normalized = "data/corrupt.txt"
            path_hash = _sha256_hex(normalized.encode("utf-8"))
            real_content = b"correct content"
            wrong_hash = "f" * 64

            _make_asset_file(schema_root, path_hash, wrong_hash, real_content)

            files = {
                normalized: {
                    "pathHash": path_hash,
                    "hash": wrong_hash,
                    "size": len(real_content),
                }
            }
            catalog = _make_catalog(files)

            results = verify_checkout_assets(catalog, schema_root)
            assert results[0].status == "FAIL"
            assert "hash mismatch" in (results[0].details or "").lower()

    def test_size_mismatch(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            schema_root = Path(tmpdir)
            normalized = "data/wrong_size.txt"
            path_hash = _sha256_hex(normalized.encode("utf-8"))
            content = b"four"
            content_hash = _sha256_hex(content)

            _make_asset_file(schema_root, path_hash, content_hash, content)

            files = {
                normalized: {
                    "pathHash": path_hash,
                    "hash": content_hash,
                    "size": 99999,
                }
            }
            catalog = _make_catalog(files)

            results = verify_checkout_assets(catalog, schema_root)
            assert results[0].status == "FAIL"
            assert "size mismatch" in (results[0].details or "").lower()

    def test_catalog_integrity_fail(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            schema_root = Path(tmpdir)
            normalized = "data/ok.txt"
            path_hash = _sha256_hex(normalized.encode("utf-8"))
            content = b"ok"
            content_hash = _sha256_hex(content)

            _make_asset_file(schema_root, path_hash, content_hash, content)

            files = {
                normalized: {
                    "pathHash": path_hash,
                    "hash": content_hash,
                    "size": len(content),
                }
            }
            fake_id = "0" * 64
            catalog = {"id": fake_id, "files": files}

            results = verify_checkout_assets(catalog, schema_root)
            assert results[0].status == "OK"
            assert results[1].path == "[catalog integrity]"
            assert results[1].status == "FAIL"
