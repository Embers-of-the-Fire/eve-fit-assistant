from __future__ import annotations

from os import PathLike
import csv
import os
import pathlib

import yaml
import requests


class ConvertCache:
    fsd: FsdCache
    resfileindex: ResfileIndexCache

    def __init__(
        self,
        fsd_base_dir: PathLike,
        resfile_index_file: str,
        resfile_cache_dir: PathLike,
    ):
        self.fsd = FsdCache(fsd_base_dir)
        self.resfileindex = ResfileIndexCache(resfile_cache_dir, resfile_index_file)

    def get(self, key: str) -> dict:
        return self.fsd.get(key)

    def download_cached(self, key: str) -> str:
        return self.resfileindex.download_cached(key)


class FsdCache:
    base_dir: PathLike
    cache: dict[str, dict]

    def __init__(self, base_dir: PathLike):
        self.base_dir = base_dir
        self.cache = {}

    def get(self, key: str) -> dict:
        if key in self.cache:
            return self.cache[key]

        with open(f"{self.base_dir}/{key}.yaml", "r", encoding="utf-8") as f:
            self.cache[key] = yaml.load(f, yaml.CSafeLoader)

        return self.cache[key]


class ResfileIndexCache:
    resfileindex: dict[str, str]
    cache_dir: PathLike
    cached: list[str]

    def __init__(self, cache_dir: PathLike, resfile_index_file: str):
        self.cache_dir = cache_dir
        os.makedirs(cache_dir, exist_ok=True)
        self.resfileindex = ResfileIndexCache._read_resfile_index(resfile_index_file)
        self.cached = []

    def download_cached(self, key: str) -> str:
        key_dir = f"{self.cache_dir}/{key.removeprefix('res:/')}"
        key_dir_path = pathlib.Path(key_dir)
        key_dir_path.parent.mkdir(parents=True, exist_ok=True)
        if key in self.cached:
            return key_dir
        url = self.resfileindex[key]
        req = requests.get(f"https://resources.eveonline.com/{url}")
        with open(key_dir, "wb") as f:
            f.write(req.content)
        return key_dir

    @staticmethod
    def _read_resfile_index(resfile_index_file) -> dict[str, str]:
        index = {}
        with open(resfile_index_file, "r", encoding="utf-8") as f:
            reader = csv.reader(f)
            for row in reader:
                index[row[0]] = row[1]
        return index
