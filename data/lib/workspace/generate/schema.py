"""V2 schema checkout generator.

Reads workspace build output, produces a content-addressed asset store
and checkout catalog per the schema V2 spec hash algorithm.

Output:
  <schema_root>/checkouts/<hash>.json   ← checkout catalog
  <schema_root>/assets/<2c>/<ph>/<ch>   ← content-addressed files
"""

from __future__ import annotations

import datetime
import hashlib
import json
import os
import posixpath

from configparser import ConfigParser
from dataclasses import dataclass
from pathlib import Path
from pathlib import PurePosixPath
from typing import TYPE_CHECKING
from typing import Literal

from data.lib.log import info
from data.lib.log import warning


if TYPE_CHECKING:
    from data.lib.workspace.config import WorkspaceConfig


def _sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _normalize_path(relative_path: str) -> str:
    """Canonicalize to POSIX with no trailing slash or relative segments."""
    resolved = PurePosixPath(relative_path)
    if resolved.is_absolute():
        raise ValueError(f"Asset path must be relative: {relative_path}")
    return posixpath.normpath(resolved.as_posix())


def _compute_checkout_hash(files: dict[str, dict[str, object]]) -> str:
    """Compute checkout ID per spec hash algorithm.

    checkoutId = SHA-256(
        "efa:checkout:v2\\n" +
        "count:" + str(len(files)) + "\\n" +
        for path in sorted(files.keys):
            "\\t" + path + "\\t" + content_hash + "\\n"
    )
    """
    payload = "efa:checkout:v2\n"
    payload += f"count:{len(files)}\n"
    for path in sorted(files.keys()):
        file_info = files[path]
        payload += f"\t{path}\t{file_info['hash']}\n"
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def _read_start_config(config: WorkspaceConfig) -> ConfigParser:
    """Read the start.ini metadata for a workspace."""
    start_config = ConfigParser()
    start_config.read(config.metadata.start_cfg)
    return start_config


def verify_checkout_hash(catalog_path: Path) -> bool:
    """Recompute and verify the checkout hash in a catalog JSON file."""
    with catalog_path.open("r", encoding="utf-8") as f:
        catalog = json.load(f)
    computed = _compute_checkout_hash(catalog["files"])
    return computed == catalog["id"]


def generate_schema_checkout(
    config: WorkspaceConfig | None,
    build_dir: Path,
    schema_root: Path,
    *,
    server_id: str | None = None,
) -> str | None:
    """Generate V2 schema checkout from workspace build output.

    Args:
        config: Workspace configuration. When None, metadata is derived
            from the optional server_id parameter.
        build_dir: Directory containing the workspace build output
            (static/, localization/, etc.).
        schema_root: Unified schema root directory. Assets land at
            <schema_root>/assets/..., checkouts at <schema_root>/checkouts/....
        server_id: Server ID override for standalone usage when config is None.

    Returns:
        The checkout hash on success, or None if the build directory is empty.

    Raises:
        ValueError: If a file path is absolute or invalid.
    """
    assets_dir = schema_root / "assets"
    checkouts_dir = schema_root / "checkouts"
    checkouts_dir.mkdir(parents=True, exist_ok=True)

    if not build_dir.is_dir() or not any(build_dir.iterdir()):
        warning(f"Build directory not found or empty: {build_dir}")
        return None

    files: dict[str, dict[str, object]] = {}
    file_count = 0
    skipped_count = 0

    for root, _dirs, filenames in os.walk(build_dir):
        root_path = Path(root)
        for name in filenames:
            file_path = root_path / name
            try:
                rel = file_path.relative_to(build_dir)
            except ValueError:
                warning(f"File outside build dir: {file_path}")
                skipped_count += 1
                continue

            normalized = _normalize_path(str(rel))

            content = file_path.read_bytes()

            content_hash = _sha256_hex(content)
            path_hash = _sha256_hex(normalized.encode("utf-8"))

            path_prefix = path_hash[:2]
            dest_dir = assets_dir / path_prefix / path_hash
            dest_dir.mkdir(parents=True, exist_ok=True)
            dest_file = dest_dir / content_hash
            if not dest_file.exists():
                dest_file.write_bytes(content)

            files[normalized] = {
                "pathHash": path_hash,
                "hash": content_hash,
                "size": file_path.stat().st_size,
            }
            file_count += 1

    if not files:
        warning("No files found in build directory")
        return None

    checkout_hash = _compute_checkout_hash(files)

    resolved_server_id = server_id or ""
    metadata: dict[str, str] = {}

    if config is not None:
        start_config = _read_start_config(config)
        resolved_server_id = start_config.get("main", "server", fallback=resolved_server_id)
        metadata = {
            "gameServer": start_config.get("main", "server", fallback=""),
            "gameBuild": start_config.get("main", "build", fallback=""),
            "gameVersion": start_config.get("main", "version", fallback=""),
        }
    elif resolved_server_id:
        metadata = {"gameServer": resolved_server_id}

    catalog = {
        "id": checkout_hash,
        "createdAt": datetime.datetime.now(datetime.UTC).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "serverId": resolved_server_id,
        "metadata": metadata,
        "files": files,
    }

    catalog_path = checkouts_dir / f"{checkout_hash}.json"
    with catalog_path.open("w", encoding="utf-8") as f:
        json.dump(catalog, f, indent=2, ensure_ascii=False)
        f.write("\n")

    info(f"Schema checkout {checkout_hash[:12]}... ({file_count} files, {skipped_count} skipped)")

    return checkout_hash


