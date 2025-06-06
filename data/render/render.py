import asyncio
from io import BytesIO
import json
import os
import sys
from PIL import Image
import shutil
import pathlib

import aiohttp
import csv


OVERLAY_DIR = pathlib.Path(__file__).parent / "overlay"


def read_resfile_index(resfile_index_file) -> dict[str, str]:
    index = {}
    with open(resfile_index_file, "r", encoding="utf-8") as f:
        reader = csv.reader(f)
        for row in reader:
            index[row[0]] = row[1]
    return index


def run(
    fsd_path: pathlib.Path,
    image_path: pathlib.Path,
    cache_dir: pathlib.Path,
    resfile_index_file: pathlib.Path,
):
    print("Rendering type icons...")

    target_dir = pathlib.Path(cache_dir) / "icons" / "type"

    if not target_dir.exists():
        target_dir.mkdir(parents=True)

    with open(fsd_path / "types.json", "r", encoding="utf-8") as f:
        types = json.load(f)
    with open(fsd_path / "graphicids.json", "r", encoding="utf-8") as f:
        graphics = json.load(f)
    with open(fsd_path / "iconids.json", "r", encoding="utf-8") as f:
        icons = json.load(f)
    index = read_resfile_index(resfile_index_file)

    need_render_graphic = []
    need_download = []
    need_render_icon = []
    print("Started copying type icons...")
    for type_id, type_item in types.items():
        type_id = int(type_id)
        if type_item.get("marketGroupID") is None and type_item.get("metaGroupID") != 15:
            continue
        if type_item["published"] is False:
            continue

        if "iconID" in type_item.keys():
            path: str = icons[str(type_item["iconID"])]["iconFile"]
            need_render_icon.append((type_id, index[path.lower()]))
        elif "graphicID" in type_item.keys():
            need_render_graphic.append(type_id)
        elif (image_path / "Types" / f"{type_id}_32.png").exists():
            shutil.copyfile(
                image_path / "Types" / f"{type_id}_32.png", target_dir / f"{type_id}.png"
            )
        else:
            need_download.append(type_id)
    print("Finished copying type icons.")

    print(f"Need to render {len(need_render_graphic)} type icons by graphic.")

    print("Start downloading type icons...")
    asyncio.run(download(need_download, target_dir))
    print("Finished downloading type icons.")

    print("Start rendering type icons by graphic...")
    asyncio.run(render_graphic(need_render_graphic, types, graphics, index, target_dir))
    print("Start rendering type icons by icon...")
    asyncio.run(render_icon(need_render_icon, types, target_dir))
    print("Finished rendering type icons.")


async def render_graphic(
    need_render: list[int],
    types: dict,
    graphics: dict,
    index: dict,
    target_dir: pathlib.Path,
):
    MAX_CONNECTIONS = 10
    semaphore = asyncio.Semaphore(MAX_CONNECTIONS)

    async def download(session: aiohttp.ClientSession, type_id):
        nonlocal types, graphics, index, semaphore
        async with semaphore:
            graphic_id = types[str(type_id)].get("graphicID")
            if graphic_id is None:
                print(f"Unknown graphic ID for {type_id=}")
                return
            try:
                graphic_index = (
                    graphics[str(graphic_id)]["iconInfo"]["folder"].removesuffix("/")
                    + f"/{graphic_id}_128.png"
                ).lower()
                graphic_url = index[graphic_index]
            except KeyError:
                return
            if os.environ["SERVER"] == "tq":
                url = f"https://resources.eveonline.com/{graphic_url}"
            elif os.environ["SERVER"] == "se":
                url = f"https://ma79.gdl.netease.com/eve/resources/{graphic_url}"
            async with session.get(url) as response:
                if response.status == 200:
                    process_type_icons(
                        type_id, types[str(type_id)], await response.read(), target_dir
                    )
                else:
                    print(
                        f"Failed to download icon for type {type_id} [{response.url}]: {await response.read()}"
                    )

    async with aiohttp.ClientSession() as session:
        await asyncio.gather(*[download(session, type_id) for type_id in need_render])


