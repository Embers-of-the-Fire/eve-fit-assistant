"""V2 schema resource snapshot generator.

Reads workspace build output, produces a content-addressed blob store and
ResourceIndex protobuf snapshot per the EFA V2 unified schema.

Output:
  <root>/assets/blobs/{2c}/{ident_hash}/{content_hash}  ← content-addressed blobs
  <root>/assets/resources/{snapshot_hash}/
    metadata.json                                         ← ResourceSnapshotMetadata
    resources.pb2                                         ← ResourceIndex
"""

from __future__ import annotations

import datetime
import os

from configparser import ConfigParser
from pathlib import Path
from pathlib import PurePosixPath
from typing import TYPE_CHECKING

from bootstrap.log import info
from bootstrap.log import warning
from bootstrap.remote.hash import content_hash as sha256_content
from bootstrap.remote.hash import ident_hash as ident_hash_fn
from bootstrap.remote.models import ResourceSnapshotMetadata
from bootstrap.remote.snapshot import SnapshotStore


if TYPE_CHECKING:
    from bootstrap.data.workspace.config import WorkspaceConfig


def _normalize_path(relative_path: str) -> str:
    """Canonicalize to POSIX with no trailing slash or relative segments."""
    import posixpath

    resolved = PurePosixPath(relative_path)
    if resolved.is_absolute():
        raise ValueError(f"Asset path must be relative: {relative_path}")
    return posixpath.normpath(resolved.as_posix())


def _read_start_config(config: WorkspaceConfig) -> ConfigParser:
    start_config = ConfigParser()
    start_config.read(config.metadata.start_cfg)
    return start_config


def generate_resource_snapshot(
    config: WorkspaceConfig | None,
    build_dir: Path,
    schema_root: Path,
    *,
    server_id: str | None = None,
    author: str | None = None,
    description: str | None = None,
) -> str | None:
    """Generate a V2 resource snapshot from workspace build output.

    Walks all files in build_dir, stores them as content-addressed blobs using
    resource:// URI identifiers, builds a ResourceIndex, and creates an immutable
    resource snapshot with a structured hash.

    Args:
        config: Workspace configuration (for server metadata). When None,
            metadata is derived from the optional server_id parameter.
        build_dir: Directory containing workspace build output
            (static/, localization/, etc.).
        schema_root: Root for the schema V2 storage (typically cache/remote/).
        server_id: Server ID override when config is None.
        author: Author identifier for the snapshot. Falls back to
            DEV_CONFIGURATION.build.author, then "".
        description: Description for the snapshot. Falls back to
            DEV_CONFIGURATION.build.description, then "".

    Returns:
        The resource snapshot hash on success, or None if build_dir is empty.
    """
    snap_store = SnapshotStore(schema_root)

    if not build_dir.is_dir() or not any(build_dir.iterdir()):
        warning(f"Build directory not found or empty: {build_dir}")
        return None

    resolved_server_id = server_id or ""
    resolved_name: dict[str, str] = {}
    market_server = ""
    game_build = ""
    game_version = ""
    game_region = ""
    game_sync = ""
    game_branch = ""

    if config is not None:
        start_config = _read_start_config(config)
        resolved_server_id = config.metadata.identifier
        resolved_name = config.metadata.name
        market_server = config.metadata.market_server
        game_build = start_config.get("main", "build", fallback="")
        game_version = start_config.get("main", "version", fallback="")
        game_region = start_config.get("main", "region", fallback="")
        game_sync = start_config.get("main", "sync", fallback="")
        game_branch = start_config.get("main", "branch", fallback="")
    elif resolved_server_id:
        pass

    # Resolve author/description: CLI override > dev config > empty string
    from bootstrap.config import DEV_CONFIGURATION

    resolved_author = author
    resolved_description = description
    if resolved_author is None and DEV_CONFIGURATION is not None:
        resolved_author = DEV_CONFIGURATION.build.author
    if resolved_description is None and DEV_CONFIGURATION is not None:
        resolved_description = DEV_CONFIGURATION.build.description
    resolved_author = resolved_author or ""
    resolved_description = resolved_description or ""

    entries: list[tuple[str, str, int]] = []
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

            normalized = _normalize_path(rel.as_posix())
            resource_id = f"resource://{normalized}"

            content_bytes = file_path.read_bytes()
            chash = sha256_content(content_bytes)
            ihash = ident_hash_fn(resource_id)

            dest_path = schema_root / "assets" / "blobs" / ihash[:2] / ihash / chash
            if not dest_path.exists():
                dest_path.parent.mkdir(parents=True, exist_ok=True)
                tmp_path = dest_path.with_suffix(dest_path.suffix + ".tmp")
                tmp_path.write_bytes(content_bytes)
                tmp_path.replace(dest_path)

            entries.append((resource_id, chash, file_path.stat().st_size))
            file_count += 1

    if not entries:
        warning("No files found in build directory")
        return None

    from bootstrap.remote.models import ResourceIndex

    index = ResourceIndex()
    index.schema_version = 1
    for rid, chash, size in entries:
        entry = index.entries.add()
        entry.resource_id = rid
        entry.content_hash = chash
        entry.size = size

    created_at = (
        datetime.datetime.now(datetime.UTC)
        .replace(microsecond=0)
        .isoformat()
        .replace("+00:00", "Z")
    )

    metadata = ResourceSnapshotMetadata(
        serverId=resolved_server_id,
        name=resolved_name,
        gameBuild=game_build,
        gameVersion=game_version,
        gameRegion=game_region,
        gameSync=game_sync,
        gameBranch=game_branch,
        marketServer=market_server,
        author=resolved_author,
        description=resolved_description,
        resourceCount=file_count,
        createdAt=created_at,
    )

    snapshot_hash = snap_store.create_resource_snapshot(metadata, index)

    info(f"Resource snapshot {snapshot_hash[:12]}... ({file_count} files, {skipped_count} skipped)")

    return snapshot_hash


# ---------------------------------------------------------------------------
# Legacy compatibility — delegates to new snapshot generator
# ---------------------------------------------------------------------------


def generate_schema_checkout(
    config: WorkspaceConfig | None,
    build_dir: Path,
    schema_root: Path,
    *,
    server_id: str | None = None,
    author: str | None = None,
    description: str | None = None,
) -> str | None:
    """Legacy wrapper — delegates to generate_resource_snapshot.

    The schema root is now expected to be the unified V2 storage root
    (e.g. cache/remote/). The returned string is the resource snapshot hash
    (previously was a checkout hash — same purpose, new algorithm).
    """
    return generate_resource_snapshot(
        config,
        build_dir,
        schema_root,
        server_id=server_id,
        author=author,
        description=description,
    )
