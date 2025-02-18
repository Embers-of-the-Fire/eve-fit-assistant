from __future__ import annotations

from cache import ConvertCache
import i18n
import attribute_pb2


def convert(cache: ConvertCache, external: dict):
    data = attribute_pb2.Attributes()
    print("Converting dogma attributes...")

    attrs = cache.get("dogmaAttributes")

    for id, entry in attrs.items():
        data.entries[id].name = entry["name"]
        if "defaultValue" in entry.keys():
            data.entries[id].defaultValue = entry["defaultValue"]
        if "categoryID" in entry.keys():
            data.entries[id].categoryID = entry["categoryID"]
        if "description" in entry.keys():
            data.entries[id].description = entry["description"]
        if "displayNameID" in entry.keys():
            i18n.into_i18n(data.entries[id].displayName, **entry["displayNameID"])
        data.entries[id].highIsGood = entry["highIsGood"]
        if "iconID" in entry.keys():
            data.entries[id].iconID = entry["iconID"]
        data.entries[id].published = entry["published"]
        if "unitID" in entry.keys():
            data.entries[id].unitID = entry["unitID"]

    external["attribute"] = data
