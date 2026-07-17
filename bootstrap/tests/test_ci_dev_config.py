from __future__ import annotations

import tomllib

from bootstrap.config import DeveloperConfiguration
from bootstrap.constant import PROJECT_ROOT


CI_DEV_CONFIG_PATH = PROJECT_ROOT / "ci" / "config" / "efa.dev.toml"


def _load_ci_dev_config() -> DeveloperConfiguration:
    with open(CI_DEV_CONFIG_PATH, "rb") as f:
        raw = tomllib.load(f)
    return DeveloperConfiguration.model_validate(raw)


def test_ci_dev_config_validates():
    _load_ci_dev_config()


def test_ci_dev_config_minio_mock_values():
    cfg = _load_ci_dev_config()
    minio = cfg.remote.minio
    assert minio is not None
    assert minio.port == 9110
    assert minio.console_port == 9111
    assert minio.bucket == "efa-ci-mock"
    assert minio.access_key.get_secret_value() == "efa-ci-mock-access"
    assert minio.secret_key.get_secret_value() == "efa-ci-mock-secret"
    assert str(minio.data_dir) == "/tmp/efa-ci-minio"
    assert minio.alias == "efa-ci-mock"
    assert minio.public_download is True


def test_ci_dev_config_s3_secrets_are_placeholders():
    cfg = _load_ci_dev_config()
    s3 = cfg.remote.s3
    assert s3 is not None
    assert ".invalid" in s3.endpoint
    assert s3.bucket.startswith("placeholder")
    assert s3.access_key.get_secret_value().startswith("placeholder")
    assert s3.secret_key.get_secret_value().startswith("placeholder")
    assert s3.alias == "efa-remote-publish"
    assert s3.public_download is True


def test_ci_dev_config_ci_storage_secrets_are_placeholders():
    cfg = _load_ci_dev_config()
    storage = cfg.ci.storage
    assert storage is not None
    assert ".invalid" in storage.endpoint
    assert storage.bucket.startswith("placeholder")
    assert storage.access_key.get_secret_value().startswith("placeholder")
    assert storage.secret_key.get_secret_value().startswith("placeholder")
    assert storage.alias == "efa-ci-storage"
    assert storage.public_url == "https://ci.storage.efa-tech.dev"


def test_ci_dev_config_raw_artifacts():
    cfg = _load_ci_dev_config()
    raw = cfg.ci.raw_artifacts
    assert raw is not None
    assert raw.remote_root == "data-generator/raw-artifact"
    assert raw.public_url == "https://ci.storage.efa-tech.dev"
