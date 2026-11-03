"""Tests for the localization database generators (combined + per-locale)."""

from __future__ import annotations

import sqlite3

from types import SimpleNamespace
from typing import TYPE_CHECKING

from bootstrap.data.workspace.generate import localizations
from bootstrap.data.workspace.generate.loc_source import apply_localization_patches
from bootstrap.data.workspace.generate.loc_source import find_missing_strings
from bootstrap.data.workspace.generate.loc_source import resolve_localized_strings
from bootstrap.data.workspace.generate.localizations import LOCALE_DB_SCHEMA_VERSION
from bootstrap.data.workspace.generate.localizations import LOCALIZATION_DB_SCHEMA_VERSION
from bootstrap.data.workspace.generate.localizations import _write_locale_db
from bootstrap.data.workspace.generate.localizations import _write_strings_db


if TYPE_CHECKING:
    from pathlib import Path

    import pytest


def _read_meta(connection: sqlite3.Connection) -> dict[str, str]:
    return dict(connection.execute("SELECT key, value FROM meta").fetchall())


class TestCombinedDb:
    def test_schema_version_and_all_locales(self, tmp_path: Path) -> None:
        path = tmp_path / "localization" / "localization.db"
        path.parent.mkdir(parents=True)

        _write_strings_db(
            path,
            [("en", {1: "Tritanium"}), ("zh", {1: "三钛合金"})],
            schema_version=LOCALIZATION_DB_SCHEMA_VERSION,
        )

        connection = sqlite3.connect(path)
        try:
            meta = _read_meta(connection)
            locales = {
                row[0]
                for row in connection.execute("SELECT DISTINCT locale FROM strings").fetchall()
            }
        finally:
            connection.close()

        assert meta == {"schema_version": str(LOCALIZATION_DB_SCHEMA_VERSION)}
        assert locales == {"en", "zh"}


class TestLocaleDb:
    def test_schema_version_locale_meta_and_single_locale(self, tmp_path: Path) -> None:
        path = tmp_path / "localization" / "locales" / "zh.db"
        path.parent.mkdir(parents=True)

        _write_locale_db(path, "zh", {1: "三钛合金", 2: "同位聚合体"})

        connection = sqlite3.connect(path)
        try:
            meta = _read_meta(connection)
            rows = connection.execute(
                "SELECT locale, id, value FROM strings ORDER BY id"
            ).fetchall()
        finally:
            connection.close()

        assert meta == {"schema_version": str(LOCALE_DB_SCHEMA_VERSION), "locale": "zh"}
        assert rows == [("zh", 1, "三钛合金"), ("zh", 2, "同位聚合体")]

    def test_query_text_matches_combined_db(self, tmp_path: Path) -> None:
        # Client query text is identical for both databases (the `strings`
        # table keeps the `locale` column); the per-locale db answers the
        # same WHERE clause the combined db does.
        path = tmp_path / "en.db"

        _write_locale_db(path, "en", {34: "Tritanium"})

        connection = sqlite3.connect(path)
        try:
            rows = connection.execute(
                "SELECT id, value FROM strings WHERE locale = ? AND id IN (?)",
                ["en", 34],
            ).fetchall()
        finally:
            connection.close()

        assert rows == [(34, "Tritanium")]

    def test_overwrites_existing_file(self, tmp_path: Path) -> None:
        path = tmp_path / "en.db"
        path.write_bytes(b"stale content")

        _write_locale_db(path, "en", {34: "Tritanium"})

        connection = sqlite3.connect(path)
        try:
            count = connection.execute("SELECT COUNT(*) FROM strings").fetchone()[0]
        finally:
            connection.close()

        assert count == 1


