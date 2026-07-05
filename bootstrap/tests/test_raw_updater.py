"""Tests for bootstrap.data.updater — CI raw-data updater."""

from __future__ import annotations

from typing import TYPE_CHECKING
from unittest.mock import patch

import pytest

from pydantic import SecretStr

from bootstrap.config import DeveloperCiRawArtifacts
from bootstrap.config import DeveloperCiStorage
from bootstrap.config import _apply_overrides
from bootstrap.data.updater.index import _parse_index_file
from bootstrap.data.updater.index import download_index
from bootstrap.data.updater.index import download_metadata
from bootstrap.data.updater.manifest import fetch_build
from bootstrap.data.updater.pipeline import UpdateCheckResult
from bootstrap.data.updater.pipeline import check_server
from bootstrap.data.updater.server import get_server_config
from bootstrap.data.updater.uploader import _resolve_storage


if TYPE_CHECKING:
    from pathlib import Path


class _MockResponse:
    """A minimal async-context-manager response for aiohttp tests."""

    def __init__(self, *, json_data: dict | None = None, body: bytes = b"") -> None:
        self._json = json_data
        self._body = body

    async def __aenter__(self) -> _MockResponse:
        return self

    async def __aexit__(self, *args) -> None:
        return None

    def raise_for_status(self) -> None:
        pass

    async def json(self) -> dict | None:
        return self._json

    async def read(self) -> bytes:
        return self._body


class _MockSession:
    """A minimal async-context-manager session for aiohttp tests."""

    def __init__(self, response: _MockResponse) -> None:
        self._response = response

    async def __aenter__(self) -> _MockSession:
        return self

    async def __aexit__(self, *args) -> None:
        return None

    def get(self, url: str) -> _MockResponse:
        return self._response


class _MockSessionPerUrl:
    """A session that returns a response based on the requested URL."""

    def __init__(self, responses: dict[str, _MockResponse]) -> None:
        self._responses = responses

    async def __aenter__(self) -> _MockSessionPerUrl:
        return self

    async def __aexit__(self, *args) -> None:
        return None

    def get(self, url: str) -> _MockResponse:
        return self._responses[url]


class TestServerConfig:
    def test_tranquility_urls(self) -> None:
        cfg = get_server_config("tranquility")
        assert cfg.id == "tranquility"
        assert cfg.manifest_url == "https://binaries.eveonline.com/eveclient_TQ.json"
        assert cfg.index_file_name == "index_tranquility.txt"
        assert cfg.fsd_dumper_server == "tq"
        assert "{build}" in cfg.index_url_template
        assert "{resource_url}" in cfg.binary_download_url

    def test_singularity_urls(self) -> None:
        cfg = get_server_config("singularity")
        assert cfg.id == "singularity"
        assert cfg.manifest_url == "https://binaries.eveonline.com/eveclient_SISI.json"
        assert cfg.index_file_name == "index_singularity.txt"
        assert cfg.fsd_dumper_server == "tq"

    def test_serenity_urls(self) -> None:
        cfg = get_server_config("serenity")
        assert cfg.id == "serenity"
        assert "eveclient_SERENITY.json" in cfg.manifest_url
        assert cfg.index_file_name == "index_serenity.txt"
        assert cfg.fsd_dumper_server == "se"
        assert "netease" in cfg.binary_download_url

    def test_unknown_server_raises(self) -> None:
        with pytest.raises(ValueError, match="Unknown server id"):
            # type: ignore[arg-type]
            get_server_config("invalid")


class TestFetchBuild:
    async def test_fetch_build_returns_integer(self) -> None:
        server = get_server_config("tranquility")
        response = _MockResponse(json_data={"build": "123456"})
        session = _MockSession(response)

        with patch("bootstrap.data.updater.manifest.aiohttp.ClientSession", return_value=session):
            result = await fetch_build(server)

        assert result == 123456

    async def test_fetch_build_missing_build_raises(self) -> None:
        server = get_server_config("tranquility")
        response = _MockResponse(json_data={"version": "1.0"})
        session = _MockSession(response)

        with (
            patch(
                "bootstrap.data.updater.manifest.aiohttp.ClientSession",
                return_value=session,
            ),
            pytest.raises(ValueError, match="missing 'build' field"),
        ):
            await fetch_build(server)


