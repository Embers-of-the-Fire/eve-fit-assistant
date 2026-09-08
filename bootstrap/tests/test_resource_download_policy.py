"""Tests for the lazy-download (NON_FORCE) resource classification."""

from __future__ import annotations

from typing import ClassVar

import pytest

from bootstrap.config import DEFAULT_LAZY_PREFIXES
from bootstrap.config import DEFAULT_RESOLUTION_VOCABULARY
from bootstrap.config import DownloadConfig
from bootstrap.config import ProjectConfiguration
from bootstrap.config import effective_lazy_prefixes
from bootstrap.config import effective_resolution
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
    def test_default_lazy_prefixes_cover_images_and_per_locale_dbs(self) -> None:
        assert DEFAULT_LAZY_PREFIXES == ["static/images/", "localization/locales/"]

    def test_model_default(self) -> None:
        assert DownloadConfig().lazy_prefixes == ["static/images/", "localization/locales/"]

    def test_project_configuration_defaults_without_table(self) -> None:
        cfg = ProjectConfiguration.model_validate(_config_dict())
        assert cfg.download.lazy_prefixes == ["static/images/", "localization/locales/"]

    def test_project_configuration_override(self) -> None:
        cfg = ProjectConfiguration.model_validate(
            _config_dict(download={"lazy_prefixes": ["static/images/graphics/"]})
        )
        assert cfg.download.lazy_prefixes == ["static/images/graphics/"]

    def test_project_configuration_empty_list_disables_lazy(self) -> None:
        cfg = ProjectConfiguration.model_validate(_config_dict(download={"lazy_prefixes": []}))
        assert cfg.download.lazy_prefixes == []

    def test_custom_resolution_derives_lazy_prefixes_without_download_override(self) -> None:
        cfg = ProjectConfiguration.model_validate(
            _config_dict(
                resolution={
                    "static_images_prefix": "assets/images/",
                    "localization_locales_prefix": "i18n/locales/",
                }
            )
        )
        assert cfg.download.lazy_prefixes == ["assets/images/", "i18n/locales/"]

    def test_explicit_download_override_wins_over_custom_resolution(self) -> None:
        cfg = ProjectConfiguration.model_validate(
            _config_dict(
                resolution={"static_images_prefix": "assets/images/"},
                download={"lazy_prefixes": ["assets/images/graphics/"]},
            )
        )
        assert cfg.download.lazy_prefixes == ["assets/images/graphics/"]

    def test_explicit_empty_list_survives_custom_resolution(self) -> None:
        cfg = ProjectConfiguration.model_validate(
            _config_dict(
                resolution={"static_images_prefix": "assets/images/"},
                download={"lazy_prefixes": []},
            )
        )
        assert cfg.download.lazy_prefixes == []


