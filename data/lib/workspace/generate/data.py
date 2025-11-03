from __future__ import annotations

from typing import TYPE_CHECKING

from data.lib.resource import ResourceManager
from data.lib.workspace.generate.paths import PathManager


if TYPE_CHECKING:
    from data.lib.workspace.config import WorkspaceConfig


class GeneratorDatasource:
    __resource_manager: ResourceManager
    __path_manager: PathManager
    __workspace_config: WorkspaceConfig
    __is_incremental: bool

    def __init__(self, config: WorkspaceConfig, is_incremental: bool):
        self.__workspace_config = config
        self.__resource_manager = ResourceManager(
            app_index=self.__workspace_config.resources.application_index,
            res_index=self.__workspace_config.resources.resource_index,
            cache_root=self.__workspace_config.paths.cache,
            fsd_root=self.__workspace_config.resources.fsd,
            patch_root=self.__workspace_config.resources.patches,
            raw_download_url=config.services.resource_url,
        )
        self.__path_manager = PathManager(
            full_generate_out_path=self.__workspace_config.paths.generated,
            base_output_path=self.__workspace_config.paths.output,
        )
        self.__is_incremental = is_incremental

    @property
    def resources(self) -> ResourceManager:
        return self.__resource_manager

    @property
    def paths(self) -> PathManager:
        return self.__path_manager

    @property
    def config(self) -> WorkspaceConfig:
        return self.__workspace_config

    @property
    def is_incremental(self) -> bool:
        return self.__is_incremental
