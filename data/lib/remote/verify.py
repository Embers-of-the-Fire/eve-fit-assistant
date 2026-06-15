"""Verification and repair — integrity checks across the full schema tree.

Verification levels (spec workflow.md §3.7):
  1. Channel head integrity — head points to existing generation
  2. Generation integrity — recompute hash matches directory name
  3. Snapshot integrity — recompute hash matches directory name
  4. Blob integrity — recompute content_hash matches recorded value
  5. Repair — re-upload missing/corrupt entities from local workspace
"""

from __future__ import annotations

import shutil

from dataclasses import dataclass
from pathlib import Path

from data.lib.remote.generation import GenerationStore
from data.lib.remote.hash import content_hash as _content_hash
from data.lib.remote.hash import generation_hash as _generation_hash
from data.lib.remote.hash import ident_hash as _ident_hash
from data.lib.remote.hash import snapshot_hash as _snapshot_hash
from data.lib.remote.head import ChannelHeadStore
from data.lib.remote.models import read_pb2 as _models_read_pb2
from data.lib.remote.paths import blob_path
from data.lib.remote.paths import generation_dir
from data.lib.remote.paths import head_metadata_path
from data.lib.remote.paths import head_reflog_path


@dataclass
class Issue:
    entity: str
    entity_type: str
    severity: str
    message: str


