from __future__ import annotations

import asyncio

from typing import TYPE_CHECKING

import aiofiles

from pydantic import BaseModel

from data.lib.log import debug
from data.lib.log import info
from data.lib.log import warning


if TYPE_CHECKING:
    from data.lib.workspace.generate import GeneratorDatasource


class IconDef(BaseModel):
    iconFile: str


async def generate(data: GeneratorDatasource, tree_shake_icons: set[int]):
    info("Generating icons...")

    icons = await data.resources.fsd.get("iconIDs")

    info(f"Tree shaken {len(set(icons.keys()).difference(tree_shake_icons))} icons.")

    tasks = (
        __download_icon(icon_id, IconDef.model_validate(icon), data)
        for icon_id, icon in icons.items()
        if icon_id in tree_shake_icons
    )
    await asyncio.gather(*tasks)

    info(f"Generated {len(icons)} icons.")


async def __download_icon(icon_id: int, icon: IconDef, data: GeneratorDatasource):
    icon_file = data.resources.res.get_resource(icon.iconFile)
    if icon_file is None:
        warning(f"Icon file {icon.iconFile} for icon ID {icon_id} not found.")
        return

    out_path = data.paths.get_icon_path(icon_id)
    if out_path.exists():
        debug(f"Icon {out_path} already exists, skipping.")
        return

    async with icon_file.open("rb") as f_input, aiofiles.open(out_path, "wb") as f_output:
        await f_output.write(await f_input.read())

    debug(f"Generated icon at {out_path}.")
