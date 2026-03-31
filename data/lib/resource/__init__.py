from __future__ import annotations

import asyncio

from typing import TYPE_CHECKING

import aiohttp

from data.lib.resource.fsd import FsdManager
from data.lib.resource.patch import PatchesManager
from data.lib.resource.resource_index import ResourceIndex


if TYPE_CHECKING:
    from pathlib import Path


CONNECTION_LIMIT = 8


class ResourceManager:
    __app_index: ResourceIndex
    __resource_index: ResourceIndex
    __fsd: FsdManager
    __patches: PatchesManager
    __session: aiohttp.ClientSession | None
    __session_lock: asyncio.Lock

    def __init__(
        self,
        app_index: Path,
        res_index: Path,
        cache_root: Path,
        fsd_root: Path,
        patch_root: Path,
        raw_download_url: str,
    ):
        self.__session = None
        self.__session_lock = asyncio.Lock()
        self.__app_index = ResourceIndex(
            index=app_index,
            resource_type="binaries",
            resource_prefix="applications",
            cache_dir=cache_root,
            raw_download_url=raw_download_url,
            session_factory=self.__get_or_create_session,
        )
        self.__resource_index = ResourceIndex(
            index=res_index,
            resource_type="resources",
            resource_prefix="resources",
            cache_dir=cache_root,
            raw_download_url=raw_download_url,
            session_factory=self.__get_or_create_session,
        )
        self.__fsd = FsdManager(fsd_root_dir=fsd_root)
        self.__patches = PatchesManager(patches_root_dir=patch_root)

    async def __get_or_create_session(self) -> aiohttp.ClientSession:
        if self.__session is not None and not self.__session.closed:
            return self.__session

        async with self.__session_lock:
            if self.__session is not None and not self.__session.closed:
                return self.__session

            self.__session = aiohttp.ClientSession(
                connector=aiohttp.TCPConnector(limit=CONNECTION_LIMIT)
            )
            return self.__session

    async def aclose(self) -> None:
        if self.__session is None or self.__session.closed:
            return

        await self.__session.close()

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
