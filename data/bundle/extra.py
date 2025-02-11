import asyncio
import sys

import download
import group_icon
import type_icon


if not __name__ == "__main__":
    exit(0)

if len(sys.argv) < 5:
    print(
        "Usage: python extra.py\n"
        "\t<path/to/fsd>\n"
        "\t<path/to/image>\n"
        "\t<path/to/res-file/index>\n"
        "\t<path/to/cache>\n"
        "\t<flag|-d|--download|default: false>"
    )

fsd_dir = sys.argv[1]
image_dir = sys.argv[2]
res_index = sys.argv[3]
cache_dir = sys.argv[4]
should_download = len(sys.argv) >= 6 and sys.argv[5] == "--download"

need_download = []
need_download.extend(group_icon.bundle(fsd_dir, image_dir, cache_dir))
need_download.extend(type_icon.bundle(fsd_dir, image_dir, cache_dir))

if should_download:
    asyncio.run(download.download_all(need_download, res_index))
else:
    print("Skip download.")
