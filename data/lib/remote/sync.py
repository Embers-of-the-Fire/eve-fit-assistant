"""Syncer — download remote metadata/catalog to local schema root (no blobs).

Reverse of Publisher: pulls remote state down to the local V2 schema store.
Metadata-only: skips assets/blobs/ entirely.
"""

from __future__ import annotations

import subprocess
import threading

from concurrent.futures import ThreadPoolExecutor
from concurrent.futures import as_completed
from dataclasses import dataclass
from typing import TYPE_CHECKING

from tqdm import tqdm

from data.lib.remote.models import read_pb2
from data.lib.remote.paths import channel_registry_path
from data.lib.remote.paths import generation_dir
from data.lib.remote.paths import head_metadata_path
from data.lib.remote.paths import head_reflog_path
from data.lib.remote.paths import release_snapshot_dir
from data.lib.remote.paths import resource_snapshot_dir


if TYPE_CHECKING:
    from pathlib import Path


@dataclass
class SyncResult:
    """Summary of what was synced for a single channel."""

    channel: str
    registry: bool = False
    head_meta: bool = False
    reflog: bool = False
    generations: int = 0
    resource_snapshots: int = 0
    release_snapshots: int = 0


class Syncer:
    """Download remote metadata/catalog to local schema root (no blobs)."""

    def __init__(
        self,
        local_root: Path,
        *,
        remote_root: str = "efa/v2",
        mc_bin: str | None = None,
        endpoint: str | None = None,
        bucket: str | None = None,
        access_key: str | None = None,
        secret_key: str | None = None,
        alias_name: str | None = None,
        workers: int = 8,
    ) -> None:
        self.local_root = local_root
        self.remote_root = remote_root.rstrip("/")
        self.mc_bin = mc_bin
        self.endpoint = endpoint
        self.bucket = bucket
        self.access_key = access_key
        self.secret_key = secret_key
        self.alias_name = alias_name
        self.workers = workers
        self._alias_set = False
        self._alias_lock = threading.Lock()
        self._s3_prefix: str = ""

    # --- Public API ----------------------------------------------------------

    def sync_channel(self, channel: str, *, max_depth: int = -1) -> SyncResult:
        """Sync a single channel from remote to local. Returns summary."""
        self._ensure_alias()
        result = SyncResult(channel=channel)

        result.registry = self._download_registry()

        result.head_meta = self._download_head_metadata(channel)
        if not result.head_meta:
            return result

        result.reflog = self._download_reflog(channel)

        gen_hash = self._read_head_gen_hash(channel)

        snapshot_hashes: dict[str, set[str]] = {
            "resources": set(),
            "releases": set(),
        }

        depth = 0
        visited: set[str] = set()
        while gen_hash and gen_hash not in visited and (max_depth < 0 or depth < max_depth):
            if self._download_generation(gen_hash):
                result.generations += 1
                visited.add(gen_hash)
                self._collect_snapshot_hashes(gen_hash, snapshot_hashes)
                gen_hash = self._read_gen_parent(gen_hash)
            else:
                break
            depth += 1

        result.resource_snapshots = self._download_snapshots(
            "resources", snapshot_hashes["resources"]
        )
        result.release_snapshots = self._download_snapshots("releases", snapshot_hashes["releases"])

        return result

    def sync_all_channels(self, *, max_depth: int = -1) -> dict[str, SyncResult]:
        """Sync all channels found in the remote registry."""
        self._ensure_alias()
        self._download_registry()

        from data.lib.remote.models import ChannelRegistry
        from data.lib.remote.models import read_json

        registry_path = channel_registry_path(self.local_root)
        if not registry_path.is_file():
            return {}

        registry = ChannelRegistry.model_validate(read_json(registry_path))
        results: dict[str, SyncResult] = {}
        for ch_name in registry.channels:
            results[ch_name] = self.sync_channel(ch_name, max_depth=max_depth)
        return results

    # --- Internal: alias management ------------------------------------------

    def _ensure_alias(self) -> None:
        if self._alias_set:
            return
        with self._alias_lock:
            if self._alias_set:
                return
            if self.mc_bin is None:
                from data.lib.utils import get_command

                self.mc_bin = get_command("mc")

            redacted = "<redacted>"
            _run(
                [
                    self.mc_bin,
                    "alias",
                    "set",
                    self.alias_name,
                    self.endpoint or "",
                    self.access_key or "",
                    self.secret_key or "",
                    "--api",
                    "s3v4",
                ],
                [
                    self.mc_bin,
                    "alias",
                    "set",
                    self.alias_name,
                    (self.endpoint or ""),
                    redacted,
                    redacted,
                    "--api",
                    "s3v4",
                ],
                "SYNC ALIAS",
            )
            self._s3_prefix = f"{self.alias_name}/{self.bucket}/{self.remote_root}"
            self._alias_set = True

    # --- Internal: download helpers ------------------------------------------

    def _s3_path(self, rel_path: str) -> str:
        return f"{self._s3_prefix}/{rel_path}"

    def _download_file(self, rel_path: str, local_path: Path) -> bool:
        """Download a single file from remote. Returns True on success."""
        local_path.parent.mkdir(parents=True, exist_ok=True)
        cmd = [self.mc_bin, "cp", self._s3_path(rel_path), str(local_path)]
        return _run_optional(cmd, rel_path)

    def _download_dir(self, rel_path: str, local_dir: Path) -> bool:
        """Download a directory recursively from remote. Returns True on success."""
        local_dir.mkdir(parents=True, exist_ok=True)
        s3_path = f"{self._s3_path(rel_path)}/"
        cmd = [self.mc_bin, "cp", "--recursive", s3_path, str(local_dir)]
        return _run_optional(cmd, rel_path)

    # --- Internal: specific downloads ----------------------------------------

    def _download_registry(self) -> bool:
        return self._download_file(
            "channels/heads/channels.json", channel_registry_path(self.local_root)
        )

    def _download_head_metadata(self, channel: str) -> bool:
        return self._download_file(
            f"channels/heads/{channel}/metadata.json",
            head_metadata_path(self.local_root, channel),
        )

    def _download_reflog(self, channel: str) -> bool:
        return self._download_file(
            f"channels/heads/{channel}/reflog.pb2",
            head_reflog_path(self.local_root, channel),
        )

    def _download_generation(self, gen_hash: str) -> bool:
        return self._download_dir(
            f"channels/refs/{gen_hash}", generation_dir(self.local_root, gen_hash)
        )

    def _download_resource_snapshot(self, snap_hash: str) -> bool:
        return self._download_dir(
            f"assets/resources/{snap_hash}",
            resource_snapshot_dir(self.local_root, snap_hash),
        )

    def _download_release_snapshot(self, snap_hash: str) -> bool:
        return self._download_dir(
            f"assets/releases/{snap_hash}",
            release_snapshot_dir(self.local_root, snap_hash),
        )

    # --- Internal: data reading ----------------------------------------------

    def _read_head_gen_hash(self, channel: str) -> str | None:
        from data.lib.remote.models import ChannelHeadMetadata
        from data.lib.remote.models import read_json

        meta_path = head_metadata_path(self.local_root, channel)
        if not meta_path.is_file():
            return None
        try:
            meta = ChannelHeadMetadata.model_validate(read_json(meta_path))
            return meta.generation_hash or None
        except Exception:
            return None

    def _read_gen_parent(self, gen_hash: str) -> str | None:
        from data.lib.remote.models import GenerationMetadata
        from data.lib.remote.models import read_json

        meta_path = generation_dir(self.local_root, gen_hash) / "metadata.json"
        if not meta_path.is_file():
            return None
        try:
            meta = GenerationMetadata.model_validate(read_json(meta_path))
            return meta.parent or None
        except Exception:
            return None

    def _collect_snapshot_hashes(self, gen_hash: str, snapshot_hashes: dict[str, set[str]]) -> None:
        from data.lib.remote.models import GenerationPointer
        from data.lib.remote.models import GenerationResources

        gen_dir = generation_dir(self.local_root, gen_hash)

        resource_path = gen_dir / "resources.pb2"
        if resource_path.is_file():
            try:
                resources = read_pb2(resource_path, GenerationResources)
                for entry in resources.entries:
                    if entry.snapshot_hash:
                        snapshot_hashes["resources"].add(entry.snapshot_hash)
            except Exception:
                pass

        release_path = gen_dir / "releases.pb2"
        if release_path.is_file():
            try:
                ptr = read_pb2(release_path, GenerationPointer)
                if ptr.snapshot_hash:
                    snapshot_hashes["releases"].add(ptr.snapshot_hash)
            except Exception:
                pass

    def _download_snapshots(self, snap_type: str, hashes: set[str]) -> int:
        """Download all snapshots of a type in parallel. Returns count downloaded."""
        if not hashes:
            return 0

        download_fn = {
            "resources": self._download_resource_snapshot,
            "releases": self._download_release_snapshot,
        }[snap_type]

        label = snap_type.capitalize()
        count = 0
        with ThreadPoolExecutor(max_workers=self.workers) as ex:
            futures = {ex.submit(download_fn, h): h for h in hashes}
            with tqdm(total=len(futures), desc=f"Syncing {label}", unit="snap") as pbar:
                for future in as_completed(futures):
                    if future.result():
                        count += 1
                    pbar.update(1)
        return count


def _run(
    cmd: list[str],
    redacted_cmd: list[str],
    title: str,
    timeout: float = 300,
) -> None:
    try:
        out = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=timeout,
        )
    except subprocess.TimeoutExpired:
        raise OSError(f"{title} timed out after {timeout}s: {' '.join(redacted_cmd)}") from None
    if out.returncode != 0:
        msg = f"Failed to execute [{out.returncode}]: {' '.join(redacted_cmd)}"
        stderr = (out.stderr or "").strip()
        if stderr:
            msg += f"\n{stderr}"
        raise OSError(msg)


def _run_optional(cmd: list[str], label: str, timeout: float = 300) -> bool:
    try:
        out = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=timeout,
        )
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return False
    return out.returncode == 0
