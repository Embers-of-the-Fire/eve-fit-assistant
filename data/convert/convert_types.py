from __future__ import annotations
from decimal import ROUND_DOWN, Decimal
from cache import ConvertCache
import i18n
import types_pb2


def convert(cache: ConvertCache, external: dict):
    data = types_pb2.Types()

    print("Converting types...")
    types = cache.get("types")

    for id, entry in types.items():
        # if not entry["published"]: # filter out unpublished types, at least currently
        #     continue
        i18n.into_i18n(data.entries[id].name, **cache.loc.get_all(entry["typeNameID"]))
        data.entries[id].groupID = entry["groupID"]
        data.entries[id].published = entry["published"]
        description = entry.get("descriptionID", None)
        if description is None:
            data.entries[id].description = ""
        else:
            data.entries[id].description = cache.loc.get(description, 'zh')
        data.entries[id].traits = build_trait(id, cache, external)

    external["types"] = data


def build_trait(type_id: int, cache: ConvertCache, external: dict) -> str:
    buffer = ""

    types = cache.get("types")
    unit_map = external["units"]

    traits = types[type_id].get("traits")
    if traits is None:
        return ""

    types_buffer = ""
    for id, entry in traits.get("types", {}).items():
        skill_name = cache.loc.get(types[id]["typeNameID"], "zh")
        skill_buffer = ""
        for bonus in sorted(entry, key=lambda t: t["importance"]):
            text = bonus["bonusText"]["zh"]
            if "bonus" in bonus.keys():
                bonus_val = normalize_float(bonus["bonus"])
                unit = unit_map.entries[bonus["unitID"]].displayName
                skill_buffer += f"    {bonus_val}{unit} {text}\n"
            else:
                skill_buffer += f"    · {text}\n"
        if skill_buffer:
            types_buffer += f"<a href=showinfo:{id}>{skill_name}</a> 每升一级：\n"
            types_buffer += skill_buffer
    if types_buffer:
        buffer += f"{types_buffer}\n"

    role_buffer = ""
    for bonus in sorted(traits.get("roleBonuses", []), key=lambda t: t["importance"]):
        text = bonus["bonusText"]["zh"]
        if "bonus" in bonus.keys():
            bonus_val = normalize_float(bonus["bonus"])
            unit = unit_map.entries[bonus["unitID"]].displayName
            role_buffer += f"    {bonus_val}{unit} {text}\n"
        else:
            role_buffer += f"    · {text}\n"
    if role_buffer:
        buffer += f"特有加成：\n{role_buffer}\n"

    misc_buffer = ""
    for bonus in sorted(traits.get("miscBonuses", []), key=lambda t: t["importance"]):
        text = bonus["bonusText"]["zh"]
        if "bonus" in bonus.keys():
            bonus_val = normalize_float(bonus["bonus"])
            unit = unit_map.entries[bonus["unitID"]].displayName
            misc_buffer += f"    {bonus_val}{unit} {text}\n"
        else:
            misc_buffer += f"    · {text}\n"
    if misc_buffer:
        buffer += f"其他加成：\n{misc_buffer}\n"

    return buffer


def normalize_float(data: float) -> str:
    d = Decimal(str(data))
    truncated = d.quantize(Decimal("0." + "0" * 2), rounding=ROUND_DOWN)
    return format(truncated.normalize(), "f")
