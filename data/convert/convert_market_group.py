from __future__ import annotations

from cache import FsdCache
import i18n
import market_group_pb2


def convert(cache: FsdCache, external: dict):
    print("Converting market groups...")

    market_groups = cache.get("marketGroups")
    types = cache.get("types")

    mgid = {}

    for id, entry in types.items():
        if "marketGroupID" not in entry.keys():
            continue

        market_group_id = entry["marketGroupID"]
        mgid.setdefault(market_group_id, []).append(id)

    mgobj = {}

    for id, entry in market_groups.items():
        if "parentGroupID" not in entry.keys():
            continue

        parent_group_id = entry["parentGroupID"]
        mgobj.setdefault(parent_group_id, []).append(id)

    data = market_group_pb2.MarketGroups()

    for id, entry in market_groups.items():
        i18n.into_i18n(data.entries[id].name, **entry["nameID"])
        if "parentGroupID" in entry.keys():
            data.entries[id].parentGroup = entry["parentGroupID"]
        data.entries[id].types.extend(mgid.get(id, []))
        data.entries[id].childGroups.extend(mgobj.get(id, []))

        if "iconID" in entry.keys():
            data.entries[id].iconID = entry["iconID"]

    external["market_groups"] = data
