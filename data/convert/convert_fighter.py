from __future__ import annotations

from cache import ConvertCache
import fighter_pb2


def convert(cache: ConvertCache, external: dict):
    data = fighter_pb2.Fighters()

    print("Converting fighter abilities")

    types = cache.get("types")
    dogma = cache.get("typeDogma")

    for key, entry in types.items():
        ty = None
        match entry.get("groupID"):
            case 1537:
                ty = fighter_pb2.Fighters.FighterType.SUPPORT
            case 1652:
                ty = fighter_pb2.Fighters.FighterType.LIGHT
            case 1653:
                ty = fighter_pb2.Fighters.FighterType.HEAVY
            case _:
                continue

        ability_flag = 0
        for effect in dogma[key].get("dogmaEffects", []):
            if effect["effectID"] == 6465:
                ability_flag |= 0b0000_0100
            elif effect["effectID"] == 6431:
                ability_flag |= 0b0000_0010
            elif effect["effectID"] == 6485:
                ability_flag |= 0b0000_1000

        amount = 0
        for attr in dogma[key].get("dogmaAttributes", []):
            if attr["attributeID"] == 2215:
                amount = int(attr["value"])
                break
                
        data.entries[key].ability = ability_flag
        data.entries[key].amount = amount
        data.entries[key].type = ty

    external["fighter"] = data
