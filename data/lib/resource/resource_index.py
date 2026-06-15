"""
CSV Index Module

CCP's resource indexes are stored in CSV files.
This module provides functionality to read and parse these CSV files.

The resource index files include:
-   `resfileindex.txt`: Resource file index
-   `index_<server-name>.txt`: Application index for a specific server
-   `resfileindex_prefetch.txt`:
    Prefetch resource file index, mainly used in the launcher and the start-up screen.
-   `resfileindex_<platform>.txt`:
    Platform-specific resource file index, e.g., `resfileindex_Windows.txt` for windows.

The CSV files has no headers, and has the following columns:
-   Resource ID: a path starts with `xxx://`, like `res://UI/Texture/Logo.png`
-   File path: a relative path on the cloud storage, like `1a/1a2b3c4d5e6f7g8h9i0j`
-   File hash: a MD5 hash of the file, like `1a2b3c4d5e6f7g8h9i0j1a2b3c4d5e6`
-   Extra info, 2 columns, usually some integers, not used now.
"""

from __future__ import annotations

import asyncio
import contextlib

from dataclasses import dataclass
from typing import TYPE_CHECKING

import aiofiles
import tenacity

from tenacity import stop_after_attempt
from tenacity import wait_fixed

from data.lib.log import debug
from data.lib.log import info
from data.lib.log import warning


if TYPE_CHECKING:
    from collections.abc import Awaitable
    from collections.abc import Callable
    from pathlib import Path

    import aiohttp

    from _typeshed import OpenBinaryMode
    from _typeshed import OpenTextMode

DOWNLOAD_RETRY_ATTEMPTS = 3
DOWNLOAD_RETRY_WAIT_SECONDS = 2


def _log_download_retry(retry_state: tenacity.RetryCallState) -> None:
    node = retry_state.args[0] if retry_state.args else None
    resource_path = getattr(node, "full_path", "<unknown resource>")
    local_path = getattr(node, "local_path", None)
    outcome = retry_state.outcome
    error = outcome.exception() if outcome is not None and outcome.failed else None
    sleep = retry_state.next_action.sleep if retry_state.next_action is not None else None

    warning(
        "Retrying download for resource "
        f"{resource_path} -> {local_path} "
        f"(attempt {retry_state.attempt_number}/{DOWNLOAD_RETRY_ATTEMPTS}, "
        f"next retry in {sleep}s): {error}"
    )


_download_locks: dict[str, asyncio.Lock] = {}


def _get_download_lock(url: str) -> asyncio.Lock:
    lock = _download_locks.get(url)
    if lock is None:
        lock = asyncio.Lock()
        _download_locks[url] = lock
    return lock


