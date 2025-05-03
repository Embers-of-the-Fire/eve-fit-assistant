from __future__ import annotations
import json
import sqlite3

from cache import ConvertCache
import skills_pb2
import character_pb2
import i18n


def convert(cache: ConvertCache, external: dict):
    data = skills_pb2.Skills()

    print("Converting skills...")

    types = cache.get("types")
    groups = cache.get("groups")
    clone_grades_db_dir = cache.download_cached("res:/staticdata/clonegrades.static")

    skill_group = [k for k, v in groups.items() if v.get("categoryID") == 16]
    
    skills = [k for k, v in types.items() if v.get("groupID") in skill_group]

    db = sqlite3.connect(clone_grades_db_dir)
    cursor = db.cursor()
    res = cursor.execute(r'SELECT "value" from "cache" LIMIT 1')
    stats, = res.fetchone()

    mapping: dict[int, int] = {}
    clone_skills: list[dict[str, int]] = json.loads(stats)["skills"]
    for record in clone_skills:
        mapping[record["typeID"]] = record["level"]

    for id in skills:
        entry = types[id]
        i18n.into_i18n(data.entries[id].name, **cache.loc.get_all(entry["typeNameID"]))
        data.entries[id].groupID = entry["groupID"]
        data.entries[id].alphaMaxLevel = mapping.get(id, 0)
        data.entries[id].published = entry["published"]

    external["skills"] = data
    
    alpha_max_data = character_pb2.Character()
    alpha_max_data.id = "predefined-level-alpha-max"
    alpha_max_data.name = "Alpha Max"
    alpha_max_data.description = ""
    for skill_id in skills:
        alpha_max_data.skills[skill_id] = mapping.get(skill_id, 0)

    external["character/alpha"] = alpha_max_data
    
    db.close()
