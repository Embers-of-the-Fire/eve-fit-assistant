"""Data models for EFA V2 schema — JSON metadata and protobuf wrappers."""

# ruff: noqa: F821 (protobuf types are provided lazily via __getattr__)

from __future__ import annotations

import importlib

from dataclasses import dataclass
from dataclasses import field
from typing import TYPE_CHECKING

from pydantic import BaseModel
from pydantic import Field

from bootstrap.remote.canonical_json import encode_canonical_json


if TYPE_CHECKING:
    from pathlib import Path


# ---------------------------------------------------------------------------
# JSON metadata models
# ---------------------------------------------------------------------------


class ResourceSnapshotMetadata(BaseModel):
    schema_version: int = Field(default=1, alias="schemaVersion")
    server_id: str = Field(alias="serverId")
    name: dict[str, str] = Field(default_factory=dict)
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
    offerings: list[str] = Field(default_factory=list)
    author: str = Field(default="")
    description: str = Field(default="")
    release_count: int = Field(alias="releaseCount")
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
        import json

        return json.load(f)


def write_json(path: Path, data: dict | BaseModel) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(encode_canonical_json(data))


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
    "AndroidArtifactVariant": ("release_index_pb2", "AndroidArtifactVariant"),
    "AndroidArtifacts": ("release_index_pb2", "AndroidArtifacts"),
    "ServerIndex": ("server_index_pb2", "ServerIndex"),
    "GenerationResources": ("generation_resources_pb2", "GenerationResources"),
    "GenerationPointer": ("generation_pointer_pb2", "GenerationPointer"),
    "HeadReflog": ("head_reflog_pb2", "HeadReflog"),
    "CheckoutReflog": ("checkout_reflog_pb2", "CheckoutReflog"),
    "ServerHistory": ("server_history_pb2", "ServerHistory"),
}


def _load_pb2_type(name: str) -> type:
    module_name, class_name = _PB2_ALIAS_MAP[name]
    module = importlib.import_module(f"bootstrap.data.schema.{module_name}")
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


def make_server_history() -> ServerHistory:
    msg = _load_pb2_type("ServerHistory")()
    msg.schema_version = 1
    return msg


def _server_index_lookup(
    server_index: ServerIndex,
) -> dict[str, tuple[str, str]]:
    """Build a {server_id: (game_build, game_version)} lookup."""
    result: dict[str, tuple[str, str]] = {}
    for entry in server_index.servers:
        result[entry.server_id] = (entry.game_build, entry.game_version)
    return result


def merge_generation_into_history(
    history: ServerHistory,
    *,
    generation_hash: str,
    timestamp: str,
    resources: GenerationResources,
    server_index: ServerIndex,
) -> ServerHistory:
    """Merge one generation's resource changes into a ServerHistory.

    Returns a *new* ServerHistory message. The original *history* is not
    mutated. Servers not present in *resources* are carried forward unchanged.
    Servers that are present get a new Snapshot prepended only when the
    snapshot hash differs from the current head (or when the server has no
    prior snapshots).
    """
    idx = _server_index_lookup(server_index)

    existing: dict[str, ServerHistory.ServerEntry] = {}
    for entry in history.servers:
        existing[entry.server_id] = entry

    result = make_server_history()

    changed_ids: set[str] = set()

    for res_entry in resources.entries:
        sid = res_entry.server_id
        snap_hash = res_entry.snapshot_hash
        changed_ids.add(sid)

        entry = result.servers.add()
        entry.server_id = sid

        old = existing.get(sid)

        if old is not None and old.snapshots and old.snapshots[0].snapshot_hash == snap_hash:
            for s in old.snapshots:
                ns = entry.snapshots.add()
                ns.CopyFrom(s)
        else:
            game_build, game_version = idx.get(sid, ("", ""))
            ns = entry.snapshots.add()
            ns.snapshot_hash = snap_hash
            ns.generation_hash = generation_hash
            ns.timestamp = timestamp
            if game_build:
                ns.game_build = game_build
            if game_version:
                ns.game_version = game_version
            if old is not None:
                for s in old.snapshots:
                    ns2 = entry.snapshots.add()
                    ns2.CopyFrom(s)

    for sid, old in existing.items():
        if sid not in changed_ids:
            entry = result.servers.add()
            entry.server_id = sid
            for s in old.snapshots:
                ns = entry.snapshots.add()
                ns.CopyFrom(s)

    return result


def make_generation_pointer(snapshot_hash: str) -> GenerationPointer:
    msg = _load_pb2_type("GenerationPointer")()
    msg.schema_version = 1
    msg.snapshot_hash = snapshot_hash
    return msg


def _make_artifact_variant(data: dict[str, str]) -> AndroidArtifactVariant:
    v = _load_pb2_type("AndroidArtifactVariant")()
    v.identifier = data["identifier"]
    v.content_hash = data["content_hash"]
    return v


def make_release_index(
    release_id: str,
    version: str,
    android: dict[str, dict[str, str]] | None = None,
) -> ReleaseIndex:
    """Build a ReleaseIndex with optional AndroidArtifacts.

    android keys: general (required), armv7, arm64, x64 (optional).
    Each value is a dict with {"identifier": str, "content_hash": str}.
    identifier is the literal release URI (e.g. "release://1.0.0/android/general").
    content_hash is the SHA-256 of the artifact file bytes.
    """
    msg = _load_pb2_type("ReleaseIndex")()
    msg.schema_version = 1
    msg.id = release_id
    msg.version = version
    if android:
        aa = _load_pb2_type("AndroidArtifacts")()
        aa.general.CopyFrom(_make_artifact_variant(android["general"]))
        if "armv7" in android:
            aa.armv7.CopyFrom(_make_artifact_variant(android["armv7"]))
        if "arm64" in android:
            aa.arm64.CopyFrom(_make_artifact_variant(android["arm64"]))
        if "x64" in android:
            aa.x64.CopyFrom(_make_artifact_variant(android["x64"]))
        msg.android.CopyFrom(aa)
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
    blobs: set[tuple[str, str]] = field(default_factory=set)
