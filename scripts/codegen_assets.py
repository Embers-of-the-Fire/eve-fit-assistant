from pathlib import Path


def kebab_to_camel(name: str) -> str:
    parts = name.split("-")
    if not parts:
        return ""
    camel = parts[0].lower()
    for part in parts[1:]:
        camel += part.capitalize()
    return camel + "Image"


def generate_dart_assets():
    assets_dir = Path("./assets")
    lib_assets_dir = Path("./lib/assets")

    lib_assets_dir.mkdir(parents=True, exist_ok=True)
    
    subfiles = []

    for subdir in assets_dir.iterdir():
        if subdir.is_dir():
            png_files = list(subdir.glob("*.png"))
            if not png_files:
                continue

            dart_filename = f"{subdir.name}.dart"
            dart_path = lib_assets_dir / dart_filename

            variables = []
            for png in sorted(png_files, key=lambda x: x.name):
                filename_stem = png.stem
                var_name = kebab_to_camel(filename_stem)
                asset_path = f"assets/{subdir.name}/{png.name}"
                variables.append(f"const AssetImage {var_name} = AssetImage('{asset_path}');\n")

            dart_code = "part of 'assets.dart';\n\n"
            dart_code += "\n".join(variables)

            with dart_path.open("w", encoding="utf-8") as f:
                f.write(dart_code)
            print(f"Generated: {dart_path}")
            subfiles.append(dart_path.name)
    
    assets_path = lib_assets_dir / "assets.dart"
    with assets_path.open("w", encoding="utf-8") as f:
        f.write("library;\n\nimport 'package:flutter/material.dart';\n\n")
        for subfile in subfiles:
            f.write(f"part '{subfile}';\n")
    print(f"Generated: {assets_path}")


if __name__ == "__main__":
    generate_dart_assets()