class TestIndexParsing:
    def test_parse_index_file(self, tmp_path: Path) -> None:
        index_file = tmp_path / "index.txt"
        index_file.write_text(
            "app:/resfileindex.txt,ab/cd1234,hash1,0,0\n"
            "app:/start.ini,ef/gh5678,hash2,0,0\n"
            "res:/foo/bar.png,ij/kl9012,hash3,0,0\n",
            encoding="utf-8",
        )
        entries = _parse_index_file(index_file)
        assert entries["app:/resfileindex.txt"] == "ab/cd1234"
        assert entries["app:/start.ini"] == "ef/gh5678"
        assert entries["res:/foo/bar.png"] == "ij/kl9012"

    async def test_download_index(self, tmp_path: Path) -> None:
        server = get_server_config("tranquility")
        out_dir = tmp_path / "out"
        out_dir.mkdir()

        response = _MockResponse(body=b"app:/resfileindex.txt,ab/cd1234\n")
        session = _MockSession(response)

        with patch("bootstrap.data.updater.index.aiohttp.ClientSession", return_value=session):
            result = await download_index(123456, server, out_dir)

        assert result == out_dir / server.index_file_name
        assert result.read_text(encoding="utf-8") == "app:/resfileindex.txt,ab/cd1234\n"

    async def test_download_metadata(self, tmp_path: Path) -> None:
        server = get_server_config("tranquility")
        out_dir = tmp_path / "out"
        out_dir.mkdir()

        index_file = tmp_path / "index_tranquility.txt"
        index_file.write_text(
            "app:/resfileindex.txt,resfileindex-hash,hash1,0,0\n"
            "app:/resfileindex_Windows.txt,resfileindex-windows-hash,hash2,0,0\n"
            "app:/resfileindex_prefetch.txt,resfileindex-prefetch-hash,hash3,0,0\n"
            "app:/resfiledependencies.yaml,dependencies-hash,hash4,0,0\n"
            "app:/start.ini,start-hash,hash5,0,0\n",
            encoding="utf-8",
        )

        responses: dict[str, _MockResponse] = {
            "https://binaries.eveonline.com/resfileindex-hash": _MockResponse(
                body=b"resfileindex content"
            ),
            "https://binaries.eveonline.com/resfileindex-windows-hash": _MockResponse(
                body=b"windows content"
            ),
            "https://binaries.eveonline.com/resfileindex-prefetch-hash": _MockResponse(
                body=b"prefetch content"
            ),
            "https://binaries.eveonline.com/dependencies-hash": _MockResponse(
                body=b"dependencies content"
            ),
            "https://binaries.eveonline.com/start-hash": _MockResponse(body=b"start content"),
        }

        session = _MockSessionPerUrl(responses)

        with patch("bootstrap.data.updater.index.aiohttp.ClientSession", return_value=session):
            await download_metadata(index_file, server, out_dir)

        assert (out_dir / "resfileindex.txt").read_bytes() == b"resfileindex content"
        assert (out_dir / "resfileindex_Windows.txt").read_bytes() == b"windows content"
        assert (out_dir / "resfileindex_prefetch.txt").read_bytes() == b"prefetch content"
        assert (out_dir / "resfiledependencies.yaml").read_bytes() == b"dependencies content"
        assert (out_dir / "start.ini").read_bytes() == b"start content"


class TestCheckServer:
    async def test_remote_build_newer_needs_update(self) -> None:
        with (
            patch("bootstrap.data.updater.pipeline.fetch_build", return_value=100),
            patch("bootstrap.data.updater.pipeline._read_bucket_build", return_value=99),
        ):
            result = await check_server("tranquility")

        assert result == UpdateCheckResult(needs_update=True, remote_build=100, bucket_build=99)

    async def test_remote_build_equal_no_update(self) -> None:
        with (
            patch("bootstrap.data.updater.pipeline.fetch_build", return_value=100),
            patch("bootstrap.data.updater.pipeline._read_bucket_build", return_value=100),
        ):
            result = await check_server("tranquility")

        assert result == UpdateCheckResult(needs_update=False, remote_build=100, bucket_build=100)

    async def test_remote_build_older_no_update(self) -> None:
        with (
            patch("bootstrap.data.updater.pipeline.fetch_build", return_value=99),
            patch("bootstrap.data.updater.pipeline._read_bucket_build", return_value=100),
        ):
            result = await check_server("tranquility")

        assert result == UpdateCheckResult(needs_update=False, remote_build=99, bucket_build=100)

    async def test_no_bucket_build_needs_update(self) -> None:
        with (
            patch("bootstrap.data.updater.pipeline.fetch_build", return_value=100),
            patch("bootstrap.data.updater.pipeline._read_bucket_build", return_value=None),
        ):
            result = await check_server("tranquility")

        assert result == UpdateCheckResult(needs_update=True, remote_build=100, bucket_build=None)


