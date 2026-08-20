#!/usr/bin/env python3
"""Render assetlinks.json from the committed template.

Reads the release signing SHA-256 fingerprint from the APP_KEY_SHA256
environment variable and substitutes it into assetlinks.template.json. Exits
non-zero when the variable is missing, unless --allow-missing is given, in
which case a placeholder fingerprint is emitted (Android App Links
verification then fails and links degrade to the browser).
"""

from __future__ import annotations

import argparse
import os
import sys

from pathlib import Path


TEMPLATE_PATH = Path(__file__).resolve().parent / "assetlinks.template.json"
PLACEHOLDER = "@APP_KEY_SHA256@"
MISSING_FINGERPRINT = ":".join(["00"] * 32)


def render(template: str, fingerprint: str) -> str:
    if PLACEHOLDER not in template:
        raise ValueError(f"template does not contain the {PLACEHOLDER} marker")
    return template.replace(PLACEHOLDER, fingerprint)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path, help="Output path for assetlinks.json")
    parser.add_argument(
        "--allow-missing",
        action="store_true",
        help="Emit a placeholder fingerprint when APP_KEY_SHA256 is unset",
    )
    args = parser.parse_args()

    fingerprint = os.environ.get("APP_KEY_SHA256", "").strip()
    if not fingerprint and not args.allow_missing:
        print(
            "APP_KEY_SHA256 is not set; pass --allow-missing to emit a placeholder",
            file=sys.stderr,
        )
        return 1
    if not fingerprint:
        fingerprint = MISSING_FINGERPRINT

    output: Path = args.output
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        render(TEMPLATE_PATH.read_text(encoding="utf-8"), fingerprint), encoding="utf-8"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
