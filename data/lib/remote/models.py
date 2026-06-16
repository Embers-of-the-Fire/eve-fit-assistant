"""Data models for EFA V2 schema — JSON metadata and protobuf wrappers."""

# ruff: noqa: F821 (protobuf types are provided lazily via __getattr__)

from __future__ import annotations

import importlib
import json

from dataclasses import dataclass
from dataclasses import field
from typing import TYPE_CHECKING

from pydantic import BaseModel
from pydantic import Field


if TYPE_CHECKING:
    from pathlib import Path


# ---------------------------------------------------------------------------
# JSON metadata models
# ---------------------------------------------------------------------------


class ResourceSnapshotMetadata(BaseModel):
    schema_version: int = Field(default=1, alias="schemaVersion")
    server_id: str = Field(alias="serverId")
    game_build: str = Field(alias="gameBuild")
    game_version: str = Field(alias="gameVersion")
    game_region: str = Field(default="", alias="gameRegion")
    game_sync: str = Field(default="", alias="gameSync")
    game_branch: str = Field(default="", alias="gameBranch")
    author: str = Field(default="")
    description: str = Field(default="")
    resource_count: int = Field(alias="resourceCount")
    created_at: str = Field(alias="createdAt")


class ReleaseSnapshotMetadata(BaseModel):
    schema_version: int = Field(default=1, alias="schemaVersion")
    version_min: str | None = Field(default=None, alias="versionMin")
    version_max: str | None = Field(default=None, alias="versionMax")
    author: str = Field(default="")
    description: str = Field(default="")
    release_count: int = Field(alias="releaseCount")
    created_at: str = Field(alias="createdAt")


class AnnouncementSnapshotMetadata(BaseModel):
    schema_version: int = Field(default=1, alias="schemaVersion")
    author: str = Field(default="")
    description: str = Field(default="")
    announcement_count: int = Field(alias="announcementCount")
    created_at: str = Field(alias="createdAt")


class GenerationMetadata(BaseModel):
    schema_version: int = Field(default=1, alias="schemaVersion")
    parent: str | None = None
    channel: str
    timestamp: str
    subject: str = ""


class ChannelHeadMetadata(BaseModel):
    """Server-side channel head metadata."""

    schema_version: int = Field(default=1, alias="schemaVersion")
    generation_hash: str = Field(alias="generationHash")
    updated_at: str = Field(default="", alias="updatedAt")
    label: dict[str, str] = Field(default_factory=dict)


class ChannelHeadMetadataClient(BaseModel):
    """Client-side channel head metadata — adds updatedAt."""

    schema_version: int = Field(default=1, alias="schemaVersion")
    generation_hash: str = Field(alias="generationHash")
    updated_at: str = Field(alias="updatedAt")
    label: dict[str, str] = Field(default_factory=dict)


class ChannelInfo(BaseModel):
    label: dict[str, str] = Field(default_factory=dict)


class ChannelRegistry(BaseModel):
    """Server-side channel registry (channels.json)."""

    schema_version: int = Field(default=1, alias="schemaVersion")
    default_channel: str = Field(alias="defaultChannel")
    channels: dict[str, ChannelInfo] = Field(default_factory=dict)


class CheckoutEntry(BaseModel):
    channel: str
    server_id: str = Field(alias="serverId")
    resource_snapshot_hash: str = Field(alias="resourceSnapshotHash")
    name: dict[str, str]
    created_at: str = Field(alias="createdAt")


class CheckoutRegistry(BaseModel):
    """Client-side checkout registry (checkouts.json)."""

    schema_version: int = Field(default=1, alias="schemaVersion")
    active_checkout_id: str | None = Field(default=None, alias="activeCheckoutId")
    checkouts: dict[str, CheckoutEntry] = Field(default_factory=dict)


