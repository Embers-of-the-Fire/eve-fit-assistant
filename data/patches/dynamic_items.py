"""This script is used to generate dynamic items.

**Important**: This script requires Python **2.7** to run.

Prerequisites:
-   The dynamic items file, named `dynamicitemattributes.fsdbinary`.
-   The official dynamic items loader, named `dynamicItemAttributesLoader.pyd`.
    This file have to be extracted from the game client and is a dyn lib.
    So we can't provide it here and could not offer any support on how to get it.
"""

import codecs
import importlib
import json
import sys


USAGE_TEXT = """Usage:
    python2 dynamic_items.py
        <dynamic_items_file>        # e.g. ./dynamicitemattributes.fsdbinary
        <dynamic_items_loader_dir>  # e.g. ./loader
        <output_file>               # e.g. ./out.json
"""

if len(sys.argv) != 4:
    print(USAGE_TEXT)
    sys.exit(1)

dynamic_items_file = sys.argv[1]
dynamic_items_loader_file = sys.argv[2]
output_file = sys.argv[3]

print(dynamic_items_loader_file)
sys.path.append(dynamic_items_loader_file)
dynamic_items_loader = importlib.import_module("dynamicItemAttributesLoader")

dynamic_items = dynamic_items_loader.load(dynamic_items_file)

out = {}
for k, v in sorted(dynamic_items.iteritems(), key=lambda u: int(u[0])):
    out[k] = {"inputOutputMapping": [], "attributeIDs": {}}

    for i in v.inputOutputMapping:
        out[k]["inputOutputMapping"].append(
            {
                "resultingType": i.resultingType,
                "applicableTypes": list(i.applicableTypes),
            }
        )

    for id, attr in v.attributeIDs.iteritems():
        out[k]["attributeIDs"][id] = {
            "max": attr.max,
            "min": attr.min,
        }

with codecs.open(output_file, "w+", encoding="utf-8") as f:
    json.dump(out, f, indent=4, ensure_ascii=False)
