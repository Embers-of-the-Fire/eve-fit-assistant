from __future__ import annotations

import json
import sqlite3

from typing import TYPE_CHECKING

from pydantic import BaseModel
from pydantic import Field

from data.lib.log import error
from data.lib.log import info
from data.lib.schema import types_pb2
from data.lib.workspace.generate.static.utils import icon
from data.lib.workspace.generate.static.utils import loc


if TYPE_CHECKING:
    from data.lib.workspace.generate import GeneratorDatasource


_REQUIRED_SKILL_ATTRIBUTE_IDS = [182, 183, 184, 1285, 1289, 1290]
_REQUIRED_SKILL_LEVEL_ATTRIBUTE_IDS = [277, 278, 279, 1286, 1287, 1288]
_SKILL_CATEGORY_ID = 16
_PREDEFINED_MAX_SKILL_PROFILE_ID = "all_5"
_PREDEFINED_ALPHA_MAX_SKILL_PROFILE_ID = "alpha_max"
_PREDEFINED_ZERO_SKILL_PROFILE_ID = "all_0"


class TypeDogmaDef(BaseModel):
    dogmaAttributes: list[DogmaAttributeItem] = Field(default_factory=list)


class DogmaAttributeItem(BaseModel):
    attributeID: int
    value: float


class TypeTraitRaw(BaseModel):
    types: dict[str, list[TraitRawBonus]] = Field(default_factory=dict)
    roleBonuses: list[TraitRawBonus] = Field(default_factory=list)
    miscBonuses: list[TraitRawBonus] = Field(default_factory=list)


class TraitRawBonus(BaseModel):
    nameID: int
    importance: int = Field(default=0)
    bonus: float | None = Field(default=None)
    unitID: int | None = Field(default=None)


class TypeDef(BaseModel):
    typeID: int

    iconID: int | None = Field(default=None)
    graphicID: int | None = Field(default=None)

    groupID: int
    marketGroupID: int | None = Field(default=None)
    metaGroupID: int | None = Field(default=None)

    isDynamicType: bool = Field(default=False)
    published: bool

    typeNameID: int
    descriptionID: int | None = Field(default=None)

    def to_pb(self) -> types_pb2.Type:
        pb = types_pb2.Type()

        pb.type_id = self.typeID
        pb.icon.CopyFrom(icon(icon_id=self.iconID, graphic_id=self.graphicID))
        pb.group_id = self.groupID
        if self.marketGroupID is not None:
            pb.market_group_id = self.marketGroupID
        if self.metaGroupID is not None:
            pb.meta_group_id = self.metaGroupID
        pb.is_dynamic_type = self.isDynamicType
        pb.published = self.published
        pb.type_name.CopyFrom(loc(self.typeNameID))
        if self.descriptionID is not None:
            pb.description.CopyFrom(loc(self.descriptionID))

        return pb


class GroupCategoryDef(BaseModel):
    groupID: int
    categoryID: int


class CloneGradeSkill(BaseModel):
    typeID: int
    level: int = Field(ge=0, le=5)


class CloneGradeDef(BaseModel):
    skills: list[CloneGradeSkill]
    internalDescription: str


def _extract_required_skills(dogma_attributes: list[DogmaAttributeItem]) -> list[tuple[int, int]]:
    attr_map = {attr.attributeID: attr.value for attr in dogma_attributes}
    requirements: list[tuple[int, int]] = []
    for skill_attr_id, level_attr_id in zip(
        _REQUIRED_SKILL_ATTRIBUTE_IDS,
        _REQUIRED_SKILL_LEVEL_ATTRIBUTE_IDS,
        strict=True,
    ):
        skill_type_id = int(attr_map.get(skill_attr_id, 0))
        if skill_type_id <= 0:
            continue
        level = int(attr_map.get(level_attr_id, 0))
        if level <= 0:
            level = 1
        requirements.append((skill_type_id, level))
    return requirements


def _append_trait_entry(pb_section, bonus: TraitRawBonus) -> None:
    entry = pb_section.entries.add()
    entry.text.CopyFrom(loc(bonus.nameID))
    if bonus.bonus is not None:
        entry.bonus = bonus.bonus
    if bonus.unitID is not None:
        entry.unit_id = bonus.unitID


def _apply_traits(pb: types_pb2.Type, traits: TypeTraitRaw | None) -> None:
    if traits is None:
        return

    for skill_type_id, entries in sorted(traits.types.items(), key=lambda item: int(item[0])):
        section = pb.trait_sections.add()
        section.kind = types_pb2.Type.SKILL
        section.skill_type_id = int(skill_type_id)
        for bonus in sorted(entries, key=lambda entry: entry.importance):
            _append_trait_entry(section, bonus)

    if traits.roleBonuses:
        section = pb.trait_sections.add()
        section.kind = types_pb2.Type.ROLE
        for bonus in sorted(traits.roleBonuses, key=lambda entry: entry.importance):
            _append_trait_entry(section, bonus)

    if traits.miscBonuses:
        section = pb.trait_sections.add()
        section.kind = types_pb2.Type.MISC
        for bonus in sorted(traits.miscBonuses, key=lambda entry: entry.importance):
            _append_trait_entry(section, bonus)


