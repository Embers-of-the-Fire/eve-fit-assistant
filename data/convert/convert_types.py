from __future__ import annotations
from cache import ConvertCache
import i18n
import types_pb2


def convert(cache: ConvertCache, external: dict):
    data = types_pb2.Types()

    print("Converting types...")
    types = cache.get("types")

    for id, entry in types.items():
        # if not entry["published"]: # filter out unpublished types, at least currently
        #     continue
        i18n.into_i18n(data.entries[id].name, **entry["name"])
        data.entries[id].groupID = entry["groupID"]
        data.entries[id].published = entry["published"]

    external["types"] = data
