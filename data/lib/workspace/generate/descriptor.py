from __future__ import annotations

import datetime

from configparser import ConfigParser
from typing import TYPE_CHECKING

import yaml

from pydantic import BaseModel

from data.lib.constant import PROJECT_ROOT
from data.lib.log import info


if TYPE_CHECKING:
    from data.lib.workspace.generate import GeneratorDatasource


class Descriptor(BaseModel):
    generateTimestamp: int
    bundleId: str
    appVersion: str

    gameVersion: str
    gameBuild: str
    gameRegion: str
    gameBranch: str
    gameServer: str

    @staticmethod
    def create(
        datasource: GeneratorDatasource,
    ):
        info("Generating descriptor...")
        start_config = ConfigParser()
        start_config.read(datasource.config.metadata.start_cfg)

        timestamp = datetime.datetime.now().timestamp()
        app_path = PROJECT_ROOT / "pubspec.yaml"
        with open(app_path, "r", encoding="utf-8") as f:
            data = yaml.load(f, yaml.CLoader)
        app_version = data["version"]

        descriptor = Descriptor(
            generateTimestamp=int(timestamp),
            appVersion=app_version,
            bundleId=datasource.config.metadata.identifier,
            gameVersion=start_config.get("main", "version"),
            gameBuild=start_config.get("main", "build"),
            gameRegion=start_config.get("main", "region"),
            gameBranch=start_config.get("main", "branch"),
            gameServer=start_config.get("main", "server"),
        )

        with open(datasource.paths.descriptor_path, "w", encoding="utf-8") as f:
            f.write(descriptor.model_dump_json(indent=4))

        info(f"Generated descriptor at {datasource.paths.descriptor_path}.")
