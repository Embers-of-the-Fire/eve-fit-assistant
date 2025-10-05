from __future__ import annotations

import os
import shutil

from typing import TYPE_CHECKING

from data.lib.constant import NATIVE_LIB_ROOT
from data.lib.log import info
from data.lib.utils import execute_command
from data.lib.utils import get_command


if TYPE_CHECKING:
    from data.lib.workspace.generate import GeneratorDatasource


NATIVE_ENV_FSD_BINARY_DIR = "FSD_BINARY_DIR"
NATIVE_ENV_FSD_FORMAT = "FSD_FORMAT"
NATIVE_ENV_FSD_LOC_EN_DIR = "FSD_LOC_EN_DIR"
NATIVE_ENV_OUTPUT_DIR = "OUTPUT_DIR"

NATIVE_OUTPUT_DIR = "native"

EN_RESOURCE_ID = "res:/localizationfsd/localization_fsd_en-us.pickle"


async def __get_native_env_map(gen: GeneratorDatasource):
    loc_path = gen.resources.res.get_resource(EN_RESOURCE_ID)
    await loc_path.download()
    env_map: dict[str, str] = {
        NATIVE_ENV_FSD_FORMAT: "msgpack",
        NATIVE_ENV_FSD_BINARY_DIR: str(gen.config.resources.fsd.resolve()),
        NATIVE_ENV_FSD_LOC_EN_DIR: str(loc_path.local_path),
        NATIVE_ENV_OUTPUT_DIR: str((gen.config.paths.cache / NATIVE_OUTPUT_DIR).resolve()),
    }
    return env_map


async def generate(data: GeneratorDatasource):
    env_map = await __get_native_env_map(data)
    uv = get_command("uv")
    info("Executing native generator...")
    info(
        f"Executing command: uv run -m data.convert in native directory: {NATIVE_LIB_ROOT.resolve()}"
    )
    execute_command(
        [uv, "run", "-m", "data.convert"],
        "NATIVE CONVERT",
        cwd=NATIVE_LIB_ROOT.resolve(),
        env={**dict(**os.environ), **env_map},
    )
    pb_dir = data.config.paths.cache / NATIVE_OUTPUT_DIR / "pb2"
    target_dir = data.paths.native_root_path
    info(f"Copying output protobuf {pb_dir} -> {target_dir}")
    shutil.copytree(pb_dir, target_dir, dirs_exist_ok=True)

    info("Finished generating native data.")
