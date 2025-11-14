"""
Patches Manager Module

This module contains support for patches management.
"""

from __future__ import annotations

import json

from typing import TYPE_CHECKING
from typing import Any
from typing import Literal

import yaml

from data.lib.log import error


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
            exit(1)

        if not self.__patches_root_dir.is_dir():
            error(f"Patches root path is not a directory: {self.__patches_root_dir}")
            exit(1)

    def get(self, patch_key: str, variant: Literal["yaml", "json"] = "yaml") -> Any:
        """Get patch data by patch key.

        The key must be the full file name without extension, and the variant will be the file extension.

        For example, `get("aaa", "json")` will load `aaa.json` file.
        """
        patch_key = patch_key.lower()
        if patch_key in self.__cache:
            return self.__cache[patch_key]

        patch_path = self.__patches_root_dir / f"{patch_key}.{variant}"
        if not patch_path.exists():
            error(f"Patch file does not exist: {patch_path}")
            exit(1)

        if not patch_path.is_file():
            error(f"Patch path is not a file: {patch_path}")
            exit(1)

        with open(patch_path, "r", encoding="utf-8") as f:
            if variant == "yaml":
                data = yaml.safe_load(f)
            elif variant == "json":
                data = json.load(f)
            else:
                error(f"Unsupported patch variant: {variant}")
                exit(1)

        self.__cache[patch_key] = data
        return data
