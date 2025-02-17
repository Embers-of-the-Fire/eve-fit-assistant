from __future__ import annotations

from cache import ConvertCache
import i18n
import tactical_mode_pb2


def convert(cache: ConvertCache, external: dict):
    data = tactical_mode_pb2.ShipTacticalMode()

    print("Collecting tactical modes...")

    tactical: dict[int, dict[str, list[int]]] = cache.get_patch("tactical_mode", "yaml")
    types = cache.get("types")

    for ship_id, dataset in tactical.items():
        for mode_id in dataset["modes"]:
            ty = types[mode_id]
            i18n.into_i18n(data.ships[ship_id].tacticalModes[mode_id].name, **ty["name"])
            data.ships[ship_id].tacticalModes[mode_id].iconID = ty["iconID"]
    
    external['tactical_mode'] = data
