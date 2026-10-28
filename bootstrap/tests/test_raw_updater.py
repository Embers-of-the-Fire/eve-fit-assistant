"""Tests for bootstrap.data.updater — CI raw-data updater."""

from __future__ import annotations

import tomllib

from typing import TYPE_CHECKING
from typing import Self
from unittest.mock import patch

import pytest

from pydantic import SecretStr

from bootstrap.config import DeveloperCi
from bootstrap.config import DeveloperCiRawArtifacts
from bootstrap.config import DeveloperCiStorage
from bootstrap.config import DeveloperConfiguration
from bootstrap.config import _apply_overrides
from bootstrap.constant import PROJECT_ROOT
from bootstrap.data.updater.index import _parse_index_file
from bootstrap.data.updater.index import download_index
from bootstrap.data.updater.index import download_metadata
from bootstrap.data.updater.manifest import fetch_build
from bootstrap.data.updater.pipeline import UpdateCheckResult
from bootstrap.data.updater.pipeline import _read_bucket_build
from bootstrap.data.updater.pipeline import check_server
from bootstrap.data.updater.server import SERVER_ALIASES
from bootstrap.data.updater.server import SERVER_IDS
from bootstrap.data.updater.server import get_server_config
from bootstrap.data.updater.server import list_server_ids
from bootstrap.data.updater.server import resolve_server_id
from bootstrap.data.updater.uploader import _resolve_storage


if TYPE_CHECKING:
    from pathlib import Path


class _MockContent:
    """A minimal aiohttp-compatible content object supporting iter_chunked."""

    def __init__(self, body: bytes) -> None:
        self._body = body

    def iter_chunked(self, chunk_size: int):
        async def _gen():
            for i in range(0, len(self._body), chunk_size):
                yield self._body[i : i + chunk_size]

        return _gen()


class _MockResponse:
    """A minimal async-context-manager response for aiohttp tests."""

    def __init__(
        self,
        *,
        json_data: dict | None = None,
        body: bytes = b"",
        status: int = 200,
    ) -> None:
        self._json = json_data
        self._body = body
        self.status = status
        self.content = _MockContent(body)

    async def __aenter__(self) -> Self:
        return self

    async def __aexit__(self, *args) -> None:
        return None

    def raise_for_status(self) -> None:
        pass

    async def json(self) -> dict | None:
        return self._json

    async def read(self) -> bytes:
        return self._body

    async def text(self) -> str:
        return self._body.decode("utf-8", errors="replace")


class _MockSession:
    """A minimal async-context-manager session for aiohttp tests."""

    def __init__(self, response: _MockResponse) -> None:
        self._response = response

    async def __aenter__(self) -> Self:
        return self

    async def __aexit__(self, *args) -> None:
        return None

    def get(self, url: str) -> _MockResponse:
        return self._response


class _MockSessionPerUrl:
    """A session that returns a response based on the requested URL."""

    def __init__(self, responses: dict[str, _MockResponse]) -> None:
        self._responses = responses

    async def __aenter__(self) -> Self:
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
            get_server_config("invalid")


