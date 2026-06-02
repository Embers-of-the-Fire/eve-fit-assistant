from __future__ import annotations

import hashlib

from typing import TYPE_CHECKING

from pydantic import BaseModel
from pydantic import Field

from data.lib.log import info
from data.lib.utils import get_file_sha256


if TYPE_CHECKING:
    from pathlib import Path


class ManifestFile(BaseModel):
    path: str
    size: int
    sha256: str


class SnapshotManifest(BaseModel):
    bundleSchemaVersion: int
    compatibleBundleSchemaVersions: list[int]
    bundleId: str
    generateTimestamp: int
    files: list[ManifestFile] = Field(default_factory=list)

    @property
    def file_map(self) -> dict[str, ManifestFile]:
        return {file.path: file for file in self.files}


def build_snapshot_manifest(
    bundle_id: str,
    generate_timestamp: int,
    bundle_schema_version: int,
    compatible_bundle_schema_versions: list[int],
    root_dir: Path,
    *,
    skipped_paths: set[str] | None = None,
) -> SnapshotManifest:
    skipped = skipped_paths or set()
    files: list[ManifestFile] = []

    for file_path in sorted(root_dir.rglob("*")):
        if not file_path.is_file():
            continue

        relative_path = file_path.relative_to(root_dir).as_posix()
        if relative_path in skipped:
            continue

        files.append(
            ManifestFile(
                path=relative_path,
                size=file_path.stat().st_size,
                sha256=get_file_sha256(file_path),
            )
        )

    return SnapshotManifest(
        bundleSchemaVersion=bundle_schema_version,
        compatibleBundleSchemaVersions=compatible_bundle_schema_versions,
        bundleId=bundle_id,
        generateTimestamp=generate_timestamp,
        files=files,
    )


def manifest_json(manifest: SnapshotManifest) -> str:
    return manifest.model_dump_json(indent=4)


def manifest_hash(manifest: SnapshotManifest) -> str:
    return hashlib.sha256(manifest_json(manifest).encode("utf-8")).hexdigest()


def write_snapshot_manifest(path: Path, manifest: SnapshotManifest) -> str:
    content = manifest_json(manifest)
    path.write_text(content, encoding="utf-8")
    digest = hashlib.sha256(content.encode("utf-8")).hexdigest()
    info(f"Generated snapshot manifest at {path}.")
    return digest


def load_snapshot_manifest(path: Path) -> SnapshotManifest:
    import json as _json

    content = path.read_text(encoding="utf-8")
    raw = _json.loads(content)
    if "bundleSchemaVersion" not in raw:
        old_version = raw.get("schemaVersion", 1)
        raw["bundleSchemaVersion"] = old_version
        raw["compatibleBundleSchemaVersions"] = [old_version]
    return SnapshotManifest.model_validate(raw)
