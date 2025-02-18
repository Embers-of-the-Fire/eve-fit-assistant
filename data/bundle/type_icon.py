import os
import shutil

import yaml

from download import DownloadItem


def bundle(fsd_path, image_path, cache_dir) -> list[DownloadItem]:
    target_dir = f"{cache_dir}/icons/type"
    if not os.path.exists(target_dir):
        os.makedirs(target_dir)

    item_icon_dir = f"{image_path}/Types/"

    with open(f"{fsd_path}/types.yaml", "r", encoding="utf-8") as f:
        types = yaml.load(f, yaml.CSafeLoader)

    all_icons = os.listdir(item_icon_dir)

    to_download: list[DownloadItem] = []

    for tid, t in types.items():
        if t.get("marketGroupID") is None:
            continue

        if f"{tid}_32.png" in all_icons:
            shutil.copyfile(f"{item_icon_dir}/{tid}_32.png", f"{target_dir}/{tid}.png")
        else:
            to_download.append(
                DownloadItem(
                    dir=target_dir,
                    file_name=f"{tid}.png",
                    url=f"https://image.eveonline.com/Type/{tid}_32.png",
                    res_id=None,
                )
            )

    return to_download
