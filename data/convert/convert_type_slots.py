from __future__ import annotations
from enum import IntEnum, unique

from cache import ConvertCache
import i18n
import slots_pb2


def convert(cache: ConvertCache, external: dict):
    data = slots_pb2.Slots()

    print("Converting slots...")

    types = cache.get("types")
    type_dogma = cache.get("typeDogma")

    for id, typedef in types.items():
        dogma = type_dogma.get(id)
        if dogma is None:
            continue

        entry = _find_slot_type(data, id, dogma["dogmaEffects"])
        if entry is not None:
            i18n.into_i18n(entry.name, **typedef["name"])
            entry.published = typedef["published"]
            entry.maxState = _find_max_state(dogma["dogmaAttributes"])
            _find_slot_charge_groups(entry, dogma["dogmaAttributes"])
            continue

        slot_id = _find_implant_slot(dogma["dogmaAttributes"])
        if slot_id is not None:
            i18n.into_i18n(data.implant[id].name, **typedef["name"])
            data.implant[id].published = typedef["published"]
            data.implant[id].slot = slot_id - 1  # eve uses 1-based index
            continue

    external["slots"] = data


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
                pb.high[id].isTurret = True
                pb.high[id].isLauncher = False
            case HighSlotType.Launcher:
                pb.high[id].isTurret = False
                pb.high[id].isLauncher = True
            case _:
                pb.high[id].isTurret = False
                pb.high[id].isLauncher = False

        return pb.high[id]

    mapping = {
        12: hi_op,
        13: lambda pb: pb.med[id],
        11: lambda pb: pb.low[id],
        2663: lambda pb: pb.rig[id],
        3772: lambda pb: pb.subsystem[id],
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
        if int(effect["effectID"]) == 42:
            return HighSlotType.Turret
        elif int(effect["effectID"]) == 40:
            return HighSlotType.Launcher

    return HighSlotType.Non


def _find_implant_slot(attr_view: list[dict[str, str | int]]) -> int | None:
    for attr in attr_view:
        if attr["attributeID"] != 331:
            continue

        return int(attr["value"])

    return None


def _find_max_state(attr_view: list[dict[str, str | int]]):
    max_state = slots_pb2.Slots.SlotState.ONLINE

    for attr in attr_view:
        if attr["attributeID"] == 6 and attr["value"] > 0:  # energy need
            max_state = slots_pb2.Slots.SlotState.ACTIVE
        if attr["attributeID"] == 73 and attr["value"] > 0:  # duration
            max_state = slots_pb2.Slots.SlotState.ACTIVE
        if attr["attributeID"] == 1211 and attr["value"] > 0:  # overload damage
            max_state = slots_pb2.Slots.SlotState.OVERLOAD
            break

    return max_state


def _find_slot_charge_groups(slot_def, attr_view: list[dict[str, str | int]]) -> None:
    charges = []
    for attr in attr_view:
        if attr["attributeID"] in [604, 605, 606, 609, 610]:
            charges.append(int(attr["value"]))

    if len(charges) > 0:
        slot_def.chargeGroups.extend(sorted(charges))
