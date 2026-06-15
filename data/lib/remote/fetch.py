"""Fetch remote state from S3-compatible storage or local origin."""

from __future__ import annotations

import json
import subprocess

from typing import TYPE_CHECKING


if TYPE_CHECKING:
    from pathlib import Path

    from data.lib.remote.channel import Channel


def fetch_remote_state_s3(
    *,
    mc_bin: str,
    endpoint: str,
    bucket: str,
    access_key: str,
    secret_key: str,
    alias_name: str,
    resource_root: str,
    channel: Channel,
    output_dir: Path,
) -> None:
    """Download efa/v2/<channel>/ manifest tree from S3 via ``mc``."""
    output_dir.mkdir(parents=True, exist_ok=True)

    bucket_target = f"{alias_name}/{bucket}"
    normalized_root = resource_root.rstrip("/")
    channel_prefix = f"{normalized_root}/{channel.value}"
    channel_target = f"{bucket_target}/{channel_prefix}"

    redacted = "<redacted>"
    _run(
        [mc_bin, "alias", "set", alias_name, endpoint, access_key, secret_key, "--api", "s3v4"],
        [mc_bin, "alias", "set", alias_name, endpoint, redacted, redacted, "--api", "s3v4"],
        "FETCH ALIAS",
    )

    try:
        _run(
            [
                mc_bin,
                "cp",
                "--recursive",
                channel_target + "/",
                str(output_dir / channel.value) + "/",
            ],
            [
                mc_bin,
                "cp",
                "--recursive",
                channel_target + "/",
                str(output_dir / channel.value) + "/",
            ],
            "FETCH REMOTE STATE",
        )
    except OSError as exc:
        msg = str(exc)
        if "Object does not exist" in msg or "NoSuchKey" in msg:
            _write_empty_remote_state(output_dir, channel)
            return
        raise


def fetch_remote_state_local(
    *,
    origin_dir: Path,
    resource_root: str,
    channel: Channel,
    output_dir: Path,
) -> None:
    """Copy remote state from a local origin directory."""
    import shutil

    src_channel_dir = origin_dir / resource_root / channel.value
    if not src_channel_dir.exists():
        raise FileNotFoundError(f"Local origin channel dir does not exist: {src_channel_dir}")

    dst_channel_dir = output_dir / channel.value
    dst_channel_dir.mkdir(parents=True, exist_ok=True)
    shutil.copytree(src_channel_dir, dst_channel_dir, dirs_exist_ok=True)


def _write_empty_remote_state(output_dir: Path, channel: Channel) -> None:
    """Create minimal empty remote state for a blank bucket."""
    ch_dir = output_dir / channel.value
    manifest_dir = ch_dir / "manifest"
    manifest_dir.mkdir(parents=True, exist_ok=True)

    index = {"manifestVersion": 1, "activatedGeneration": ""}
    generations: dict[str, object] = {}

    def _write(path: Path, data: dict[str, object]) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            json.dumps(data, indent=4, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )

    _write(manifest_dir / "index.json", index)
    _write(manifest_dir / "generations.json", generations)


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------


def _json_loads_dict(text: str, label: str) -> dict[str, object]:
    data = json.loads(text)
    if not isinstance(data, dict):
        raise TypeError(f"{label} JSON decoded as {type(data).__name__}, expected dict")
    return data


def _run(
    cmd: list[str],
    redacted_cmd: list[str],
    title: str,
    timeout: float = 300,
) -> None:
    try:
        out = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=timeout,
        )
    except subprocess.TimeoutExpired:
        raise OSError(f"{title} timed out after {timeout}s: {' '.join(redacted_cmd)}") from None
    if out.returncode != 0:
        msg = f"Failed to execute [{out.returncode}]: {' '.join(redacted_cmd)}"
        stderr = (out.stderr or "").strip()
        if stderr:
            msg += f"\n{stderr}"
        raise OSError(msg)
