"""ResourceManager — cross-snapshot blob dedup + differential upload (spec v2-reg).

Per-publish singleton (publisher side only). For each unique blob remote path it
HEAD-checks the destination and skips the PUT when the blob already exists.
"""

from __future__ import annotations

import threading

from contextlib import contextmanager
from dataclasses import dataclass
from typing import TYPE_CHECKING

from tqdm import tqdm


if TYPE_CHECKING:
    from collections.abc import Iterator
    from pathlib import Path

    from bootstrap.remote.publish import Publisher


@dataclass
class _Stats:
    total_registered: int = 0  # every process_blob call, incl. dupes (§5)
    existing: int = 0  # HEAD hit on remote
    uploaded: int = 0  # processed unique blobs (existing + PUT) — see §4


class ResourceManager:
    def __init__(
        self,
        publisher: Publisher,
        *,
        expected_total: int | None = None,
        show_progress: bool = True,
    ) -> None:
        self._pub = publisher
        self.expected_total = expected_total
        self._show_progress = show_progress
        self._bar: tqdm | None = None
        self._dedup: dict[str, Path] = {}  # remote_path -> local_path (unique)
        self._stats = _Stats()
        self._lock = threading.Lock()

    # --- progress bar (§4) ---------------------------------------------------

    @contextmanager
    def progress(self) -> Iterator[ResourceManager]:
        """Open the single blob progress bar for the duration of a publish."""
        if not self._show_progress:
            self._bar = None
            yield self
            return
        self._bar = tqdm(
            total=self.expected_total,  # None => absolute-count mode (§4)
            desc="Blobs",
            unit="file",
            unit_scale=False,
            smoothing=0.3,  # rolling throughput, ~last few seconds
        )
        try:
            yield self
        finally:
            self._bar.close()
            self._bar = None

    def _tick(self) -> None:
        if self._bar is None:
            return
        self._bar.update(1)
        self._bar.set_postfix_str(
            f"{self.existing} Existing  {self.uploaded}/{self.unique_count} Uploaded",
            refresh=False,
        )

    # --- enumeration (single pass, called inline by the publisher) -----------

    def process_blob(self, local_path: Path, remote_path: str) -> None:
        """Register a blob (dedup) and, if new, HEAD-check + upload.

        Inline contract per spec §3.1. Safe to call from worker threads.
        """
        with self._lock:
            self._stats.total_registered += 1
            if remote_path in self._dedup:
                return
            self._dedup[remote_path] = local_path
        self._handle_unique(local_path, remote_path)

    def _handle_unique(self, local_path: Path, remote_path: str) -> None:
        exists = self._pub._remote_exists(remote_path)
        if exists:
            with self._lock:
                self._stats.existing += 1
                self._stats.uploaded += 1
        else:
            self._pub._upload_file(
                local_path,
                remote_path,
                attrs={"Cache-Control": "immutable, max-age=31536000"},
            )
            with self._lock:
                self._stats.uploaded += 1
        self._tick()

    # --- summary (§5) --------------------------------------------------------

    def log_summary(self) -> None:
        s = self._stats
        actually_uploaded = s.uploaded - s.existing
        print("ResourceManager:")
        print(f"  Total blobs registered (with dupes): {s.total_registered}")
        print(f"  Unique blobs after dedup:             {len(self._dedup)}")
        print(f"    Existing on remote:  {s.existing}")
        print(f"    Uploaded:            {actually_uploaded}")

    # --- read-only accessors (for the progress bar in Stage 02) --------------

    @property
    def unique_count(self) -> int:
        return len(self._dedup)

    @property
    def existing(self) -> int:
        return self._stats.existing

    @property
    def uploaded(self) -> int:
        return self._stats.uploaded

    @property
    def total_registered(self) -> int:
        return self._stats.total_registered
