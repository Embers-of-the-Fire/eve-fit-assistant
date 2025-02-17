from __future__ import annotations

import sys
import os

from google.protobuf.json_format import MessageToJson

from cache import ConvertCache
import convert_market_group
import convert_types
import convert_ships
import convert_type_slots
import convert_groups
import convert_skills
import convert_character
import convert_subsystem
import convert_tactical_mode
import convert_implant_group

if not __name__ == "__main__":
    exit(0)

USAGE = """Usage:
    python3 convert.py
        <path/to/eve-sde/fsd>
        <path/to/resfileindex>
        <path/to/patches>
        <path/to/output>
        <path/to/resfileindex-cache>"""

if len(sys.argv) < 6:
    print(USAGE)
    exit(1)


def convert(fsd_dir, resfileindex, patch_dir, out_dir, index_cache):
    os.makedirs(f"{out_dir}/pb2", exist_ok=True)
    os.makedirs(f"{out_dir}/json", exist_ok=True)
    os.makedirs(f"{out_dir}/pb2/character", exist_ok=True)
    os.makedirs(f"{out_dir}/json/character", exist_ok=True)

    data = {}
    cache = ConvertCache(fsd_dir, resfileindex, index_cache, patch_dir)

    convert_types.convert(cache, data)
    convert_market_group.convert(cache, data)
    convert_ships.convert(cache, data)
    convert_type_slots.convert(cache, data)
    convert_groups.convert(cache, data)
    convert_skills.convert(cache, data)
    convert_character.convert(cache, data)
    convert_subsystem.convert(cache, data)
    convert_tactical_mode.convert(cache, data)
    convert_implant_group.convert(cache, data)

    for key, value in data.items():
        with open(f"{out_dir}/json/{key}.json", "w", encoding="utf-8") as fp:
            fp.write(MessageToJson(value, sort_keys=True))

        with open(f"{out_dir}/pb2/{key}.pb", "wb") as fp:
            fp.write(value.SerializeToString())


convert(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5])
