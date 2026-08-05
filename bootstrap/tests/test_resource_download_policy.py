"""Tests for the lazy-download (NON_FORCE) resource classification."""

from __future__ import annotations

from typing import ClassVar

import pytest

from bootstrap.config import DEFAULT_LAZY_PREFIXES
from bootstrap.config import DownloadConfig
from bootstrap.config import ProjectConfiguration
from bootstrap.remote.models import RESOURCE_INDEX_FORMAT_VERSION
from bootstrap.remote.models import is_lazy_resource
from bootstrap.remote.models import make_resource_index


def _config_dict(**overrides: object) -> dict:
    base: dict = {
        "localizations": {
            "default": "en",
            "supported": ["en", "zh"],
            "translation": {"en": "English", "zh": "简体中文"},
        },
        "paths": {"log": "data/log"},
        "version": {"major": 0, "minor": 1, "patch": 0, "build": 1},
    }
    base.update(overrides)
    return base


class TestDownloadConfig:
    def test_default_lazy_prefixes_cover_all_images(self) -> None:
        assert DEFAULT_LAZY_PREFIXES == ["static/images/"]

    def test_model_default(self) -> None:
        assert DownloadConfig().lazy_prefixes == ["static/images/"]

    def test_project_configuration_defaults_without_table(self) -> None:
        cfg = ProjectConfiguration.model_validate(_config_dict())
        assert cfg.download.lazy_prefixes == ["static/images/"]

    def test_project_configuration_override(self) -> None:
        cfg = ProjectConfiguration.model_validate(
            _config_dict(download={"lazy_prefixes": ["static/images/graphics/"]})
        )
        assert cfg.download.lazy_prefixes == ["static/images/graphics/"]

    def test_project_configuration_empty_list_disables_lazy(self) -> None:
        cfg = ProjectConfiguration.model_validate(_config_dict(download={"lazy_prefixes": []}))
        assert cfg.download.lazy_prefixes == []


class TestIsLazyResource:
    def test_matches_prefix_relative_to_scheme(self) -> None:
        assert is_lazy_resource("resource://static/images/icons/1.png", ["static/images/"])
        assert is_lazy_resource("resource://static/images/graphics/2.png", ["static/images/"])

    def test_no_match_outside_prefix(self) -> None:
        assert not is_lazy_resource("resource://static/collection.pb2", ["static/images/"])
        assert not is_lazy_resource("resource://localization/localization.db", ["static/images/"])

    def test_empty_prefixes_never_lazy(self) -> None:
        assert not is_lazy_resource("resource://static/images/icons/1.png", [])


class TestMakeResourceIndex:
    _entries: ClassVar[list[tuple[str, str, int]]] = [
        ("resource://static/collection.pb2", "aa" * 32, 10),
        ("resource://static/images/icons/1.png", "bb" * 32, 20),
        ("resource://static/images/graphics/2.png", "cc" * 32, 30),
        ("resource://localization/localization.db", "dd" * 32, 40),
    ]

    def test_emits_policy_aware_format_without_touching_schema_version(self) -> None:
        index = make_resource_index(self._entries)
        # schema_version is reserved for the remote storage protocol.
        assert index.schema_version == 1
        assert index.format_version == RESOURCE_INDEX_FORMAT_VERSION == 3

    def test_default_classification_marks_all_images_lazy(self) -> None:
        index = make_resource_index(self._entries)
        policy = {e.resource_id: e.download_policy for e in index.entries}
        force = index.DownloadPolicy.FORCE
        non_force = index.DownloadPolicy.NON_FORCE
        assert policy["resource://static/collection.pb2"] == force
        assert policy["resource://localization/localization.db"] == force
        assert policy["resource://static/images/icons/1.png"] == non_force
        assert policy["resource://static/images/graphics/2.png"] == non_force

    def test_custom_prefixes(self) -> None:
        index = make_resource_index(self._entries, lazy_prefixes=["static/images/graphics/"])
        policy = {e.resource_id: e.download_policy for e in index.entries}
        non_force = index.DownloadPolicy.NON_FORCE
        force = index.DownloadPolicy.FORCE
        assert policy["resource://static/images/graphics/2.png"] == non_force
        assert policy["resource://static/images/icons/1.png"] == force

    def test_empty_prefixes_force_everything(self) -> None:
        index = make_resource_index(self._entries, lazy_prefixes=[])
        force = index.DownloadPolicy.FORCE
        assert all(e.download_policy == force for e in index.entries)
        assert index.format_version == RESOURCE_INDEX_FORMAT_VERSION

    def test_roundtrip_preserves_policy(self) -> None:
        from bootstrap.data.schema import resource_index_pb2

        index = make_resource_index(self._entries)
        parsed = resource_index_pb2.ResourceIndex.FromString(index.SerializeToString())
        assert parsed.format_version == RESOURCE_INDEX_FORMAT_VERSION
        assert {e.resource_id: e.download_policy for e in parsed.entries} == {
            e.resource_id: e.download_policy for e in index.entries
        }


if __name__ == "__main__":
    raise SystemExit(pytest.main([__file__, "-v"]))
