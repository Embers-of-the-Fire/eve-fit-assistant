from __future__ import annotations
from cache import ConvertCache
import unit_pb2


def convert(cache: ConvertCache, external: dict):
    data = unit_pb2.Units()

    print("Converting units...")
    units = cache.get_patch("dogma_units", "json")

    for unit_id, entry in units.items():
        # if not entry["published"]: # filter out unpublished types, at least currently
        #     continue
        id = int(unit_id)
        data.entries[id].name = entry["name"]
        data.entries[id].displayName = entry["displayName"]
        data.entries[id].description = entry["description"]

    external["units"] = data
