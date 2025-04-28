from __future__ import annotations
from cache import ConvertCache
import unit_pb2


def convert(cache: ConvertCache, external: dict):
    data = unit_pb2.Units()

    print("Converting units...")
    units = cache.get("dogmaUnits")

    for unit_id, entry in units.items():
        data.entries[unit_id].name = entry["name"]
        data.entries[unit_id].id = unit_id
        if "displayNameID" in entry.keys():
            data.entries[unit_id].displayName = cache.loc.get(entry["displayNameID"], "zh")
        else:
            data.entries[unit_id].displayName = ""
        if "descriptionID" in entry.keys():
            data.entries[unit_id].description = cache.loc.get(entry["descriptionID"], "zh")
        else:
            data.entries[unit_id].description = ""

    external["units"] = data
