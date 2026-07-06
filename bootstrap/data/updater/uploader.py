"""Upload raw artifacts to the CI S3-compatible bucket via ``mc``."""

from __future__ import annotations

import asyncio
import os

from typing import TYPE_CHECKING
from urllib.parse import quote

from bootstrap.log import info
from bootstrap.utils import get_command


if TYPE_CHECKING:
    from pathlib import Path

    from bootstrap.config import DeveloperCiRawArtifacts
    from bootstrap.config import DeveloperCiStorage
    from bootstrap.data.updater.server import ServerId


_REDACTED = "<redacted>"


async def _run_mc(
    cmd: list[str],
    title: str,
    *,
    env: dict[str, str] | None = None,
    secrets: set[str] | None = None,
) -> None:
    """Run an ``mc`` subcommand and raise on failure.

    Any argument whose value is present in ``secrets`` is replaced with
    ``<redacted>`` in logs. Value-based redaction is robust against future
    changes to argument order.

    ``env`` is merged into the subprocess environment; values are not logged.
    """

    mc = get_command("mc")
    full_cmd = [mc, *cmd]
    redacted = {s for s in (secrets or set()) if s != ""}
    redacted_cmd = [_REDACTED if arg in redacted else arg for arg in full_cmd]
    info(f"{title}: {' '.join(redacted_cmd)}")
    process = await asyncio.create_subprocess_exec(
        *full_cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.STDOUT,
        env={**os.environ, **(env or {})},
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
        ["alias", "set", alias, endpoint, "--api", "s3v4"],
        "CI RAW ARTIFACTS ALIAS",
        env={
            # ``MC_HOST_<alias>`` is parsed as a URL, so access/secret key characters that
            # are special in the userinfo segment (``/``, ``+``, ``=``, ``@``, ``:``) must
            # be percent-encoded. ``mc`` then decodes them before sending to S3.
            f"MC_HOST_{alias}": (
                "https://"
                f"{quote(access_key, safe='')}:{quote(secret_key, safe='')}"
                f"@{endpoint.removeprefix('https://')}"
            ),
        },
    )

    server_root = f"{alias}/{bucket}/{config.remote_root}/{server_id}"

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

    build_file = artifacts_dir.parent / "build.txt"
    await _run_mc(
        ["cp", str(build_file), f"{server_root}/build.txt"],
        f"UPLOAD {server_id} BUILD.TXT",
    )
