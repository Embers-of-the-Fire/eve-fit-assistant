"""Upload raw artifacts to the CI S3-compatible bucket via ``mc``."""

from __future__ import annotations

import asyncio

from typing import TYPE_CHECKING

from bootstrap.log import info
from bootstrap.utils import get_command


if TYPE_CHECKING:
    from pathlib import Path

    from bootstrap.config import DeveloperCiRawArtifacts
    from bootstrap.config import DeveloperCiStorage
    from bootstrap.data.updater.server import ServerId


_REDACTED = "<redacted>"


async def _run_mc(cmd: list[str], title: str, *, redacted_indices: set[int] | None = None) -> None:
    """Run an ``mc`` subcommand and raise on failure.

    Arguments at ``redacted_indices`` are replaced with ``<redacted>`` in logs.
    """
    mc = get_command("mc")
    full_cmd = [mc, *cmd]
    redacted_cmd = list(full_cmd)
    for idx in redacted_indices or set():
        if 0 <= idx < len(redacted_cmd):
            redacted_cmd[idx] = _REDACTED
    info(f"{title}: {' '.join(redacted_cmd)}")
    process = await asyncio.create_subprocess_exec(
        *full_cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.STDOUT,
    )
    assert process.stdout is not None
    async for line in process.stdout:
        info(line.decode("utf-8", errors="replace").rstrip())
    await process.wait()
    if process.returncode != 0:
        raise RuntimeError(f"{title} failed with exit code {process.returncode}")


def _resolve_storage(
    config: DeveloperCiRawArtifacts,
    storage: DeveloperCiStorage,
) -> tuple[str, str, str, str, str]:
    """Return endpoint, bucket, access_key, secret_key, alias with overrides applied."""
    resolved_access_key = config.access_key or storage.access_key
    resolved_secret_key = config.secret_key or storage.secret_key
    return (
        config.endpoint or storage.endpoint,
        config.bucket or storage.bucket,
        resolved_access_key.get_secret_value() if resolved_access_key else "",
        resolved_secret_key.get_secret_value() if resolved_secret_key else "",
        config.alias or storage.alias,
    )


async def upload_artifacts(
    server_id: ServerId,
    artifacts_dir: Path,
    build: int,
    config: DeveloperCiRawArtifacts,
    storage: DeveloperCiStorage,
) -> None:
    """Upload raw artifacts and ``build.txt`` to the CI bucket."""
    endpoint, bucket, access_key, secret_key, alias = _resolve_storage(config, storage)

    await _run_mc(
        ["alias", "set", alias, endpoint, access_key, secret_key, "--api", "s3v4"],
        "CI RAW ARTIFACTS ALIAS",
        redacted_indices={5, 6},
    )

    server_root = f"{alias}/{bucket}/{config.remote_root}/{server_id}"
    build_file = artifacts_dir.parent / "build.txt"
    build_file.write_text(str(build), encoding="utf-8")

    await _run_mc(
        [
            "mirror",
            "--overwrite",
            "--remove",
            f"{artifacts_dir}/",
            f"{server_root}/artifacts/",
        ],
        f"UPLOAD {server_id} ARTIFACTS",
    )

    await _run_mc(
        ["cp", str(build_file), f"{server_root}/build.txt"],
        f"UPLOAD {server_id} BUILD.TXT",
    )