class TestServerDiscovery:
    def test_server_ids_match_resources_tree(self) -> None:
        """SERVER_IDS must stay in sync with data/resources descriptor files."""
        resources_root = PROJECT_ROOT / "data" / "resources"
        expected: set[str] = set()
        for entry in resources_root.iterdir():
            if not entry.is_dir():
                continue
            descriptor_path = entry / "descriptor.toml"
            if not descriptor_path.is_file():
                continue
            with open(descriptor_path, "rb") as f:
                data = tomllib.load(f)
            if data.get("ignore", False):
                continue
            metadata = data.get("metadata") or {}
            if metadata.get("server", False):
                identifier = metadata.get("identifier")
                if isinstance(identifier, str) and identifier:
                    expected.add(identifier)
        assert frozenset(expected) == SERVER_IDS

    def test_server_aliases_target_known_servers(self) -> None:
        for alias, target in SERVER_ALIASES.items():
            assert target in SERVER_IDS, f"alias {alias!r} targets unknown server {target!r}"

    def test_server_configs_cover_all_servers(self) -> None:
        for server_id in SERVER_IDS:
            cfg = get_server_config(server_id)
            assert cfg.id == server_id

    def test_list_server_ids_is_sorted(self) -> None:
        server_ids = list_server_ids()
        assert server_ids == sorted(server_ids)
        assert set(server_ids) == SERVER_IDS

    def test_resolve_server_id_normalizes_aliases(self) -> None:
        assert resolve_server_id("tq") == "tranquility"
        assert resolve_server_id("TQ") == "tranquility"
        assert resolve_server_id("se") == "serenity"
        assert resolve_server_id("sisi") == "singularity"

    def test_resolve_server_id_rejects_unknown(self) -> None:
        with pytest.raises(ValueError, match="Unknown server id"):
            resolve_server_id("not-a-server")


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
    async def test_parse_index_file(self, tmp_path: Path) -> None:
        index_file = tmp_path / "index.txt"
        index_file.write_text(
            "app:/resfileindex.txt,ab/cd1234,hash1,0,0\n"
            "app:/start.ini,ef/gh5678,hash2,0,0\n"
            "res:/foo/bar.png,ij/kl9012,hash3,0,0\n",
            encoding="utf-8",
        )
        entries = await _parse_index_file(index_file)
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


class TestReadBucketBuild:
    def _dev_config(
        self, public_url: str | None = "https://public.example.com"
    ) -> DeveloperConfiguration:
        raw_artifacts = DeveloperCiRawArtifacts(
            remote_root="data-generator/raw-artifact",
            public_url=public_url,
        )
        return DeveloperConfiguration(ci=DeveloperCi(raw_artifacts=raw_artifacts))

    async def test_returns_bucket_build_from_public_url(self, monkeypatch) -> None:
        monkeypatch.setattr(
            "bootstrap.data.updater.pipeline.bootstrap.config.DEV_CONFIGURATION",
            self._dev_config(),
        )
        response = _MockResponse(body=b"123456")
        session = _MockSession(response)

        with patch("bootstrap.data.updater.pipeline.aiohttp.ClientSession", return_value=session):
            result = await _read_bucket_build("tranquility")

        assert result == 123456

    async def test_returns_none_on_404(self, monkeypatch) -> None:
        monkeypatch.setattr(
            "bootstrap.data.updater.pipeline.bootstrap.config.DEV_CONFIGURATION",
            self._dev_config(),
        )
        response = _MockResponse(body=b"not found", status=404)
        session = _MockSession(response)

        with patch("bootstrap.data.updater.pipeline.aiohttp.ClientSession", return_value=session):
            result = await _read_bucket_build("tranquility")

        assert result is None

    async def test_returns_none_when_public_url_missing(self, monkeypatch) -> None:
        monkeypatch.setattr(
            "bootstrap.data.updater.pipeline.bootstrap.config.DEV_CONFIGURATION",
            self._dev_config(public_url=None),
        )

        result = await _read_bucket_build("tranquility")

        assert result is None


class _FakeS3Client:
    """Stand-in for S3Client recording upload/mirror calls."""

    def __init__(self, endpoint: str, bucket: str) -> None:
        self.endpoint = endpoint
        self.bucket = bucket
        self.mirror_up_calls: list[tuple[Path, str, bool]] = []
        self.mirror_down_calls: list[tuple[str, Path]] = []
        self.upload_calls: list[tuple[Path, str]] = []

    def mirror_up(self, src_dir: Path, prefix: str, *, delete: bool = False) -> None:
        self.mirror_up_calls.append((src_dir, prefix, delete))

    def mirror_down(self, prefix: str, dest_dir: Path) -> None:
        self.mirror_down_calls.append((prefix, dest_dir))

    def upload_file(self, src: Path, key: str, *, attrs: dict | None = None) -> None:
        self.upload_calls.append((src, key))


