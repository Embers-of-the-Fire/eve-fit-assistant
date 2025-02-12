from __future__ import annotations

from cache import ConvertCache
import i18n
import groups_pb2


def convert(cache: ConvertCache, external: dict):
    data = groups_pb2.Groups()

    try:
        market_groups_data = external["market_groups"]
    except KeyError as e:
        e.add_note("Missing required dependency `market_groups`")
        raise e

    print("Converting groups...")
    groups = cache.get("groups")
    types = cache.get("types")

    for id, entry in groups.items():
        i18n.into_i18n(data.entries[id].name, **entry["name"])

    for id, entry in types.items():
        group_id = entry.get("groupID")
        if group_id is not None:
            data.entries[group_id].types.append(id)

    group_sub_market_group: dict[int, set[int]] = {}

    def rec_add_group(base: int, ty: int):
        nonlocal group_sub_market_group
        group_sub_market_group.setdefault(ty, set()).add(base)
        if market_groups_data.entries[base].parentGroup:
            rec_add_group(market_groups_data.entries[base].parentGroup, ty)

    for group_id, group_data in market_groups_data.entries.items():
        for type_id in group_data.types:
            type_group_id = types[type_id].get("groupID")
            if type_group_id is None:
                continue
            rec_add_group(group_id, type_group_id)

    for group_id, group_data in group_sub_market_group.items():
        data.entries[group_id].relatedMarketGroups.extend(group_data)

    external["groups"] = data
