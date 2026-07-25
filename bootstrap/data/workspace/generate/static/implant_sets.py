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
from pydantic import ValidationError

import bootstrap.config

from bootstrap.constant import IMPLANT_SLOT_ATTR_ID
from bootstrap.data.schema import collections_pb2
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
# Separators between the set name and the slot discriminator in localized type
# names ("High-grade Crystal Alpha", "高级水晶—阿尔法型", "低级辟邪 - 阿尔法型").
_SEPARATOR_CHARS = " \t-\N{EN DASH}\N{EM DASH}"


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
        except ValidationError as e:
            error(f"Failed to validate dogma attribute {attribute_id} for implant sets: {e}")
            continue
        if attribute.name.lower().startswith(_IMPLANT_SET_ATTR_PREFIXES):
            set_attribute_ids.add(int(attribute_id))

    set_effects: dict[int, int] = {}
    for effect_id, raw in dogma_effects.items():
        try:
            effect = EffectDef.model_validate(raw)
        except ValidationError as e:
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
    stripped = prefix.rstrip(_SEPARATOR_CHARS)
    return stripped or prefix


# Closed grade vocabulary used to derive family names from set display names.
# Only affects display strings; membership/mechanics never depend on it.
_GRADE_PREFIXES: dict[str, tuple[str, ...]] = {
    "en": ("low-grade ", "mid-grade ", "high-grade "),
    "zh": ("低级", "中级", "高级"),
}


def family_display_name(displays: list[str], lang: str) -> str:
    """Family name from the per-grade display names of one family.

    Strips the grade prefix from each display; requires all sets of the
    family to agree on the remainder. Falls back to the longest common
    suffix when the grade structure is not recognized.
    """
    if not displays:
        return ""
    if len(displays) == 1:
        return displays[0]

    grades = _GRADE_PREFIXES.get(lang, ())
    families = set()
    for display in displays:
        lowered = display.lower()
        for grade in grades:
            if lowered.startswith(grade):
                families.add(display[len(grade) :])
                break
    if len(families) == 1:
        return families.pop()

    # Fallback: longest common suffix, trimmed to a clean token boundary.
    lcs = os.path.commonprefix([display[::-1] for display in displays])[::-1]
    starts_mid_token = any(
        len(display) > len(lcs) and display[-len(lcs) - 1] != " " for display in displays
    )
    if starts_mid_token:
        _head, sep, tail = lcs.partition(" ")
        if sep:
            lcs = tail
    stripped = lcs.strip(_SEPARATOR_CHARS)
    return stripped or lcs.strip()


def cluster_members(members: list[SetMember], name_of) -> list[list[SetMember]]:
    """Split an effect family into grades by the members' base names."""
    clusters: dict[str, list[SetMember]] = defaultdict(list)
    for member in members:
        clusters[base_name(name_of(member.type_id))].append(member)
    return list(clusters.values())


class MergedSet(NamedTuple):
    effect_id: int
    display: str
    members: list[SetMember]


