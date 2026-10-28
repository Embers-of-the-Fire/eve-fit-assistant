from __future__ import annotations

import asyncio
import os
import sqlite3

from typing import TYPE_CHECKING

import bootstrap.config

from bootstrap.data.workspace.generate.loc_source import apply_localization_patches
from bootstrap.data.workspace.generate.loc_source import find_missing_strings
from bootstrap.data.workspace.generate.loc_source import load_localization_patch_map
from bootstrap.data.workspace.generate.loc_source import load_localized_strings
from bootstrap.log import info
from bootstrap.log import warning


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

#: Maximum number of still-missing strings sampled into log lines and CI
#: annotations per locale (the full count is always reported).
_MISSING_SAMPLE_LIMIT = 20


async def generate(ws_data: GeneratorDatasource):
    info("Generating localizations...")

    target_languages = bootstrap.config.CONFIGURATION.localizations.supported
    default_language = bootstrap.config.CONFIGURATION.localizations.default

    per_language = await asyncio.gather(*(__generate(ws_data, lang) for lang in target_languages))
    reference = dict(per_language)[default_language]
    for lang, strings in per_language:
        if lang == default_language:
            continue
        __apply_patches(ws_data, lang, strings, reference)
        __report_missing(ws_data, lang, strings, reference)

    __write_localization_db(ws_data.paths.localization_db_path, per_language)
    for lang, strings in per_language:
        _write_locale_db(ws_data.paths.localization_locale_db_path(lang), lang, strings)

    info(f"Generated {len(target_languages)} localizations.")


async def __generate(
    ws_data: GeneratorDatasource, lang: LocalizationType
) -> tuple[str, dict[int, str]]:
    strings = await load_localized_strings(ws_data, lang)

    # Localization ships only as the SQLite database; the per-language
    # protobuf bundle is no longer emitted.
    info(f"Generated localization for {lang}.")
    return lang, strings


def __apply_patches(
    ws_data: GeneratorDatasource,
    lang: LocalizationType,
    strings: dict[int, str],
    reference: dict[int, str],
):
    """Fills missing strings from the workspace's curated localization patches."""
    patch_map = load_localization_patch_map(ws_data, lang)
    if not patch_map:
        return
    report = apply_localization_patches(strings, reference, patch_map)
    if report.filled:
        info(f"Applied {len(report.filled)} curated localization patches for {lang}.")
    for key in report.stale_keys:
        warning(
            f"Stale localization patch for {lang}: {key!r}"
            " (already translated upstream, or the English source text changed)"
        )


def __report_missing(
    ws_data: GeneratorDatasource,
    lang: LocalizationType,
    strings: dict[int, str],
    reference: dict[int, str],
):
    """Flags strings still missing after patching; surfaces as a GitHub
    Actions warning annotation when running in CI."""
    missing = find_missing_strings(strings, reference)
    if not missing:
        return
    workspace = ws_data.config.metadata.identifier
    patch_hint = f"data/resources/{workspace}/patches/localization.yaml"
    sample = ", ".join(
        f"{text!r} ({message_id})" for message_id, text in missing[:_MISSING_SAMPLE_LIMIT]
    )
    warning(
        f"{len(missing)} strings have no {lang} localization on {workspace}"
        f" (e.g. {sample}); add curated translations to {patch_hint}"
    )
    if os.environ.get("GITHUB_ACTIONS") == "true":
        print(
            f"::warning title=Missing {lang} localization ({workspace})::"
            f"{len(missing)} strings have no {lang} text (e.g. {sample})."
            f" Add curated translations to {patch_hint}."
        )


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
