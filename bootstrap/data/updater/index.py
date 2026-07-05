"""Download and parse EVE application indexes and metadata files."""

from __future__ import annotations

from typing import TYPE_CHECKING

import aiofiles
import aiohttp

from bootstrap.log import info


if TYPE_CHECKING:
    from pathlib import Path

    from bootstrap.data.updater.server import ServerConfig


_METADATA_PATHS = {
    "app:/resfileindex.txt",
    "app:/resfileindex_Windows.txt",
    "app:/resfileindex_prefetch.txt",
    "app:/resfiledependencies.yaml",
    "app:/start.ini",
}


async def _download_file(session: aiohttp.ClientSession, url: str, dest: Path) -> None:
    """Download a single file to ``dest``."""
    info(f"Downloading {url} -> {dest}")
    async with session.get(url) as response:
        response.raise_for_status()
        content = await response.read()
    dest.parent.mkdir(parents=True, exist_ok=True)
    async with aiofiles.open(dest, "wb") as f:
        await f.write(content)


async def download_index(build: int, server: ServerConfig, out_dir: Path) -> Path:
    """Download the application index for ``build`` to ``out_dir``."""
    url = server.index_url_template.format(build=build)
    dest = out_dir / server.index_file_name
    async with aiohttp.ClientSession() as session:
        await _download_file(session, url, dest)
    return dest


def _parse_index_file(index_file: Path) -> dict[str, str]:
    """Parse an EVE application index CSV into a ``path -> url`` mapping."""
    entries: dict[str, str] = {}
    with open(index_file, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            parts = line.split(",")
            if len(parts) < 2:
                continue
            resource_id = parts[0]
            resource_url = parts[1]
            entries[resource_id] = resource_url
    return entries


async def download_metadata(index_file: Path, server: ServerConfig, out_dir: Path) -> None:
    """Download metadata files referenced by the application index."""
    entries = _parse_index_file(index_file)
    async with aiohttp.ClientSession() as session:
        for resource_id in _METADATA_PATHS:
            resource_url = entries.get(resource_id)
            if resource_url is None:
                raise FileNotFoundError(f"Metadata entry {resource_id!r} not found in {index_file}")
            url = server.binary_download_url.format(resource_url=resource_url)
            file_name = resource_id.replace("app:/", "")
            await _download_file(session, url, out_dir / file_name)

    resfileindex_url = entries.get("app:/resfileindex.txt")
    if resfileindex_url is None:
        raise FileNotFoundError(f"Metadata entry 'app:/resfileindex.txt' not found in {index_file}")


async def download_resource_index(
    index_file: Path,
    server: ServerConfig,
    out_dir: Path,
) -> Path:
    """Download ``resfileindex.txt`` referenced by the application index."""
    entries = _parse_index_file(index_file)
    resource_url = entries.get("app:/resfileindex.txt")
    if resource_url is None:
        raise FileNotFoundError(f"Metadata entry 'app:/resfileindex.txt' not found in {index_file}")
    url = server.binary_download_url.format(resource_url=resource_url)
    dest = out_dir / "resfileindex.txt"
    async with aiohttp.ClientSession() as session:
        await _download_file(session, url, dest)
    return dest
