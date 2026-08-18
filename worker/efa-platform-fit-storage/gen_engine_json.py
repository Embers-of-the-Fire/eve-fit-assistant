#!/usr/bin/env python3
"""Generate the negative-only engine patch JSONs for the fit-storage worker.

The eve-fit-os build script unconditionally requires
`<OUTPUT_DIR>/json/{dogmaAttributes,dogmaEffects}.json` to generate the
negative-ID patch constants — even with `default-features = false`. Every
negative-ID entry is fully determined by the submodule's tracked
`data/patches/*.yaml`, so this script replicates the ID-assignment semantics
of `data/convert/patches/{dogma_attributes,dogma_effects}.py` exactly:

  - YAMLs are processed in `sorted(os.listdir())` order;
  - sequential IDs start at -1 and decrement;
  - a pinned `new.id` is used as-is and does not consume a sequence number.

Effect-modifier fixups are skipped: the engine's build.rs consumes only
`name` + ID from these files.

Output: `<crate>/engine-json/json/{dogmaAttributes,dogmaEffects}.json`
(gitignored; regenerated as part of every build).

Requires: Python 3.10+, PyYAML.
"""

from __future__ import annotations

import json
import os
import sys

from pathlib import Path

import yaml


CRATE_DIR = Path(__file__).resolve().parent
WORKSPACE_ROOT = CRATE_DIR.parent.parent
PATCHES_DIR = WORKSPACE_ROOT / "packages" / "eve-fit-os" / "data" / "patches"
OUTPUT_DIR = CRATE_DIR / "engine-json" / "json"


def collect_entries(section: str) -> dict[int, str]:
    entries: dict[int, str] = {}
    next_id = -1
    for filename in sorted(os.listdir(PATCHES_DIR)):
        if not filename.endswith(".yaml"):
            continue
        with open(PATCHES_DIR / filename, encoding="utf-8") as fp:
            document = yaml.load(fp, Loader=yaml.CSafeLoader)
        for patch in document.get(section, []):
            new = patch.get("new")
            if not new:
                continue
            name = new["name"]
            if "id" in new:
                entry_id = new["id"]
            else:
                entry_id = next_id
                next_id -= 1
            if name in entries.values():
                raise ValueError(f"Patch name {name!r} is not unique.")
            entries[entry_id] = name
    return entries


def write_json(path: Path, entries: dict[int, str]) -> None:
    payload = {"entries": {str(k): {"name": v} for k, v in sorted(entries.items())}}
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as fp:
        json.dump(payload, fp, indent=2, sort_keys=True)
        fp.write("\n")


def main() -> int:
    attributes = collect_entries("attributes")
    effects = collect_entries("effects")
    write_json(OUTPUT_DIR / "dogmaAttributes.json", attributes)
    write_json(OUTPUT_DIR / "dogmaEffects.json", effects)
    print(
        f"Wrote {len(attributes)} patch attributes and {len(effects)} patch effects to {OUTPUT_DIR}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