class Verifier:
    """Integrity verification across heads, generations, snapshots, and blobs."""

    def __init__(self, root: Path, workspace_root: Path | None = None) -> None:
        self.root = root
        self.workspace_root = workspace_root
        self.gen_store = GenerationStore(root)
        self.head_store = ChannelHeadStore(root)

    # --- Full verification ---------------------------------------------------

    def verify_all(self) -> dict[str, list[Issue]]:
        return {
            "heads": self.verify_head_integrity(),
            "generations": self.verify_generation_integrity(),
            "snapshots": self.verify_snapshot_integrity(),
            "blobs": self.verify_blob_integrity(),
        }

    # --- Head integrity ------------------------------------------------------

    def verify_head_integrity(self) -> list[Issue]:
        issues: list[Issue] = []
        registry = self.head_store.get_registry()

        for channel_name in registry.channels:
            meta_path = head_metadata_path(self.root, channel_name)
            if not meta_path.is_file():
                issues.append(
                    Issue(
                        entity=channel_name,
                        entity_type="head",
                        severity="error",
                        message=f"Missing metadata.json for channel {channel_name!r}",
                    )
                )
                continue

            try:
                head = self.head_store.get_head(channel_name)
            except Exception as exc:
                issues.append(
                    Issue(
                        entity=channel_name,
                        entity_type="head",
                        severity="error",
                        message=f"Failed to read head metadata: {exc}",
                    )
                )
                continue

            if not head.generation_hash:
                issues.append(
                    Issue(
                        entity=channel_name,
                        entity_type="head",
                        severity="warning",
                        message="Head has no generationHash (uninitialized)",
                    )
                )
                continue

            gen_dir = generation_dir(self.root, head.generation_hash)
            if not gen_dir.is_dir():
                issues.append(
                    Issue(
                        entity=channel_name,
                        entity_type="head",
                        severity="error",
                        message=(
                            f"Head points to generation {head.generation_hash[:12]}..."
                            " but directory not found"
                        ),
                    )
                )

            reflog_path = head_reflog_path(self.root, channel_name)
            if reflog_path.is_file():
                try:
                    from data.lib.remote.models import HeadReflog

                    reflog = _models_read_pb2(reflog_path, HeadReflog)
                    if reflog.entries:
                        last = reflog.entries[-1]
                        if last.to != head.generation_hash:
                            issues.append(
                                Issue(
                                    entity=channel_name,
                                    entity_type="head",
                                    severity="error",
                                    message=(
                                        f"Reflog last entry.to ({last.to[:12]}...)"
                                        f" != head.generationHash"
                                        f" ({head.generation_hash[:12]}...)"
                                    ),
                                )
                            )
                except Exception:
                    pass

        return issues

    # --- Generation integrity -----------------------------------------------

    def verify_generation_integrity(self) -> list[Issue]:
        issues: list[Issue] = []
        refs_dir = self.root / "channels" / "refs"
        if not refs_dir.is_dir():
            return issues

        for entry in sorted(refs_dir.iterdir()):
            if not entry.is_dir():
                continue
            if entry.name.startswith("tmp"):
                continue
            if not (entry / "metadata.json").is_file():
                continue

            expected = entry.name
            try:
                files = {}
                for fname in [
                    "metadata.json",
                    "server.pb2",
                    "resources.pb2",
                    "releases.pb2",
                    "announcements.pb2",
                ]:
                    fp = entry / fname
                    if not fp.is_file():
                        raise FileNotFoundError(f"Missing file: {fp}")
                    files[fname] = fp.read_bytes()

                computed = _generation_hash(files)
                if computed != expected:
                    issues.append(
                        Issue(
                            entity=expected[:12] + "...",
                            entity_type="generation",
                            severity="error",
                            message=(
                                f"Hash mismatch: expected {expected[:12]}..."
                                f", computed {computed[:12]}..."
                            ),
                        )
                    )
            except Exception as exc:
                issues.append(
                    Issue(
                        entity=expected[:12] + "...",
                        entity_type="generation",
                        severity="error",
                        message=str(exc),
                    )
                )

        return issues

    # --- Snapshot integrity -------------------------------------------------

    def verify_snapshot_integrity(self) -> list[Issue]:
        issues: list[Issue] = []
        issues.extend(
            self._verify_snapshots_of_type("resource", self.root / "assets" / "resources")
        )
        issues.extend(self._verify_snapshots_of_type("release", self.root / "assets" / "releases"))
        issues.extend(
            self._verify_snapshots_of_type("announcement", self.root / "assets" / "announcements")
        )
        return issues

    def _verify_snapshots_of_type(self, snap_type: str, base_dir: Path) -> list[Issue]:
        issues: list[Issue] = []
        if not base_dir.is_dir():
            return issues

        proto_names = {
            "resource": "resources.pb2",
            "release": "releases.pb2",
            "announcement": "announcements.pb2",
        }
        proto_name = proto_names[snap_type]

        for snap_dir in sorted(base_dir.iterdir()):
            if not snap_dir.is_dir():
                continue
            if snap_dir.name.startswith("tmp"):
                continue
            if not (snap_dir / "metadata.json").is_file():
                continue

            expected = snap_dir.name
            try:
                meta_path = snap_dir / "metadata.json"
                proto_path = snap_dir / proto_name
                if not proto_path.is_file():
                    raise FileNotFoundError(f"Missing file: {proto_path}")

                files = {
                    "metadata.json": meta_path.read_bytes(),
                    proto_name: proto_path.read_bytes(),
                }
                computed = _snapshot_hash(snap_type, files)  # type: ignore[arg-type]
                if computed != expected:
                    issues.append(
                        Issue(
                            entity=expected[:12] + "...",
                            entity_type=f"{snap_type}_snapshot",
                            severity="error",
                            message=(
                                f"Hash mismatch: expected {expected[:12]}..."
                                f", computed {computed[:12]}..."
                            ),
                        )
                    )
            except Exception as exc:
                issues.append(
                    Issue(
                        entity=expected[:12] + "...",
                        entity_type=f"{snap_type}_snapshot",
                        severity="error",
                        message=str(exc),
                    )
                )

        return issues

    # --- Blob integrity -----------------------------------------------------

    def verify_blob_integrity(self) -> list[Issue]:
        issues: list[Issue] = []

        resources_dir = self.root / "assets" / "resources"
        if not resources_dir.is_dir():
            return issues

        for snap_dir in sorted(resources_dir.iterdir()):
            if not snap_dir.is_dir():
                continue
            proto_path = snap_dir / "resources.pb2"
            if not proto_path.is_file():
                continue

            try:
                from data.lib.remote.models import ResourceIndex

                index = _models_read_pb2(proto_path, ResourceIndex)
            except Exception:
                continue

            for entry in index.entries:
                ihash = _ident_hash(entry.resource_id)
                bpath = blob_path(self.root, ihash, entry.content_hash)
                if not bpath.is_file():
                    issues.append(
                        Issue(
                            entity=f"{entry.resource_id}",
                            entity_type="blob",
                            severity="error",
                            message=f"Missing blob: {bpath}",
                        )
                    )
                    continue

                try:
                    actual_hash = _content_hash(bpath.read_bytes())
                    if actual_hash != entry.content_hash:
                        issues.append(
                            Issue(
                                entity=f"{entry.resource_id}",
                                entity_type="blob",
                                severity="error",
                                message=(
                                    f"Content hash mismatch: expected"
                                    f" {entry.content_hash[:12]}..."
                                    f", got {actual_hash[:12]}..."
                                ),
                            )
                        )
                except Exception as exc:
                    issues.append(
                        Issue(
                            entity=f"{entry.resource_id}",
                            entity_type="blob",
                            severity="error",
                            message=str(exc),
                        )
                    )

        return issues

    # --- Repair --------------------------------------------------------------

    def repair(self) -> int:
        """Attempt to repair missing/corrupt entities from workspace_root.

        Returns count of entities repaired.
        """
        if self.workspace_root is None:
            return 0

        fixed = 0
        all_issues = self.verify_all()

        for head_issue in all_issues.get("heads", []):
            if "directory not found" in head_issue.message:
                gen_hash = head_issue.message.split("generation ")[-1]
                gen_hash = gen_hash.split(" ")[0]
                if len(gen_hash) >= 64:
                    actual_hash = gen_hash[:64]
                    src = generation_dir(self.workspace_root, actual_hash)
                    dst = generation_dir(self.root, actual_hash)
                    if src.is_dir() and not dst.exists():
                        shutil.copytree(src, dst)
                        fixed += 1

        for issue in all_issues.get("blobs", []):
            if issue.severity == "error" and "Missing blob" in issue.message:
                path_suffix = issue.message.split(": ", 1)[-1]
                if path_suffix.startswith("Missing blob: "):
                    path_suffix = path_suffix[len("Missing blob: ") :]
                src = self.workspace_root / Path(path_suffix).relative_to(self.root)
                dst = Path(path_suffix)
                if src.is_file() and not dst.is_file():
                    dst.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(src, dst)
                    fixed += 1

        return fixed
