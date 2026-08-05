from __future__ import annotations

import asyncio
import pickle
import sqlite3

from typing import TYPE_CHECKING

import aiofiles

import bootstrap.config

from bootstrap.data.schema import localizations_pb2
from bootstrap.localization import to_native_localization
from bootstrap.log import info


if TYPE_CHECKING:
    from pathlib import Path

    from bootstrap.data.workspace.generate import GeneratorDatasource
    from bootstrap.localization import LocalizationType


#: Schema version of the emitted localization SQLite database. Bump when the
#: layout changes; clients refuse to open mismatched versions.
LOCALIZATION_DB_SCHEMA_VERSION = 1


def __to_proto_loc_type(loc_type: LocalizationType) -> localizations_pb2.LocalizationLanguage:
    match loc_type:
        case "en":
            return localizations_pb2.LocalizationLanguage.EN
        case "zh":
            return localizations_pb2.LocalizationLanguage.ZH

    raise ValueError(f"Unknown localization type: {loc_type}")


async def generate(ws_data: GeneratorDatasource):
    info("Generating localizations...")

    target_languages = bootstrap.config.CONFIGURATION.localizations.supported

    per_language = await asyncio.gather(*(__generate(ws_data, lang) for lang in target_languages))

    __write_localization_db(ws_data.paths.localization_db_path, per_language)

    info(f"Generated {len(target_languages)} localizations.")


async def __generate(
    ws_data: GeneratorDatasource, lang: LocalizationType
) -> tuple[str, dict[int, str]]:
    file = ws_data.resources.res.get_resource(
        f"res:/localizationfsd/localization_fsd_{to_native_localization(lang)}.pickle"
    )

    async with file.open() as f:
        _lang_code, loc = pickle.loads(await f.read())

    strings: dict[int, str] = {key: value[0] for key, value in loc.items()}

    pb = localizations_pb2.Localization()
    pb.language = __to_proto_loc_type(lang)
    for key, value in strings.items():
        pb.localized_strings[key] = value

    # The protobuf bundle is preserved for backward compatibility with older
    # clients; newer clients query the SQLite database instead.
    async with aiofiles.open(ws_data.paths.get_localization_path(lang), "wb") as f:
        await f.write(pb.SerializeToString())

    info(f"Generated localization for {lang}.")
    return lang, strings


def __write_localization_db(path: Path, per_language: list[tuple[str, dict[int, str]]]):
    """Writes all localized strings into a single SQLite database.

    Layout: `strings(locale TEXT, id INTEGER, value TEXT, PRIMARY KEY(locale, id))`
    plus a `meta` table carrying the schema version. Clients open the database
    read-only and resolve names lazily by primary-key lookup.
    """
    path.unlink(missing_ok=True)

    connection = sqlite3.connect(path)
    try:
        connection.execute("PRAGMA journal_mode = OFF")
        connection.execute("PRAGMA synchronous = OFF")
        connection.execute("CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT NOT NULL)")
        connection.execute(
            "CREATE TABLE strings("
            "locale TEXT NOT NULL, "
            "id INTEGER NOT NULL, "
            "value TEXT NOT NULL, "
            "PRIMARY KEY(locale, id)"
            ") WITHOUT ROWID"
        )
        connection.execute(
            "INSERT INTO meta(key, value) VALUES ('schema_version', ?)",
            (str(LOCALIZATION_DB_SCHEMA_VERSION),),
        )

        total = 0
        for lang, strings in per_language:
            connection.executemany(
                "INSERT INTO strings(locale, id, value) VALUES (?, ?, ?)",
                [(lang, key, value) for key, value in strings.items()],
            )
            total += len(strings)

        connection.commit()
    finally:
        connection.close()

    info(f"Generated localization database ({total} strings).")