async def _load_info_bubble_traits(data: GeneratorDatasource) -> dict[int, TypeTraitRaw]:
    node = data.resources.res.get_resource("res:/staticdata/infobubbles.static")
    await node.download()
    path = node.local_path
    if path is None:
        raise RuntimeError("Failed to resolve infobubbles.static local path")

    with sqlite3.connect(path) as connection:
        traits_row = connection.execute(
            "SELECT value FROM cache WHERE key = 'infoBubbleTypeBonuses'",
        ).fetchone()

    if traits_row is None:
        raise RuntimeError("Failed to load infoBubbleTypeBonuses from infobubbles.static")

    traits = json.loads(traits_row[0])
    return {int(type_id): TypeTraitRaw.model_validate(value) for type_id, value in traits.items()}


async def _load_skill_group_ids(data: GeneratorDatasource) -> set[int]:
    groups = await data.resources.fsd.get("groups")
    skill_group_ids: set[int] = set()
    for group_id, group_def in groups.items():
        try:
            validated = GroupCategoryDef.model_validate(group_def)
        except Exception as e:
            error(f"Failed to validate group {group_id} for skill alpha levels: {e}")
            continue
        if validated.categoryID == _SKILL_CATEGORY_ID:
            skill_group_ids.add(validated.groupID)
    return skill_group_ids


def _normalize_clone_grade_skills(skills: list[CloneGradeSkill]) -> tuple[tuple[int, int], ...]:
    return tuple(sorted((skill.typeID, skill.level) for skill in skills))


async def _load_alpha_skill_levels(data: GeneratorDatasource) -> dict[int, int]:
    node = data.resources.res.get_resource("res:/staticdata/clonegrades.static")
    await node.download()
    path = node.local_path
    if path is None:
        raise RuntimeError("Failed to resolve clonegrades.static local path")

    with sqlite3.connect(path) as connection:
        rows = connection.execute('SELECT "key", "value" FROM "cache"').fetchall()

    if not rows:
        raise RuntimeError("Failed to load clonegrades.static cache rows")

    first_key, first_value = rows[0]
    first_grade = CloneGradeDef.model_validate_json(first_value)
    first_skills = _normalize_clone_grade_skills(first_grade.skills)

    for key, value in rows[1:]:
        grade = CloneGradeDef.model_validate_json(value)
        if _normalize_clone_grade_skills(grade.skills) != first_skills:
            error(
                "Clone grade skills differ from the first cache row; "
                f"alpha max levels are generated from {first_key!r}, but {key!r} differs."
            )

    return {skill.typeID: skill.level for skill in first_grade.skills}


async def generate(data: GeneratorDatasource, collection):
    info("Generating types...")
    types = await data.resources.fsd.get("types")
    type_dogma = await data.resources.fsd.get("typedogma")
    traits = await _load_info_bubble_traits(data)
    skill_group_ids = await _load_skill_group_ids(data)
    alpha_skill_levels = await _load_alpha_skill_levels(data)
    skill_type_ids: list[int] = []

    cnt = 0
    for type_id, type_def in types.items():
        try:
            validated = TypeDef.model_validate(type_def)
        except Exception as e:
            error(f"Failed to validate type {type_id}: {e}")
            continue

        cnt += 1
        pb = validated.to_pb()
        if validated.groupID in skill_group_ids:
            pb.alpha_max_level = alpha_skill_levels.get(validated.typeID, 0)

        dogma_def = type_dogma.get(type_id)
        if dogma_def is not None:
            try:
                validated_dogma = TypeDogmaDef.model_validate(dogma_def)
            except Exception as e:
                error(f"Failed to validate type dogma {type_id}: {e}")
            else:
                for skill_type_id, level in _extract_required_skills(
                    validated_dogma.dogmaAttributes
                ):
                    req = pb.required_skills.add()
                    req.skill_type_id = skill_type_id
                    req.level = level

                for attr in validated_dogma.dogmaAttributes:
                    entry = pb.dogma_attributes.add()
                    entry.dogma_attribute_id = attr.attributeID
                    entry.value = attr.value

        _apply_traits(pb, traits.get(type_id))
        collection.types[type_id].CopyFrom(pb)
        if validated.groupID in skill_group_ids:
            skill_type_ids.append(validated.typeID)

    for skill_type_id in sorted(skill_type_ids):
        collection.skill_profiles[_PREDEFINED_MAX_SKILL_PROFILE_ID].skills[skill_type_id] = 5
        collection.skill_profiles[_PREDEFINED_ALPHA_MAX_SKILL_PROFILE_ID].skills[skill_type_id] = (
            alpha_skill_levels.get(
                skill_type_id,
                0,
            )
        )
        collection.skill_profiles[_PREDEFINED_ZERO_SKILL_PROFILE_ID].skills[skill_type_id] = 0

    info(f"Generated {cnt} types")