class TestUploader:
    def test_resolve_storage_without_overrides(self) -> None:
        config = DeveloperCiRawArtifacts(remote_root="data-generator/raw-artifact")
        storage = DeveloperCiStorage(
            endpoint="https://example.com",
            bucket="bucket",
            alias="alias",
            access_key="key",
            secret_key="secret",
            public_url="https://public.example.com",
        )
        endpoint, bucket, access_key, secret_key, alias = _resolve_storage(config, storage)
        assert endpoint == "https://example.com"
        assert bucket == "bucket"
        assert alias == "alias"
        assert access_key == "key"
        assert secret_key == "secret"

    def test_resolve_storage_with_overrides(self) -> None:
        config = DeveloperCiRawArtifacts(
            remote_root="data-generator/raw-artifact",
            endpoint="https://override.com",
            bucket="override-bucket",
            alias="override-alias",
            access_key="override-key",
            secret_key="override-secret",
        )
        storage = DeveloperCiStorage(
            endpoint="https://example.com",
            bucket="bucket",
            alias="alias",
            access_key="key",
            secret_key="secret",
            public_url="https://public.example.com",
        )
        endpoint, bucket, access_key, secret_key, alias = _resolve_storage(config, storage)
        assert endpoint == "https://override.com"
        assert bucket == "override-bucket"
        assert alias == "override-alias"
        assert access_key == "override-key"
        assert secret_key == "override-secret"


class TestConfigOverrides:
    def test_apply_overrides_creates_nested_tables(self) -> None:
        cfg = _apply_overrides(
            {},
            [
                ("ci.storage.endpoint", "https://test.example.com"),
                ("ci.storage.bucket", "bucket"),
            ],
        )
        assert cfg["ci"]["storage"]["endpoint"] == "https://test.example.com"
        assert cfg["ci"]["storage"]["bucket"] == "bucket"

    def test_apply_overrides_parses_toml_primitives(self) -> None:
        cfg = _apply_overrides(
            {},
            [
                ("version.major", "42"),
                ("version.pre_label", '"beta"'),
                ("remote.verify_upload", "true"),
            ],
        )
        assert cfg["version"]["major"] == 42
        assert cfg["version"]["pre_label"] == "beta"
        assert cfg["remote"]["verify_upload"] is True

    def test_apply_overrides_falls_back_to_literal_string(self) -> None:
        cfg = _apply_overrides(
            {},
            [("ci.storage.secret_key", "abc=def+ghi")],
        )
        assert cfg["ci"]["storage"]["secret_key"] == "abc=def+ghi"


class TestSecretStrRedaction:
    def test_storage_secrets_are_redacted_in_dump(self) -> None:
        storage = DeveloperCiStorage(
            endpoint="https://example.com",
            bucket="bucket",
            alias="alias",
            access_key="ACCESS_KEY",
            secret_key="SECRET_KEY",
            public_url="https://public.example.com",
        )
        dumped = storage.model_dump()
        assert isinstance(dumped["access_key"], SecretStr)
        assert dumped["access_key"].get_secret_value() == "ACCESS_KEY"  # SecretStr keeps value
        assert str(dumped["access_key"]) == "**********"
        assert isinstance(dumped["secret_key"], SecretStr)
        assert str(dumped["secret_key"]) == "**********"
        assert dumped["endpoint"] == "https://example.com"

    def test_storage_secrets_are_available_via_get_secret_value(self) -> None:
        storage = DeveloperCiStorage(
            endpoint="https://example.com",
            bucket="bucket",
            alias="alias",
            access_key="ACCESS_KEY",
            secret_key="SECRET_KEY",
            public_url="https://public.example.com",
        )
        assert storage.access_key.get_secret_value() == "ACCESS_KEY"
        assert storage.secret_key.get_secret_value() == "SECRET_KEY"

    def test_str_representation_does_not_leak_secret(self) -> None:
        storage = DeveloperCiStorage(
            endpoint="https://example.com",
            bucket="bucket",
            alias="alias",
            access_key="ACCESS_KEY",
            secret_key="SECRET_KEY",
            public_url="https://public.example.com",
        )
        text = str(storage)
        assert "ACCESS_KEY" not in text
        assert "SECRET_KEY" not in text
        assert "**********" in text
