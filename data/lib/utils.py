from __future__ import annotations

import hashlib
import shutil
import subprocess
import sys

from typing import TYPE_CHECKING

from data.lib.log import debug
from data.lib.log import error
from data.lib.log import info


if TYPE_CHECKING:
    from pathlib import Path


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


def get_bin_size(size: int) -> str:
    """Convert a size in bytes to a human-readable string."""
    for unit in ["B", "KB", "MB", "GB", "TB"]:
        if size < 1024.0:
            return f"{size:.2f} {unit}"
        size /= 1024.0
    return f"{size:.2f} PB"


def try_get_attr[T, R](obj: T | None, attr: str) -> R | None:
    if obj is None:
        return None
    return getattr(obj, attr, None)


def execute_command(cmd: list, title: str, dry_run: bool = False, *args, **kwargs):
    if dry_run:
        info(f"[Dry-Run] {title}: " + " ".join(cmd))
        return

    line_width = 30
    title = title.strip()
    if len(title) < line_width:
        left = int((line_width - len(title) - 2) / 2)
        right = line_width - len(title) - 2 - left
        title = ("-" * left) + f" {title} " + ("-" * right)

    debug("Executing command: " + " ".join(cmd))
    debug(title)
    out = subprocess.run(cmd, *args, capture_output=True, text=True, **kwargs)
    if out.returncode != 0:
        for line in out.stdout.splitlines():
            error(line)
        error(f"Failed to execute command [{out.returncode}]:")
        for line in out.stderr.splitlines():
            error(line)
        exit(out.returncode)
    else:
        for line in out.stdout.splitlines():
            debug(line)
    debug("-" * line_width)


def get_file_sha256(file: Path) -> str:
    with file.open("rb") as f:
        hasher = hashlib.sha256()
        for chunk in iter(lambda: f.read(8192), b""):
            hasher.update(chunk)
        return hasher.hexdigest()
