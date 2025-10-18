from __future__ import annotations

from typing import TYPE_CHECKING

from pydantic import BaseModel
from pydantic import Field

from data.lib.constant import (
    HIGH_SLOT_ATTR,
    MEDIUM_SLOT_ATTR,
    LOW_SLOT_ATTR,
    SERVICE_SLOT_ATTR,
    HIGH_SLOT_MODIFIER_ATTR,
    MEDIUM_SLOT_MODIFIER_ATTR,
    LOW_SLOT_MODIFIER_ATTR,
    TURRET_SLOT_MODIFIER_ATTR,
    LAUNCHER_SLOT_MODIFIER_ATTR,
    TURRET_SLOT_ATTR,
    LAUNCHER_SLOT_ATTR,
    RIG_SLOT_ATTR,
    SUBSYSTEM_SLOT_ATTR,
)
from data.lib.log import error
from data.lib.log import info
from data.lib.schema import fit_pb2


if TYPE_CHECKING:
    from data.lib.workspace.generate import GeneratorDatasource


class TypeDogmaDef(BaseModel):
    dogmaAttributes: list[DogmaAttributeItem] = Field(default_factory=list)


class DogmaAttributeItem(BaseModel):
    attributeID: int
    value: float


_DETERMINE_SHIP_ATTRS = [
    HIGH_SLOT_ATTR,
    MEDIUM_SLOT_ATTR,
    LOW_SLOT_ATTR,
    SERVICE_SLOT_ATTR,
]
_DETERMINE_SUBSYSTEM_ATTRS = [
    HIGH_SLOT_MODIFIER_ATTR,
    MEDIUM_SLOT_MODIFIER_ATTR,
    LOW_SLOT_MODIFIER_ATTR,
    TURRET_SLOT_MODIFIER_ATTR,
    LAUNCHER_SLOT_MODIFIER_ATTR,
]


async def generate(data: GeneratorDatasource, collection):
    info("Generating fit dependencies...")
    type_dogma = await data.resources.fsd.get("typedogma")

    ship = 0
    subsystem = 1
    for type_id, dogma_def in type_dogma.items():
        try:
            validated = TypeDogmaDef.model_validate(dogma_def)
        except Exception as e:
            error(f"Failed to validate category {type_id}: {e}")
            continue

        if any(
            attr.attributeID in _DETERMINE_SHIP_ATTRS and attr.value > 0
            for attr in validated.dogmaAttributes
        ):
            ship += 1
            ship_def = fit_pb2.Ship()
            ship_def.type_id = type_id
            ship_def.high_slots = next(
                (
                    int(attr.value)
                    for attr in validated.dogmaAttributes
                    if attr.attributeID == HIGH_SLOT_ATTR
                ),
                0,
            )
            ship_def.medium_slots = next(
                (
                    int(attr.value)
                    for attr in validated.dogmaAttributes
                    if attr.attributeID == MEDIUM_SLOT_ATTR
                ),
                0,
            )
            ship_def.low_slots = next(
                (
                    int(attr.value)
                    for attr in validated.dogmaAttributes
                    if attr.attributeID == LOW_SLOT_ATTR
                ),
                0,
            )
            ship_def.rig_slots = next(
                (
                    int(attr.value)
                    for attr in validated.dogmaAttributes
                    if attr.attributeID == RIG_SLOT_ATTR
                ),
                0,
            )
            ship_def.subsystem_slots = next(
                (
                    int(attr.value)
                    for attr in validated.dogmaAttributes
                    if attr.attributeID == SUBSYSTEM_SLOT_ATTR
                ),
                0,
            )
            ship_def.service_slots = next(
                (
                    int(attr.value)
                    for attr in validated.dogmaAttributes
                    if attr.attributeID == SERVICE_SLOT_ATTR
                ),
                0,
            )
            ship_def.turret_slots = next(
                (
                    int(attr.value)
                    for attr in validated.dogmaAttributes
                    if attr.attributeID == TURRET_SLOT_ATTR
                ),
                0,
            )
            ship_def.launcher_slots = next(
                (
                    int(attr.value)
                    for attr in validated.dogmaAttributes
                    if attr.attributeID == LAUNCHER_SLOT_ATTR
                ),
                0,
            )
            collection.ships.append(ship_def)
        elif any(
            attr.attributeID in _DETERMINE_SUBSYSTEM_ATTRS and attr.value > 0
            for attr in validated.dogmaAttributes
        ):
            subsystem += 1
            subsystem_def = fit_pb2.Subsystem()
            subsystem_def.type_id = type_id
            subsystem_def.high_slots = next(
                (
                    int(attr.value)
                    for attr in validated.dogmaAttributes
                    if attr.attributeID == HIGH_SLOT_MODIFIER_ATTR
                ),
                0,
            )
            subsystem_def.medium_slots = next(
                (
                    int(attr.value)
                    for attr in validated.dogmaAttributes
                    if attr.attributeID == MEDIUM_SLOT_MODIFIER_ATTR
                ),
                0,
            )
            subsystem_def.low_slots = next(
                (
                    int(attr.value)
                    for attr in validated.dogmaAttributes
                    if attr.attributeID == LOW_SLOT_MODIFIER_ATTR
                ),
                0,
            )
            subsystem_def.turret_slots = next(
                (
                    int(attr.value)
                    for attr in validated.dogmaAttributes
                    if attr.attributeID == TURRET_SLOT_MODIFIER_ATTR
                ),
                0,
            )
            subsystem_def.launcher_slots = next(
                (
                    int(attr.value)
                    for attr in validated.dogmaAttributes
                    if attr.attributeID == LAUNCHER_SLOT_MODIFIER_ATTR
                ),
                0,
            )
            collection.subsystems.append(subsystem_def)

    info(f"Generated {ship} ships and {subsystem} subsystems")
