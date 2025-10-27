from __future__ import annotations

import shutil

from typing import TYPE_CHECKING

import aiofiles

from data.lib.log import info, warning
from data.lib.schema import collections_pb2
from data.lib.utils import get_bin_size

from . import images
from . import localizations
from . import native
from . import static
from .data import GeneratorDatasource
from .descriptor import Descriptor
from .hash_list import generate_hash_list


if TYPE_CHECKING:
    from data.lib.workspace.config import WorkspaceConfig


async def run_generator(config: WorkspaceConfig, skip: set[str], gen_hash: bool):
    info("Running data generator...")
    datasource = GeneratorDatasource(config, is_incremental=False)

    desc = Descriptor.create(datasource)

    with open(datasource.paths.descriptor_path, "w", encoding="utf-8") as f:
        f.write(desc.model_dump_json(indent=4))

    info(f"Generated descriptor at {datasource.paths.descriptor_path}.")

    collection_cache: collections_pb2.Collection | None = None
    if "static" not in skip:
        collection_cache = await static.generate(datasource)

    if "native" not in skip:
        await native.generate(datasource)
    if "localization" not in skip:
        await localizations.generate(datasource)
    if "images" not in skip:
        if collection_cache is None:
            info("Collection cache not provided, loading from disk...")
            async with aiofiles.open(datasource.paths.static_collection_path, "rb") as f:
                content = await f.read()
                collection_cache = collections_pb2.Collection()
                collection_cache.ParseFromString(content)

        await images.generate(datasource, collection_cache)

    info("Data generator finished.")

    if gen_hash:
        generate_hash_list(datasource, desc)
    else:
        warning("Skip generating hash.")

    shutil.make_archive(
        str(config.paths.output / config.metadata.identifier),
        format="zip",
        root_dir=datasource.paths.full_generate_out_path,
    )

    out_path = config.paths.output / f"{config.metadata.identifier}.zip"

    info(f"Generated data archive of {get_bin_size(out_path.stat().st_size)} at {out_path}.")
