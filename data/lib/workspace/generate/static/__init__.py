from __future__ import annotations

import asyncio

from typing import TYPE_CHECKING

import aiofiles

from data.lib.log import info
from data.lib.schema import collections_pb2

from . import categories
from . import dogma_attributes
from . import dogma_units
from . import groups
from . import market_groups
from . import meta_groups
from . import type_materials
from . import types


if TYPE_CHECKING:
    from data.lib.workspace.generate import GeneratorDatasource


async def generate(data: GeneratorDatasource) -> collections_pb2.Collection:
    info("Start generating static data...")
    collection = collections_pb2.Collection()

    tasks = (
        module.generate(data, collection)
        for module in [
            types,
            categories,
            groups,
            market_groups,
            meta_groups,
            type_materials,
            dogma_units,
            dogma_attributes,
        ]
    )
    await asyncio.gather(*tasks)

    info("Finished generating static data, writing to disk.")

    target = data.paths.static_collection_path

    async with aiofiles.open(target, "wb") as f:
        await f.write(collection.SerializeToString())

    return collection
