"""This script is used to generate dogma units.

**Important**: This script requires Python **2.7** to run.

Prerequisites:
-   The dogma units file, named `dogmaunits.fsdbinary`.
-   The official dogma units loader, named `dogmaUnitsloader.pyd`.
    This file have to be extracted from the game client and is a dyn lib.
    So we can't provide it here and could not offer any support on how to get it.
-   The localization pickle, named `localization_fsd_xx.pickle`.
"""

import codecs
import importlib
import json
import pickle
import sys

USAGE_TEXT = """Usage:
    python2 dogma_units.py
        <dogma_units_file>        # e.g. ./dogmaunits.fsdbinary
        <localization>            # e.g. ./localization_fsd_zh.pickle
        <dogma_units_loader_dir>  # e.g. ./loader
        <output_file>             # e.g. ./out.json
"""

if len(sys.argv) != 5:
    print(USAGE_TEXT)
    sys.exit(1)

dogma_units_file = sys.argv[1]
localization_file = sys.argv[2]
dogma_units_loader_file = sys.argv[3]
output_file = sys.argv[4]

print(dogma_units_loader_file)
sys.path.append(dogma_units_loader_file)
dogma_units_loader = importlib.import_module('dogmaUnitsLoader')

dogma_units = dogma_units_loader.load(dogma_units_file)

with open(localization_file, 'rb') as f:
    lang_id, localization = pickle.load(f)

## We can not share the output's content and structure here,
## and I'm sorry not to provide any example & docs.

out = {}
for k, v in sorted(dogma_units.iteritems(), key=lambda u: int(u[0])):
    display_name = localization.get(v.displayNameID, ("",))[0]
    description = localization.get(v.descriptionID, ("",))[0]
    out[k] = {'name': v.name, 'displayName': display_name, 'description': description}

## We export the data to JSON to avoid managing dependencies when using Python2.
## The script can be run on a "clean" python2 interpreter.

with codecs.open(output_file, "w+", encoding="utf-8") as f:
    json.dump(out, f, indent=4, ensure_ascii=False)
