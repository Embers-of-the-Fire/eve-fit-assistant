from __future__ import annotations

from collections import defaultdict
from enum import IntEnum
from enum import unique
from typing import TYPE_CHECKING

from pydantic import BaseModel
from pydantic import Field

from data.lib.constant import BOOSTER_SLOT_ATTR_ID
from data.lib.constant import CHARGE_GROUP_IDS
from data.lib.constant import DURATION_ATTR
from data.lib.constant import ENERGY_NEED_ATTR
from data.lib.constant import FIGHTER_TUBES_ATTR
from data.lib.constant import HI_EFFECT_ID
from data.lib.constant import HIGH_SLOT_ATTR
from data.lib.constant import HIGH_SLOT_MODIFIER_ATTR
from data.lib.constant import IMPLANT_SLOT_ATTR_ID
from data.lib.constant import LAUNCHER_EFFECT_ID
from data.lib.constant import LAUNCHER_SLOT_ATTR
from data.lib.constant import LAUNCHER_SLOT_MODIFIER_ATTR
from data.lib.constant import LOW_EFFECT_ID
from data.lib.constant import LOW_SLOT_ATTR
from data.lib.constant import LOW_SLOT_MODIFIER_ATTR
from data.lib.constant import MAX_SUBSYSTEM_SLOT_ATTR
from data.lib.constant import MED_EFFECT_ID
from data.lib.constant import MEDIUM_SLOT_ATTR
from data.lib.constant import MEDIUM_SLOT_MODIFIER_ATTR
from data.lib.constant import OVERLOAD_DAMAGE_ATTR
from data.lib.constant import RIG_EFFECT_ID
from data.lib.constant import RIG_SLOT_ATTR
from data.lib.constant import SERVICE_EFFECT_ID
from data.lib.constant import SERVICE_SLOT_ATTR
from data.lib.constant import SPEED_ATTR
from data.lib.constant import SUBSYSTEM_CORE_SLOT
from data.lib.constant import SUBSYSTEM_DEFENSIVE_SLOT
from data.lib.constant import SUBSYSTEM_EFFECT_ID
from data.lib.constant import SUBSYSTEM_OFFENSIVE_SLOT
from data.lib.constant import SUBSYSTEM_PROPULSION_SLOT
from data.lib.constant import SUBSYSTEM_SLOT_ATTR
from data.lib.constant import TURRET_EFFECT_ID
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
    dogma_effects = await data.resources.fsd.get("dogmaeffects")
    tactical_modes = data.resources.patches.get("tactical_mode", "yaml")

    ship = 0
    subsystem = 0
    slots = 0
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
            subsystem_def.subsystem_type = ss_variant_map.get(
                slot_type, fit_pb2.Subsystem.SubsystemType.UNKNOWN
            )

            collection.subsystems[type_id].CopyFrom(subsystem_def)

        dogma = type_dogma.get(type_id, defaultdict(list))
        entry = _find_slot_type(collection.slots, type_id, dogma["dogmaEffects"])
        if entry is not None:
            entry.type_id = type_id
            entry.max_state = _find_max_state(
                dogma["dogmaAttributes"], dogma["dogmaEffects"], dogma_effects
            )
            _find_slot_charge_groups(entry, dogma["dogmaAttributes"])
            slots += 1
        else:
            implant_slot_id = _find_implant_slot(dogma["dogmaAttributes"])
            if implant_slot_id is not None:
                entry = collection.slots.implant_slots[type_id]
                entry.type_id = type_id
                entry.slot_index = implant_slot_id
                slots += 1
            else:
                booster_slot_id = _find_booster_slot(dogma["dogmaAttributes"])
                if booster_slot_id is not None:
                    entry = collection.slots.booster_slots[type_id]
                    entry.type_id = type_id
                    entry.slot_index = booster_slot_id
                    slots += 1

    info(f"Generated {ship} ships, {subsystem} subsystems, {slots} slots")


@unique
class SlotType(IntEnum):
    High = 0
    Medium = 1
    Low = 2
    Rig = 3
    Subsystem = 4


def _find_slot_type(pb, id: int, effect_view: list[dict[str, str | bool]]):
    def hi_op(pb):
        match _find_high_slot_req(effect_view):
            case HighSlotType.Turret:
                pb.high_slots[id].is_turret = True
                pb.high_slots[id].is_launcher = False
            case HighSlotType.Launcher:
                pb.high_slots[id].is_turret = False
                pb.high_slots[id].is_launcher = True
            case _:
                pb.high_slots[id].is_turret = False
                pb.high_slots[id].is_launcher = False

        return pb.high_slots[id]

    mapping = {
        HI_EFFECT_ID: hi_op,
        MED_EFFECT_ID: lambda pb: pb.medium_slots[id],
        LOW_EFFECT_ID: lambda pb: pb.low_slots[id],
        RIG_EFFECT_ID: lambda pb: pb.rig_slots[id],
        SUBSYSTEM_EFFECT_ID: lambda pb: pb.subsystem_slots[id],
        SERVICE_EFFECT_ID: lambda pb: pb.service_slots[id],
    }
    for effect in effect_view:
        ty = mapping.get(int(effect["effectID"]))
        if ty is not None:
            return ty(pb)

    return None


@unique
class HighSlotType(IntEnum):
    Non = 0
    Turret = 1
    Launcher = 2


def _find_high_slot_req(effect_view: list[dict[str, str | bool]]):
    for effect in effect_view:
        if int(effect["effectID"]) == TURRET_EFFECT_ID:
            return HighSlotType.Turret
        elif int(effect["effectID"]) == LAUNCHER_EFFECT_ID:
            return HighSlotType.Launcher

    return HighSlotType.Non


def _find_implant_slot(attr_view: list[dict[str, str | int]]) -> int | None:
    for attr in attr_view:
        if attr["attributeID"] != IMPLANT_SLOT_ATTR_ID:
            continue

        return int(attr["value"])

    return None


def _find_booster_slot(attr_view: list[dict[str, str | int]]) -> int | None:
    for attr in attr_view:
        if attr["attributeID"] != BOOSTER_SLOT_ATTR_ID:
            continue

        return int(attr["value"])

    return None


def _find_max_state(
    attr_view: list[dict[str, str | int]], effect_view: list[dict[str, str | bool]], effects: dict
):
    max_state = fit_pb2.Slots.SlotState.ONLINE

    for attr in attr_view:
        if attr["attributeID"] == ENERGY_NEED_ATTR and attr["value"] > 0:  # energy need
            max_state = fit_pb2.Slots.SlotState.ACTIVE
        if attr["attributeID"] == DURATION_ATTR and attr["value"] > 0:  # duration
            max_state = fit_pb2.Slots.SlotState.ACTIVE
        if attr["attributeID"] == SPEED_ATTR and attr["value"] > 0:  # speed
            max_state = fit_pb2.Slots.SlotState.ACTIVE
        if attr["attributeID"] == OVERLOAD_DAMAGE_ATTR and attr["value"] > 0:  # overload damage
            max_state = fit_pb2.Slots.SlotState.OVERLOAD
            break

    for effect in effect_view:
        if effects[effect["effectID"]]["effectCategory"] == 5:
            max_state = fit_pb2.Slots.SlotState.OVERLOAD
            break

    return max_state


def _find_slot_charge_groups(slot_def, attr_view: list[dict[str, str | int]]) -> None:
    charges = []
    for attr in attr_view:
        if attr["attributeID"] in CHARGE_GROUP_IDS:
            charges.append(int(attr["value"]))

    if len(charges) > 0:
        slot_def.charge_groups.extend(sorted(charges))
