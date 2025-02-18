"""Units codegen.

Some units have special formatter, so we generate a list for its id.
"""

import json
from pathlib import Path
from case_convert import camel_case


def codegen(_1, app_out: Path, _2, out_dir: Path):
    print("Generating units...")
    units_file = app_out / "units.json"
    with open(units_file, "r", encoding="utf-8") as f:
        units = json.load(f)

    out_file = out_dir / "constant" / "unit.dart"
    out_file.parent.mkdir(parents=True, exist_ok=True)
    with open(out_file, "w+", encoding="utf-8") as f:
        f.write("enum UnitType {")
        for key, unit in sorted(units["entries"].items(), key=lambda u: int(u[0])):
            f.write(f"  /// - Name: {unit['name']}\n")
            f.write(f"  /// - Display: {unit['displayName']}\n")
            f.write(f"  /// - Description: {unit['description'].replace('\n', ' ')}\n")
            f.write(f"  {camel_case(unit['name'].replace('/', 'Per'))}({key}),\n\n")
        f.write("  ;\n\n  final int id;\n\n")
        f.write("  const UnitType(this.id);\n\n")
        f.write("  static UnitType? fromID(int id) => switch (id) {\n")
        for key, unit in sorted(units["entries"].items(), key=lambda u: int(u[0])):
            f.write(f"    {key} => UnitType.{camel_case(unit['name'].replace('/', 'Per'))},\n")
        f.write("    _ => null,\n  };\n")
        f.write("}\n")
