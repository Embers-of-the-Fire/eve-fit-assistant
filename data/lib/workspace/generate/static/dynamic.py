from __future__ import annotations

from pydantic import BaseModel
from pydantic import Field

from data.lib.log import info


class DynamicInputOutputMapping(BaseModel):
    resultingType: int
    applicableTypes: list[int] = Field(default_factory=list)


class DynamicAttribute(BaseModel):
    max: float
    min: float


class DynamicItemAttributes(BaseModel):
    inputOutputMapping: list[DynamicInputOutputMapping] = Field(default_factory=list)
    attributeIDs: dict[int, DynamicAttribute] = Field(default_factory=dict)


async def generate(data, collection):
    info("Generating dynamic item dependencies...")

    dynamic_items = await data.resources.fsd.get("dynamicItemAttributes")

    applicable: dict[int, set[int]] = {}

    for modifier_type_id, raw in dynamic_items.items():
        modifier_type_id = int(modifier_type_id)
        dynamic_item = DynamicItemAttributes.model_validate(raw)
        if not dynamic_item.inputOutputMapping:
            continue
        if len(dynamic_item.inputOutputMapping) > 1:
            raise ValueError(
                "Dynamic mutator "
                f"{modifier_type_id} has {len(dynamic_item.inputOutputMapping)} "
                "input/output mappings; generation only supports one"
            )

        mapping = dynamic_item.inputOutputMapping[0]
        entry = collection.dynamic_mutators[modifier_type_id]
        entry.modifier_type_id = modifier_type_id
        entry.resulting_type_id = mapping.resultingType
        entry.applicable_types.extend(sorted(mapping.applicableTypes))

        for attribute_id, attribute in dynamic_item.attributeIDs.items():
            attr_entry = entry.attributes[attribute_id]
            attr_entry.min = attribute.min
            attr_entry.max = attribute.max

        for base_type_id in mapping.applicableTypes:
            applicable.setdefault(base_type_id, set()).add(modifier_type_id)

    for base_type_id, modifier_type_ids in applicable.items():
        collection.dynamic_type_options[base_type_id].modifier_type_ids.extend(
            sorted(modifier_type_ids)
        )

    info(
        "Generated "
        f"{len(collection.dynamic_mutators)} dynamic mutators and "
        f"{len(collection.dynamic_type_options)} dynamic type option sets"
    )
