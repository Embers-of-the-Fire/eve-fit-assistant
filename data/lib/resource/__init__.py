from __future__ import annotations

from typing import TYPE_CHECKING

from data.lib.resource.fsd import FsdManager
from data.lib.resource.patch import PatchesManager
from data.lib.resource.resource_index import ResourceIndex


if TYPE_CHECKING:
    from pathlib import Path


class ResourceManager:
    __app_index: ResourceIndex
    __resource_index: ResourceIndex
    __fsd: FsdManager
    __patches: PatchesManager

    def __init__(
        self,
        app_index: Path,
        res_index: Path,
        cache_root: Path,
        fsd_root: Path,
        patch_root: Path,
        raw_download_url: str,
    ):
        self.__app_index = ResourceIndex(
            index=app_index,
            resource_type="binaries",
            resource_prefix="applications",
            cache_dir=cache_root,
            raw_download_url=raw_download_url,
        )
        self.__resource_index = ResourceIndex(
            index=res_index,
            resource_type="resources",
            resource_prefix="resources",
            cache_dir=cache_root,
            raw_download_url=raw_download_url,
        )
        self.__fsd = FsdManager(fsd_root_dir=fsd_root)
        self.__patches = PatchesManager(patches_root_dir=patch_root)

    @property
    def app(self) -> ResourceIndex:
        return self.__app_index

    @property
    def res(self) -> ResourceIndex:
        return self.__resource_index

    @property
    def fsd(self) -> FsdManager:
        return self.__fsd

    @property
    def patches(self) -> PatchesManager:
        return self.__patches
