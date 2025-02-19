from __future__ import annotations

from cache import ConvertCache
import character_pb2


def convert(cache: ConvertCache, external: dict):
    print("Creating predefined skill groups...")

    types = cache.get("types")
    groups = cache.get("groups")

    skill_group = [k for k, v in groups.items() if v.get("categoryID") == 16]

    skills = [k for k, v in types.items() if v.get("groupID") in skill_group]

    all_5_data = character_pb2.Character()
    all_5_data.id = ""
    all_5_data.name = "All 5"
    all_5_data.description = ""
    for skill_id in skills:
        all_5_data.skills[skill_id] = 5

    external["character/max"] = all_5_data

    all_0_data = character_pb2.Character()
    all_0_data.id = ""
    all_0_data.name = "All 0"
    all_0_data.description = ""
    for skill_id in skills:
        all_0_data.skills[skill_id] = 0

    external["character/min"] = all_0_data
