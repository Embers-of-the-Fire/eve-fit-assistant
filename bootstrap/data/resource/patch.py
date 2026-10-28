"""
Patches Manager Module

This module contains support for patches management.
"""

from __future__ import annotations

import json
import sys

from typing import TYPE_CHECKING
from typing import Any
from typing import Literal

import yaml

from bootstrap.log import error


if TYPE_CHECKING:
    from pathlib import Path


class PatchesManager:
    __patches_root_dir: Path
    __cache: dict[str, Any]

    def __init__(self, patches_root_dir: Path) -> None:
        self.__patches_root_dir = patches_root_dir
        self.__cache = {}
        if not self.__patches_root_dir.exists():
            error(f"Patches root directory does not exist: {self.__patches_root_dir}")
            sys.exit(1)

        if not self.__patches_root_dir.is_dir():
            error(f"Patches root path is not a directory: {self.__patches_root_dir}")
            sys.exit(1)

    def get(self, patch_key: str, variant: Literal["yaml", "json"] = "yaml") -> Any:
        """Get patch data by patch key.

        The key must be the full file name without extension, and the variant will be the file extension.

        For example, `get("aaa", "json")` will load `aaa.json` file.
        """
        data = self.get_optional(patch_key, variant)
        if data is None:
            patch_path = self.__patches_root_dir / f"{patch_key.lower()}.{variant}"
            error(f"Patch file does not exist: {patch_path}")
            sys.exit(1)
        return data

    def get_optional(self, patch_key: str, variant: Literal["yaml", "json"] = "yaml") -> Any:
        """Get patch data by patch key, or `None` when the patch file does not exist.

        Same key/variant semantics as `get`; intended for optional patches
        (e.g. curated localization overrides) that a workspace may omit.
        """
        patch_key = patch_key.lower()
        if patch_key in self.__cache:
            return self.__cache[patch_key]

        patch_path = self.__patches_root_dir / f"{patch_key}.{variant}"
        if not patch_path.exists():
            return None

        if not patch_path.is_file():
            error(f"Patch path is not a file: {patch_path}")
            sys.exit(1)

        with open(patch_path, "r", encoding="utf-8") as f:
            if variant == "yaml":
                data = yaml.safe_load(f)
            elif variant == "json":
                data = json.load(f)
            else:
                error(f"Unsupported patch variant: {variant}")
                sys.exit(1)

        # An empty patch file parses to None; treat it as an empty mapping so
        # `get` only errors for genuinely missing files.
        if data is None:
            data = {}

        self.__cache[patch_key] = data
        return data
