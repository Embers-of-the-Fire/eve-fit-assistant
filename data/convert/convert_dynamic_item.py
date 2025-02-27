from __future__ import annotations

import dynamic_item_pb2
from cache import ConvertCache


def convert(cache: ConvertCache, external: dict):
    data = dynamic_item_pb2.DynamicItems()

    print("Converting dynamic items...")
    dyns = cache.get_patch("dynamic_items", "json")

    for dyn_id, dyn_entry in dyns.items():
        dyn_id = int(dyn_id)
        mapping = dyn_entry["inputOutputMapping"][0]
        data.entries[dyn_id].inputOutputMapping.resultingType = mapping["resultingType"]
        data.entries[dyn_id].inputOutputMapping.applicableTypes.extend(mapping["applicableTypes"])
        for attr_id, attr_map in dyn_entry["attributeIDs"].items():
            data.entries[dyn_id].attributes[int(attr_id)].max = attr_map["max"]
            data.entries[dyn_id].attributes[int(attr_id)].min = attr_map["min"]

    external["dynamic_item"] = data
