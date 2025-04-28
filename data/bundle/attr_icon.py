import json
import os
import shutil

from download import DownloadItem


def bundle(fsd_path, image_path, cache_dir) -> list[DownloadItem]:
    target_dir = f"{cache_dir}/icons/icon"
    if not os.path.exists(target_dir):
        os.makedirs(target_dir)

    item_icon_dir = f"{image_path}/Icons/items/"

    with open(f"{fsd_path}/dogmaattributes.json", "r", encoding="utf-8") as f:
        attrs = json.load(f)
    with open(f"{fsd_path}/iconids.json", "r", encoding="utf-8") as f:
        icons = json.load(f)

    used_icon = {
        x["iconID"] for x in attrs.values() if "iconID" in x.keys() and x.get("published", False)
    }

    to_download: list[DownloadItem] = []

    for icon in used_icon:
        path: str = icons[str(icon)]["iconFile"]
        name = path.split("/").pop()
        icon_path = f"{item_icon_dir}/{name}"
        icon_out_path = f"{target_dir}/{icon}.png"
        if os.path.exists(icon_path):
            shutil.copyfile(icon_path, icon_out_path)
        else:
            to_download.append(
                DownloadItem(dir=target_dir, file_name=f"{icon}.png", res_id=path)
            )

    return to_download
