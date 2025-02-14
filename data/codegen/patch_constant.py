import json
from pathlib import Path
from typing import TypedDict


class PatchAttrConfig(TypedDict):
    name: str
    high_is_good: bool


def codegen(native: Path, out_dir: Path):
    print("Generating patched attribute constant code...")
    patched_attr = native / "dogmaAttributes.json"
    with open(patched_attr, "r", encoding="utf-8") as f:
        attrs = json.load(f)

    out: dict[int, PatchAttrConfig] = {}

    for key, value in attrs["entries"].items():
        key = int(key)
        if key >= 0:
            continue
        out[key] = {
            "name": value["name"],
            "high_is_good": value["highIsGood"],
        }

    out_file = out_dir / "constant" / "attribute.dart"
    out_file.parent.mkdir(parents=True, exist_ok=True)
    with open(out_file, "w+", encoding="utf-8") as f:
        for key, config in out.items():
            f.write(f"/// - Name: {config['name']}\n")
            f.write(f"/// - High is good: {config['high_is_good']}\n")
            f.write(f"const int {config['name']} = {key};\n\n")