@dataclass
class VerifyResult:
    path: str
    status: Literal["OK", "FAIL", "MISSING"]
    details: str | None = None
    size: int | None = None


def verify_checkout_assets(catalog: dict, schema_root: Path) -> list[VerifyResult]:
    """Verify all assets referenced by a checkout catalog.

    Checks asset existence, content hash match, file size match, and
    catalog integrity (the checkout hash itself).

    Args:
        catalog: The checkout catalog dict (must have "id" and "files").
        schema_root: Unified schema root directory (containing assets/ subdir).

    Returns:
        List of VerifyResult entries, one per file plus a trailing catalog
        integrity entry.
    """
    results: list[VerifyResult] = []
    files = catalog.get("files", {})

    for path, file_info in files.items():
        ph = file_info["pathHash"]
        ch = file_info["hash"]
        expected_size = file_info["size"]

        asset_path = schema_root / "assets" / ph[:2] / ph / ch
        if not asset_path.exists():
            results.append(
                VerifyResult(
                    path=path,
                    status="MISSING",
                    details=f"Asset not found at {asset_path}",
                )
            )
            continue

        actual_size = asset_path.stat().st_size
        actual_hash = _sha256_hex(asset_path.read_bytes())

        if actual_hash != ch:
            results.append(
                VerifyResult(
                    path=path,
                    status="FAIL",
                    details=(
                        f"Content hash mismatch: expected {ch[:12]}..., got {actual_hash[:12]}..."
                    ),
                    size=actual_size,
                )
            )
        elif actual_size != expected_size:
            results.append(
                VerifyResult(
                    path=path,
                    status="FAIL",
                    details=(f"Size mismatch: expected {expected_size}, got {actual_size}"),
                    size=actual_size,
                )
            )
        else:
            results.append(VerifyResult(path=path, status="OK", size=actual_size))

    computed_id = _compute_checkout_hash(files)
    catalog_id = catalog.get("id")
    if computed_id != catalog_id:
        results.append(
            VerifyResult(
                path="[catalog integrity]",
                status="FAIL",
                details=(f"Checkout hash mismatch: expected {catalog_id}, computed {computed_id}"),
            )
        )
    else:
        results.append(VerifyResult(path="[catalog integrity]", status="OK"))

    return results
