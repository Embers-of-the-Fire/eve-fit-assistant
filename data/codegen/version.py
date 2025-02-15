from pathlib import Path


def codegen(_, version_file: Path, out_dir: Path):
    print("Generating bundle version timestamp constant...")

    with open(version_file, "r", encoding="utf-8") as f:
        timestamp = version_file.read_text()

    time = int(timestamp)

    out_file = out_dir / "constant" / "bundle.dart"
    out_file.parent.mkdir(parents=True, exist_ok=True)
    with open(out_file, "w+", encoding="utf-8") as f:
        f.write("import 'package:eve_fit_assistant/storage/static/storage.dart';\n\n")
        f.write("/// Bundled static data version\n")
        f.write(f"const StaticVersionInfo dataVersion = StaticVersionInfo(createTime: {time});\n")