class TestEffectiveVocabulary:
    def test_falls_back_to_builtin_vocabulary_without_configuration(
        self, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        monkeypatch.setattr("bootstrap.config.CONFIGURATION", None)
        assert effective_resolution() is DEFAULT_RESOLUTION_VOCABULARY
        assert effective_lazy_prefixes() == DEFAULT_LAZY_PREFIXES

    def test_uses_loaded_configuration(self, monkeypatch: pytest.MonkeyPatch) -> None:
        cfg = ProjectConfiguration.model_validate(_config_dict(resolution={"scheme": "custom://"}))
        monkeypatch.setattr("bootstrap.config.CONFIGURATION", cfg)
        assert effective_resolution().scheme == "custom://"
        assert effective_lazy_prefixes() == cfg.download.lazy_prefixes


class TestIsLazyResource:
    def test_matches_prefix_relative_to_scheme(self) -> None:
        assert is_lazy_resource("resource://static/images/icons/1.png", ["static/images/"])
        assert is_lazy_resource("resource://static/images/graphics/2.png", ["static/images/"])

    def test_no_match_outside_prefix(self) -> None:
        assert not is_lazy_resource("resource://static/collection.pb2", ["static/images/"])
        assert not is_lazy_resource("resource://localization/localization.db", ["static/images/"])
        assert not is_lazy_resource("resource://agent/agent_resource.db", ["static/images/"])

    def test_locales_prefix_does_not_match_legacy_combined_db(self) -> None:
        # The legacy combined db must stay FORCE for released clients; the
        # per-locale prefix matches only the per-locale databases.
        assert is_lazy_resource("resource://localization/locales/en.db", ["localization/locales/"])
        assert not is_lazy_resource(
            "resource://localization/localization.db", ["localization/locales/"]
        )

    def test_empty_prefixes_never_lazy(self) -> None:
        assert not is_lazy_resource("resource://static/images/icons/1.png", [])

    def test_strips_custom_scheme_from_loaded_configuration(
        self, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        cfg = ProjectConfiguration.model_validate(_config_dict(resolution={"scheme": "custom://"}))
        monkeypatch.setattr("bootstrap.config.CONFIGURATION", cfg)
        assert is_lazy_resource("custom://static/images/icons/1.png", ["static/images/"])
        # The built-in scheme no longer strips: the path keeps its prefix.
        assert not is_lazy_resource("resource://static/images/icons/1.png", ["static/images/"])


class TestMakeResourceIndex:
    _entries: ClassVar[list[tuple[str, str, int]]] = [
        ("resource://static/collection.pb2", "aa" * 32, 10),
        ("resource://static/images/icons/1.png", "bb" * 32, 20),
        ("resource://static/images/graphics/2.png", "cc" * 32, 30),
        ("resource://localization/localization.db", "dd" * 32, 40),
        ("resource://localization/locales/en.db", "ff" * 32, 60),
        ("resource://agent/agent_resource.db", "ee" * 32, 50),
    ]

    def test_emits_policy_aware_format_without_touching_schema_version(self) -> None:
        index = make_resource_index(self._entries)
        # schema_version is reserved for the remote storage protocol.
        assert index.schema_version == 1
        assert index.format_version == RESOURCE_INDEX_FORMAT_VERSION == 2

    def test_default_classification_marks_images_and_per_locale_dbs_lazy(self) -> None:
        index = make_resource_index(self._entries)
        policy = {e.resource_id: e.download_policy for e in index.entries}
        force = index.DownloadPolicy.FORCE
        non_force = index.DownloadPolicy.NON_FORCE
        assert policy["resource://static/collection.pb2"] == force
        # The legacy combined db stays FORCE: released native clients open it
        # via a direct file path that cannot fetch lazily.
        assert policy["resource://localization/localization.db"] == force
        assert policy["resource://agent/agent_resource.db"] == force
        assert policy["resource://static/images/icons/1.png"] == non_force
        assert policy["resource://static/images/graphics/2.png"] == non_force
        assert policy["resource://localization/locales/en.db"] == non_force

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

    def test_omitted_prefixes_follow_custom_resolution_without_download_override(
        self, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        cfg = ProjectConfiguration.model_validate(
            _config_dict(
                resolution={
                    "scheme": "custom://",
                    "static_images_prefix": "assets/images/",
                    "localization_locales_prefix": "i18n/locales/",
                    "legacy_localization_db": "i18n/combined.db",
                }
            )
        )
        monkeypatch.setattr("bootstrap.config.CONFIGURATION", cfg)

        entries = [
            ("custom://static/collection.pb2", "aa" * 32, 10),
            ("custom://assets/images/icons/1.png", "bb" * 32, 20),
            ("custom://i18n/locales/en.db", "cc" * 32, 30),
            ("custom://i18n/combined.db", "dd" * 32, 40),
        ]
        index = make_resource_index(entries)
        policy = {e.resource_id: e.download_policy for e in index.entries}
        force = index.DownloadPolicy.FORCE
        non_force = index.DownloadPolicy.NON_FORCE
        assert policy["custom://assets/images/icons/1.png"] == non_force
        assert policy["custom://i18n/locales/en.db"] == non_force
        # The legacy combined db stays FORCE, as under the built-in defaults.
        assert policy["custom://i18n/combined.db"] == force
        assert policy["custom://static/collection.pb2"] == force

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