def merge_set_clusters(
    members_by_effect: dict[int, list[SetMember]], set_effects: dict[int, int], name_of
) -> list[MergedSet]:
    """Merge per-effect clusters into sets keyed by display name.

    A single set family can be spread over multiple setBonus effects (e.g.
    Talisman uses one effect for Alpha-Epsilon and another including Omega;
    Genolution has one effect per bonus attribute). Returns one MergedSet per
    (family, grade) with the cluster-locale display name.
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

    sets: list[MergedSet] = []
    for display, entry in merged.items():
        primary_effect = max(entry["effects"].items(), key=lambda kv: (kv[1], -kv[0]))[0]
        members = sorted(entry["slots"].values(), key=lambda m: (m.slot, m.type_id))
        sets.append(MergedSet(effect_id=primary_effect, display=display, members=members))
    return sets


def family_key(display: str) -> str:
    """Family key from a display name: drop a leading grade token if present."""
    first, sep, rest = display.partition(" ")
    if sep and rest and first.lower().endswith("-grade"):
        return rest
    return display


def assign_set_ids(sets: list[MergedSet]) -> list[tuple[int, MergedSet]]:
    """Group sets into families and assign deterministic set IDs.

    set_id = family_index * 100 + grade_rank, so sets of one family share
    set_id // 100 and grade ranks ascend with set strength (low < mid < high).
    Families group grades across different effects (e.g. Low-grade and
    High-grade Grail use different set effects).
    """
    families: dict[str, list[MergedSet]] = defaultdict(list)
    for merged_set in sets:
        families[family_key(merged_set.display)].append(merged_set)

    assigned: list[tuple[int, MergedSet]] = []
    for family_index, key in enumerate(sorted(families)):
        entries = sorted(
            families[key],
            key=lambda s: sum(m.set_value for m in s.members) / len(s.members),
        )
        for rank, merged_set in enumerate(entries):
            assigned.append((family_index * 100 + rank, merged_set))
    return assigned


async def _load_localized_names(
    data: GeneratorDatasource, lang: LocalizationType
) -> dict[int, str]:
    resource = data.resources.res.get_resource(
        f"res:/localizationfsd/localization_fsd_{to_native_localization(lang)}.pickle"
    )
    async with resource.open() as f:
        _lang_code, loc = pickle.loads(await f.read())
    return {int(key): value[0] for key, value in loc.items()}


async def generate(data: GeneratorDatasource, collection: collections_pb2.Collection):
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
        except ValidationError as e:
            error(f"Failed to validate group {group_id} for implant sets: {e}")
            continue
        if group.categoryID == _IMPLANT_CATEGORY_ID:
            implant_group_ids.add(group.groupID)

    type_name_ids: dict[int, int] = {}
    for type_id, raw in types.items():
        try:
            type_def = TypeDef.model_validate(raw)
        except ValidationError as e:
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
        except ValidationError as e:
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

    merged = merge_set_clusters(
        members_by_effect, set_effects, lambda tid: name_of(cluster_lang, tid)
    )
    assigned = assign_set_ids(merged)

    # Family display name per locale from the family's per-grade display
    # names ("低级水晶"/"高级水晶" -> "水晶").
    family_sets: dict[int, list[MergedSet]] = defaultdict(list)
    for set_id, merged_set in assigned:
        family_sets[set_id // 100].append(merged_set)

    family_names: dict[int, dict[str, str]] = {}
    for family_id, sets_in_family in family_sets.items():
        names: dict[str, str] = {}
        for lang in locales:
            displays = [
                display
                for s in sets_in_family
                if (display := set_display_name([name_of(lang, m.type_id) for m in s.members]))
            ]
            family = family_display_name(displays, lang)
            if not family and lang != cluster_lang:
                family = family_display_name(
                    [
                        display
                        for s in sets_in_family
                        if (
                            display := set_display_name(
                                [name_of(cluster_lang, m.type_id) for m in s.members]
                            )
                        )
                    ],
                    cluster_lang,
                )
            if family:
                names[lang] = family
        family_names[family_id] = names

    count = 0
    for set_id, merged_set in assigned:
        pb = fit_pb2.ImplantSet()
        pb.set_id = set_id
        pb.effect_id = merged_set.effect_id
        pb.member_type_ids.extend(member.type_id for member in merged_set.members)

        for lang in locales:
            display = set_display_name([name_of(lang, m.type_id) for m in merged_set.members])
            if not display and lang != cluster_lang:
                display = set_display_name(
                    [name_of(cluster_lang, m.type_id) for m in merged_set.members]
                )
            if display:
                pb.names[lang] = display

        for lang, family in family_names.get(set_id // 100, {}).items():
            pb.family_names[lang] = family

        if not pb.names:
            warning(f"Implant set for effect {merged_set.effect_id} has no display name, skipped")
            continue

        collection.implant_sets[pb.set_id].CopyFrom(pb)
        count += 1

    info(f"Generated {count} implant sets in {len(family_sets)} families")
