"""Tests for the localization database generators (combined + per-locale)."""

from __future__ import annotations

import sqlite3

from typing import TYPE_CHECKING

from bootstrap.data.workspace.generate.localizations import LOCALE_DB_SCHEMA_VERSION
from bootstrap.data.workspace.generate.localizations import LOCALIZATION_DB_SCHEMA_VERSION
from bootstrap.data.workspace.generate.localizations import _write_locale_db
from bootstrap.data.workspace.generate.localizations import _write_strings_db


if TYPE_CHECKING:
    from pathlib import Path


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
