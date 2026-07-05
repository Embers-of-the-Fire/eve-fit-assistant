"""End-to-end raw-data update pipeline."""

from __future__ import annotations

import shutil
import subprocess

from dataclasses import dataclass
from typing import TYPE_CHECKING

import bootstrap.config

from bootstrap.data.updater.fsd import generate_fsd
from bootstrap.data.updater.index import download_index
from bootstrap.data.updater.index import download_metadata
from bootstrap.data.updater.index import download_resource_index
from bootstrap.data.updater.manifest import fetch_build
from bootstrap.data.updater.server import SERVER_ALIASES
from bootstrap.data.updater.server import get_server_config
from bootstrap.data.updater.uploader import upload_artifacts
from bootstrap.log import info
from bootstrap.utils import get_command


if TYPE_CHECKING:
    from pathlib import Path

    from bootstrap.data.updater.server import ServerId


@dataclass(frozen=True)
class UpdateCheckResult:
    """Result of comparing the remote build with the bucket build."""

    needs_update: bool
    remote_build: int
    bucket_build: int | None


@dataclass(frozen=True)
class UpdateResult:
    """Result of a raw-data update run."""

    server_id: ServerId
    build: int
    artifacts_dir: Path
    uploaded: bool


def _resolve_server_id(server_id: str) -> ServerId:
    """Normalize a server identifier to the canonical form."""
    normalized = SERVER_ALIASES.get(server_id.lower(), server_id.lower())
    if normalized in ("tranquility", "serenity", "singularity"):
        return normalized  # type: ignore[return-value]
    raise ValueError(f"Unknown server id: {server_id}")


def _get_raw_artifacts_dir(server_id: ServerId) -> Path:
    """Return the local directory where raw artifacts are assembled."""
    bootstrap.config.DeveloperConfiguration.ensure_loaded()
    root = bootstrap.config.DEV_CONFIGURATION.paths.root
    return root / "raw-artifacts" / server_id


async def _read_bucket_build(server_id: ServerId) -> int | None:
    """Read the current build number stored in the CI bucket, if any."""
    bootstrap.config.DeveloperConfiguration.ensure_loaded()
    storage = bootstrap.config.DEV_CONFIGURATION.ci.storage
    raw_artifacts = bootstrap.config.DEV_CONFIGURATION.ci.raw_artifacts
    if storage is None or raw_artifacts is None:
        return None

    alias = raw_artifacts.alias or storage.alias
    bucket = raw_artifacts.bucket or storage.bucket
    remote_root = raw_artifacts.remote_root
    build_path = f"{alias}/{bucket}/{remote_root}/{server_id}/build.txt"

    mc = get_command("mc")
    cmd = [mc, "cat", build_path]
    info(f"Reading bucket build: {' '.join(cmd)}")
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=60,
            check=False,
        )
    except FileNotFoundError:
        return None
    if result.returncode != 0:
        return None
    try:
        return int(result.stdout.strip())
    except ValueError:
        return None


async def check_server(server_id: str) -> UpdateCheckResult:
    """Check whether the remote EVE build is newer than the one in the CI bucket."""
    resolved = _resolve_server_id(server_id)
    server = get_server_config(resolved)
    remote_build = await fetch_build(server)
    bucket_build = await _read_bucket_build(resolved)
    return UpdateCheckResult(
        needs_update=bucket_build is None or remote_build > bucket_build,
        remote_build=remote_build,
        bucket_build=bucket_build,
    )


async def update_server(
    server_id: str,
    *,
    upload: bool = True,
    keep_temp: bool = False,
) -> UpdateResult:
    """Download, convert, and optionally upload raw data for a server."""
    resolved = _resolve_server_id(server_id)
    server = get_server_config(resolved)

    build = await fetch_build(server)
    base_dir = _get_raw_artifacts_dir(resolved)
    artifacts_dir = base_dir / "artifacts"
    temp_root = base_dir / "temp"

    if base_dir.exists():
        shutil.rmtree(base_dir)
    artifacts_dir.mkdir(parents=True, exist_ok=True)
    temp_root.mkdir(parents=True, exist_ok=True)

    index_file = await download_index(build, server, artifacts_dir)
    await download_metadata(index_file, server, artifacts_dir)
    resfileindex_file = await download_resource_index(index_file, server, artifacts_dir)
    await generate_fsd(index_file, resfileindex_file, server, artifacts_dir, temp_root)

    uploaded = False
    if upload:
        bootstrap.config.DeveloperConfiguration.ensure_loaded()
        ci = bootstrap.config.DEV_CONFIGURATION.ci
        if ci.raw_artifacts is None:
            ci.raw_artifacts = bootstrap.config.DeveloperCiRawArtifacts()
        raw_artifacts, storage = ci.require_raw_artifacts()
        await upload_artifacts(resolved, artifacts_dir, build, raw_artifacts, storage)
        uploaded = True

    if not keep_temp:
        shutil.rmtree(temp_root, ignore_errors=True)

    return UpdateResult(
        server_id=resolved,
        build=build,
        artifacts_dir=artifacts_dir,
        uploaded=uploaded,
    )
