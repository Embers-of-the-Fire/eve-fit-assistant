from __future__ import annotations

import datetime

from configparser import ConfigParser
from typing import TYPE_CHECKING

import yaml

from pydantic import BaseModel

from data.lib.config import CONFIGURATION
from data.lib.constant import PROJECT_ROOT
from data.lib.log import info


if TYPE_CHECKING:
    from data.lib.workspace.generate import GeneratorDatasource


class Descriptor(BaseModel):
    generateTimestamp: int

    isIncremental: bool
    manifestHash: str | None = None
    baseBundleId: str | None = None
    baseManifestHash: str | None = None

    bundleId: str
    appVersion: str

    bundleSchemaVersion: int
    compatibleBundleSchemaVersions: list[int]

    gameVersion: str
    gameBuild: str
    gameRegion: str
    gameBranch: str
    gameServer: str

    @staticmethod
    def create(
        datasource: GeneratorDatasource,
        *,
        base_bundle_id: str | None = None,
        base_manifest_hash: str | None = None,
    ) -> Descriptor:
        info("Generating descriptor...")
        start_config = ConfigParser()
        start_config.read(datasource.config.metadata.start_cfg)

        timestamp = datetime.datetime.now().timestamp()
        app_path = PROJECT_ROOT / "pubspec.yaml"
        with open(app_path, "r", encoding="utf-8") as f:
            pubspec = yaml.load(f, yaml.CLoader)
        app_version = pubspec["version"]

        descriptor = Descriptor(
            generateTimestamp=int(timestamp),
            isIncremental=datasource.is_incremental,
            baseBundleId=base_bundle_id,
            baseManifestHash=base_manifest_hash,
            appVersion=app_version,
            bundleId=datasource.config.metadata.identifier,
            bundleSchemaVersion=CONFIGURATION.bundle_schema.current,
            compatibleBundleSchemaVersions=CONFIGURATION.bundle_schema.supported,
            gameVersion=start_config.get("main", "version"),
            gameBuild=start_config.get("main", "build"),
            gameRegion=start_config.get("main", "region"),
            gameBranch=start_config.get("main", "branch"),
            gameServer=start_config.get("main", "server"),
        )

        return descriptor