async def download(need_download: list[int], target_dir: pathlib.Path):
    MAX_CONNECTIONS = 10
    semaphore = asyncio.Semaphore(MAX_CONNECTIONS)

    async def download(session: aiohttp.ClientSession, type_id):
        nonlocal semaphore
        if (target_dir / f"{type_id}.png").exists():
            return
        async with semaphore:
            if os.environ["SERVER"] == "tq":
                url = f"https://resources.eveonline.com/Type/{type_id}_32.png"
            elif os.environ["SERVER"] == "se":
                url = f"https://image.evepc.163.com/Type/{type_id}_32.png"
            print(f"Downloading icon for type {type_id} from {url}")
            async with session.get(url) as response:
                if response.status == 200:
                    with open(target_dir / f"{type_id}.png", "wb") as f:
                        f.write(await response.read())
                else:
                    print(
                        f"Failed to download icon for type {type_id} [{response.url}]: {await response.read()}"
                    )

    async with aiohttp.ClientSession() as session:
        await asyncio.gather(*[download(session, type_id) for type_id in need_download])


async def render_icon(
    need_download: list[tuple[int, str]],
    types: dict,
    target_dir: pathlib.Path,
):
    MAX_CONNECTIONS = 10
    semaphore = asyncio.Semaphore(MAX_CONNECTIONS)

    async def download(session: aiohttp.ClientSession, item: tuple[int, str]):
        nonlocal semaphore
        async with semaphore:
            if os.environ["SERVER"] == "tq":
                url = f"https://resources.eveonline.com/{item[1]}"
            elif os.environ["SERVER"] == "se":
                url = f"https://ma79.gdl.netease.com/eve/resources/{item[1]}"
            print(f"Downloading icon from {url}")
            async with session.get(url) as response:
                if response.status == 200:
                    process_type_icons(item[0], types[str(item[0])], await response.read(), target_dir)
                else:
                    print(f"Failed to download icon [{response.url}]: {await response.read()}")

    async with aiohttp.ClientSession() as session:
        await asyncio.gather(*[download(session, item) for item in need_download])


def process_type_icons(type_id: int, type_info: dict, image: bytes, target_dir: pathlib.Path):
    METAGROUP_MAP: dict[int, str | None] = {
        1: None,
        2: "t2.png",
        3: "storyline.png",
        4: "faction.png",
        5: "officer.png",
        6: "deadspace.png",
        14: "t3.png",
        15: "abyssal.png",
        17: "premium.png",
        19: "time-limited.png",
        52: "struct-fraction.png",
        53: "struct-t2.png",
        54: "struct.png",
    }

    with Image.open(BytesIO(image)) as img_base:
        resized_jpg = img_base.resize((32, 32), Image.LANCZOS)

        final_image = resized_jpg.convert("RGBA")

    overlay_file = METAGROUP_MAP[type_info.get("metaGroupID", 1)]
    if overlay_file is not None:
        with Image.open(OVERLAY_DIR / overlay_file) as img_png:
            png_rgba = img_png.convert("RGBA")
            final_image.paste(png_rgba, (0, 0), png_rgba)

    final_image.save(target_dir / f"{type_id}.png", "PNG")


if not __name__ == "__main__":
    exit(0)

if len(sys.argv) < 5:
    print(
        "Usage: python render.py\n"
        "\t<path/to/fsd>\n"
        "\t<path/to/image>\n"
        "\t<path/to/cache>\n"
        "\t<path/to/res-file-index>\n"
    )

fsd_dir = sys.argv[1]
image_dir = sys.argv[2]
cache_dir = sys.argv[3]
res_index = sys.argv[4]

run(
    pathlib.Path(fsd_dir),
    pathlib.Path(image_dir),
    pathlib.Path(cache_dir),
    pathlib.Path(res_index),
)
