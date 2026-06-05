"""Fetch remote state from S3-compatible storage or HTTP origin."""

from __future__ import annotations

import json
import subprocess

from typing import TYPE_CHECKING


if TYPE_CHECKING:
    from pathlib import Path

    from data.lib.remote.channel import Channel


def _channel_subdir(channel: Channel) -> str:
    return f"channels/{channel.value}"


def _remote_state_output_paths(output_dir: Path, channel: Channel) -> dict[str, Path]:
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
    channel: Channel,
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
    channel: Channel,
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
    channel: Channel,
    output_dir: Path,
) -> None:
    """Download channel catalogs + index over HTTP."""
    from urllib.error import URLError
    from urllib.parse import urlparse
    from urllib.request import urlopen

    scheme = urlparse(origin_url).scheme
    if scheme not in ("http", "https"):
        raise ValueError(f"origin_url scheme must be http or https, got {scheme!r}")

    ch_prefix = f"{origin_url.rstrip('/')}/{resource_root}/{_channel_subdir(channel)}"
    paths = _remote_state_output_paths(output_dir, channel)

    def _fetch(name: str, local: Path, label: str) -> None:
        remote_path = f"{ch_prefix}/{local.relative_to(output_dir)}"
        try:
            with urlopen(remote_path, timeout=300) as resp:
                data = json.loads(resp.read().decode("utf-8"))
        except (URLError, ValueError) as exc:
            raise OSError(f"Failed to fetch {label} from {remote_path}: {exc}") from exc
        local.parent.mkdir(parents=True, exist_ok=True)
        local.write_text(json.dumps(data, indent=4, ensure_ascii=False) + "\n", encoding="utf-8")

    # Download index first — it may reference generation-scoped catalogs.
    _fetch("index", paths["index"], "index")
    index = _json_loads_dict(paths["index"].read_text(encoding="utf-8"), "index")

    for section, legacy_path, label in [
        ("documents", paths["documents_catalog"], "documents_catalog"),
        ("bundles", paths["bundles_catalog"], "bundles_catalog"),
    ]:
        resolved, _from_index = _resolve_catalog_local_path(output_dir, index, section, legacy_path)
        # Always download the legacy path so consumers that don't read the
        # index still work.
        _fetch(section, legacy_path, label)
        # Also download the generation-scoped catalog if the index references
        # a different path.
        if resolved != legacy_path:
            _fetch(section, resolved, f"{label} (generation-scoped)")


def read_local_remote_state(
    remote_state_dir: Path,
    channel: Channel,
) -> tuple[dict[str, object], dict[str, object], dict[str, object]]:
    """Read previously-fetched remote state from a local directory.

    Returns (index, documents_catalog, bundles_catalog) as dicts.
    """
    paths = _remote_state_output_paths(remote_state_dir, channel)
    if not paths["index"].is_file():
        raise FileNotFoundError(f"Remote index file not found in {remote_state_dir}")

    index = _json_loads_dict(paths["index"].read_text(encoding="utf-8"), "index")

    docs_catalog_path, docs_from_index = _resolve_catalog_local_path(
        remote_state_dir, index, "documents", paths["documents_catalog"]
    )
    bundles_catalog_path, bundles_from_index = _resolve_catalog_local_path(
        remote_state_dir, index, "bundles", paths["bundles_catalog"]
    )

    def _read_catalog(path: Path, from_index: bool, label: str) -> dict[str, object]:
        if path.is_file():
            return _json_loads_dict(path.read_text(encoding="utf-8"), label)
        if from_index:
            raise FileNotFoundError(
                f"Index-referenced {label} not found: {path}."
                f" The remote state may be incomplete; re-fetch and try again."
            )
        return {}

    docs = _read_catalog(docs_catalog_path, docs_from_index, "documents_catalog")
    bundles = _read_catalog(bundles_catalog_path, bundles_from_index, "bundles_catalog")
    return index, docs, bundles


def _resolve_catalog_local_path(
    base_dir: Path, index: dict[str, object], section: str, fallback: Path
) -> tuple[Path, bool]:
    """Resolve the local path for a catalog file from index.json's catalogPath.

    Returns ``(path, is_from_index)`` — *is_from_index* is True when the
    resolved path came from the index's ``catalogPath`` field rather than
    the legacy fallback.
    """
    sec = index.get(section, {})
    if isinstance(sec, dict):
        catalog_path = sec.get("catalogPath")
        if isinstance(catalog_path, str):
            return base_dir / catalog_path, True
    return fallback, False


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