class TestArtifactTransfer:
    @pytest.fixture
    def fake_client(self, monkeypatch) -> _FakeS3Client:
        client = _FakeS3Client("https://s3.example.com", "bucket")

        def _factory(endpoint: str, bucket: str, access_key: str, secret_key: str):
            client.factory_args = (endpoint, bucket, access_key, secret_key)
            return client

        monkeypatch.setattr("bootstrap.data.updater.uploader._make_client", _factory)
        return client

    @pytest.fixture
    def storage(self) -> DeveloperCiStorage:
        return DeveloperCiStorage(
            endpoint="https://s3.example.com",
            bucket="bucket",
            access_key="ACCESS_KEY",
            secret_key="SECRET_KEY",  # noqa: S106
            public_url="https://public.example.com",
        )

    async def test_upload_artifacts(
        self, fake_client: _FakeS3Client, storage: DeveloperCiStorage, tmp_path: Path
    ) -> None:
        from bootstrap.data.updater.uploader import upload_artifacts

        config = DeveloperCiRawArtifacts(remote_root="data-generator/raw-artifact")
        artifacts_dir = tmp_path / "artifacts"
        artifacts_dir.mkdir()
        build_file = tmp_path / "build.txt"
        build_file.write_text("123456", encoding="utf-8")

        await upload_artifacts("tranquility", artifacts_dir, 123456, config, storage)

        assert fake_client.factory_args == (
            "https://s3.example.com",
            "bucket",
            "ACCESS_KEY",
            "SECRET_KEY",
        )
        assert fake_client.mirror_up_calls == [
            (artifacts_dir, "data-generator/raw-artifact/tranquility/artifacts", True)
        ]
        assert fake_client.upload_calls == [
            (build_file, "data-generator/raw-artifact/tranquility/build.txt")
        ]

    async def test_download_artifacts(
        self, fake_client: _FakeS3Client, storage: DeveloperCiStorage, tmp_path: Path
    ) -> None:
        from bootstrap.data.updater.uploader import download_artifacts

        config = DeveloperCiRawArtifacts(remote_root="data-generator/raw-artifact")
        output_dir = tmp_path / "out"

        await download_artifacts("tranquility", output_dir, config, storage)

        assert fake_client.mirror_down_calls == [
            ("data-generator/raw-artifact/tranquility/artifacts", output_dir / "tranquility")
        ]


class TestUpdateServer:
    async def test_writes_build_txt_when_upload_disabled(self, monkeypatch, tmp_path: Path) -> None:
        from bootstrap.data.updater.pipeline import update_server

        async def _fake_fetch_build(_server):
            return 123456

        async def _fake_download_index(_build, _server, out_dir):
            return out_dir / "index_tranquility.txt"

        async def _fake_download_metadata(_index_file, _server, _out_dir):
            return

        async def _fake_download_resource_index(_index_file, _server, _out_dir):
            return _out_dir / "resfileindex.txt"

        async def _fake_generate_fsd(
            _index_file, _resfileindex_file, _server, _out_dir, _temp_root
        ):
            return

        monkeypatch.setattr("bootstrap.data.updater.pipeline.fetch_build", _fake_fetch_build)
        monkeypatch.setattr("bootstrap.data.updater.pipeline.download_index", _fake_download_index)
        monkeypatch.setattr(
            "bootstrap.data.updater.pipeline.download_metadata", _fake_download_metadata
        )
        monkeypatch.setattr(
            "bootstrap.data.updater.pipeline.download_resource_index",
            _fake_download_resource_index,
        )
        monkeypatch.setattr("bootstrap.data.updater.pipeline.generate_fsd", _fake_generate_fsd)
        monkeypatch.setattr(
            "bootstrap.config.DEV_CONFIGURATION",
            self._dev_config(),
        )

        monkeypatch.setattr(
            "bootstrap.data.updater.pipeline._get_raw_artifacts_dir",
            lambda _server_id: tmp_path / "tranquility",
        )

        result = await update_server("tranquility", upload=False, keep_temp=False)

        assert result.server_id == "tranquility"
        assert result.build == 123456
        assert result.uploaded is False
        build_file = result.artifacts_dir.parent / "build.txt"
        assert build_file.is_file()
        assert build_file.read_text(encoding="utf-8") == "123456"

    def _dev_config(
        self, public_url: str | None = "https://public.example.com"
    ) -> DeveloperConfiguration:
        raw_artifacts = DeveloperCiRawArtifacts(
            remote_root="data-generator/raw-artifact",
            public_url=public_url,
        )
        return DeveloperConfiguration(ci=DeveloperCi(raw_artifacts=raw_artifacts))


