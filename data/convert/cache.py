from __future__ import annotations

import json
from logging import warning
from os import PathLike
import csv
import os
import pathlib
import pickle
from typing import Any, Literal

import yaml
import requests


class ConvertCache:
    fsd: FsdCache
    loc: LocCache
    resfileindex: ResfileIndexCache
    patches: PatchesCache

    def __init__(
        self,
        fsd_base_dir: PathLike,
        resfile_index_file: str,
        resfile_cache_dir: PathLike,
        patch_dir: PathLike,
    ):
        self.fsd = FsdCache(fsd_base_dir)
        self.resfileindex = ResfileIndexCache(resfile_cache_dir, resfile_index_file)
        self.loc = LocCache(self.resfileindex)
        self.patches = PatchesCache(patch_dir)

    def get(self, key: str, no_int_key = False) -> dict:
        return self.fsd.get((key, no_int_key))

    def download_cached(self, key: str) -> str:
        return self.resfileindex.download_cached(key)

    def get_patch(self, key: str, style: Literal["yaml", "json"]) -> Any:
        return self.patches.read_cached(key, style)


class FsdCache:
    base_dir: PathLike
    cache: dict[tuple[str, bool], dict]

    def __init__(self, base_dir: PathLike):
        self.base_dir = base_dir
        self.cache = {}

    def get(self, key: str, no_int_key = False) -> dict:
        key = key.lower()
        
        if (key, no_int_key) in self.cache:
            return self.cache[(key, no_int_key)]

        with open(f"{self.base_dir}/{key}.json", "r", encoding="utf-8") as f:
            self.cache[(key, no_int_key)] = {int(k): v for k, v in json.load(f).items()}

        return self.cache[(key, no_int_key)]


class ResfileIndexCache:
    resfileindex: dict[str, str]
    cache_dir: PathLike
    cached: list[str]

    def __init__(self, cache_dir: PathLike, resfile_index_file: str):
        self.cache_dir = cache_dir
        os.makedirs(cache_dir, exist_ok=True)
        self.resfileindex = ResfileIndexCache._read_resfile_index(resfile_index_file)
        self.cached = []

    def download_cached(self, key: str):
        key_dir = f"{self.cache_dir}/{key.removeprefix('res:/')}"
        key_dir_path = pathlib.Path(key_dir)
        key_dir_path.parent.mkdir(parents=True, exist_ok=True)
        if key in self.cached:
            return key_dir
        if key_dir_path.exists():
            return key_dir
        url = self.resfileindex[key]
        try:
            if os.environ["SERVER"] == "tq":
                url = f"https://resources.eveonline.com/{url}"
            elif os.environ["SERVER"] == "se":
                url = f"https://ma79.gdl.netease.com/eve/resources/{url}"
            req = requests.get(url)
            with open(key_dir, "wb") as f:
                f.write(req.content)
            return key_dir
        except requests.exceptions.RequestException as e:
            warning(f"Unable to download file: {e}")
            try:
                with open(key_dir, "rb") as f:
                    return f.read()
            except FileNotFoundError as e2:
                raise ExceptionGroup("Failed to download resfile", [e, e2])

    @staticmethod
    def _read_resfile_index(resfile_index_file) -> dict[str, str]:
        index = {}
        with open(resfile_index_file, "r", encoding="utf-8") as f:
            reader = csv.reader(f)
            for row in reader:
                index[row[0]] = row[1]
        return index
    
    
class LocCache:
    cache: dict[Literal['zh', 'en'], dict[int, str]]
    _res: ResfileIndexCache
    
    def __init__(self, resfile_index: ResfileIndexCache):
        self.cache = {}
        self._res = resfile_index
        
        zh = self._res.download_cached("res:/localizationfsd/localization_fsd_zh.pickle")
        self.cache['zh'] = {k: v[0] for k, v in pickle.loads(zh)[0].items()}
        en = self._res.download_cached("res:/localizationfsd/localization_fsd_en-us.pickle")
        self.cache['en'] = {k: v[0] for k, v in pickle.loads(en)[0].items()}
    
    def get(self, key: str, lang: Literal['zh', 'en']) -> str:
        key = key.lower()
        if lang not in self.cache:
            raise ValueError(f"Unsupported language: {lang}")
        if key in self.cache[lang]:
            return self.cache[lang][key]
        else:
            return key
    
    def get_all(self, key: str) -> dict[Literal['zh', 'en'], str]:
        return {lang: self.get(key, lang) for lang in self.cache.keys()}


class PatchesCache:
    patch_dir: PathLike
    cached: dict[str, Any]

    def __init__(self, patch_dir: PathLike):
        self.patch_dir = patch_dir
        self.cached = {}

    def read_cached(self, key: str, style: Literal["yaml", "json"]):
        if key in self.cached.keys():
            return self.cached[key]
        match style:
            case "yaml":
                with open(f"{self.patch_dir}/{key}.yaml", "r", encoding="utf-8") as f:
                    out = yaml.load(f, yaml.CSafeLoader)
                    self.cached[key] = out
                    return out
            case "json":
                with open(f"{self.patch_dir}/{key}.json", "r", encoding="utf-8") as f:
                    out = json.load(f)
                    self.cached[key] = out
                    return out
