from __future__ import annotations

import argparse
import json
from pathlib import Path

import msgpack


def convert_file(msgpack_file: Path, overwrite: bool) -> bool:
    json_file = msgpack_file.with_suffix(".json")
    if json_file.exists() and not overwrite:
        print(f"Skipping existing file: {json_file.name}")
        return False

    payload = msgpack_file.read_bytes()
    data = msgpack.unpackb(payload, raw=False, strict_map_key=False)

    with json_file.open("w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2, sort_keys=True)
        f.write("\n")

    print(f"Converted {msgpack_file.name} -> {json_file.name}")
    return True


def main():
    parser = argparse.ArgumentParser(
        description="Convert all .msgpack files under data/fsd to .json."
    )
    parser.add_argument(
        "--fsd-dir",
        type=Path,
        default=Path(__file__).resolve().parent / "fsd",
        help="Directory containing .msgpack files. Default: ./data/fsd",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Overwrite existing .json files.",
    )
    args = parser.parse_args()

    fsd_dir = args.fsd_dir.resolve()
    if not fsd_dir.exists() or not fsd_dir.is_dir():
        raise FileNotFoundError(f"FSD directory not found: {fsd_dir}")

    msgpack_files = sorted(fsd_dir.glob("*.msgpack"))
    if not msgpack_files:
        print(f"No .msgpack files found in: {fsd_dir}")
        return

    converted = 0
    for file in msgpack_files:
        converted += 1 if convert_file(file, args.overwrite) else 0

    print(f"Done: converted {converted}/{len(msgpack_files)} files.")


if __name__ == "__main__":
    main()
