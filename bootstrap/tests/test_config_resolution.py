"""Tests for ``ResolutionVocabulary`` generation-path validation."""

from __future__ import annotations

import pytest

from pydantic import ValidationError

from bootstrap.config import ResolutionVocabulary


class TestResolutionVocabularyPaths:
    def test_defaults_are_valid(self) -> None:
        vocab = ResolutionVocabulary()
        assert vocab.legacy_localization_db == "localization/localization.db"
        assert vocab.localization_locales_prefix == "localization/locales/"

    @pytest.mark.parametrize(
        "value",
        [
            "/etc/localization.db",
            "//host/share/localization.db",
            "../escape.db",
            "localization/../../escape.db",
            "..",
        ],
    )
    def test_legacy_localization_db_rejects_escaping_paths(self, value: str) -> None:
        with pytest.raises(ValidationError):
            ResolutionVocabulary(legacy_localization_db=value)

    @pytest.mark.parametrize(
        "value",
        [
            "/etc/locales/",
            "//host/share/locales/",
            "../locales/",
            "localization/../locales/",
            "..",
        ],
    )
    def test_localization_locales_prefix_rejects_escaping_paths(self, value: str) -> None:
        with pytest.raises(ValidationError):
            ResolutionVocabulary(localization_locales_prefix=value)

    @pytest.mark.parametrize(
        ("field", "value"),
        [
            ("legacy_localization_db", "localization/combined.db"),
            ("localization_locales_prefix", "localization/per-locale/"),
        ],
    )
    def test_relative_paths_without_parent_segments_are_accepted(
        self, field: str, value: str
    ) -> None:
        vocab = ResolutionVocabulary(**{field: value})
        assert getattr(vocab, field) == value
