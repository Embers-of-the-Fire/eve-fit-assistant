"""Garbage collection — reachability-based pruning of unreferenced entities.

Reachability algorithm (spec §8.1, §8.3):
  1. Start from every channel head → load its `history.pb2`.
  2. The head history is the authoritative reachability root for resource
     snapshots: every `snapshot_hash` it records (and the snapshot's blobs) is
     kept, decoupled from the generation that introduced it.
  3. Generation retention is policy-driven: keep only the head + the last N
     ancestor generations (``retention_depth``). Resource snapshots of pruned
     generations survive solely via the history root from step 2.
  4. Heads without a `history.pb2` (pre-feature, no feature-era commit yet)
     fall back to the legacy full parent-chain walk so nothing is lost.
  5. Delete everything not in the reachable set, then strip dead `history.pb2`
     copies from retained non-head generations.
"""

from __future__ import annotations

import shutil

from typing import TYPE_CHECKING

from bootstrap.remote.generation import GenerationStore
from bootstrap.remote.hash import ident_hash
from bootstrap.remote.head import ChannelHeadStore
from bootstrap.remote.models import ReachabilitySet
from bootstrap.remote.models import read_pb2
from bootstrap.remote.paths import generation_dir
from bootstrap.remote.paths import resource_snapshot_dir


if TYPE_CHECKING:
    from pathlib import Path


class GarbageCollector:
    """Reachability-based GC for both local workspace and remote tiers.

    ``retention_depth`` is the number of ancestor (non-head) generations kept
    per channel head, walked from the tip; the head itself is always kept, so a
    head retains ``retention_depth + 1`` generations total. ``0`` (default)
    keeps the head only.
    """

    def __init__(self, root: Path, retention_depth: int = 0) -> None:
        self.root = root
        self.retention_depth = max(retention_depth, 0)
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
            self._collect_for_head(head.generation_hash, reachable)

        return reachable

    def _collect_for_head(self, head_hash: str, reachable: ReachabilitySet) -> None:
        history = self._load_head_history(head_hash)
        if history is None:
            # §8.1 step 4: pre-feature head — legacy full parent-chain walk.
            self._collect_full_chain(head_hash, reachable)
            return

        # §8.1: head history is the reachability root for resource snapshots and
        # their blobs, decoupled from the introducing generation.
        for server in history.servers:
            for snap in server.snapshots:
                if not snap.snapshot_hash:
                    continue
                reachable.resource_snapshots.add(snap.snapshot_hash)
                self._collect_resource_blobs(snap.snapshot_hash, reachable)

        # §8.3: retention policy — keep head + last N generations and their
        # release snapshots. Pruned generations' resource snapshots survive via
        # the history root above.
        self._collect_retained_generations(head_hash, reachable)

    def _collect_retained_generations(self, head_hash: str, reachable: ReachabilitySet) -> None:
        keep = self.retention_depth + 1
        try:
            for idx, gen in enumerate(self.gen_store.walk_parent_chain(head_hash)):
                if idx >= keep:
                    break
                reachable.generations.add(gen.hash)
                if gen.release_pointer.snapshot_hash:
                    reachable.release_snapshots.add(gen.release_pointer.snapshot_hash)
        except FileNotFoundError:
            pass

    def _collect_full_chain(self, head_hash: str, reachable: ReachabilitySet) -> None:
        try:
            for gen in self.gen_store.walk_parent_chain(head_hash):
                reachable.generations.add(gen.hash)

                if gen.release_pointer.snapshot_hash:
                    reachable.release_snapshots.add(gen.release_pointer.snapshot_hash)

                for entry in gen.resources.entries:
                    snap_hash = entry.snapshot_hash
                    if not snap_hash:
                        continue
                    reachable.resource_snapshots.add(snap_hash)
                    self._collect_resource_blobs(snap_hash, reachable)
        except FileNotFoundError:
            pass

    def _load_head_history(self, head_hash: str):
        from bootstrap.remote.models import ServerHistory

        history_path = generation_dir(self.root, head_hash) / "history.pb2"
        if not history_path.is_file():
            return None
        return read_pb2(history_path, ServerHistory)

    def _head_hashes(self) -> set[str]:
        heads: set[str] = set()
        registry = self.head_store.get_registry()
        for channel_name in registry.channels:
            try:
                head = self.head_store.get_head(channel_name)
            except FileNotFoundError:
                continue
            if head.generation_hash:
                heads.add(head.generation_hash)
        return heads

    def _collect_resource_blobs(self, snap_hash: str, reachable: ReachabilitySet) -> None:
        from bootstrap.remote.models import ResourceIndex

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
        head_hashes = self._head_hashes()
        deleted: list[str] = []

        deleted.extend(self._prune_entities("generations", reachable.generations, dry_run))
        deleted.extend(
            self._prune_entities("resource_snapshots", reachable.resource_snapshots, dry_run)
        )
        deleted.extend(
            self._prune_entities("release_snapshots", reachable.release_snapshots, dry_run)
        )
        deleted.extend(self._prune_blobs(reachable.blobs, dry_run))
        deleted.extend(self._strip_nonhead_history(head_hashes, reachable.generations, dry_run))
        deleted.extend(self._prune_tmp_dirs(dry_run))

        return deleted

    def _strip_nonhead_history(
        self,
        head_hashes: set[str],
        retained: set[str],
        dry_run: bool,
    ) -> list[str]:
        """§8.2: only the head's `history.pb2` is ever read by clients; strip the
        dead copies from retained non-head generations. Never touch a head."""
        deleted: list[str] = []
        for gen_hash in sorted(retained):
            if gen_hash in head_hashes:
                continue
            history_path = generation_dir(self.root, gen_hash) / "history.pb2"
            if history_path.is_file():
                deleted.append(str(history_path))
                if not dry_run:
                    history_path.unlink(missing_ok=True)
        return deleted

    def _prune_entities(self, label: str, reachable_hashes: set[str], dry_run: bool) -> list[str]:
        deleted: list[str] = []
        base_dir_map = {
            "generations": self.root / "channels" / "refs",
            "resource_snapshots": self.root / "assets" / "resources",
            "release_snapshots": self.root / "assets" / "releases",
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
