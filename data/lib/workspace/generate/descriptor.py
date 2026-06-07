from __future__ import annotations

import datetime

from configparser import ConfigParser
from typing import TYPE_CHECKING

from pydantic import BaseModel

from data.lib.config import CONFIGURATION
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

    name: dict[str, str]

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
        app_version = CONFIGURATION.version.render_full()

        descriptor = Descriptor(
            generateTimestamp=int(timestamp),
            isIncremental=datasource.is_incremental,
            baseBundleId=base_bundle_id,
            baseManifestHash=base_manifest_hash,
            appVersion=app_version,
            name=datasource.config.metadata.name,
            bundleId=datasource.config.metadata.identifier,
            bundleSchemaVersion=CONFIGURATION.bundle_schema.current,
            compatibleBundleSchemaVersions=list(
                range(
                    CONFIGURATION.bundle_schema.min,
                    CONFIGURATION.bundle_schema.current + 1,
                )
            ),
            gameVersion=start_config.get("main", "version"),
            gameBuild=start_config.get("main", "build"),
            gameRegion=start_config.get("main", "region"),
            gameBranch=start_config.get("main", "branch"),
            gameServer=start_config.get("main", "server"),
        )

        return descriptor
