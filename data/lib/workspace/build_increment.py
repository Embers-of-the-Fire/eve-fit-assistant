from __future__ import annotations

import shutil

from typing import TYPE_CHECKING

from data.lib.log import debug
from data.lib.log import error
from data.lib.log import info
from data.lib.log import warning
from data.lib.utils import get_bin_size
from data.lib.utils import get_file_sha256
from data.lib.workspace.generate import Descriptor
from data.lib.workspace.generate import GeneratorDatasource


if TYPE_CHECKING:
    from pathlib import Path

    from data.lib.workspace.config import WorkspaceConfig


def build_increment_bundle(config: WorkspaceConfig, previous_hash_list_path: Path):
    warning("Make sure you've already generated the full bundle.")
    warning("Increment bundle depends on the full bundle generation cache.")

    if not previous_hash_list_path.exists() or not previous_hash_list_path.is_file():
        error("Hash list file does not exist.")
        return

    datasource = GeneratorDatasource(config, is_incremental=True)
    desc = Descriptor.create(datasource)

    with open(datasource.paths.increment_descriptor_path, "w", encoding="utf-8") as f:
        f.write(desc.model_dump_json(indent=4))

    info(f"Generated descriptor at {datasource.paths.increment_descriptor_path}.")

    with open(previous_hash_list_path, "r", encoding="utf-8") as f:
        previous_hashes = {
            row[0]: {"size": int(row[1]), "hash": row[2]}
            for row in (line.strip().split(",") for line in f)
        }

    full_generated = datasource.paths.full_generate_out_path
    increment_generated = datasource.paths.increment_generate_out_path

    included = 0
    for file_path in full_generated.rglob("*"):
        if not file_path.is_file():
            continue

        relative_path = file_path.relative_to(full_generated).as_posix()
        if "descriptor.json" in relative_path:
            continue
        absolute_parent = (increment_generated / relative_path).parent
        cfg = previous_hashes.get(relative_path)
        if cfg is None:
            absolute_parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(file_path, increment_generated / relative_path)
            debug(f"Including {relative_path} (new file)")
            included += 1
            continue
        file_size = file_path.stat().st_size
        if file_size != cfg["size"]:
            absolute_parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(file_path, increment_generated / relative_path)
            debug(f"Including {relative_path} (new file)")
            included += 1
            continue
        file_hash = get_file_sha256(file_path)
        if file_hash != cfg["hash"]:
            absolute_parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(file_path, increment_generated / relative_path)
            debug(f"Including {relative_path} (new file)")
            included += 1
            continue

    shutil.make_archive(
        str(datasource.config.paths.output / f"{datasource.config.metadata.identifier}_increment"),
        format="zip",
        root_dir=increment_generated,
    )

    out_path = (
        datasource.config.paths.output / f"{datasource.config.metadata.identifier}_increment.zip"
    )

    info(
        f"Generated increment data archive of {get_bin_size(out_path.stat().st_size)} at {out_path}, including {included} files."
    )