class TestUploader:
    def test_resolve_storage_without_overrides(self) -> None:
        config = DeveloperCiRawArtifacts(remote_root="data-generator/raw-artifact")
        storage = DeveloperCiStorage(
            endpoint="https://example.com",
            bucket="bucket",
            access_key="key",
            secret_key="secret",  # noqa: S106
            public_url="https://public.example.com",
        )
        endpoint, bucket, access_key, secret_key = _resolve_storage(config, storage)
        assert endpoint == "https://example.com"
        assert bucket == "bucket"
        assert access_key == "key"
        assert secret_key == "secret"  # noqa: S105

    def test_resolve_storage_with_overrides(self) -> None:
        config = DeveloperCiRawArtifacts(
            remote_root="data-generator/raw-artifact",
            endpoint="https://override.com",
            bucket="override-bucket",
            access_key="override-key",
            secret_key="override-secret",  # noqa: S106
        )
        storage = DeveloperCiStorage(
            endpoint="https://example.com",
            bucket="bucket",
            access_key="key",
            secret_key="secret",  # noqa: S106
            public_url="https://public.example.com",
        )
        endpoint, bucket, access_key, secret_key = _resolve_storage(config, storage)
        assert endpoint == "https://override.com"
        assert bucket == "override-bucket"
        assert access_key == "override-key"
        assert secret_key == "override-secret"  # noqa: S105


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
                ("version.testing.major", "42"),
                ("version.testing.num", "3"),
                ("remote.verify_upload", "true"),
            ],
        )
        assert cfg["version"]["testing"]["major"] == 42
        assert cfg["version"]["testing"]["num"] == 3
        assert cfg["remote"]["verify_upload"] is True

    def test_apply_overrides_falls_back_to_literal_string(self) -> None:
        cfg = _apply_overrides(
            {},
            [("ci.storage.secret_key", "abc=def+ghi")],
        )
        assert cfg["ci"]["storage"]["secret_key"] == "abc=def+ghi"  # noqa: S105

    def test_dev_env_overrides_create_ci_storage_without_dev_toml(self) -> None:
        cfg = _apply_overrides(
            {},
            [
                ("ci.storage.endpoint", "https://test.example.com"),
                ("ci.storage.bucket", "bucket"),
                ("ci.storage.access_key", "key"),
                ("ci.storage.secret_key", "secret"),
            ],
        )
        dev = DeveloperConfiguration.model_validate(cfg)
        assert dev.ci.storage is not None
        assert dev.ci.storage.endpoint == "https://test.example.com"
        assert dev.ci.storage.bucket == "bucket"
        assert dev.ci.storage.access_key.get_secret_value() == "key"
        assert dev.ci.storage.secret_key.get_secret_value() == "secret"
        assert dev.ci.storage.public_url is None


class TestSecretStrRedaction:
    def test_storage_secrets_are_redacted_in_dump(self) -> None:
        storage = DeveloperCiStorage(
            endpoint="https://example.com",
            bucket="bucket",
            access_key="ACCESS_KEY",
            secret_key="SECRET_KEY",  # noqa: S106
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
            access_key="ACCESS_KEY",
            secret_key="SECRET_KEY",  # noqa: S106
            public_url="https://public.example.com",
        )
        assert storage.access_key.get_secret_value() == "ACCESS_KEY"
        assert storage.secret_key.get_secret_value() == "SECRET_KEY"

    def test_str_representation_does_not_leak_secret(self) -> None:
        storage = DeveloperCiStorage(
            endpoint="https://example.com",
            bucket="bucket",
            access_key="ACCESS_KEY",
            secret_key="SECRET_KEY",  # noqa: S106
            public_url="https://public.example.com",
        )
        text = str(storage)
        assert "ACCESS_KEY" not in text
        assert "SECRET_KEY" not in text
        assert "**********" in text
