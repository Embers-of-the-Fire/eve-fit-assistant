"""Implant set (e.g. "High-grade Crystal Alpha..Omega") metadata generator.

Set identity is derived from dogma, never from type names: all members of a
set share a setBonus/implantSet dogma effect and carry the corresponding
implantSet attribute. Type names are used only to produce baked per-locale
display names via longest-common-prefix within each grade cluster.
"""

from __future__ import annotations

import os
import pickle

from collections import defaultdict
from typing import TYPE_CHECKING
from typing import NamedTuple

from pydantic import BaseModel
from pydantic import Field

import bootstrap.config

from bootstrap.constant import IMPLANT_SLOT_ATTR_ID
from bootstrap.data.schema import fit_pb2
from bootstrap.localization import to_native_localization
from bootstrap.log import error
from bootstrap.log import info
from bootstrap.log import warning


if TYPE_CHECKING:
    from bootstrap.data.workspace.generate import GeneratorDatasource
    from bootstrap.localization import LocalizationType


_IMPLANT_CATEGORY_ID = 20
# FSD naming is inconsistent: "implantSetGuristas", "ImplantSetNirvana",
# "setBonusMimesis", ...
_IMPLANT_SET_ATTR_PREFIXES = ("implantset", "setbonus")


class DogmaAttributeItem(BaseModel):
    attributeID: int
    value: float


class DogmaEffectItem(BaseModel):
    effectID: int


class TypeDogmaDef(BaseModel):
    dogmaAttributes: list[DogmaAttributeItem] = Field(default_factory=list)
    dogmaEffects: list[DogmaEffectItem] = Field(default_factory=list)


class TypeDef(BaseModel):
    typeID: int
    groupID: int
    published: bool
    typeNameID: int


class GroupDef(BaseModel):
    groupID: int
    categoryID: int


class ModifierInfoDef(BaseModel):
    modifyingAttributeID: int | None = Field(default=None)


class EffectDef(BaseModel):
    effectName: str = ""
    modifierInfo: list[ModifierInfoDef] = Field(default_factory=list)


class AttributeDef(BaseModel):
    name: str = ""


class SetMember(NamedTuple):
    type_id: int
    slot: int
    set_value: float


def find_set_effects(dogma_effects: dict, dogma_attributes: dict) -> dict[int, int]:
    """Map set effect IDs to their implantSet attribute ID.

    FSD effect naming is inconsistent ("setBonusGuristas", "haloSetBonus",
    "federationsetbonus3", "imperialsetLGbonus", "implantSetWarpSpeed"), so
    instead of matching effect names, an effect is a set effect iff it
    modifies by an attribute named implantSet*/setBonus* (case-insensitive).
    """
    set_attribute_ids: set[int] = set()
    for attribute_id, raw in dogma_attributes.items():
        try:
            attribute = AttributeDef.model_validate(raw)
        except Exception as e:
            error(f"Failed to validate dogma attribute {attribute_id} for implant sets: {e}")
            continue
        if attribute.name.lower().startswith(_IMPLANT_SET_ATTR_PREFIXES):
            set_attribute_ids.add(int(attribute_id))

    set_effects: dict[int, int] = {}
    for effect_id, raw in dogma_effects.items():
        try:
            effect = EffectDef.model_validate(raw)
        except Exception as e:
            error(f"Failed to validate dogma effect {effect_id} for implant sets: {e}")
            continue
        for modifier in effect.modifierInfo:
            if modifier.modifyingAttributeID in set_attribute_ids:
                set_effects[int(effect_id)] = modifier.modifyingAttributeID
                break
    return set_effects


def base_name(name: str) -> str:
    """Strip the trailing slot discriminator token ("... Alpha", "... CA-1")."""
    base, sep, _ = name.rpartition(" ")
    return base if sep else name


def set_display_name(names: list[str]) -> str:
    """Longest common prefix of member names, trimmed to a clean word boundary."""
    if not names:
        return ""
    prefix = os.path.commonprefix(names).strip()
    if prefix and not prefix[-1].isalnum() and " " in prefix:
        prefix = prefix[: prefix.rindex(" ")].strip()
    return prefix


def cluster_members(members: list[SetMember], name_of) -> list[list[SetMember]]:
    """Split an effect family into grades by the members' base names."""
    clusters: dict[str, list[SetMember]] = defaultdict(list)
    for member in members:
        clusters[base_name(name_of(member.type_id))].append(member)
    return list(clusters.values())


