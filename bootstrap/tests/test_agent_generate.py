"""Tests for the agent resource database generator."""

from __future__ import annotations

import sqlite3

from typing import TYPE_CHECKING

from bootstrap.data.workspace.generate.agent import _AGENT_RESOURCE_APPLICATION_ID
from bootstrap.data.workspace.generate.agent import AGENT_RESOURCE_DB_SCHEMA_VERSION
from bootstrap.data.workspace.generate.agent import _type_metas
from bootstrap.data.workspace.generate.agent import _type_name_ids
from bootstrap.data.workspace.generate.agent import _TypeMeta
from bootstrap.data.workspace.generate.agent import _write_db


if TYPE_CHECKING:
    from pathlib import Path


class TestTypeNameIds:
    def test_extracts_type_name_mapping(self) -> None:
        raw = {
            34: {"typeID": 34, "typeNameID": 67718, "groupID": 18},
            "35": {"typeID": 35, "typeNameID": 67719, "groupID": 18},
        }
        assert _type_name_ids(raw) == {34: 67718, 35: 67719}

    def test_skips_missing_name_id(self) -> None:
        raw = {34: {"typeID": 34, "groupID": 18}}
        assert _type_name_ids(raw) == {}


class TestTypeMetas:
    def test_resolves_group_and_category(self) -> None:
        metas = _type_metas(
            {34: {"typeID": 34, "typeNameID": 67718, "groupID": 18}},
            {18: {"groupID": 18, "categoryID": 4}},
            {},
        )
        meta = metas[34]
        assert meta.group_id == 18
        assert meta.category_id == 4
        assert meta.slot_index is None
        assert meta.slot_kind is None

    def test_unknown_group_yields_null_category(self) -> None:
        metas = _type_metas({34: {"typeID": 34, "groupID": 9999}}, {}, {})
        assert metas[34].group_id == 9999
        assert metas[34].category_id is None

    def test_implant_and_booster_slots(self) -> None:
        metas = _type_metas(
            {
                33516: {"typeID": 33516, "groupID": 748},
                81083: {"typeID": 81083, "groupID": 1735},
            },
            {},
            {
                33516: {"dogmaAttributes": [{"attributeID": 331, "value": 1.0}]},
                81083: {"dogmaAttributes": [{"attributeID": 1087, "value": 2.0}]},
            },
        )
        assert metas[33516].slot_kind == "implant"
        assert metas[33516].slot_index == 1
        assert metas[81083].slot_kind == "booster"
        assert metas[81083].slot_index == 2


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
            {34: _meta(group_id=18, category_id=4), 35: _meta(group_id=18, category_id=4)},
        )

        connection = sqlite3.connect(path)
        try:
            app_id = connection.execute("PRAGMA application_id").fetchone()[0]
            version = connection.execute(
                "SELECT value FROM meta WHERE key = 'schema_version'"
            ).fetchone()[0]
            rows = connection.execute(
                "SELECT id, value, group_id, category_id FROM type_names "
                "WHERE locale = ? AND value LIKE ? ORDER BY LENGTH(value) ASC",
                ["en", "%trit%"],
            ).fetchall()
            zh_rows = connection.execute(
                "SELECT id, value FROM type_names WHERE locale = ?", ["zh"]
            ).fetchall()
        finally:
            connection.close()

        assert app_id == _AGENT_RESOURCE_APPLICATION_ID
        assert version == str(AGENT_RESOURCE_DB_SCHEMA_VERSION)
        assert rows == [(34, "Tritanium", 18, 4)]
        assert zh_rows == [(34, "三钛合金")]

    def test_writes_slot_metadata(self, tmp_path: Path) -> None:
        path = tmp_path / "agent_resource.db"

        _write_db(
            path,
            [("en", [(33516, "High-grade Crystal Alpha")])],
            {33516: _meta(group_id=748, category_id=20, slot_index=1, slot_kind="implant")},
        )

        connection = sqlite3.connect(path)
        try:
            row = connection.execute(
                "SELECT slot_index, slot_kind FROM type_names WHERE id = 33516"
            ).fetchone()
        finally:
            connection.close()

        assert row == (1, "implant")

    def test_ids_are_real_type_ids_not_name_ids(self, tmp_path: Path) -> None:
        path = tmp_path / "agent_resource.db"

        _write_db(path, [("en", [(34, "Tritanium")])], {})

        connection = sqlite3.connect(path)
        try:
            (stored_id,) = connection.execute("SELECT id FROM type_names").fetchone()
        finally:
            connection.close()

        assert stored_id == 34

    def test_overwrites_existing_file(self, tmp_path: Path) -> None:
        path = tmp_path / "agent_resource.db"
        path.write_bytes(b"stale content")

        _write_db(path, [("en", [(34, "Tritanium")])], {})

        connection = sqlite3.connect(path)
        try:
            count = connection.execute("SELECT COUNT(*) FROM type_names").fetchone()[0]
        finally:
            connection.close()

        assert count == 1


def _meta(
    group_id: int | None = None,
    category_id: int | None = None,
    slot_index: int | None = None,
    slot_kind: str | None = None,
) -> _TypeMeta:
    return _TypeMeta(
        group_id=group_id,
        category_id=category_id,
        slot_index=slot_index,
        slot_kind=slot_kind,
    )