@dataclass(kw_only=True)
class _ResourceNode:
    full_path: str
    name: str
    is_file: bool
    session_factory: Callable[[], Awaitable[aiohttp.ClientSession]]
    url: str | None = None
    local_path: Path | None = None
    children: dict[str, _ResourceNode] | None = None

    def recursive_construct(
        self, path_parts: list[str], full_path: str, url: str | None, base_path: Path
    ) -> _ResourceNode:
        if not path_parts:
            self.url = url
            self.local_path = base_path / self.full_path.replace(":", "")
            return self

        if self.is_file:
            raise ValueError(f"Cannot add child to a file node: {self.full_path}")

        if self.children is None:
            self.children = {}

        next_part = path_parts[0]
        if next_part not in self.children:
            is_file = len(path_parts) == 1
            child_full_path = f"{full_path}/{next_part}" if full_path else next_part
            self.children[next_part] = _ResourceNode(
                full_path=child_full_path,
                name=next_part,
                is_file=is_file,
                session_factory=self.session_factory,
            )

        next_node = self.children[next_part]
        return next_node.recursive_construct(path_parts[1:], next_node.full_path, url, base_path)

    def recursive_find(self, path_parts: list[str]) -> _ResourceNode | None:
        if not path_parts:
            return self

        if not self.children:
            return None

        next_part = path_parts[0]
        next_node = self.children.get(next_part)
        if not next_node:
            return None

        return next_node.recursive_find(path_parts[1:])

    @tenacity.retry(
        stop=stop_after_attempt(DOWNLOAD_RETRY_ATTEMPTS),
        wait=wait_fixed(DOWNLOAD_RETRY_WAIT_SECONDS),
        before_sleep=_log_download_retry,
    )
    async def download(self):
        if not self.is_file:
            raise ValueError(f"Cannot download a directory node: {self.full_path}")
        if not self.url:
            raise ValueError(f"Cannot download a node without URL: {self.full_path}")
        if not self.local_path:
            raise ValueError(f"Cannot download a node without local path: {self.full_path}")

        lock = _get_download_lock(self.url)
        async with lock:
            if self.local_path.exists():
                return

            debug(f"Downloading resource: {self.url} -> {self.local_path}")
            session = await self.session_factory()
            async with session.get(self.url) as response:
                response.raise_for_status()
                content = await response.read()
            if not self.local_path.parent.exists():
                self.local_path.parent.mkdir(parents=True, exist_ok=True)
            async with aiofiles.open(self.local_path, "wb") as f:
                await f.write(content)

    def download_blocking(self):
        asyncio.get_event_loop().run_until_complete(self.download())

    @contextlib.contextmanager
    def open_blocking(self, mode: OpenTextMode | OpenBinaryMode = "rb"):
        if self.local_path is None:
            raise ValueError(f"Cannot open a node without local path: {self.full_path}")

        if not self.local_path.exists():
            self.download_blocking()
        with open(self.local_path, mode) as f:
            yield f

    @contextlib.asynccontextmanager
    async def open(self, mode: OpenTextMode | OpenBinaryMode = "rb"):
        if self.local_path is None:
            raise ValueError(f"Cannot open a node without local path: {self.full_path}")

        if not self.local_path.exists():
            await self.download()
        async with aiofiles.open(self.local_path, mode) as f:
            yield f


class ResourceIndex:
    __cache_dir: Path
    __raw_download_url: str
    __resource_type: str
    __resource_tree: _ResourceNode
    __resource_prefix: str

    @staticmethod
    def normalize_key(key: str) -> str:
        return key.replace("\\", "/").lower()

    def __init__(
        self,
        index: Path,
        resource_type: str,
        resource_prefix: str,
        cache_dir: Path,
        raw_download_url: str,
        session_factory: Callable[[], Awaitable[aiohttp.ClientSession]],
    ):
        assert index.is_file()

        self.__cache_dir = cache_dir

        if not self.__cache_dir.exists():
            self.__cache_dir.mkdir(parents=True, exist_ok=True)

        self.__resource_type = resource_type
        self.__raw_download_url = raw_download_url.rstrip("/")

        self.__resource_prefix = resource_prefix
        self.__resource_tree = _ResourceNode(
            full_path=resource_prefix,
            name=resource_prefix,
            is_file=False,
            session_factory=session_factory,
        )

        info(f"Loading resource index from {index}")
        with open(index, "r", encoding="utf-8") as f:
            it = f.read().splitlines()
            for line in it:
                parts: list[str] = line.strip().split(",")
                if len(parts) < 3:
                    continue
                resource_id = self.normalize_key(parts[0])
                file_path = parts[1]

                path_parts = resource_id.split("/")
                self.__resource_tree.recursive_construct(
                    path_parts, "", self.__get_url(file_path), cache_dir
                )
            info(f"Resource index loaded {len(it)} entries.")

    def __get_url(self, file_path: str) -> str:
        return self.__raw_download_url.format(
            resource_type=self.__resource_type, resource_url=file_path
        )

    def get_resource(self, resource_id: str) -> _ResourceNode:
        return self.__resource_tree.recursive_find(self.normalize_key(resource_id).split("/"))