def merge_set_clusters(
    members_by_effect: dict[int, list[SetMember]], set_effects: dict[int, int], name_of
) -> list[tuple[int, int, list[SetMember]]]:
    """Merge per-effect clusters into sets keyed by display name.

    A single set family can be spread over multiple setBonus effects (e.g.
    Talisman uses one effect for Alpha-Epsilon and another including Omega;
    Genolution has one effect per bonus attribute). Returns a list of
    (set_id, effect_id, members) with deterministic set IDs.
    """
    merged: dict[str, dict] = {}
    for effect_id in sorted(set_effects):
        members = members_by_effect.get(effect_id, [])
        for cluster in cluster_members(members, name_of):
            if len(cluster) < 2:
                continue
            display = set_display_name([name_of(m.type_id) for m in cluster])
            if not display:
                continue
            entry = merged.setdefault(display, {"effects": defaultdict(int), "slots": {}})
            for member in cluster:
                entry["effects"][effect_id] += 1
                entry["slots"].setdefault(member.slot, member)

    sets_by_effect: dict[int, list[dict]] = defaultdict(list)
    for entry in merged.values():
        primary_effect = max(entry["effects"].items(), key=lambda kv: (kv[1], -kv[0]))[0]
        sets_by_effect[primary_effect].append(entry)

    sets: list[tuple[int, int, list[SetMember]]] = []
    for effect_id, entries in sorted(sets_by_effect.items()):
        entries.sort(
            key=lambda entry: (
                sum(m.set_value for m in entry["slots"].values()) / len(entry["slots"])
            )
        )
        for rank, entry in enumerate(entries):
            members = sorted(entry["slots"].values(), key=lambda m: (m.slot, m.type_id))
            sets.append((effect_id * 100 + rank, effect_id, members))
    return sets


async def _load_localized_names(
    data: GeneratorDatasource, lang: LocalizationType
) -> dict[int, str]:
    resource = data.resources.res.get_resource(
        f"res:/localizationfsd/localization_fsd_{to_native_localization(lang)}.pickle"
    )
    async with resource.open() as f:
        _lang_code, loc = pickle.loads(await f.read())
    return {int(key): value[0] for key, value in loc.items()}


async def generate(data: GeneratorDatasource, collection):
    info("Generating implant sets...")

    type_dogma = await data.resources.fsd.get("typedogma")
    types = await data.resources.fsd.get("types")
    groups = await data.resources.fsd.get("groups")
    dogma_effects = await data.resources.fsd.get("dogmaeffects")
    dogma_attributes = await data.resources.fsd.get("dogmaattributes")

    set_effects = find_set_effects(dogma_effects, dogma_attributes)
    if not set_effects:
        warning("No implant set effects found in dogma effects")
        return

    implant_group_ids: set[int] = set()
    for group_id, raw in groups.items():
        try:
            group = GroupDef.model_validate(raw)
        except Exception as e:
            error(f"Failed to validate group {group_id} for implant sets: {e}")
            continue
        if group.categoryID == _IMPLANT_CATEGORY_ID:
            implant_group_ids.add(group.groupID)

    type_name_ids: dict[int, int] = {}
    for type_id, raw in types.items():
        try:
            type_def = TypeDef.model_validate(raw)
        except Exception as e:
            error(f"Failed to validate type {type_id} for implant sets: {e}")
            continue
        if type_def.published and type_def.groupID in implant_group_ids:
            type_name_ids[type_def.typeID] = type_def.typeNameID

    members_by_effect: dict[int, list[SetMember]] = defaultdict(list)
    for type_id, raw in type_dogma.items():
        type_id = int(type_id)
        if type_id not in type_name_ids:
            continue
        try:
            dogma = TypeDogmaDef.model_validate(raw)
        except Exception as e:
            error(f"Failed to validate type dogma {type_id} for implant sets: {e}")
            continue

        attributes = {attr.attributeID: attr.value for attr in dogma.dogmaAttributes}
        slot = attributes.get(IMPLANT_SLOT_ATTR_ID)
        if slot is None:
            continue

        for effect in dogma.dogmaEffects:
            set_attr = set_effects.get(effect.effectID)
            if set_attr is not None and set_attr in attributes:
                members_by_effect[effect.effectID].append(
                    SetMember(type_id=type_id, slot=int(slot), set_value=attributes[set_attr])
                )

    locales: list[LocalizationType] = bootstrap.config.CONFIGURATION.localizations.supported
    names_by_locale = {lang: await _load_localized_names(data, lang) for lang in locales}
    cluster_lang: LocalizationType = "en" if "en" in locales else locales[0]

    def name_of(lang: LocalizationType, type_id: int) -> str:
        name_id = type_name_ids.get(type_id)
        if name_id is None:
            return str(type_id)
        return names_by_locale[lang].get(name_id, str(type_id))

    count = 0
    sets = merge_set_clusters(
        members_by_effect, set_effects, lambda tid: name_of(cluster_lang, tid)
    )
    for set_id, effect_id, members in sets:
        pb = fit_pb2.ImplantSet()
        pb.set_id = set_id
        pb.effect_id = effect_id
        pb.member_type_ids.extend(member.type_id for member in members)

        for lang in locales:
            display = set_display_name([name_of(lang, m.type_id) for m in members])
            if not display and lang != cluster_lang:
                display = set_display_name([name_of(cluster_lang, m.type_id) for m in members])
            if display:
                pb.names[lang] = display

        if not pb.names:
            warning(f"Implant set for effect {effect_id} has no display name, skipped")
            continue

        collection.implant_sets[pb.set_id].CopyFrom(pb)
        count += 1

    info(f"Generated {count} implant sets")
