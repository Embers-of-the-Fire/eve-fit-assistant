"""Tests for the agent resource database bundling placeholder."""

from __future__ import annotations

import sqlite3

from typing import TYPE_CHECKING

from bootstrap.data.workspace.generate.agent import _AGENT_RESOURCE_APPLICATION_ID
from bootstrap.data.workspace.generate.agent import write_placeholder


if TYPE_CHECKING:
    from pathlib import Path


class TestWritePlaceholder:
    def test_creates_valid_sqlite_file(self, tmp_path: Path) -> None:
        path = tmp_path / "agent" / "agent_resource.db"
        path.parent.mkdir(parents=True)

        write_placeholder(path)

        assert path.is_file()
        assert path.stat().st_size > 0

        connection = sqlite3.connect(path)
        try:
            app_id = connection.execute("PRAGMA application_id").fetchone()[0]
            tables = connection.execute(
                "SELECT name FROM sqlite_master WHERE type = 'table'"
            ).fetchall()
        finally:
            connection.close()

        assert app_id == _AGENT_RESOURCE_APPLICATION_ID
        assert tables == []

    def test_overwrites_existing_file(self, tmp_path: Path) -> None:
        path = tmp_path / "agent_resource.db"
        path.write_bytes(b"stale content")

        write_placeholder(path)

        connection = sqlite3.connect(path)
        try:
            tables = connection.execute(
                "SELECT name FROM sqlite_master WHERE type = 'table'"
            ).fetchall()
        finally:
            connection.close()

        assert tables == []
