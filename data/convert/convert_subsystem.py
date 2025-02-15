from __future__ import annotations

from cache import ConvertCache
import i18n
import subsystem_pb2


def convert(cache: ConvertCache, external: dict):
    print("Collecting subsystems...")

    data = subsystem_pb2.ShipSubsystem()

    types = cache.get("types")
    groups = cache.get("groups")
    dogma = cache.get("typeDogma")

    subsystem_group = [k for k, v in groups.items() if v.get("categoryID") == 32]

    subsystems: dict[int, dict[int, list[int]]] = {}

    for id, entry in types.items():
        if entry.get("groupID") not in subsystem_group:
            continue

        group_id = entry["groupID"]
        type_dogma = dogma[id]["dogmaAttributes"]

        for dgm in type_dogma:
            if dgm["attributeID"] == 1380:
                (subsystems.setdefault(int(dgm["value"]), {}).setdefault(group_id, []).append(id))
                break

    for ship_id, subsystem_data in subsystems.items():
        data.ships[ship_id].offensive.extend(subsystem_data[956])
        data.ships[ship_id].offensiveMarket = types[subsystem_data[956][0]]["marketGroupID"]
        data.ships[ship_id].propulsion.extend(subsystem_data[957])
        data.ships[ship_id].propulsionMarket = types[subsystem_data[957][0]]["marketGroupID"]
        data.ships[ship_id].core.extend(subsystem_data[958])
        data.ships[ship_id].coreMarket = types[subsystem_data[958][0]]["marketGroupID"]
        data.ships[ship_id].defensive.extend(subsystem_data[954])
        data.ships[ship_id].defensiveMarket = types[subsystem_data[954][0]]["marketGroupID"]

        for subs in subsystem_data.values():
            _process_subsystems(data, subs, cache=cache)

    external["subsystem"] = data


def _process_subsystems(base, ids: list[int], cache: ConvertCache):
    for id in ids:
        _process_subsystem(base.subsystems[id], id, cache)


def _process_subsystem(data, id: int, cache: ConvertCache) -> subsystem_pb2.Subsystem:
    types = cache.get("types")
    dogma = cache.get("typeDogma")

    item_data = types[id]
    item_dogma = dogma[id]

    i18n.into_i18n(data.name, **item_data["name"])
    for dgm in item_dogma["dogmaAttributes"]:
        value = int(dgm['value'])
        match (dgm['attributeID']):
            case 1374:
                data.high = value
            case 1375:
                data.medium = value
            case 1376:
                data.low = value
            case 1368:
                data.turret = value
            case 1369:
                data.launcher = value

    return data
