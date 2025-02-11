from __future__ import annotations

import sys
import os

from google.protobuf.json_format import MessageToJson

from cache import FsdCache
import convert_market_group
import convert_types
import convert_ships
import convert_type_slots
import convert_groups

if not __name__ == "__main__":
    exit(0)

if len(sys.argv) < 2:
    print("Usage: python3 convert.py <path/to/eve-sde/fsd> <path/to/output>")
    exit(1)


def convert(fsd_dir, out_dir):
    os.makedirs(f"{out_dir}/pb2", exist_ok=True)
    os.makedirs(f"{out_dir}/json", exist_ok=True)

    data = {}
    cache = FsdCache(fsd_dir)

    convert_types.convert(cache, data)
    convert_market_group.convert(cache, data)
    convert_ships.convert(cache, data)
    convert_type_slots.convert(cache, data)
    convert_groups.convert(cache, data)

    for key, value in data.items():
        with open(f"{out_dir}/json/{key}.json", "w", encoding="utf-8") as fp:
            fp.write(MessageToJson(value, sort_keys=True))

        with open(f"{out_dir}/pb2/{key}.pb", "wb") as fp:
            fp.write(value.SerializeToString())


convert(sys.argv[1], sys.argv[2])
