"""Orchestrate FSD binary collection, conversion, and msgpack compression."""

from __future__ import annotations

import asyncio
import os
import shutil
import sys
import zipfile

from typing import TYPE_CHECKING

from bootstrap.constant import PROJECT_ROOT
from bootstrap.log import info


if TYPE_CHECKING:
    from pathlib import Path

    from bootstrap.data.updater.server import ServerConfig


_DUMPER_DIR = PROJECT_ROOT / "tools" / "eve-fsd-dumper"
_PY27_ZIP = _DUMPER_DIR / "py27.zip"


async def _copy_scripts(work_dir: Path) -> None:
    """Copy vendored dumper scripts into the temporary work directory."""
    for name in ("collect.py", "convert.py", "compress.py"):
        shutil.copy(_DUMPER_DIR / name, work_dir / name)


async def _ensure_python2(extract_dir: Path) -> Path:
    """Return the path to a usable Python 2.7 executable.

    On Windows this extracts the bundled portable interpreter.
    On other platforms the conversion step cannot succeed because CCP's
    ``*Loader.pyd`` files are Windows-only, so we fail early.
    """
    if sys.platform != "win32":
        raise OSError(
            "FSD binary conversion requires Windows because CCP's loaders are .pyd files."
        )

    if not _PY27_ZIP.is_file():
        raise FileNotFoundError(
            f"Portable Python 2.7 archive not found: {_PY27_ZIP}\n"
            f"       Download it from the CI bucket (build-dependencies/py27.zip) "
            f"and place it at the path above."
        )

    python_exe = extract_dir / "python.exe"
    if python_exe.is_file():
        return python_exe

    info(f"Extracting portable Python 2.7 from {_PY27_ZIP}")
    extract_dir.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(_PY27_ZIP, "r") as zf:
        _safe_extractall(zf, extract_dir)
    if not python_exe.is_file():
        raise FileNotFoundError(f"python.exe not found after extracting {_PY27_ZIP}")
    return python_exe


def _safe_extractall(zf: zipfile.ZipFile, dest: Path) -> None:
    dest_resolved = dest.resolve()
    for member in zf.namelist():
        member_path = (dest / member).resolve()
        if dest_resolved not in member_path.parents and member_path != dest_resolved:
            raise ValueError(f"Unsafe path in zip archive: {member}")
    zf.extractall(dest)


async def _run_script(
    cmd: list[str],
    title: str,
    cwd: Path,
    extra_env: dict[str, str] | None = None,
) -> None:
    """Run a script inside ``cwd`` and stream its output."""
    info(f"{title}: {' '.join(cmd)}")
    env = os.environ.copy()
    if extra_env:
        env.update(extra_env)
    process = await asyncio.create_subprocess_exec(
        *cmd,
        cwd=cwd,
        env=env,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.STDOUT,
    )
    assert process.stdout is not None
    async for line in process.stdout:
        info(line.decode("utf-8", errors="replace").rstrip())
    await process.wait()
    if process.returncode != 0:
        raise RuntimeError(f"{title} failed with exit code {process.returncode}")


async def generate_fsd(
    index_file: Path,
    resfileindex_file: Path,
    server: ServerConfig,
    out_dir: Path,
    temp_root: Path,
) -> Path:
    """Generate ``*.msgpack`` FSD files from ``*.fsdbinary`` resources.

    Returns the path to the directory containing the generated msgpack files.
    """
    work_dir = temp_root / "fsd-work"
    work_dir.mkdir(parents=True, exist_ok=True)

    if sys.platform != "win32":
        raise OSError(
            "FSD binary conversion requires Windows because CCP's loaders are .pyd files."
        )

    await _copy_scripts(work_dir)

    env = {"FSD_DUMPER_SERVER": server.fsd_dumper_server}
    await _run_script(
        [sys.executable, str(work_dir / "collect.py"), str(index_file), str(resfileindex_file)],
        "COLLECT FSD BINARIES",
        work_dir,
        extra_env=env,
    )

    python2 = await _ensure_python2(work_dir / "py27")
    await _run_script(
        [
            str(python2),
            str(work_dir / "convert.py"),
            str(work_dir / "data" / "fsdbinary"),
            str(work_dir / "data" / "loader"),
        ],
        "CONVERT FSD BINARIES",
        work_dir,
    )

    out_msgpack = work_dir / "out_msgpack"
    await _run_script(
        [
            sys.executable,
            str(work_dir / "compress.py"),
            str(work_dir / "out_pickle"),
            str(out_msgpack),
        ],
        "COMPRESS FSD PICKLES",
        work_dir,
    )

    fsd_dir = out_dir / "fsd"
    if fsd_dir.exists():
        shutil.rmtree(fsd_dir)
    fsd_dir.mkdir(parents=True, exist_ok=True)

    for msgpack_file in out_msgpack.glob("*.msgpack"):
        shutil.copy(msgpack_file, fsd_dir / msgpack_file.name)

    info(f"Copied {len(list(fsd_dir.glob('*.msgpack')))} msgpack files to {fsd_dir}")
    return fsd_dir
