"""Remote content session management — EFA V2 unified schema subsystem.

Provides generation creation, channel head management, publishing to remote,
garbage collection, and verification.

Usage:
    from data.lib.remote import SessionManager

    mgr = SessionManager(root=Path("cache/remote"))
    mgr.ensure_channel("testing", {"en": "Testing"})
    gen_hash = mgr.create_generation(...)
    mgr.push("testing", gen_hash)
    mgr.publish("testing")

Typical root path: cache/remote/ (implicit structure, not configured).
"""

from __future__ import annotations

from typing import TYPE_CHECKING

from data.lib.remote.blob import BlobStore
from data.lib.remote.channel import Channel as Channel
from data.lib.remote.gc import GarbageCollector
from data.lib.remote.generation import GenerationStore
from data.lib.remote.head import ChannelHeadStore
from data.lib.remote.publish import Publisher
from data.lib.remote.snapshot import SnapshotStore
from data.lib.remote.sync import Syncer
from data.lib.remote.verify import Verifier


if TYPE_CHECKING:
    from pathlib import Path

    from data.lib.remote.models import GenerationPointer
    from data.lib.remote.models import GenerationResources
    from data.lib.remote.models import Issue
    from data.lib.remote.models import ServerIndex


class SessionManagerCommittedError(Exception):
    """Raised when an operation is attempted on an already-committed session."""


class SessionManagerInvalidError(Exception):
    """Raised when no session is currently active."""


class SessionManager:
    """Top-level facade for the EFA V2 schema dev-side pipeline.

    All operations work within a single root directory (e.g. cache/remote/).
    """

    def __init__(self, root: Path) -> None:
        self.root = root
        self.blob_store = BlobStore(root)
        self.snap_store = SnapshotStore(root)
        self.gen_store = GenerationStore(root)
        self.head_store = ChannelHeadStore(root)
        self._gc = GarbageCollector(root)
        self._verifier = Verifier(root)

    # --- Channel registry ----------------------------------------------------

    def ensure_channel(self, name: str, label: dict[str, str] | None = None) -> None:
        self.head_store.ensure_channel(name, label)

    def set_default_channel(self, name: str) -> None:
        self.head_store.set_default(name)

    def get_channels(self):
        return self.head_store.get_registry()

    # --- Blob ----------------------------------------------------------------

    def store_blob(self, data: bytes, uri: str) -> tuple[str, str]:
        """Store a blob. Returns (ident_hash, content_hash)."""
        from data.lib.remote.hash import ident_hash

        ihash = ident_hash(uri)
        chash = self.blob_store.store(data, ihash)
        return ihash, chash

    def store_blob_file(self, src: Path, uri: str) -> tuple[str, str]:
        """Store a blob from a file path. Returns (ident_hash, content_hash)."""
        from data.lib.remote.hash import ident_hash

        ihash = ident_hash(uri)
        chash = self.blob_store.store_from_path(src, ihash)
        return ihash, chash

    # --- Snapshot creation ---------------------------------------------------

    def create_resource_snapshot(
        self,
        metadata,
        index_msg,
    ) -> str:
        return self.snap_store.create_resource_snapshot(metadata, index_msg)

    def create_release_snapshot(self, metadata, index_msg) -> str:
        return self.snap_store.create_release_snapshot(metadata, index_msg)

    def create_announcement_snapshot(self, metadata, index_msg) -> str:
        return self.snap_store.create_announcement_snapshot(metadata, index_msg)

    # --- Generation creation -------------------------------------------------

    def create_generation(
        self,
        metadata,
        server_index: ServerIndex,
        resources: GenerationResources,
        release_pointer: GenerationPointer,
        announcement_pointer: GenerationPointer,
    ) -> str:
        return self.gen_store.create(
            metadata=metadata,
            server_index_msg=server_index,
            resources_msg=resources,
            release_pointer=release_pointer,
            announcement_pointer=announcement_pointer,
        )

    def load_generation(self, gen_hash: str):
        return self.gen_store.load(gen_hash)

    # --- Head management -----------------------------------------------------

    def push(self, channel: str, gen_hash: str) -> None:
        self.head_store.push(channel, gen_hash)

    def revert(self, channel: str, target_hash: str) -> None:
        self.head_store.revert(channel, target_hash)

    def get_head(self, channel: str):
        return self.head_store.get_head(channel)

    def get_reflog(self, channel: str):
        return self.head_store.get_reflog(channel)

    # --- Publishing ----------------------------------------------------------

    def make_publisher(
        self,
        *,
        mc_bin: str | None = None,
        endpoint: str | None = None,
        bucket: str | None = None,
        access_key: str | None = None,
        secret_key: str | None = None,
        alias_name: str | None = None,
        origin_dir: Path | None = None,
        workers: int = 8,
    ) -> Publisher:
        return Publisher(
            local_root=self.root,
            mc_bin=mc_bin,
            endpoint=endpoint,
            bucket=bucket,
            access_key=access_key,
            secret_key=secret_key,
            alias_name=alias_name,
            origin_dir=origin_dir,
            workers=workers,
        )

    # --- Syncing -------------------------------------------------------------

    def make_syncer(
        self,
        *,
        mc_bin: str | None = None,
        endpoint: str | None = None,
        bucket: str | None = None,
        access_key: str | None = None,
        secret_key: str | None = None,
        alias_name: str | None = None,
        workers: int = 8,
    ) -> Syncer:
        return Syncer(
            local_root=self.root,
            mc_bin=mc_bin,
            endpoint=endpoint,
            bucket=bucket,
            access_key=access_key,
            secret_key=secret_key,
            alias_name=alias_name,
            workers=workers,
        )

    def publish(self, channel: str, *, workers: int | None = None, **kwargs) -> None:
        """Publish the full chain (head → generation → snapshots → blobs)."""
        pub = self.make_publisher(workers=workers if workers is not None else 8, **kwargs)
        pub.publish_all_for_head(channel)

    def publish_to_origin(self, channel: str, origin_dir: Path) -> None:
        pub = self.make_publisher(origin_dir=origin_dir)
        pub.publish_all_for_head(channel)

    # --- Maintenance ---------------------------------------------------------

    def gc(self, dry_run: bool = False) -> list[str]:
        return self._gc.prune(dry_run=dry_run)

    def verify(self) -> dict[str, list[Issue]]:
        return self._verifier.verify_all()

    def repair(self, workspace_root: Path | None = None) -> int:
        verifier = Verifier(self.root, workspace_root)
        return verifier.repair()

    # --- Accessors -----------------------------------------------------------

    def get_blob_store(self) -> BlobStore:
        return self.blob_store

    def get_head_store(self) -> ChannelHeadStore:
        return self.head_store
