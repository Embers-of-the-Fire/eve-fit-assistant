from __future__ import annotations

import asyncio
import pickle
import sqlite3

from typing import TYPE_CHECKING

import bootstrap.config

from bootstrap.localization import to_native_localization
from bootstrap.log import info


if TYPE_CHECKING:
    from pathlib import Path

    from bootstrap.data.workspace.generate import GeneratorDatasource
    from bootstrap.localization import LocalizationType


#: Schema version of the emitted legacy combined localization SQLite database.
#: Bump when the layout changes; clients refuse to open mismatched versions.
LOCALIZATION_DB_SCHEMA_VERSION = 1

#: Schema version of the emitted per-locale localization SQLite databases
#: (`localization/locales/<locale>.db`). Same table shapes as the combined
#: database, so client query text is identical for both.
LOCALE_DB_SCHEMA_VERSION = 2


async def generate(ws_data: GeneratorDatasource):
    info("Generating localizations...")

    target_languages = bootstrap.config.CONFIGURATION.localizations.supported

    per_language = await asyncio.gather(*(__generate(ws_data, lang) for lang in target_languages))

    __write_localization_db(ws_data.paths.localization_db_path, per_language)
    for lang, strings in per_language:
        _write_locale_db(ws_data.paths.localization_locale_db_path(lang), lang, strings)

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

    # Localization ships only as the SQLite database; the per-language
    # protobuf bundle is no longer emitted.
    info(f"Generated localization for {lang}.")
    return lang, strings


def __write_localization_db(path: Path, per_language: list[tuple[str, dict[int, str]]]):
    """Writes all localized strings into the legacy combined SQLite database.

    Retained indefinitely for older clients; carries every supported locale.
    """
    _write_strings_db(path, per_language, schema_version=LOCALIZATION_DB_SCHEMA_VERSION)
    total = sum(len(strings) for _, strings in per_language)
    info(f"Generated localization database ({total} strings).")


def _write_locale_db(path: Path, locale: str, strings: dict[int, str]):
    """Writes the per-locale SQLite database for a single locale.

    Carries `meta.locale` for diagnostics and pipeline verification; the
    `strings.locale` column is retained (single value) so client query text
    is identical to the combined database.
    """
    _write_strings_db(
        path,
        [(locale, strings)],
        schema_version=LOCALE_DB_SCHEMA_VERSION,
        extra_meta={"locale": locale},
    )
    info(f"Generated per-locale localization database for {locale} ({len(strings)} strings).")


def _write_strings_db(
    path: Path,
    per_language: list[tuple[str, dict[int, str]]],
    *,
    schema_version: int,
    extra_meta: dict[str, str] | None = None,
):
    """Writes localized strings into a SQLite database.

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
            (str(schema_version),),
        )
        for key, value in (extra_meta or {}).items():
            connection.execute(
                "INSERT INTO meta(key, value) VALUES (?, ?)",
                (key, value),
            )

        for lang, strings in per_language:
            connection.executemany(
                "INSERT INTO strings(locale, id, value) VALUES (?, ?, ?)",
                [(lang, key, value) for key, value in strings.items()],
            )

        connection.commit()
    finally:
        connection.close()
