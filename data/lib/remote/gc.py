"""Garbage collection — reachability-based pruning of unreferenced entities.

Reachability algorithm (spec §12):
  1. Start from every channel head → collect all generationHash values.
  2. For each head generation, walk parent chain → collect all reachable gens.
  3. For each reachable generation, collect all snapshot hashes.
  4. For each reachable resource snapshot, collect all blob (ident_hash, content_hash) pairs.
  5. Delete everything not in the reachable set.
"""

from __future__ import annotations

import shutil

from typing import TYPE_CHECKING

from data.lib.remote.generation import GenerationStore
from data.lib.remote.hash import ident_hash
from data.lib.remote.head import ChannelHeadStore
from data.lib.remote.models import ReachabilitySet
from data.lib.remote.models import read_pb2
from data.lib.remote.paths import resource_snapshot_dir


if TYPE_CHECKING:
    from pathlib import Path


class GarbageCollector:
    """Reachability-based GC for both local workspace and remote tiers."""

    def __init__(self, root: Path) -> None:
        self.root = root
        self.gen_store = GenerationStore(root)
        self.head_store = ChannelHeadStore(root)

    def collect_reachable(self) -> ReachabilitySet:
        reachable = ReachabilitySet()

        registry = self.head_store.get_registry()
        for channel_name in registry.channels:
            try:
                head = self.head_store.get_head(channel_name)
            except FileNotFoundError:
                continue
            if not head.generation_hash:
                continue

            try:
                for gen in self.gen_store.walk_parent_chain(head.generation_hash):
                    reachable.generations.add(gen.hash)

                    if gen.release_pointer.snapshot_hash:
                        reachable.release_snapshots.add(gen.release_pointer.snapshot_hash)

                    if gen.announcement_pointer.snapshot_hash:
                        reachable.announcement_snapshots.add(gen.announcement_pointer.snapshot_hash)

                    for entry in gen.resources.entries:
                        snap_hash = entry.snapshot_hash
                        if not snap_hash:
                            continue
                        reachable.resource_snapshots.add(snap_hash)
                        self._collect_resource_blobs(snap_hash, reachable)

            except FileNotFoundError:
                continue

        return reachable

    def _collect_resource_blobs(self, snap_hash: str, reachable: ReachabilitySet) -> None:
        from data.lib.remote.models import ResourceIndex

        snap_dir = resource_snapshot_dir(self.root, snap_hash)
        proto_path = snap_dir / "resources.pb2"
        if not proto_path.is_file():
            return
        try:
            index = read_pb2(proto_path, ResourceIndex)
        except Exception:
            return
        for entry in index.entries:
            reachable.blobs.add((ident_hash(entry.resource_id), entry.content_hash))

    def prune(self, dry_run: bool = False) -> list[str]:
        reachable = self.collect_reachable()
        deleted: list[str] = []

        deleted.extend(self._prune_entities("generations", reachable.generations, dry_run))
        deleted.extend(
            self._prune_entities("resource_snapshots", reachable.resource_snapshots, dry_run)
        )
        deleted.extend(
            self._prune_entities("release_snapshots", reachable.release_snapshots, dry_run)
        )
        deleted.extend(
            self._prune_entities(
                "announcement_snapshots", reachable.announcement_snapshots, dry_run
            )
        )
        deleted.extend(self._prune_blobs(reachable.blobs, dry_run))
        deleted.extend(self._prune_tmp_dirs(dry_run))

        return deleted

    def _prune_entities(self, label: str, reachable_hashes: set[str], dry_run: bool) -> list[str]:
        deleted: list[str] = []
        base_dir_map = {
            "generations": self.root / "channels" / "refs",
            "resource_snapshots": self.root / "assets" / "resources",
            "release_snapshots": self.root / "assets" / "releases",
            "announcement_snapshots": self.root / "assets" / "announcements",
        }
        base_dir = base_dir_map[label]
        if not base_dir.is_dir():
            return deleted

        for entry in sorted(base_dir.iterdir()):
            if not entry.is_dir():
                continue
            if entry.name.startswith("tmp"):
                continue
            if entry.name not in reachable_hashes:
                deleted.append(str(entry))
                if not dry_run:
                    shutil.rmtree(entry, ignore_errors=True)

        return deleted

    def _prune_blobs(
        self,
        reachable_blobs: set[tuple[str, str]],
        dry_run: bool,
    ) -> list[str]:
        deleted: list[str] = []
        blobs_root = self.root / "assets" / "blobs"
        if not blobs_root.is_dir():
            return deleted

        for shard_dir in sorted(blobs_root.iterdir()):
            if not shard_dir.is_dir() or shard_dir.name.startswith("tmp"):
                continue
            for ident_dir in sorted(shard_dir.iterdir()):
                if not ident_dir.is_dir():
                    continue
                for blob_file in sorted(ident_dir.iterdir()):
                    if not blob_file.is_file():
                        continue
                    ident = ident_dir.name
                    content = (
                        blob_file.name.rsplit(".tmp", 1)[0]
                        if blob_file.name.endswith(".tmp")
                        else blob_file.name
                    )
                    if (ident, content) not in reachable_blobs:
                        deleted.append(str(blob_file))
                        if not dry_run:
                            blob_file.unlink(missing_ok=True)

                remaining = list(ident_dir.iterdir())
                if not remaining:
                    deleted.append(str(ident_dir))
                    if not dry_run:
                        ident_dir.rmdir()

            remaining = list(shard_dir.iterdir())
            if not remaining:
                deleted.append(str(shard_dir))
                if not dry_run:
                    shard_dir.rmdir()

        return deleted

    def _prune_tmp_dirs(self, dry_run: bool) -> list[str]:
        deleted: list[str] = []
        tmp_patterns = ["tmp_", "_temp"]

        for root_dir in [
            self.root / "assets" / "blobs",
            self.root / "assets" / "resources",
            self.root / "assets" / "releases",
            self.root / "assets" / "announcements",
            self.root / "channels" / "refs",
        ]:
            if not root_dir.is_dir():
                continue
            for entry in sorted(root_dir.iterdir()):
                if not entry.is_dir():
                    continue
                name = entry.name
                if any(name.startswith(p) or name.endswith(p) for p in tmp_patterns):
                    deleted.append(str(entry))
                    if not dry_run:
                        shutil.rmtree(entry, ignore_errors=True)

        return deleted