class CheckoutMetadata(BaseModel):
    """Client-side checkout metadata."""

    schema_version: int = Field(default=1, alias="schemaVersion")
    channel: str
    resource_snapshot_hash: str = Field(alias="resourceSnapshotHash")
    server_id: str = Field(alias="serverId")
    game_build: str = Field(default="", alias="gameBuild")
    game_version: str = Field(default="", alias="gameVersion")
    game_region: str = Field(default="", alias="gameRegion")
    game_sync: str = Field(default="", alias="gameSync")
    game_branch: str = Field(default="", alias="gameBranch")
    name: dict[str, str]
    created_at: str = Field(alias="createdAt")


# ---------------------------------------------------------------------------
# JSON read/write helpers
# ---------------------------------------------------------------------------


def read_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def write_json(path: Path, data: dict | BaseModel) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if isinstance(data, BaseModel):
        text = data.model_dump_json(indent=2, by_alias=True) + "\n"
    else:
        text = json.dumps(data, indent=2, ensure_ascii=False) + "\n"
    path.write_text(text, encoding="utf-8")


def write_json_atomic(path: Path, data: dict | BaseModel) -> None:
    """Write to .tmp then atomically rename to path."""
    tmp_path = path.with_suffix(path.suffix + ".tmp")
    write_json(tmp_path, data)
    tmp_path.rename(path)


# ---------------------------------------------------------------------------
# Protobuf read/write helpers
# ---------------------------------------------------------------------------


def read_pb2(path: Path, message_cls):
    msg = message_cls()
    msg.ParseFromString(path.read_bytes())
    return msg


def write_pb2(path: Path, message) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(message.SerializeToString())


def write_pb2_atomic(path: Path, message) -> None:
    tmp_path = path.with_suffix(path.suffix + ".tmp")
    write_pb2(tmp_path, message)
    tmp_path.rename(path)


# ---------------------------------------------------------------------------
# Lazy protobuf type access — avoids triggering imports before protobuf files
# are generated (e.g. when x.py is imported on a fresh checkout).
# ---------------------------------------------------------------------------

_PB2_ALIAS_MAP: dict[str, tuple[str, str]] = {
    "ResourceIndex": ("resource_index_pb2", "ResourceIndex"),
    "ReleaseIndex": ("release_index_pb2", "ReleaseIndex"),
    "AnnouncementIndex": ("announcement_index_pb2", "AnnouncementIndex"),
    "ServerIndex": ("server_index_pb2", "ServerIndex"),
    "GenerationResources": ("generation_resources_pb2", "GenerationResources"),
    "GenerationPointer": ("generation_pointer_pb2", "GenerationPointer"),
    "HeadReflog": ("head_reflog_pb2", "HeadReflog"),
    "CheckoutReflog": ("checkout_reflog_pb2", "CheckoutReflog"),
}


def _load_pb2_type(name: str) -> type:
    module_name, class_name = _PB2_ALIAS_MAP[name]
    module = importlib.import_module(f"data.lib.schema.{module_name}")
    return getattr(module, class_name)


def __getattr__(name: str):
    if name in _PB2_ALIAS_MAP:
        val = _load_pb2_type(name)
        globals()[name] = val
        return val
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")


def make_resource_index(entries: list[tuple[str, str, int]]) -> ResourceIndex:
    """Build a ResourceIndex from (resource_id, content_hash, size) tuples."""
    msg = _load_pb2_type("ResourceIndex")()
    msg.schema_version = 1
    for rid, content, size in entries:
        entry = msg.entries.add()
        entry.resource_id = rid
        entry.content_hash = content
        entry.size = size
    return msg


def make_server_index(
    servers: list[tuple[str, dict[str, str], str, str, str, str, str]],
) -> ServerIndex:
    """Build a ServerIndex from (server_id, name_map, game_build, game_version,
    region, sync, branch) tuples."""
    msg = _load_pb2_type("ServerIndex")()
    msg.schema_version = 1
    for sid, name_map, build, version, region, sync, branch in servers:
        entry = msg.servers.add()
        entry.server_id = sid
        for locale, display_name in name_map.items():
            entry.name[locale] = display_name
        entry.game_build = build
        entry.game_version = version
        if region:
            entry.region = region
        if sync:
            entry.sync = sync
        if branch:
            entry.branch = branch
    return msg


