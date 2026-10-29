"""Tests for ``ResolutionVocabulary`` generation-path validation."""

from __future__ import annotations

import pytest

from pydantic import ValidationError

from bootstrap.resolution import ResolutionVocabulary


def _vocabulary(**overrides: str) -> ResolutionVocabulary:
    base = {
        "scheme": "resource://",
        "legacy_localization_db": "localization/localization.db",
        "localization_locales_prefix": "localization/locales/",
        "static_images_prefix": "static/images/",
        "static_models_prefix": "static/models/",
        "locale_placeholder": "locale",
    }
    base.update(overrides)
    return ResolutionVocabulary(**base)


class TestResolutionVocabularyPaths:
    def test_spec_values_are_valid(self) -> None:
        vocab = _vocabulary()
        assert vocab.legacy_localization_db == "localization/localization.db"
        assert vocab.localization_locales_prefix == "localization/locales/"

    @pytest.mark.parametrize(
        "value",
        [
            "/etc/localization.db",
            "//host/share/localization.db",
            "../escape.db",
            "localization/../../escape.db",
            r"..\escape.db",
            r"localization\..\..\escape.db",
            "C:/escape.db",
            "C:escape.db",
            "..",
        ],
    )
    def test_legacy_localization_db_rejects_escaping_paths(self, value: str) -> None:
        with pytest.raises(ValidationError):
            _vocabulary(legacy_localization_db=value)

    @pytest.mark.parametrize(
        "value",
        [
            "/etc/locales/",
            "//host/share/locales/",
            "../locales/",
            "localization/../locales/",
            r"..\locales/",
            r"localization\..\..\locales/",
            "C:/locales/",
            "C:locales/",
            "..",
        ],
    )
    def test_localization_locales_prefix_rejects_escaping_paths(self, value: str) -> None:
        with pytest.raises(ValidationError):
            _vocabulary(localization_locales_prefix=value)

    @pytest.mark.parametrize(
        "value",
        [
            "/etc/models/",
            "//host/share/models/",
            "../models/",
            "static/../models/",
            r"..\models/",
            r"static\..\..\models/",
            "C:/models/",
            "C:models/",
            "..",
        ],
    )
    def test_static_models_prefix_rejects_escaping_paths(self, value: str) -> None:
        with pytest.raises(ValidationError):
            _vocabulary(static_models_prefix=value)

    @pytest.mark.parametrize(
        ("field", "value"),
        [
            ("legacy_localization_db", "localization/combined.db"),
            ("localization_locales_prefix", "localization/per-locale/"),
            ("static_models_prefix", "assets/models/"),
        ],
    )
    def test_relative_paths_without_parent_segments_are_accepted(
        self, field: str, value: str
    ) -> None:
        vocab = _vocabulary(**{field: value})
        assert getattr(vocab, field) == value
