from __future__ import annotations

from cache import ConvertCache
import i18n
import ships_pb2


def convert(cache: ConvertCache, external: dict):
    data = ships_pb2.Ships()

    print("Converting ships...")

    groups = cache.get("groups")
    types = cache.get("types")
    dogma = cache.get("typeDogma")
    
    tactical = cache.get_patch("tactical_mode")

    ship_groups = [k for k, v in groups.items() if v.get("categoryID") == 6]

    ships: list[tuple[int, dict]] = []
    for id, entry in types.items():
        if entry["groupID"] in ship_groups:
            ships.append((id, entry))

    for id, entry in ships:
        i18n.into_i18n(data.entries[id].name, **entry["name"])
        data.entries[id].groupID = entry["groupID"]
        data.entries[id].published = entry["published"]

        dogma_map: dict[int, float] = {}
        for item in dogma[id].get("dogmaAttributes", []):
            dogma_map[item["attributeID"]] = item["value"]

        data.entries[id].highSlotNum = int(dogma_map.get(14, 0))
        data.entries[id].medSlotNum = int(dogma_map.get(13, 0))
        data.entries[id].lowSlotNum = int(dogma_map.get(12, 0))
        data.entries[id].rigSlotNum = int(dogma_map.get(1137, 0))
        data.entries[id].hasSubsystem = int(dogma_map.get(1367, 0)) > 0
        data.entries[id].turretSlotNum = int(dogma_map.get(102, 0))
        data.entries[id].launcherSlotNum = int(dogma_map.get(101, 0))
        data.entries[id].droneBandwidth = int(dogma_map.get(1271, 0))
        data.entries[id].hasTacticalMode = id in tactical.keys()

    external["ships"] = data
