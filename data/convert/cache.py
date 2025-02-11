from os import PathLike

import yaml


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
