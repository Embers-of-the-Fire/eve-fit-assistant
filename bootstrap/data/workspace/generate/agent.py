from __future__ import annotations

import sqlite3

from typing import TYPE_CHECKING

from bootstrap.log import info


if TYPE_CHECKING:
    from pathlib import Path

    from bootstrap.data.workspace.generate import GeneratorDatasource


#: Magic stored in the SQLite header `application_id` field ("EFAR").
_AGENT_RESOURCE_APPLICATION_ID = 0x45464152


async def generate(ws_data: GeneratorDatasource):
    """Emits the agent resource database.

    Bundling placeholder: the database schema (e.g. the type-name search
    table backing the chat `search_items` tool) is defined later; for now an
    empty but valid SQLite database is shipped so the
    `resource://agent/agent_resource.db` resource exists in snapshots with
    the default FORCE download policy.
    """
    info("Generating agent resources...")

    write_placeholder(ws_data.paths.agent_resource_db_path)

    info("Generated agent resource database (placeholder).")


def write_placeholder(path: Path):
    """Writes an empty, valid SQLite database (no tables) at [path]."""
    path.unlink(missing_ok=True)

    connection = sqlite3.connect(path)
    try:
        # Setting application_id forces the header page to be written, so the
        # artifact is a valid non-empty SQLite file even without any tables.
        connection.execute(f"PRAGMA application_id = {_AGENT_RESOURCE_APPLICATION_ID}")
        connection.commit()
    finally:
        connection.close()
