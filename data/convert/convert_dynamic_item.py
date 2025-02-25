from __future__ import annotations

import dynamic_item_pb2
from cache import ConvertCache


def convert(cache: ConvertCache, external: dict):
    data = dynamic_item_pb2.DynamicItems()

    print("Converting dynamic items...")
    dyns = cache.get_patch("dynamic_items", "json")

    for dyn_id, dyn_entry in dyns.items():
        dyn_id = int(dyn_id)
        for mapping in dyn_entry["inputOutputMapping"]:
            m = dynamic_item_pb2.DynamicItems.DynamicItem.InputOutputMapping()
            m.resultingType = mapping["resultingType"]
            m.applicableTypes.extend(mapping["applicableTypes"])
            data.entries[dyn_id].inputOutputMapping.append(m)
        for attr_id, attr_map in dyn_entry["attributeIDs"].items():
            data.entries[dyn_id].attributes[int(attr_id)].max = attr_map["max"]
            data.entries[dyn_id].attributes[int(attr_id)].min = attr_map["min"]

    external["dynamic_item"] = data
