from typing import NamedTuple
import json
from pathlib import Path

import case_convert


class Predefined(NamedTuple):
    id: str
    name: str


def codegen(_1, app_out: Path, _2, out_dir: Path):
    print("Generating predefined character ids...")

    char_dir = app_out / "character"

    predefined: set[Predefined] = set()
    for file in char_dir.glob("*.json"):
        if not file.is_file():
            continue

        with open(file, "r", encoding="utf-8") as f:
            data = json.load(f)

        predefined.add(Predefined(name=data["name"], id=data["id"]))

    out_file = out_dir / "constant" / "character.dart"
    with open(out_file, 'w+', encoding='utf-8') as f:
        for defined in predefined:
            f.write(f"/// - Name: {defined.name}\n")
            f.write(f"/// - ID: {defined.id}\n")
            f.write(f"const String {case_convert.camel_case(defined.id)} = {defined.id!r};\n\n")
