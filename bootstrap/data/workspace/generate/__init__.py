from __future__ import annotations

from typing import TYPE_CHECKING

import aiofiles

from bootstrap.config import DEV_CONFIGURATION
from bootstrap.data.schema import collections_pb2
from bootstrap.log import info

from . import agent
from . import images
from . import localizations
from . import native
from . import schema as schema_generator
from . import static
from .data import GeneratorDatasource


if TYPE_CHECKING:
    from pathlib import Path

    from bootstrap.data.workspace.config import WorkspaceConfig


async def run_generator(
    config: WorkspaceConfig,
    skip: set[str],
    author: str | None = None,
    description: str | None = None,
    schema_root: Path | None = None,
) -> str | None:
    info("Running data generator...")
    datasource = GeneratorDatasource(config)
    try:
        collection_cache: collections_pb2.Collection | None = None
        if "static" not in skip:
            collection_cache = await static.generate(datasource)

        if "native" not in skip:
            await native.generate(datasource)
        if "localization" not in skip:
            await localizations.generate(datasource)
        if "agent" not in skip:
            await agent.generate(datasource)
        if "images" not in skip:
            if collection_cache is None:
                info("Collection cache not provided, loading from disk...")
                async with aiofiles.open(datasource.paths.static_collection_path, "rb") as f:
                    content = await f.read()
                    collection_cache = collections_pb2.Collection()
                    collection_cache.ParseFromString(content)

            await images.generate(datasource, collection_cache)

        snapshot_hash = schema_generator.generate_schema_checkout(
            config,
            build_dir=datasource.paths.full_generate_out_path,
            schema_root=schema_root or DEV_CONFIGURATION.paths.schema_dir,
            author=author,
            description=description,
        )

        info("Data generator finished.")
    finally:
        await datasource.aclose()
    return snapshot_hash
