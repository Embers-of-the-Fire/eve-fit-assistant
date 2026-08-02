"""Blob store — content-addressed binary storage.

Stores blobs at assets/blobs/{2c}/{ident_hash}/{content_hash}.
Atomic writes (tmp + rename), idempotent (skip if exists).
"""

from __future__ import annotations

from typing import TYPE_CHECKING

from bootstrap.remote.hash import content_hash
from bootstrap.remote.paths import blob_path


if TYPE_CHECKING:
    from pathlib import Path


class BlobStore:
    """Local filesystem blob store.

    Blobs are addressed by (ident_hash, content_hash). The store is append-only
    for safety — deletions are handled by garbage collection.
    """

    def __init__(self, root: Path) -> None:
        self.root = root

    def store(self, data: bytes, ident_hash: str) -> str:
        """Store raw bytes and return the content_hash.

        Atomic write: writes to .tmp first, then renames. Skips if the target
        file already exists (idempotent).
        """
        chash = content_hash(data)
        target = blob_path(self.root, ident_hash, chash)
        if target.exists():
            return chash
        target.parent.mkdir(parents=True, exist_ok=True)
        tmp = target.with_suffix(target.suffix + ".tmp")
        tmp.write_bytes(data)
        tmp.replace(target)
        return chash

    def store_from_path(self, src: Path, ident_hash: str) -> str:
        """Store a file from disk by path. Returns content_hash."""
        data = src.read_bytes()
        return self.store(data, ident_hash)

    def exists(self, ident_hash: str, content_hash: str) -> bool:
        return blob_path(self.root, ident_hash, content_hash).exists()

    def read(self, ident_hash: str, content_hash: str) -> bytes:
        target = blob_path(self.root, ident_hash, content_hash)
        if not target.exists():
            raise FileNotFoundError(f"Blob not found: {target}")
        return target.read_bytes()

    def path_for(self, ident_hash: str, content_hash: str) -> Path:
        return blob_path(self.root, ident_hash, content_hash)

    def delete(self, ident_hash: str, content_hash: str) -> None:
        target = blob_path(self.root, ident_hash, content_hash)
        if target.exists():
            target.unlink()
