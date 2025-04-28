from __future__ import annotations

import dynamic_item_pb2
from cache import ConvertCache


def convert(cache: ConvertCache, external: dict):
    data = dynamic_item_pb2.DynamicItems()

    print("Converting dynamic items...")
    dyns = cache.get("dynamicItemAttributes")

    maybe_dynamic = set()
    for dyn_id, dyn_entry in dyns.items():
        mapping = dyn_entry["inputOutputMapping"][0]
        data.entries[dyn_id].inputOutputMapping.resultingType = mapping["resultingType"]
        data.entries[dyn_id].inputOutputMapping.applicableTypes.extend(
            sorted(mapping["applicableTypes"])
        )
        maybe_dynamic.update(mapping["applicableTypes"])
        for attr_id, attr_map in dyn_entry["attributeIDs"].items():
            data.entries[dyn_id].attributes[int(attr_id)].max = attr_map["max"]
            data.entries[dyn_id].attributes[int(attr_id)].min = attr_map["min"]

    external["dynamic_item"] = data

    data = dynamic_item_pb2.DynamicTypes()
    for type_id in maybe_dynamic:
        muts = filter(
            lambda x: any(type_id in t["applicableTypes"] for t in x[1]["inputOutputMapping"]),
            dyns.items(),
        )
        data.entries[type_id].mutaplasmidTypes.extend(sorted({int(x[0]) for x in muts}))

    external["dynamic_type"] = data
