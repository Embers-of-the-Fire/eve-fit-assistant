from __future__ import annotations

import asyncio
import pickle
import sqlite3

from typing import TYPE_CHECKING

from pydantic import BaseModel
from pydantic import ValidationError

import bootstrap.config

from bootstrap.localization import to_native_localization
from bootstrap.log import error
from bootstrap.log import info


if TYPE_CHECKING:
    from pathlib import Path

    from bootstrap.data.workspace.generate import GeneratorDatasource
    from bootstrap.localization import LocalizationType


#: Magic stored in the SQLite header `application_id` field ("EFAR").
_AGENT_RESOURCE_APPLICATION_ID = 0x45464152

#: Schema version of the emitted agent resource SQLite database. Bump when the
#: layout changes; clients refuse to open mismatched versions.
AGENT_RESOURCE_DB_SCHEMA_VERSION = 1


class _TypeNameRef(BaseModel):
    typeNameID: int | None = None


async def generate(ws_data: GeneratorDatasource):
    """Emits the agent resource database.

    Currently carries only the `type_names` table: localized type names keyed
    by real type id (resolved through the FSD `typeNameID`, which differs
    from the type id), backing the chat `search_items` tool.
    """
    info("Generating agent resources...")

    raw_types = await ws_data.resources.fsd.get("types")
    name_ids = _type_name_ids(raw_types)

    target_languages = bootstrap.config.CONFIGURATION.localizations.supported
    per_locale = await asyncio.gather(
        *(_locale_rows(ws_data, lang, name_ids) for lang in target_languages)
    )

    _write_db(ws_data.paths.agent_resource_db_path, per_locale)


def _type_name_ids(raw_types: dict) -> dict[int, int]:
    """Maps type id to its localization message id (`typeNameID`)."""
    result: dict[int, int] = {}
    for type_id, raw in raw_types.items():
        try:
            ref = _TypeNameRef.model_validate(raw)
        except ValidationError as e:
            error(f"Failed to validate type {type_id} for agent resources: {e}")
            continue
        if ref.typeNameID is not None:
            result[int(type_id)] = ref.typeNameID
    return result


async def _locale_rows(
    ws_data: GeneratorDatasource,
    lang: LocalizationType,
    name_ids: dict[int, int],
) -> tuple[str, list[tuple[int, str]]]:
    """Resolves (type id, localized name) rows for one locale."""
    resource = ws_data.resources.res.get_resource(
        f"res:/localizationfsd/localization_fsd_{to_native_localization(lang)}.pickle"
    )
    async with resource.open() as f:
        _lang_code, loc = pickle.loads(await f.read())

    rows = [
        (type_id, loc[name_id][0])
        for type_id, name_id in name_ids.items()
        if name_id in loc and loc[name_id][0]
    ]
    return lang, rows


def _write_db(path: Path, per_locale: list[tuple[str, list[tuple[int, str]]]]):
    """Writes the agent resource database.

    Layout: `type_names(locale TEXT, id INTEGER, value TEXT, PRIMARY KEY(locale, id))`
    where `id` is the real type id, plus a `meta` table carrying the schema
    version. Clients open the database read-only.
    """
    path.unlink(missing_ok=True)

    connection = sqlite3.connect(path)
    try:
        connection.execute("PRAGMA journal_mode = OFF")
        connection.execute("PRAGMA synchronous = OFF")
        connection.execute(f"PRAGMA application_id = {_AGENT_RESOURCE_APPLICATION_ID}")
        connection.execute("CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT NOT NULL)")
        connection.execute(
            "CREATE TABLE type_names("
            "locale TEXT NOT NULL, "
            "id INTEGER NOT NULL, "
            "value TEXT NOT NULL, "
            "PRIMARY KEY(locale, id)"
            ") WITHOUT ROWID"
        )
        connection.execute(
            "INSERT INTO meta(key, value) VALUES ('schema_version', ?)",
            (str(AGENT_RESOURCE_DB_SCHEMA_VERSION),),
        )

        total = 0
        for lang, rows in per_locale:
            connection.executemany(
                "INSERT INTO type_names(locale, id, value) VALUES (?, ?, ?)",
                [(lang, type_id, name) for type_id, name in rows],
            )
            total += len(rows)

        connection.commit()
    finally:
        connection.close()

    info(f"Generated agent resource database ({total} type names).")
