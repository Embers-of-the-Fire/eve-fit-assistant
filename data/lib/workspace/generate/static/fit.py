from __future__ import annotations

from typing import TYPE_CHECKING

from pydantic import BaseModel
from pydantic import Field

from data.lib.constant import FIGHTER_TUBES_ATTR
from data.lib.constant import HIGH_SLOT_ATTR
from data.lib.constant import HIGH_SLOT_MODIFIER_ATTR
from data.lib.constant import LAUNCHER_SLOT_ATTR
from data.lib.constant import LAUNCHER_SLOT_MODIFIER_ATTR
from data.lib.constant import LOW_SLOT_ATTR
from data.lib.constant import LOW_SLOT_MODIFIER_ATTR
from data.lib.constant import MAX_SUBSYSTEM_SLOT_ATTR
from data.lib.constant import MEDIUM_SLOT_ATTR
from data.lib.constant import MEDIUM_SLOT_MODIFIER_ATTR
from data.lib.constant import RIG_SLOT_ATTR
from data.lib.constant import SERVICE_SLOT_ATTR
from data.lib.constant import SUBSYSTEM_CORE_SLOT
from data.lib.constant import SUBSYSTEM_DEFENSIVE_SLOT
from data.lib.constant import SUBSYSTEM_OFFENSIVE_SLOT
from data.lib.constant import SUBSYSTEM_PROPULSION_SLOT
from data.lib.constant import SUBSYSTEM_SLOT_ATTR
from data.lib.constant import TURRET_SLOT_ATTR
from data.lib.constant import TURRET_SLOT_MODIFIER_ATTR
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


_DETERMINE_SHIP_ATTRS = {
    HIGH_SLOT_ATTR,
    MEDIUM_SLOT_ATTR,
    LOW_SLOT_ATTR,
    SERVICE_SLOT_ATTR,
}
_DETERMINE_SUBSYSTEM_ATTRS = {
    HIGH_SLOT_MODIFIER_ATTR,
    MEDIUM_SLOT_MODIFIER_ATTR,
    LOW_SLOT_MODIFIER_ATTR,
    TURRET_SLOT_MODIFIER_ATTR,
    LAUNCHER_SLOT_MODIFIER_ATTR,
}


def _first_attr_where(source, target):
    return next((int(attr.value) for attr in source if attr.attributeID == target), 0)


async def generate(data: GeneratorDatasource, collection):
    info("Generating fit dependencies...")
    type_dogma = await data.resources.fsd.get("typedogma")
    tactical_modes = data.resources.patches.get("tactical_mode", "yaml")

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
            ship_def.high_slots = _first_attr_where(validated.dogmaAttributes, HIGH_SLOT_ATTR)
            ship_def.medium_slots = _first_attr_where(validated.dogmaAttributes, MEDIUM_SLOT_ATTR)
            ship_def.low_slots = _first_attr_where(validated.dogmaAttributes, LOW_SLOT_ATTR)
            ship_def.rig_slots = _first_attr_where(validated.dogmaAttributes, RIG_SLOT_ATTR)
            ship_def.subsystem_slots = _first_attr_where(
                validated.dogmaAttributes, MAX_SUBSYSTEM_SLOT_ATTR
            )
            ship_def.service_slots = _first_attr_where(validated.dogmaAttributes, SERVICE_SLOT_ATTR)
            ship_def.turret_slots = _first_attr_where(validated.dogmaAttributes, TURRET_SLOT_ATTR)
            ship_def.launcher_slots = _first_attr_where(
                validated.dogmaAttributes, LAUNCHER_SLOT_ATTR
            )
            ship_def.fighter_tubes = _first_attr_where(
                validated.dogmaAttributes, FIGHTER_TUBES_ATTR
            )

            tm_variant_map = {
                "defense": fit_pb2.TacticalMode.TacticalModeVariant.DEFENSE,
                "speed": fit_pb2.TacticalMode.TacticalModeVariant.SPEED,
                "target": fit_pb2.TacticalMode.TacticalModeVariant.TARGET,
            }
            if type_id in tactical_modes:
                for mode in tactical_modes[type_id]["modes"]:
                    tm = ship_def.tactical_modes.add()
                    tm.type_id = mode["typeId"]
                    tm.ship_id = type_id
                    tm.variant = tm_variant_map[mode["variant"].lower()]

            collection.ships[type_id].CopyFrom(ship_def)
        elif any(
            attr.attributeID in _DETERMINE_SUBSYSTEM_ATTRS and attr.value > 0
            for attr in validated.dogmaAttributes
        ):
            subsystem += 1
            subsystem_def = fit_pb2.Subsystem()
            subsystem_def.type_id = type_id
            subsystem_def.high_slots = _first_attr_where(
                validated.dogmaAttributes, HIGH_SLOT_MODIFIER_ATTR
            )
            subsystem_def.medium_slots = _first_attr_where(
                validated.dogmaAttributes, MEDIUM_SLOT_MODIFIER_ATTR
            )
            subsystem_def.low_slots = _first_attr_where(
                validated.dogmaAttributes, LOW_SLOT_MODIFIER_ATTR
            )
            subsystem_def.turret_slots = _first_attr_where(
                validated.dogmaAttributes, TURRET_SLOT_MODIFIER_ATTR
            )
            subsystem_def.launcher_slots = _first_attr_where(
                validated.dogmaAttributes, LAUNCHER_SLOT_MODIFIER_ATTR
            )

            ss_variant_map = {
                SUBSYSTEM_CORE_SLOT: fit_pb2.Subsystem.SubsystemType.CORE,
                SUBSYSTEM_DEFENSIVE_SLOT: fit_pb2.Subsystem.SubsystemType.DEFENSIVE,
                SUBSYSTEM_OFFENSIVE_SLOT: fit_pb2.Subsystem.SubsystemType.OFFENSIVE,
                SUBSYSTEM_PROPULSION_SLOT: fit_pb2.Subsystem.SubsystemType.PROPULSION,
            }
            slot_type = _first_attr_where(validated.dogmaAttributes, SUBSYSTEM_SLOT_ATTR)
            subsystem_def.subsystem_type = ss_variant_map.get(slot_type, fit_pb2.Subsystem.SubsystemType.UNKNOWN)

            collection.subsystems[type_id].CopyFrom(subsystem_def)

    info(f"Generated {ship} ships and {subsystem} subsystems")
