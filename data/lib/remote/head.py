"""Channel head management — mutable pointers, reflog, and channel registry.

Manages channels/heads/:
  channels.json           — Channel registry
  {channel}/metadata.json — Head pointer (atomic write)
  {channel}/reflog.pb2    — Append-only operational log
"""

from __future__ import annotations

from typing import TYPE_CHECKING

from data.lib.remote.generation import utc_timestamp
from data.lib.remote.models import ChannelHeadMetadata
from data.lib.remote.models import ChannelInfo
from data.lib.remote.models import ChannelRegistry
from data.lib.remote.models import HeadReflog
from data.lib.remote.models import append_head_reflog_entry
from data.lib.remote.models import read_json
from data.lib.remote.models import read_pb2
from data.lib.remote.models import write_json_atomic
from data.lib.remote.models import write_pb2
from data.lib.remote.paths import channel_head_dir
from data.lib.remote.paths import channel_registry_path
from data.lib.remote.paths import head_metadata_path
from data.lib.remote.paths import head_reflog_path


if TYPE_CHECKING:
    from pathlib import Path


class ChannelHeadStore:
    """Manages channel heads — mutable pointers to current generations."""

    def __init__(self, root: Path) -> None:
        self.root = root

    # --- Registry ------------------------------------------------------------

    def get_registry(self) -> ChannelRegistry:
        path = channel_registry_path(self.root)
        if not path.is_file():
            return ChannelRegistry(defaultChannel="", channels={})
        return ChannelRegistry.model_validate(read_json(path))

    def _save_registry(self, registry: ChannelRegistry) -> None:
        write_json_atomic(channel_registry_path(self.root), registry)

    def ensure_channel(self, name: str, label: dict[str, str] | None = None) -> None:
        """Ensure a channel exists in the registry and its head directory is created."""
        registry = self.get_registry()
        if name not in registry.channels:
            registry.channels[name] = ChannelInfo(label=label or {"en": name})
            self._save_registry(registry)

        head_dir = channel_head_dir(self.root, name)
        head_dir.mkdir(parents=True, exist_ok=True)

        meta_path = head_metadata_path(self.root, name)
        if not meta_path.is_file():
            meta = ChannelHeadMetadata(generationHash="", label=label or {"en": name})
            write_json_atomic(meta_path, meta)

        reflog_path = head_reflog_path(self.root, name)
        if not reflog_path.is_file():
            empty_reflog = HeadReflog()
            empty_reflog.schema_version = 1
            write_pb2(reflog_path, empty_reflog)

    def set_default(self, name: str) -> None:
        """Set the default channel in the registry."""
        registry = self.get_registry()
        if name not in registry.channels:
            raise ValueError(f"Channel {name!r} not in registry")
        registry.default_channel = name
        self._save_registry(registry)

    # --- Head operations -----------------------------------------------------

    def get_head(self, channel: str) -> ChannelHeadMetadata:
        meta_path = head_metadata_path(self.root, channel)
        if not meta_path.is_file():
            raise FileNotFoundError(f"Channel head not found: {meta_path}")
        return ChannelHeadMetadata.model_validate(read_json(meta_path))

    def push(self, channel: str, gen_hash: str, author: str = "pipeline") -> None:
        """Advance the channel head to a new generation.

        Appends a reflog entry (op="push"), then atomically updates metadata.json.
        """
        self._ensure_channel_dir(channel)
        current = self._safe_get_head(channel)
        current_hash = current.generation_hash if current else ""

        ts = utc_timestamp()
        self._append_reflog(channel, current_hash, gen_hash, "push", ts)
        self._update_head_metadata(channel, gen_hash, current.label if current else {})

    def revert(self, channel: str, target_hash: str, author: str = "pipeline") -> None:
        """Revert the channel head to a previous generation.

        Appends a reflog entry (op="revert"), then atomically updates metadata.json.
        The target generation must already exist.
        """
        self._ensure_channel_dir(channel)
        current = self.get_head(channel)
        current_hash = current.generation_hash

        ts = utc_timestamp()
        self._append_reflog(channel, current_hash, target_hash, "revert", ts)
        self._update_head_metadata(channel, target_hash, current.label)

    # --- Reflog --------------------------------------------------------------

    def get_reflog(self, channel: str) -> HeadReflog:
        path = head_reflog_path(self.root, channel)
        if not path.is_file():
            empty = HeadReflog()
            empty.schema_version = 1
            return empty
        return read_pb2(path, HeadReflog)

    # --- Internal ------------------------------------------------------------

    def _ensure_channel_dir(self, channel: str) -> None:
        head_dir = channel_head_dir(self.root, channel)
        head_dir.mkdir(parents=True, exist_ok=True)

    def _safe_get_head(self, channel: str) -> ChannelHeadMetadata | None:
        meta_path = head_metadata_path(self.root, channel)
        if not meta_path.is_file():
            return None
        return ChannelHeadMetadata.model_validate(read_json(meta_path))

    def _append_reflog(
        self,
        channel: str,
        from_hash: str,
        to_hash: str,
        op: str,
        timestamp: str,
    ) -> None:
        existing = self.get_reflog(channel)
        append_head_reflog_entry(existing, from_hash, to_hash, op, timestamp)
        write_pb2(head_reflog_path(self.root, channel), existing)

    def _update_head_metadata(
        self,
        channel: str,
        gen_hash: str,
        label: dict[str, str],
    ) -> None:
        meta = ChannelHeadMetadata(generationHash=gen_hash, label=label)
        write_json_atomic(head_metadata_path(self.root, channel), meta)
