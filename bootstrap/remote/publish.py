"""Publisher — idempotent upload of generations, snapshots, and blobs to S3/MinIO.

Priority order: blobs → snapshots → generation → head (spec §11.3 remark).
Idempotent: skip if remote file exists (content-addressed, immutable).
"""

from __future__ import annotations

import subprocess
import threading

from concurrent.futures import ThreadPoolExecutor
from concurrent.futures import as_completed
from typing import TYPE_CHECKING

from google.protobuf.message import DecodeError
from tqdm import tqdm

from bootstrap.remote.generation import GenerationStore
from bootstrap.remote.hash import ident_hash
from bootstrap.remote.head import ChannelHeadStore
from bootstrap.remote.models import read_pb2
from bootstrap.remote.paths import blob_path
from bootstrap.remote.paths import channel_head_dir
from bootstrap.remote.paths import channel_registry_path
from bootstrap.remote.paths import generation_dir
from bootstrap.remote.paths import release_snapshot_dir
from bootstrap.remote.paths import resource_snapshot_dir
from bootstrap.remote.resource_manager import ResourceManager
from bootstrap.remote.snapshot import SnapshotStore


_RELEASE_VARIANT_NAMES = ("general", "armv7", "arm64", "x64")


if TYPE_CHECKING:
    from concurrent.futures import Future
    from pathlib import Path

    from bootstrap.remote.generation import Generation
    from bootstrap.remote.models import GenerationPointer
    from bootstrap.remote.models import GenerationResources


