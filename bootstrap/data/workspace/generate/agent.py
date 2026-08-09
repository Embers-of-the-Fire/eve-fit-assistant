from __future__ import annotations

import asyncio
import pickle
import sqlite3

from dataclasses import dataclass
from typing import TYPE_CHECKING

from pydantic import BaseModel
from pydantic import ValidationError

import bootstrap.config

from bootstrap.constant import BOOSTER_SLOT_ATTR_ID
from bootstrap.constant import IMPLANT_SLOT_ATTR_ID
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
#:
#: v2 adds the `group_id`, `category_id`, `slot_index`, and `slot_kind`
#: columns to `type_names` so the chat `search_items` tool can filter by item
#: kind and read implant/booster slots without joining app-side type data.
AGENT_RESOURCE_DB_SCHEMA_VERSION = 2


class _TypeNameRef(BaseModel):
    typeNameID: int | None = None
    groupID: int | None = None


class _GroupRef(BaseModel):
    categoryID: int | None = None


@dataclass(frozen=True)
class _TypeMeta:
    """Structural metadata for one type, shared across locales."""

    group_id: int | None = None
    category_id: int | None = None
    slot_index: int | None = None
    slot_kind: str | None = None


async def generate(ws_data: GeneratorDatasource):
    """Emits the agent resource database.

    Carries the `type_names` table: localized type names keyed by real type id
    (resolved through the FSD `typeNameID`, which differs from the type id),
    plus per-type structural metadata (group/category ids and, for implants
    and boosters, the dogma slot) backing the chat `search_items` tool.
    """
    info("Generating agent resources...")

    raw_types = await ws_data.resources.fsd.get("types")
    name_ids = _type_name_ids(raw_types)
    metas = _type_metas(
        raw_types,
        await ws_data.resources.fsd.get("groups"),
        await ws_data.resources.fsd.get("typedogma"),
    )

    target_languages = bootstrap.config.CONFIGURATION.localizations.supported
    per_locale = await asyncio.gather(
        *(_locale_rows(ws_data, lang, name_ids) for lang in target_languages)
    )

    _write_db(ws_data.paths.agent_resource_db_path, per_locale, metas)


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


def _type_metas(raw_types: dict, raw_groups: dict, raw_typedogma: dict) -> dict[int, _TypeMeta]:
    """Builds group/category ids and implant/booster slot info per type.

    Implant and booster slots come from the dogma attributes
    `IMPLANT_SLOT_ATTR_ID` (331) and `BOOSTER_SLOT_ATTR_ID` (1087), mirroring
    the collection generator's `Slots.implant_slots`/`booster_slots` maps.
    """
    group_categories: dict[int, int] = {}
    for group_id, raw in raw_groups.items():
        try:
            ref = _GroupRef.model_validate(raw)
        except ValidationError as e:
            error(f"Failed to validate group {group_id} for agent resources: {e}")
            continue
        if ref.categoryID is not None:
            group_categories[int(group_id)] = ref.categoryID

    slots: dict[int, tuple[str, int]] = {}
    for type_id, raw in raw_typedogma.items():
        for attr in raw.get("dogmaAttributes") or []:
            attribute_id = attr.get("attributeID")
            if attribute_id == IMPLANT_SLOT_ATTR_ID:
                slots[int(type_id)] = ("implant", int(attr["value"]))
                break
            if attribute_id == BOOSTER_SLOT_ATTR_ID:
                slots[int(type_id)] = ("booster", int(attr["value"]))
                break

    metas: dict[int, _TypeMeta] = {}
    for type_id, raw in raw_types.items():
        try:
            ref = _TypeNameRef.model_validate(raw)
        except ValidationError:
            continue
        slot_kind, slot_index = slots.get(int(type_id), (None, None))
        metas[int(type_id)] = _TypeMeta(
            group_id=ref.groupID,
            category_id=group_categories.get(ref.groupID) if ref.groupID is not None else None,
            slot_index=slot_index,
            slot_kind=slot_kind,
        )
    return metas


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


def _write_db(
    path: Path,
    per_locale: list[tuple[str, list[tuple[int, str]]]],
    metas: dict[int, _TypeMeta],
):
    """Writes the agent resource database.

    Layout: `type_names(locale TEXT, id INTEGER, value TEXT, group_id INTEGER,
    category_id INTEGER, slot_index INTEGER, slot_kind TEXT,
    PRIMARY KEY(locale, id))` where `id` is the real type id, plus a `meta`
    table carrying the schema version. `slot_index`/`slot_kind` are only set
    for implants and boosters (`slot_kind` is `implant` or `booster`).
    Clients open the database read-only.
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
            "group_id INTEGER, "
            "category_id INTEGER, "
            "slot_index INTEGER, "
            "slot_kind TEXT, "
            "PRIMARY KEY(locale, id)"
            ") WITHOUT ROWID"
        )
        connection.execute(
            "INSERT INTO meta(key, value) VALUES ('schema_version', ?)",
            (str(AGENT_RESOURCE_DB_SCHEMA_VERSION),),
        )

        empty = _TypeMeta()
        total = 0
        for lang, rows in per_locale:
            connection.executemany(
                "INSERT INTO type_names"
                "(locale, id, value, group_id, category_id, slot_index, slot_kind) "
                "VALUES (?, ?, ?, ?, ?, ?, ?)",
                [
                    (
                        lang,
                        type_id,
                        name,
                        meta.group_id,
                        meta.category_id,
                        meta.slot_index,
                        meta.slot_kind,
                    )
                    for type_id, name in rows
                    for meta in (metas.get(type_id, empty),)
                ],
            )
            total += len(rows)

        connection.commit()
    finally:
        connection.close()

    info(f"Generated agent resource database ({total} type names).")
