from __future__ import annotations

import shutil
import sys


def get_command(name: str) -> str:
    if sys.platform == "win32":
        path = (
            shutil.which(f"{name}.bat")
            or shutil.which(f"{name}.cmd")
            or shutil.which(f"{name}.bat")
            or shutil.which(name)
        )
    else:
        path = shutil.which(name)

    if path is None:
        raise FileNotFoundError(f"Command '{name}' not found in PATH.")

    return path