class Publisher:
    """Upload local schema state to S3/MinIO or local origin."""

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
        origin_dir: Path | None = None,
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
        self.origin_dir = origin_dir
        self.workers = workers
        self.gen_store = GenerationStore(local_root)
        self.snap_store = SnapshotStore(local_root)
        self.head_store = ChannelHeadStore(local_root)
        self._alias_set = False
        self._alias_lock = threading.Lock()

    # --- Public API ----------------------------------------------------------

    def publish_generation(self, channel: str, gen_hash: str) -> None:
        """Upload a single generation and all its referenced snapshots and blobs."""
        gen = self.gen_store.load(gen_hash)
        parent_gen = self._load_parent_generation(gen)
        prefixes = self._gen_remote_prefix()

        self._ensure_alias()

        rm = ResourceManager(
            self, expected_total=self._count_unique_blobs(gen, parent_gen, prefixes)
        )
        with rm.progress(), ThreadPoolExecutor(max_workers=self.workers) as ex:
            futures: list[Future[None]] = []
            changed_resource_hashes = self._changed_resource_snapshots(gen, parent_gen)
            changed_release = self._changed_release(gen, parent_gen)
            snapshot_uploads = self._enumerate_resource_blobs(
                gen.resources,
                prefixes,
                rm,
                ex,
                futures,
                only_snapshots=changed_resource_hashes,
            )
            release_dir_upload = self._enumerate_release_blobs(
                gen.release_pointer,
                prefixes,
                rm,
                ex,
                futures,
                skip=not changed_release,
            )
            for fut in as_completed(futures):
                fut.result()
        rm.log_summary()

        for snap_dir, remote in snapshot_uploads:
            self._upload_dir(snap_dir, remote)
        if release_dir_upload is not None:
            self._upload_dir(*release_dir_upload)
        self._upload_dir(
            generation_dir(self.local_root, gen_hash), prefixes + f"channels/refs/{gen_hash}"
        )

    def publish_head(self, channel: str) -> None:
        """Upload channel head metadata and reflog to remote."""
        prefixes = self._gen_remote_prefix()
        head_dir = channel_head_dir(self.local_root, channel)
        self._upload_tree(head_dir, prefixes + f"channels/heads/{channel}")

        registry_path = channel_registry_path(self.local_root)
        if registry_path.is_file():
            self._upload_file(registry_path, prefixes + "channels/heads/channels.json")

    def publish_all_for_head(self, channel: str) -> None:
        """Publish full chain from head → generation → snapshots → blobs → head."""
        head = self.head_store.get_head(channel)
        if not head.generation_hash:
            return

        gen = self.gen_store.load(head.generation_hash)
        parent_gen = self._load_parent_generation(gen)
        prefixes = self._gen_remote_prefix()

        self._ensure_alias()

        rm = ResourceManager(
            self, expected_total=self._count_unique_blobs(gen, parent_gen, prefixes)
        )
        with rm.progress(), ThreadPoolExecutor(max_workers=self.workers) as ex:
            futures: list[Future[None]] = []
            changed_resource_hashes = self._changed_resource_snapshots(gen, parent_gen)
            changed_release = self._changed_release(gen, parent_gen)
            snapshot_uploads = self._enumerate_resource_blobs(
                gen.resources,
                prefixes,
                rm,
                ex,
                futures,
                only_snapshots=changed_resource_hashes,
            )
            release_dir_upload = self._enumerate_release_blobs(
                gen.release_pointer,
                prefixes,
                rm,
                ex,
                futures,
                skip=not changed_release,
            )
            for fut in as_completed(futures):
                fut.result()
        rm.log_summary()

        for snap_dir, remote in snapshot_uploads:
            self._upload_dir(snap_dir, remote)
        if release_dir_upload is not None:
            self._upload_dir(*release_dir_upload)
        self._upload_dir(
            generation_dir(self.local_root, head.generation_hash),
            prefixes + f"channels/refs/{head.generation_hash}",
        )

        self.publish_head(channel)

    # --- Internal ------------------------------------------------------------

    def _gen_remote_prefix(self) -> str:
        """Remote S3 prefix for efa/v2.

        Returns the base prefix (``<remote_root>/``). The channel is NOT
        embedded here — each caller appends the appropriate path segment
        (e.g. ``channels/heads/{channel}/``), keeping the prefix
        channel-independent.
        """
        return f"{self.remote_root}/"

    def _load_parent_generation(self, gen: Generation) -> Generation | None:
        """Load the parent generation, if one is recorded and present locally."""
        parent_hash = gen.metadata.parent or ""
        if not parent_hash:
            return None
        try:
            return self.gen_store.load(parent_hash)
        except FileNotFoundError:
            return None

    def _changed_resource_snapshots(
        self, gen: Generation, parent_gen: Generation | None
    ) -> set[str]:
        """Return the set of resource snapshot hashes that changed vs. parent.

        If there is no parent generation, every snapshot is considered changed.
        """
        if parent_gen is None:
            return {entry.snapshot_hash for entry in gen.resources.entries}
        parent_hashes = {
            entry.server_id: entry.snapshot_hash for entry in parent_gen.resources.entries
        }
        return {
            entry.snapshot_hash
            for entry in gen.resources.entries
            if parent_hashes.get(entry.server_id) != entry.snapshot_hash
        }

    def _changed_release(self, gen: Generation, parent_gen: Generation | None) -> bool:
        """True when the release pointer differs from the parent generation."""
        if not gen.release_pointer.snapshot_hash:
            return False
        if parent_gen is None:
            return True
        return gen.release_pointer.snapshot_hash != parent_gen.release_pointer.snapshot_hash

    def _ensure_alias(self) -> None:
        """Set the S3 alias once (thread-safe, idempotent)."""
        if self._alias_set:
            return
        with self._alias_lock:
            if self._alias_set:
                return
            if self.origin_dir is not None:
                self._alias_set = True
                return
            if self.mc_bin is None:
                from bootstrap.utils import get_command

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
                "PUBLISH ALIAS",
            )
            self._alias_set = True

    def _enumerate_resource_blobs(
        self,
        resources: GenerationResources,
        prefixes: str,
        rm: ResourceManager,
        ex: ThreadPoolExecutor,
        futures: list[Future[None]],
        *,
        only_snapshots: set[str] | None = None,
    ) -> list[tuple[Path, str]]:
        """Collect changed snapshot dir uploads and dispatch their blobs to the RM.

        Snapshots not listed in ``only_snapshots`` are skipped entirely under the
        assumption that they were already uploaded as part of the parent
        generation. When ``only_snapshots`` is None, every snapshot is processed.
        """
        from bootstrap.remote.models import ResourceIndex

        seen: set[str] = set()
        snapshot_uploads: list[tuple[Path, str]] = []
        for entry in resources.entries:
            snap_hash = entry.snapshot_hash
            if snap_hash in seen:
                continue
            seen.add(snap_hash)

            if only_snapshots is not None and snap_hash not in only_snapshots:
                continue

            snap_dir = resource_snapshot_dir(self.local_root, snap_hash)
            if not snap_dir.is_dir():
                raise FileNotFoundError(
                    f"Resource snapshot directory missing: {snap_dir} "
                    f"(referenced by generation {resources.gen_hash})"
                )

            snapshot_uploads.append((snap_dir, prefixes + f"assets/resources/{snap_hash}"))

            index = read_pb2(snap_dir / "resources.pb2", ResourceIndex)
            for ri_entry in index.entries:
                ihash = ident_hash(ri_entry.resource_id)
                bpath = blob_path(self.local_root, ihash, ri_entry.content_hash)
                remote = prefixes + f"assets/blobs/{ihash[:2]}/{ihash}/{ri_entry.content_hash}"
                if not bpath.is_file():

                    def _check_remote_resource(
                        local_bpath: Path = bpath,
                        remote_path: str = remote,
                        snap: str = snap_hash,
                        res_id: str = ri_entry.resource_id,
                    ) -> None:
                        if self._remote_exists(remote_path):
                            return
                        raise FileNotFoundError(
                            f"Resource blob missing: {local_bpath} "
                            f"(snapshot {snap}, resource {res_id})"
                        )

                    futures.append(ex.submit(_check_remote_resource))
                    continue
                futures.append(ex.submit(rm.process_blob, bpath, remote))
        return snapshot_uploads

    def _enumerate_release_blobs(
        self,
        pointer: GenerationPointer,
        prefixes: str,
        rm: ResourceManager,
        ex: ThreadPoolExecutor,
        futures: list[Future[None]],
        *,
        skip: bool = False,
    ) -> tuple[Path, str] | None:
        """Dispatch release APK blobs to the RM; return the release snapshot dir upload.

        When ``skip`` is True, the release snapshot is assumed unchanged from the
        parent generation and is not enumerated or uploaded.
        """
        from bootstrap.remote.models import ReleaseIndex

        if skip:
            return None

        snap_hash = pointer.snapshot_hash
        if not snap_hash:
            return None

        snap_dir = release_snapshot_dir(self.local_root, snap_hash)
        if not snap_dir.is_dir():
            return None

        dir_upload = (snap_dir, prefixes + f"assets/releases/{snap_hash}")

        pb2_file = snap_dir / "releases.pb2"
        if not pb2_file.is_file():
            raise FileNotFoundError(
                f"Release index file missing: {pb2_file} "
                f"(snapshot {snap_hash}, referenced by generation)"
            )

        index = read_pb2(pb2_file, ReleaseIndex)

        if not index.HasField("android"):
            return dir_upload

        android = index.android
        for variant_name in _RELEASE_VARIANT_NAMES:
            if not android.HasField(variant_name):
                continue
            v = getattr(android, variant_name)
            ihash = ident_hash(v.identifier)
            bpath = blob_path(self.local_root, ihash, v.content_hash)
            remote = prefixes + f"assets/blobs/{ihash[:2]}/{ihash}/{v.content_hash}"
            if not bpath.is_file():

                def _check_remote_release(
                    local_bpath: Path = bpath,
                    remote_path: str = remote,
                    snap: str = snap_hash,
                    variant: str = variant_name,
                ) -> None:
                    if self._remote_exists(remote_path):
                        return
                    raise FileNotFoundError(
                        f"Release blob missing: {local_bpath} (snapshot {snap}, variant {variant})"
                    )

                futures.append(ex.submit(_check_remote_release))
                continue
            futures.append(ex.submit(rm.process_blob, bpath, remote))
        return dir_upload

    def _count_unique_blobs(
        self, gen: Generation, parent_gen: Generation | None, prefixes: str
    ) -> int:
        """Pre-count unique blob remote paths for changed snapshots only.

        Unchanged snapshots inherited from the parent generation are not
        counted, because they are skipped during enumeration.
        """
        from bootstrap.remote.models import ReleaseIndex
        from bootstrap.remote.models import ResourceIndex

        changed_resource_hashes = self._changed_resource_snapshots(gen, parent_gen)
        changed_release = self._changed_release(gen, parent_gen)

        unique: set[str] = set()

        seen: set[str] = set()
        for entry in gen.resources.entries:
            snap_hash = entry.snapshot_hash
            if snap_hash in seen or snap_hash not in changed_resource_hashes:
                continue
            seen.add(snap_hash)
            snap_dir = resource_snapshot_dir(self.local_root, snap_hash)
            if not snap_dir.is_dir():
                continue
            try:
                index = read_pb2(snap_dir / "resources.pb2", ResourceIndex)
            except Exception:
                continue
            for ri_entry in index.entries:
                ihash = ident_hash(ri_entry.resource_id)
                bpath = blob_path(self.local_root, ihash, ri_entry.content_hash)
                if bpath.is_file():
                    unique.add(
                        prefixes + f"assets/blobs/{ihash[:2]}/{ihash}/{ri_entry.content_hash}"
                    )

        if changed_release:
            snap_hash = gen.release_pointer.snapshot_hash
            if snap_hash:
                snap_dir = release_snapshot_dir(self.local_root, snap_hash)
                pb2_file = snap_dir / "releases.pb2"
                if snap_dir.is_dir() and pb2_file.is_file():
                    try:
                        rel_index = read_pb2(pb2_file, ReleaseIndex)
                    except (OSError, DecodeError):
                        rel_index = None
                    if rel_index is not None and rel_index.HasField("android"):
                        android = rel_index.android
                        for variant_name in _RELEASE_VARIANT_NAMES:
                            if not android.HasField(variant_name):
                                continue
                            v = getattr(android, variant_name)
                            ihash = ident_hash(v.identifier)
                            bpath = blob_path(self.local_root, ihash, v.content_hash)
                            if bpath.is_file():
                                unique.add(
                                    prefixes + f"assets/blobs/{ihash[:2]}/{ihash}/{v.content_hash}"
                                )

        return len(unique)

    def _upload_file(
        self, src: Path, remote_path: str, *, attrs: dict[str, str] | None = None
    ) -> None:
        if self.origin_dir is not None:
            self._upload_local(src, remote_path)
        else:
            self._upload_s3(src, remote_path, attrs=attrs)

    def _remote_exists(self, remote_path: str) -> bool:
        """True if the blob already exists at the destination (spec §3.1)."""
        if self.origin_dir is not None:
            return (self.origin_dir / remote_path).exists()
        if self.mc_bin is None:
            from bootstrap.utils import get_command

            self.mc_bin = get_command("mc")
        bucket_target = f"{self.alias_name}/{self.bucket}"
        s3_path = f"{bucket_target}/{remote_path}"
        return _stat_ok([self.mc_bin, "stat", s3_path])

    def _upload_dir(self, src_dir: Path, remote_path: str) -> None:
        if self.origin_dir is not None:
            files = [
                (f, remote_path + "/" + str(f.relative_to(src_dir)))
                for f in src_dir.rglob("*")
                if f.is_file()
            ]
            if files:
                self._upload_files_parallel(files, desc=f"Uploading {src_dir.name}")
        else:
            if self.mc_bin is None:
                from bootstrap.utils import get_command

                self.mc_bin = get_command("mc")

            bucket_target = f"{self.alias_name}/{self.bucket}"
            s3_path = f"{bucket_target}/{remote_path}"
            _run(
                [self.mc_bin, "cp", "--recursive", f"{src_dir}/", s3_path],
                [self.mc_bin, "cp", "--recursive", f"{src_dir}/", s3_path],
                f"PUBLISH DIR {remote_path}",
            )

    def _upload_tree(self, src_dir: Path, remote_path: str) -> None:
        self._upload_dir(src_dir, remote_path)

    def _upload_files_parallel(self, files: list[tuple[Path, str]], *, desc: str) -> None:
        with ThreadPoolExecutor(max_workers=self.workers) as ex:
            futures = {ex.submit(self._upload_file, p, r): (p, r) for p, r in files}
            with tqdm(total=len(futures), desc=desc, unit="file") as pbar:
                for future in as_completed(futures):
                    future.result()
                    pbar.update(1)

    def _upload_local(self, src: Path, remote_path: str) -> None:
        import shutil

        dst = self.origin_dir / remote_path
        if dst.exists():
            return
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)

    def _upload_s3(
        self, src: Path, remote_path: str, *, attrs: dict[str, str] | None = None
    ) -> None:
        if self.mc_bin is None:
            from bootstrap.utils import get_command

            self.mc_bin = get_command("mc")

        bucket_target = f"{self.alias_name}/{self.bucket}"
        s3_path = f"{bucket_target}/{remote_path}"

        cmd: list[str] = [self.mc_bin, "cp"]
        if attrs:
            for k, v in attrs.items():
                cmd.extend(["--attr", f"{k}={v}"])
        cmd.extend([str(src), s3_path])
        _run(cmd, cmd, f"PUBLISH {remote_path}")


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


def _stat_ok(cmd: list[str], timeout: float = 60) -> bool:
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
