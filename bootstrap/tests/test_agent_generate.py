"""Tests for the agent resource database generator."""

from __future__ import annotations

import sqlite3

from typing import TYPE_CHECKING

from bootstrap.data.workspace.generate.agent import _AGENT_RESOURCE_APPLICATION_ID
from bootstrap.data.workspace.generate.agent import AGENT_RESOURCE_DB_SCHEMA_VERSION
from bootstrap.data.workspace.generate.agent import _type_name_ids
from bootstrap.data.workspace.generate.agent import _write_db


if TYPE_CHECKING:
    from pathlib import Path


class TestTypeNameIds:
    def test_extracts_type_name_mapping(self) -> None:
        raw = {
            34: {"typeID": 34, "typeNameID": 67718},
            "35": {"typeID": 35, "typeNameID": 67719},
        }
        assert _type_name_ids(raw) == {34: 67718, 35: 67719}

    def test_skips_missing_name_id(self) -> None:
        raw = {34: {"typeID": 34}}
        assert _type_name_ids(raw) == {}


class TestWriteDb:
    def test_writes_queryable_type_names(self, tmp_path: Path) -> None:
        path = tmp_path / "agent" / "agent_resource.db"
        path.parent.mkdir(parents=True)

        _write_db(
            path,
            [
                ("en", [(34, "Tritanium"), (35, "Pyerite")]),
                ("zh", [(34, "三钛合金")]),
            ],
        )

        connection = sqlite3.connect(path)
        try:
            app_id = connection.execute("PRAGMA application_id").fetchone()[0]
            version = connection.execute(
                "SELECT value FROM meta WHERE key = 'schema_version'"
            ).fetchone()[0]
            rows = connection.execute(
                "SELECT id, value FROM type_names WHERE locale = ? AND value LIKE ? "
                "ORDER BY LENGTH(value) ASC",
                ["en", "%trit%"],
            ).fetchall()
            zh_rows = connection.execute(
                "SELECT id, value FROM type_names WHERE locale = ?", ["zh"]
            ).fetchall()
        finally:
            connection.close()

        assert app_id == _AGENT_RESOURCE_APPLICATION_ID
        assert version == str(AGENT_RESOURCE_DB_SCHEMA_VERSION)
        assert rows == [(34, "Tritanium")]
        assert zh_rows == [(34, "三钛合金")]

    def test_ids_are_real_type_ids_not_name_ids(self, tmp_path: Path) -> None:
        path = tmp_path / "agent_resource.db"

        _write_db(path, [("en", [(34, "Tritanium")])])

        connection = sqlite3.connect(path)
        try:
            (stored_id,) = connection.execute("SELECT id FROM type_names").fetchone()
        finally:
            connection.close()

        assert stored_id == 34

    def test_overwrites_existing_file(self, tmp_path: Path) -> None:
        path = tmp_path / "agent_resource.db"
        path.write_bytes(b"stale content")

        _write_db(path, [("en", [(34, "Tritanium")])])

        connection = sqlite3.connect(path)
        try:
            count = connection.execute("SELECT COUNT(*) FROM type_names").fetchone()[0]
        finally:
            connection.close()

        assert count == 1
