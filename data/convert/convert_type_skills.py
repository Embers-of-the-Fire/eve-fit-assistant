from __future__ import annotations
from collections.abc import Callable

from cache import ConvertCache
import skills_pb2


def convert(cache: ConvertCache, external: dict):
    data = skills_pb2.TypeSkills()

    print("Converting type skills...")

    dogmas = cache.get("typeDogma")

    skill_requirements = [
        (182, 277),
        (183, 278),
        (184, 279),
        (1285, 1286),
        (1289, 1287),
        (1290, 1288),
    ]

    for type_id, dogma in dogmas.items():
        skills = {}
        for attr in dogma["dogmaAttributes"]:
            id = attr["attributeID"]
            if (x := _list_index_by(skill_requirements, id, lambda x: x[0])) is not None:
                skills.setdefault(x, {})["skillID"] = int(attr["value"])
            elif (x := _list_index_by(skill_requirements, id, lambda x: x[1])) is not None:
                skills.setdefault(x, {})["level"] = int(attr["value"])
        for _, value in sorted(skills.items(), key=lambda x: x[0]):
            s = skills_pb2.TypeSkills.Skill()
            s.id = value["skillID"]
            s.level = value["level"]
            data.entries[type_id].skills.append(s)
    
    external["type_skills"] = data


def _list_index_by[T, R](list: list[T], key: R, func: Callable[[T], R]) -> int | None:
    for i, item in enumerate(list):
        if func(item) == key:
            return i
    return None
