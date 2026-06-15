"""Snapshot store — resource, release, and announcement snapshot CRUD.

Snapshots are immutable, content-addressed collections stored at:
  assets/{type}/{snapshot_hash}/
    metadata.json
    {type}.pb2

Snapshot creation uses atomic write (tmp + rename after computing hash).
"""

from __future__ import annotations

from typing import TYPE_CHECKING
from typing import Literal

from data.lib.remote.hash import snapshot_hash as _compute_snapshot_hash
from data.lib.remote.models import AnnouncementSnapshotMetadata
from data.lib.remote.models import ReleaseSnapshotMetadata
from data.lib.remote.models import ResourceSnapshotMetadata
from data.lib.remote.models import read_json
from data.lib.remote.models import read_pb2
from data.lib.remote.models import write_json
from data.lib.remote.models import write_pb2
from data.lib.remote.paths import announcement_snapshot_dir
from data.lib.remote.paths import release_snapshot_dir
from data.lib.remote.paths import resource_snapshot_dir
from data.lib.remote.paths import temp_announcement_snapshot_dir
from data.lib.remote.paths import temp_release_snapshot_dir
from data.lib.remote.paths import temp_resource_snapshot_dir


if TYPE_CHECKING:
    from pathlib import Path

    from data.lib.remote.models import AnnouncementIndex
    from data.lib.remote.models import ReleaseIndex
    from data.lib.remote.models import ResourceIndex


SnapshotType = Literal["resource", "release", "announcement"]

_PROTO_NAME: dict[SnapshotType, str] = {
    "resource": "resources.pb2",
    "release": "releases.pb2",
    "announcement": "announcements.pb2",
}


def _get_proto_class(snap_type: SnapshotType) -> type:
    from data.lib.remote.models import AnnouncementIndex
    from data.lib.remote.models import ReleaseIndex
    from data.lib.remote.models import ResourceIndex

    return {
        "resource": ResourceIndex,
        "release": ReleaseIndex,
        "announcement": AnnouncementIndex,
    }[snap_type]


class SnapshotStore:
    """Read/write snapshots under assets/{type}/{snapshot_hash}/."""

    def __init__(self, root: Path) -> None:
        self.root = root

    # --- Resource snapshots --------------------------------------------------

    def create_resource_snapshot(
        self,
        metadata: ResourceSnapshotMetadata,
        index_msg: ResourceIndex,
    ) -> str:
        return self._create_snapshot("resource", metadata, index_msg)

    def load_resource_snapshot(
        self, snapshot_hash: str
    ) -> tuple[ResourceSnapshotMetadata, ResourceIndex]:
        from data.lib.remote.models import ResourceIndex

        return self._load_snapshot(
            "resource", snapshot_hash, ResourceSnapshotMetadata, ResourceIndex
        )

    def delete_resource_snapshot(self, snapshot_hash: str) -> None:
        self._delete_snapshot("resource", snapshot_hash)

    def list_resource_snapshots(self) -> list[str]:
        return self._list_snapshots(self.root / "assets" / "resources")

    # --- Release snapshots ---------------------------------------------------

    def create_release_snapshot(
        self,
        metadata: ReleaseSnapshotMetadata,
        index_msg: ReleaseIndex,
    ) -> str:
        return self._create_snapshot("release", metadata, index_msg)

    def load_release_snapshot(
        self, snapshot_hash: str
    ) -> tuple[ReleaseSnapshotMetadata, ReleaseIndex]:
        from data.lib.remote.models import ReleaseIndex

        return self._load_snapshot("release", snapshot_hash, ReleaseSnapshotMetadata, ReleaseIndex)

    def delete_release_snapshot(self, snapshot_hash: str) -> None:
        self._delete_snapshot("release", snapshot_hash)

    def list_release_snapshots(self) -> list[str]:
        return self._list_snapshots(self.root / "assets" / "releases")

    # --- Announcement snapshots ---------------------------------------------

    def create_announcement_snapshot(
        self,
        metadata: AnnouncementSnapshotMetadata,
        index_msg: AnnouncementIndex,
    ) -> str:
        return self._create_snapshot("announcement", metadata, index_msg)

    def load_announcement_snapshot(
        self, snapshot_hash: str
    ) -> tuple[AnnouncementSnapshotMetadata, AnnouncementIndex]:
        from data.lib.remote.models import AnnouncementIndex

        return self._load_snapshot(
            "announcement", snapshot_hash, AnnouncementSnapshotMetadata, AnnouncementIndex
        )

    def delete_announcement_snapshot(self, snapshot_hash: str) -> None:
        self._delete_snapshot("announcement", snapshot_hash)

    def list_announcement_snapshots(self) -> list[str]:
        return self._list_snapshots(self.root / "assets" / "announcements")

    # --- Internal ------------------------------------------------------------

    def _create_snapshot(
        self,
        snap_type: SnapshotType,
        metadata,
        index_msg,
    ) -> str:
        import shutil

        temp_dir_map = {
            "resource": temp_resource_snapshot_dir(self.root),
            "release": temp_release_snapshot_dir(self.root),
            "announcement": temp_announcement_snapshot_dir(self.root),
        }
        proto_name = _PROTO_NAME[snap_type]
        dir_map = {
            "resource": resource_snapshot_dir,
            "release": release_snapshot_dir,
            "announcement": announcement_snapshot_dir,
        }

        temp_dir = temp_dir_map[snap_type]
        if temp_dir.exists():
            shutil.rmtree(temp_dir, ignore_errors=True)
        temp_dir.mkdir(parents=True, exist_ok=True)

        write_json(temp_dir / "metadata.json", metadata)
        write_pb2(temp_dir / proto_name, index_msg)

        metadata_bytes = (temp_dir / "metadata.json").read_bytes()
        index_bytes = (temp_dir / proto_name).read_bytes()

        files = {"metadata.json": metadata_bytes, proto_name: index_bytes}
        snap_hash = _compute_snapshot_hash(snap_type, files)

        target_dir = dir_map[snap_type](self.root, snap_hash)
        if not target_dir.exists():
            temp_dir.rename(target_dir)
        else:
            shutil.rmtree(temp_dir, ignore_errors=True)

        return snap_hash

    def _load_snapshot(self, snap_type, snapshot_hash, meta_cls, proto_cls):
        dir_map = {
            "resource": resource_snapshot_dir,
            "release": release_snapshot_dir,
            "announcement": announcement_snapshot_dir,
        }
        proto_name = _PROTO_NAME[snap_type]
        snap_dir = dir_map[snap_type](self.root, snapshot_hash)

        if not snap_dir.is_dir():
            raise FileNotFoundError(f"Snapshot not found: {snap_dir}")

        metadata = meta_cls.model_validate(read_json(snap_dir / "metadata.json"))
        index = read_pb2(snap_dir / proto_name, proto_cls)
        return metadata, index

    def _delete_snapshot(self, snap_type, snapshot_hash) -> None:
        import shutil

        dir_map = {
            "resource": resource_snapshot_dir,
            "release": release_snapshot_dir,
            "announcement": announcement_snapshot_dir,
        }
        snap_dir = dir_map[snap_type](self.root, snapshot_hash)
        if snap_dir.exists():
            shutil.rmtree(snap_dir, ignore_errors=True)

    @staticmethod
    def _list_snapshots(typed_dir: Path) -> list[str]:
        if not typed_dir.is_dir():
            return []
        return sorted(
            d.name for d in typed_dir.iterdir() if d.is_dir() and (d / "metadata.json").is_file()
        )
