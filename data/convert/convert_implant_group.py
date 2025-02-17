from __future__ import annotations

from cache import ConvertCache
import implant_group_pb2


def convert(cache: ConvertCache, external: dict):
    data = implant_group_pb2.ImplantGroups()

    print("Collecting tactical modes...")

    implant_groups = cache.get_patch("implant_group", "yaml")

    for group in implant_groups:
        g = implant_group_pb2.ImplantGroups.ImplantGroup()
        g.name = group["name"]
        for subgroup in group["groups"]:
            sg = implant_group_pb2.ImplantGroups.ImplantSubGroup()
            sg.name = subgroup["name"]
            sg.items.extend(subgroup["items"])
            g.groups.append(sg)
        data.groups.append(g)

    external["implant_group"] = data
