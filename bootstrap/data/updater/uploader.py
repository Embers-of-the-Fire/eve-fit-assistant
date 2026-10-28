"""Upload raw artifacts to the CI S3-compatible bucket via boto3."""

from __future__ import annotations

import asyncio

from typing import TYPE_CHECKING

from bootstrap.log import info
from bootstrap.remote.s3client import S3Client


if TYPE_CHECKING:
    from pathlib import Path

    from bootstrap.config import DeveloperCiRawArtifacts
    from bootstrap.config import DeveloperCiStorage
    from bootstrap.data.updater.server import ServerId


def _resolve_storage(
    config: DeveloperCiRawArtifacts,
    storage: DeveloperCiStorage,
) -> tuple[str, str, str, str]:
    """Return endpoint, bucket, access_key, secret_key with overrides applied."""
    resolved_access_key = config.access_key or storage.access_key
    resolved_secret_key = config.secret_key or storage.secret_key
    return (
        config.endpoint or storage.endpoint,
        config.bucket or storage.bucket,
        resolved_access_key.get_secret_value() if resolved_access_key else "",
        resolved_secret_key.get_secret_value() if resolved_secret_key else "",
    )


def _make_client(
    endpoint: str,
    bucket: str,
    access_key: str,
    secret_key: str,
) -> S3Client:
    """Build the S3 client for the CI storage target."""
    return S3Client(
        endpoint=endpoint,
        bucket=bucket,
        access_key=access_key,
        secret_key=secret_key,
    )


async def upload_artifacts(
    server_id: ServerId,
    artifacts_dir: Path,
    build: int,
    config: DeveloperCiRawArtifacts,
    storage: DeveloperCiStorage,
) -> None:
    """Upload raw artifacts and ``build.txt`` to the CI bucket."""
    endpoint, bucket, access_key, secret_key = _resolve_storage(config, storage)
    client = _make_client(endpoint, bucket, access_key, secret_key)

    server_root = f"{config.remote_root}/{server_id}"

    info(f"UPLOAD {server_id} ARTIFACTS: {artifacts_dir} -> {bucket}/{server_root}/artifacts/")
    await asyncio.to_thread(
        client.mirror_up, artifacts_dir, f"{server_root}/artifacts", delete=True
    )

    build_file = artifacts_dir.parent / "build.txt"
    info(f"UPLOAD {server_id} BUILD.TXT: {build_file} -> {bucket}/{server_root}/build.txt")
    await asyncio.to_thread(client.upload_file, build_file, f"{server_root}/build.txt")


async def download_artifacts(
    server_id: ServerId,
    output_dir: Path,
    config: DeveloperCiRawArtifacts,
    storage: DeveloperCiStorage,
) -> None:
    """Download raw artifacts from the CI bucket to a local directory."""
    endpoint, bucket, access_key, secret_key = _resolve_storage(config, storage)
    client = _make_client(endpoint, bucket, access_key, secret_key)

    server_root = f"{config.remote_root}/{server_id}"
    target_dir = output_dir / server_id

    info(f"DOWNLOAD {server_id} ARTIFACTS: {bucket}/{server_root}/artifacts/ -> {target_dir}")
    await asyncio.to_thread(client.mirror_down, f"{server_root}/artifacts", target_dir)