class TestApplyLocalizationPatches:
    def test_fills_missing_by_english_text(self) -> None:
        reference = {1054541: "Advanced Carriers", 34: "Tritanium"}
        strings = {34: "三钛合金"}

        report = apply_localization_patches(
            strings, reference, {"Advanced Carriers": "高级航空母舰"}
        )

        assert strings[1054541] == "高级航空母舰"
        assert report.filled == {1054541: "高级航空母舰"}
        assert report.stale_keys == []

    def test_fills_empty_upstream_string(self) -> None:
        reference = {1: "Advanced Carriers"}
        strings = {1: ""}

        report = apply_localization_patches(
            strings, reference, {"Advanced Carriers": "高级航空母舰"}
        )

        assert strings[1] == "高级航空母舰"
        assert report.filled == {1: "高级航空母舰"}

    def test_never_overrides_existing_translation(self) -> None:
        reference = {1: "Carriers"}
        strings = {1: "航空母舰"}

        report = apply_localization_patches(strings, reference, {"Carriers": "母舰"})

        assert strings[1] == "航空母舰"
        assert report.filled == {}
        # Already translated upstream: the patch can never apply again.
        assert report.stale_keys == ["Carriers"]

    def test_ignores_empty_reference_text(self) -> None:
        reference = {1: ""}
        strings: dict[int, str] = {}

        report = apply_localization_patches(strings, reference, {"": "无"})

        assert strings == {}
        assert report.filled == {}

    def test_reports_stale_keys(self) -> None:
        reference = {1: "Advanced Carriers"}
        strings = {1: "高级航空母舰"}

        report = apply_localization_patches(
            strings,
            reference,
            {"Advanced Carriers": "高级航空母舰", "Removed Group": "已移除"},
        )

        assert report.filled == {}
        assert report.stale_keys == ["Advanced Carriers", "Removed Group"]


class TestResolveLocalizedStrings:
    def test_upstream_then_patch_then_default_precedence(self) -> None:
        reference = {1: "Upstream", 2: "Patched", 3: "English", 4: ""}
        strings = {1: "上游", 2: "", 3: "", 4: ""}

        report = resolve_localized_strings(
            strings, reference, {"Upstream": "覆盖", "Patched": "补丁"}
        )

        assert strings == {1: "上游", 2: "补丁", 3: "English", 4: ""}
        assert report.patches.filled == {2: "补丁"}
        assert report.patches.stale_keys == ["Upstream"]
        assert report.fallback_filled == [(3, "English")]

    def test_applies_default_fallback_without_patches(self) -> None:
        reference = {2: "Second", 1: "First"}
        strings = {2: ""}

        report = resolve_localized_strings(strings, reference, {})

        assert strings == {1: "First", 2: "Second"}
        assert report.patches.filled == {}
        assert report.patches.stale_keys == []
        assert report.fallback_filled == [(1, "First"), (2, "Second")]


class TestFindMissingStrings:
    def test_reports_missing_and_empty(self) -> None:
        reference = {1: "Advanced Carriers", 2: "Tritanium", 3: "Empty In Target"}
        strings = {2: "三钛合金", 3: ""}

        assert find_missing_strings(strings, reference) == [
            (1, "Advanced Carriers"),
            (3, "Empty In Target"),
        ]

    def test_ignores_empty_reference_text(self) -> None:
        reference = {1: ""}
        assert find_missing_strings({}, reference) == []


class TestFallbackWarning:
    def test_reports_terminal_and_github_warnings(
        self, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
    ) -> None:
        warnings: list[str] = []
        monkeypatch.setattr(localizations, "warning", warnings.append)
        monkeypatch.setenv("GITHUB_ACTIONS", "true")
        ws_data = SimpleNamespace(
            config=SimpleNamespace(metadata=SimpleNamespace(identifier="tranquility"))
        )

        getattr(localizations, "__report_fallback")(
            ws_data, "zh", "en", [(2, "Second"), (1, "First")]
        )

        assert len(warnings) == 1
        assert "Filled 2 missing zh strings with en on tranquility" in warnings[0]
        assert "data/resources/tranquility/patches/localization.yaml" in warnings[0]
        output = capsys.readouterr().out
        assert "::warning title=en fallback for zh localization (tranquility)::" in output
        assert "Filled 2 missing zh strings with en after curated patches" in output

    def test_does_not_warn_when_fallback_is_unused(
        self, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
    ) -> None:
        warnings: list[str] = []
        monkeypatch.setattr(localizations, "warning", warnings.append)
        monkeypatch.setenv("GITHUB_ACTIONS", "true")
        ws_data = SimpleNamespace(
            config=SimpleNamespace(metadata=SimpleNamespace(identifier="tranquility"))
        )

        getattr(localizations, "__report_fallback")(ws_data, "zh", "en", [])

        assert warnings == []
        assert capsys.readouterr().out == ""
