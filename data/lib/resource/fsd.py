"""
FSD Manager Module

This module provides functionality to manage and access files stored in the FSD.
"""

from __future__ import annotations

from typing import TYPE_CHECKING

import aiofiles
import msgpack

from data.lib.log import debug
from data.lib.log import error


if TYPE_CHECKING:
    from pathlib import Path


class FsdManager:
    __fsd_root_dir: Path
    __cache: dict[str, dict]

    def __init__(self, fsd_root_dir: Path) -> None:
        self.__fsd_root_dir = fsd_root_dir
        self.__cache = {}
        if not self.__fsd_root_dir.exists():
            error(f"FSD root directory does not exist: {self.__fsd_root_dir}")
            exit(1)

        if not self.__fsd_root_dir.is_dir():
            error(f"FSD root path is not a directory: {self.__fsd_root_dir}")
            exit(1)

    async def get(self, fsd_key: str) -> dict:
        fsd_key = fsd_key.lower()
        if fsd_key in self.__cache:
            debug(f"FSD cache hit: {fsd_key}")
            return self.__cache[fsd_key]

        fsd_path = self.__fsd_root_dir / f"{fsd_key}.msgpack"
        if not fsd_path.exists():
            error(f"FSD file does not exist: {fsd_path}")
            exit(1)

        if not fsd_path.is_file():
            error(f"FSD path is not a file: {fsd_path}")
            exit(1)

        async with aiofiles.open(fsd_path, "rb") as f:
            debug(f"Loading FSD file: {fsd_path}")
            content = await f.read()
            data = msgpack.unpackb(content, strict_map_key=False)

        self.__cache[fsd_key] = data
        return data