def make_generation_resources(
    mappings: list[tuple[str, str]],
) -> GenerationResources:
    """Build a GenerationResources from (server_id, snapshot_hash) tuples."""
    msg = _load_pb2_type("GenerationResources")()
    msg.schema_version = 1
    for sid, snap_hash in mappings:
        entry = msg.entries.add()
        entry.server_id = sid
        entry.snapshot_hash = snap_hash
    return msg


def make_generation_pointer(snapshot_hash: str) -> GenerationPointer:
    msg = _load_pb2_type("GenerationPointer")()
    msg.schema_version = 1
    msg.snapshot_hash = snapshot_hash
    return msg


def make_release_index(
    entries: list[tuple[str, str, list[str], str]],
) -> ReleaseIndex:
    """Build a ReleaseIndex from (id, version, offerings, ident_hash) tuples."""
    msg = _load_pb2_type("ReleaseIndex")()
    msg.schema_version = 1
    for rid, version, offerings, ihash in entries:
        entry = msg.entries.add()
        entry.id = rid
        entry.version = version
        entry.offerings.extend(offerings)
        entry.ident_hash = ihash
    return msg


def make_announcement_index(
    entries: list[dict],
) -> AnnouncementIndex:
    """Build an AnnouncementIndex from a list of entry dicts.

    Each dict can have: id, first_published_at, updated_at, content_hashes,
    version_min, version_max, is_version_update.
    """
    msg = _load_pb2_type("AnnouncementIndex")()
    msg.schema_version = 1
    for e in entries:
        entry = msg.entries.add()
        entry.id = e["id"]
        entry.first_published_at = e["first_published_at"]
        entry.updated_at = e["updated_at"]
        for locale, chash in e.get("content_hashes", {}).items():
            entry.content_hashes[locale] = chash
        if "version_min" in e:
            entry.version_min = e["version_min"]
        if "version_max" in e:
            entry.version_max = e["version_max"]
        if e.get("is_version_update", False):
            entry.is_version_update = True
    return msg


def make_head_reflog_entry(
    from_hash: str,
    to_hash: str,
    op: str,
    timestamp: str,
) -> HeadReflog:
    """Build a single-entry HeadReflog."""
    msg = _load_pb2_type("HeadReflog")()
    msg.schema_version = 1
    entry = msg.entries.add()
    setattr(entry, "from", from_hash)
    entry.to = to_hash
    entry.op = op
    entry.timestamp = timestamp
    return msg


def append_head_reflog_entry(
    reflog: HeadReflog,
    from_hash: str,
    to_hash: str,
    op: str,
    timestamp: str,
) -> HeadReflog:
    entry = reflog.entries.add()
    setattr(entry, "from", from_hash)
    entry.to = to_hash
    entry.op = op
    entry.timestamp = timestamp
    return reflog


def make_checkout_reflog() -> CheckoutReflog:
    msg = _load_pb2_type("CheckoutReflog")()
    msg.schema_version = 1
    return msg


def append_checkout_reflog_entry(
    reflog: CheckoutReflog,
    from_hash: str,
    to_hash: str,
    timestamp: str,
) -> CheckoutReflog:
    entry = reflog.entries.add()
    setattr(entry, "from", from_hash)
    entry.to = to_hash
    entry.timestamp = timestamp
    return reflog


# ---------------------------------------------------------------------------
# Reachability set (used by GC)
# ---------------------------------------------------------------------------


@dataclass
class ReachabilitySet:
    generations: set[str] = field(default_factory=set)
    resource_snapshots: set[str] = field(default_factory=set)
    release_snapshots: set[str] = field(default_factory=set)
    announcement_snapshots: set[str] = field(default_factory=set)
    blobs: set[tuple[str, str]] = field(default_factory=set)
