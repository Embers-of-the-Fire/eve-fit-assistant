from __future__ import annotations

import asyncio

from typing import TYPE_CHECKING

import aiofiles

from pydantic import BaseModel
from pydantic import Field

from data.lib.log import debug
from data.lib.log import info
from data.lib.log import warning
from data.lib.utils import try_get_attr
from data.lib.workspace.generate.paths import GraphicVariantType


if TYPE_CHECKING:
    from data.lib.workspace.generate import GeneratorDatasource


class GraphicIconInfo(BaseModel):
    folder: str | None = Field(default=None)


class GraphicDef(BaseModel):
    iconInfo: GraphicIconInfo | None = Field(default=None)


async def generate(data: GeneratorDatasource, tree_shake_graphics: set[int]):
    info("Generating graphics...")

    graphics = await data.resources.fsd.get("graphicIDs")

    info(f"Tree shaken {len(set(graphics.keys()).difference(tree_shake_graphics))} graphics.")

    filtered_graphics = list(
        filter(
            lambda t: t[1] is not None,
            (
                (
                    graphic_id,
                    try_get_attr(GraphicDef.model_validate(graphic_def).iconInfo, "folder")
                    if isinstance(graphic_def, dict)
                    else None,
                )
                for graphic_id, graphic_def in graphics.items()
                if graphic_id in tree_shake_graphics
            ),
        )
    )

    tasks = (
        __download_graphic(graphic_id, graphic_folder, data)
        for graphic_id, graphic_folder in filtered_graphics
    )
    await asyncio.gather(*tasks)

    info(f"Generated {len(filtered_graphics)} graphics.")


async def __download_graphic(graphic_id: int, graphic_folder: str, data: GeneratorDatasource):
    maybe_graphic_files = [
        (f"{graphic_folder}/{graphic_id}_64.png", GraphicVariantType.NONE),
        (f"{graphic_folder}/{graphic_id}_64_bp.png", GraphicVariantType.BP),
        (f"{graphic_folder}/{graphic_id}_64_bpc.png", GraphicVariantType.BPC),
    ]

    found = False
    for graphic_file_path, ty in maybe_graphic_files:
        graphic_file = data.resources.res.get_resource(graphic_file_path)
        if graphic_file is not None:
            found = True
        else:
            continue

        target_dir = data.paths.get_graphic_path(graphic_id, variant=ty)
        if target_dir.exists():
            debug(f"Graphic at {target_dir} already exists, skipping.")
            continue

        async with (
            graphic_file.open() as f_input,
            aiofiles.open(target_dir, "wb+") as f_output,
        ):
            content = await f_input.read()
            await f_output.write(content)

        debug(f"Generated graphic at {target_dir}.")

    if not found:
        warning(f"No graphic files found for graphic ID {graphic_id} in folder {graphic_folder}.")
