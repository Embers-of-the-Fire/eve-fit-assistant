"""Fetch remote state from S3-compatible storage or HTTP origin."""

from __future__ import annotations

import json
import subprocess

from typing import TYPE_CHECKING


if TYPE_CHECKING:
    from pathlib import Path


def _channel_subdir(channel: str) -> str:
    if not channel:
        raise ValueError("channel must not be empty")
    if ".." in channel or "/" in channel or "\\" in channel:
        raise ValueError(f"channel {channel!r} contains path separators or parent references")
    return f"channels/{channel}"


def _remote_state_output_paths(output_dir: Path, channel: str) -> dict[str, Path]:
    ch = _channel_subdir(channel)
    return {
        "index": output_dir / ch / "index.json",
        "documents_catalog": output_dir / ch / "documents" / "catalog.json",
        "bundles_catalog": output_dir / ch / "bundles" / "catalog.json",
    }


def fetch_remote_state_s3(
    *,
    mc_bin: str,
    endpoint: str,
    bucket: str,
    access_key: str,
    secret_key: str,
    alias_name: str,
    resource_root: str,
    channel: str,
    output_dir: Path,
) -> None:
    """Download channel catalogs + index from S3-compatible storage via ``mc``."""
    output_dir.mkdir(parents=True, exist_ok=True)

    bucket_target = f"{alias_name}/{bucket}"
    channel_prefix = f"{resource_root}/{_channel_subdir(channel)}"
    channel_target = f"{bucket_target}/{channel_prefix}"

    redacted = "<redacted>"
    _run(
        [mc_bin, "alias", "set", alias_name, endpoint, access_key, secret_key],
        [mc_bin, "alias", "set", alias_name, endpoint, redacted, redacted],
        "FETCH ALIAS",
    )

    _run(
        [
            mc_bin,
            "cp",
            "--recursive",
            channel_target + "/",
            str(output_dir / _channel_subdir(channel)) + "/",
        ],
        [
            mc_bin,
            "cp",
            "--recursive",
            channel_target + "/",
            str(output_dir / _channel_subdir(channel)) + "/",
        ],
        "FETCH REMOTE STATE",
    )


def fetch_remote_state_local(
    *,
    origin_dir: Path,
    resource_root: str,
    channel: str,
    output_dir: Path,
) -> None:
    """Copy remote state from a local origin directory."""
    import shutil

    src_channel_dir = origin_dir / resource_root / _channel_subdir(channel)
    if not src_channel_dir.exists():
        raise FileNotFoundError(f"Local origin channel dir does not exist: {src_channel_dir}")

    dst_channel_dir = output_dir / _channel_subdir(channel)
    dst_channel_dir.mkdir(parents=True, exist_ok=True)
    shutil.copytree(src_channel_dir, dst_channel_dir, dirs_exist_ok=True)


def fetch_remote_state_http(
    *,
    origin_url: str,
    resource_root: str,
    channel: str,
    output_dir: Path,
) -> None:
    """Download channel catalogs + index over HTTP."""
    from urllib.error import URLError
    from urllib.request import urlopen

    ch_prefix = f"{origin_url.rstrip('/')}/{resource_root}/{_channel_subdir(channel)}"
    paths = _remote_state_output_paths(output_dir, channel)

    for name, remote_path in [
        ("index", f"{ch_prefix}/index.json"),
        ("documents_catalog", f"{ch_prefix}/documents/catalog.json"),
        ("bundles_catalog", f"{ch_prefix}/bundles/catalog.json"),
    ]:
        try:
            with urlopen(remote_path) as resp:
                data = json.loads(resp.read().decode("utf-8"))
        except (URLError, ValueError) as exc:
            raise OSError(f"Failed to fetch {name} from {remote_path}: {exc}") from exc

        paths[name].parent.mkdir(parents=True, exist_ok=True)
        paths[name].write_text(
            json.dumps(data, indent=4, ensure_ascii=False) + "\n", encoding="utf-8"
        )


def read_local_remote_state(
    remote_state_dir: Path,
    channel: str,
) -> tuple[dict[str, object], dict[str, object], dict[str, object]]:
    """Read previously-fetched remote state from a local directory.

    Returns (index, documents_catalog, bundles_catalog) as dicts.
    """
    paths = _remote_state_output_paths(remote_state_dir, channel)
    missing = [k for k, p in paths.items() if not p.is_file()]
    if missing:
        raise FileNotFoundError(
            f"Remote state files not found in {remote_state_dir}: {', '.join(missing)}"
        )

    index: dict[str, object] = json.loads(paths["index"].read_text(encoding="utf-8"))
    docs: dict[str, object] = json.loads(paths["documents_catalog"].read_text(encoding="utf-8"))
    bundles: dict[str, object] = json.loads(paths["bundles_catalog"].read_text(encoding="utf-8"))
    return index, docs, bundles


def _run(cmd: list[str], redacted_cmd: list[str], title: str) -> None:
    out = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if out.returncode != 0:
        msg = f"Failed to execute [{out.returncode}]: {' '.join(redacted_cmd)}"
        stderr = (out.stderr or "").strip()
        if stderr:
            msg += f"\n{stderr}"
        raise OSError(msg)
