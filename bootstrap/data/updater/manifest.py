"""Fetch EVE client manifests and parse build numbers."""

from __future__ import annotations

from typing import TYPE_CHECKING

import aiohttp

from bootstrap.log import info


if TYPE_CHECKING:
    from bootstrap.data.updater.server import ServerConfig


async def fetch_build(server: ServerConfig) -> int:
    """Fetch the remote EVE client manifest and return the build number."""
    info(f"Fetching manifest from {server.manifest_url}")
    async with aiohttp.ClientSession() as session, session.get(server.manifest_url) as response:
        response.raise_for_status()
        data = await response.json()
    build = data.get("build")
    if build is None:
        raise ValueError(f"Manifest missing 'build' field: {server.manifest_url}")
    return int(str(build).strip())
