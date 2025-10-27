from __future__ import annotations

from typing import TYPE_CHECKING

from data.lib.log import info

from . import graphics
from . import icons


if TYPE_CHECKING:
    from data.lib.workspace.generate import GeneratorDatasource


async def generate(data: GeneratorDatasource, collection_cache):
    info("Generating images...")

    tree_shake_icons = set()
    tree_shake_graphics = set()

    def parse_from_icon(icon):
        nonlocal tree_shake_icons, tree_shake_graphics
        if icon.graphic_id:
            tree_shake_graphics.add(icon.graphic_id)
        if icon.icon_id:
            tree_shake_icons.add(icon.icon_id)

    for type_pb in collection_cache.types.values():
        parse_from_icon(type_pb.icon)
    for category_pb in collection_cache.categories.values():
        parse_from_icon(category_pb.icon)
    for group_pb in collection_cache.groups.values():
        parse_from_icon(group_pb.icon)
    for market_group_pb in collection_cache.market_groups.values():
        parse_from_icon(market_group_pb.icon)
    for meta_group_pb in collection_cache.meta_groups.values():
        parse_from_icon(meta_group_pb.icon)
    for dogma_attribute_pb in collection_cache.dogma_attributes.values():
        parse_from_icon(dogma_attribute_pb.icon)

    await icons.generate(data, tree_shake_icons)
    await graphics.generate(data, tree_shake_graphics)

    info("Image generation complete.")
