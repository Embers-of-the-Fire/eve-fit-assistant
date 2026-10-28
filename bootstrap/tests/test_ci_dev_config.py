from __future__ import annotations

import tomllib

from pathlib import Path

from bootstrap.config import DeveloperConfiguration
from bootstrap.constant import PROJECT_ROOT


CI_DEV_CONFIG_PATH = PROJECT_ROOT / "ci" / "config" / "efa.dev.toml"


def _load_ci_dev_config() -> DeveloperConfiguration:
    with open(CI_DEV_CONFIG_PATH, "rb") as f:
        raw = tomllib.load(f)
    return DeveloperConfiguration.model_validate(raw)


def test_ci_dev_config_validates():
    _load_ci_dev_config()


def test_ci_dev_config_mock_values():
    cfg = _load_ci_dev_config()
    mock = cfg.remote.mock
    assert mock is not None
    assert mock.port == 9110
    assert mock.console_port == 9111
    assert mock.bucket == "efa-ci-mock"
    assert mock.access_key.get_secret_value() == "efa-ci-mock-access"
    assert mock.secret_key.get_secret_value() == "efa-ci-mock-secret"
    assert mock.data_dir == Path("/tmp/efa-ci-mock")
    assert mock.public_download is True


def test_ci_dev_config_s3_secrets_are_placeholders():
    cfg = _load_ci_dev_config()
    s3 = cfg.remote.s3
    assert s3 is not None
    assert ".invalid" in s3.endpoint
    assert s3.bucket.startswith("placeholder")
    assert s3.access_key.get_secret_value().startswith("placeholder")
    assert s3.secret_key.get_secret_value().startswith("placeholder")
    assert s3.public_download is True


def test_ci_dev_config_ci_storage_secrets_are_placeholders():
    cfg = _load_ci_dev_config()
    storage = cfg.ci.storage
    assert storage is not None
    assert ".invalid" in storage.endpoint
    assert storage.bucket.startswith("placeholder")
    assert storage.access_key.get_secret_value().startswith("placeholder")
    assert storage.secret_key.get_secret_value().startswith("placeholder")
    assert storage.public_url == "https://ci.storage.efa-tech.dev"


def test_ci_dev_config_raw_artifacts():
    cfg = _load_ci_dev_config()
    raw = cfg.ci.raw_artifacts
    assert raw is not None
    assert raw.remote_root == "data-generator/raw-artifact"
    assert raw.public_url == "https://ci.storage.efa-tech.dev"
