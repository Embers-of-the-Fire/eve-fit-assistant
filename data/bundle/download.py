import asyncio
import os
from typing import NamedTuple

import aiofiles
import aiohttp

import read_resfile_index

# 设置最大并发连接数
MAX_CONNECTIONS = 5  # 你可以根据需要调整这个值
semaphore = asyncio.Semaphore(MAX_CONNECTIONS)


class DownloadItem(NamedTuple):
    res_id: str
    dir: str
    file_name: str


async def download(session: aiohttp.ClientSession, item: DownloadItem, index: dict[str, str]):
    u = index.get(item.res_id.lower())
    if u is None:
        print(f"Failed to download {item.res_id.lower()}")
        return
    async with semaphore:
        if os.environ["SERVER"] == "tq":
            url = f"https://resources.eveonline.com/{index[item.res_id.lower()]}"
        elif os.environ["SERVER"] == "se":
            url = f"https://ma79.gdl.netease.com/eve/resources/{index[item.res_id.lower()]}"

        print(f"Downloading {url} to {item.dir}/{item.file_name}")
        async with session.get(url) as response:
            async with aiofiles.open(f"{item.dir}/{item.file_name}", "wb") as f:
                await f.write(await response.read())


async def download_all(items: list[DownloadItem], resfile_index: str):
    index = read_resfile_index.read_resfile_index(resfile_index)
    items = set(items)
    async with aiohttp.ClientSession() as session:
        tasks = [download(session, item, index) for item in items]
        print(len(tasks))
        await asyncio.gather(*tasks)
