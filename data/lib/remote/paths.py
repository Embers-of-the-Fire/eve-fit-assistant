"""Path computation helpers for EFA V2 schema layout.

All paths are relative to the storage root (e.g. cache/remote/).
"""

from __future__ import annotations

from typing import TYPE_CHECKING


if TYPE_CHECKING:
    from pathlib import Path


def blob_path(root: Path, ident_hash: str, content_hash: str) -> Path:
    """assets/blobs/{2c}/{ident_hash}/{content_hash}"""
    return root / "assets" / "blobs" / ident_hash[:2] / ident_hash / content_hash


def blob_ident_dir(root: Path, ident_hash: str) -> Path:
    """assets/blobs/{2c}/{ident_hash}/"""
    return root / "assets" / "blobs" / ident_hash[:2] / ident_hash


def blob_shard_dir(root: Path, ident_hash: str) -> Path:
    """assets/blobs/{2c}/"""
    return root / "assets" / "blobs" / ident_hash[:2]


def resource_snapshot_dir(root: Path, snapshot_hash: str) -> Path:
    """assets/resources/{snapshot_hash}/"""
    return root / "assets" / "resources" / snapshot_hash


def release_snapshot_dir(root: Path, snapshot_hash: str) -> Path:
    """assets/releases/{snapshot_hash}/"""
    return root / "assets" / "releases" / snapshot_hash


def announcement_snapshot_dir(root: Path, snapshot_hash: str) -> Path:
    """assets/announcements/{snapshot_hash}/"""
    return root / "assets" / "announcements" / snapshot_hash


def generation_dir(root: Path, generation_hash: str) -> Path:
    """channels/refs/{generation_hash}/"""
    return root / "channels" / "refs" / generation_hash


def channel_head_dir(root: Path, channel: str) -> Path:
    """channels/heads/{channel}/"""
    return root / "channels" / "heads" / channel


def channel_registry_path(root: Path) -> Path:
    """channels/heads/channels.json"""
    return root / "channels" / "heads" / "channels.json"


def head_metadata_path(root: Path, channel: str) -> Path:
    """channels/heads/{channel}/metadata.json"""
    return channel_head_dir(root, channel) / "metadata.json"


def head_reflog_path(root: Path, channel: str) -> Path:
    """channels/heads/{channel}/reflog.pb2"""
    return channel_head_dir(root, channel) / "reflog.pb2"


# ---------------------------------------------------------------------------
# Temp / atomic write helpers
# ---------------------------------------------------------------------------


def temp_generation_dir(root: Path) -> Path:
    """channels/refs/tmp_gen/"""
    return root / "channels" / "refs" / "tmp_gen"


def temp_resource_snapshot_dir(root: Path) -> Path:
    """assets/resources/tmp_snapshot/"""
    return root / "assets" / "resources" / "tmp_snapshot"


def temp_release_snapshot_dir(root: Path) -> Path:
    """assets/releases/tmp_snapshot/"""
    return root / "assets" / "releases" / "tmp_snapshot"


def temp_announcement_snapshot_dir(root: Path) -> Path:
    """assets/announcements/tmp_snapshot/"""
    return root / "assets" / "announcements" / "tmp_snapshot"
