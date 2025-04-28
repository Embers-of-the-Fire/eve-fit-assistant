from __future__ import annotations
from cache import ConvertCache
import unit_pb2


def convert(cache: ConvertCache, external: dict):
    data = unit_pb2.Units()

    print("Converting units...")
    units = cache.get("dogmaUnits")

    for unit_id, entry in units.items():
        data.entries[id].name = entry["name"]
        data.entries[id].id = id
        data.entries[id].displayName = cache.loc.get(entry["displayNameID"], "zh")
        if "descriptionID" in entry.keys():
            data.entries[id].description = cache.loc.get(entry["descriptionID"], "zh")
        else:
            data.entries[id].description = ""

    external["units"] = data
