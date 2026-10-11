"""Tests for the ship-model generator's job construction."""

from __future__ import annotations

import pytest

from bootstrap.data.workspace.generate.models import SHIP_CATEGORY_ID
from bootstrap.data.workspace.generate.models import build_ship_jobs


def _groups() -> dict:
    return {
        25: {"categoryID": SHIP_CATEGORY_ID},  # Frigate
        26: {"categoryID": SHIP_CATEGORY_ID},  # Cruiser
        358: {"categoryID": 16},  # Large Projectile Ammo (not a ship)
    }


def _types() -> dict:
    return {
        587: {"groupID": 25, "graphicID": 46},  # Rifter
        588: {"groupID": 25, "graphicID": 47},
        590: {"groupID": 358, "graphicID": 100},  # ammo: excluded
        591: {"groupID": 25, "graphicID": 999},  # unknown graphic: excluded
        592: {"groupID": 25, "graphicID": 200},  # legacy graphicFile: excluded
        593: {"groupID": 25},  # no graphicID: excluded
    }


def _graphicids() -> dict:
    return {
        46: {
            "sofHullName": "mf4_t1",
            "sofFactionName": "minmatarbase",
            "sofRaceName": "minmatar",
        },
        47: {
            "sofHullName": "af1_t1",
            "sofFactionName": "amarrbase",
            "sofRaceName": "amarr",
        },
        200: {"graphicFile": "res:/legacy.red"},
    }


class TestBuildShipJobs:
    def test_selects_sof_backed_ships_only(self) -> None:
        jobs = build_ship_jobs(_types(), _groups(), _graphicids())
        assert jobs == {
            587: "mf4_t1:minmatarbase:minmatar",
            588: "af1_t1:amarrbase:amarr",
        }

    def test_empty_tables_produce_no_jobs(self) -> None:
        assert build_ship_jobs({}, {}, {}) == {}

    def test_missing_group_excludes_type(self) -> None:
        types = {1: {"groupID": 9999, "graphicID": 46}}
        assert build_ship_jobs(types, _groups(), _graphicids()) == {}


if __name__ == "__main__":
    raise SystemExit(pytest.main([__file__, "-v"]))
