"""Structured hash engine for EFA V2 schema.

Primitives:
  ident_hash(uri_string)  → SHA-256 hex of identifier URI
  content_hash(bytes)     → SHA-256 hex of raw bytes

Structured hashes:
  snapshot_hash(type, files)  → "efa:{type}:v2\\n" + sorted file hashes
  generation_hash(files)      → "efa:generation:v2\\n" + sorted file hashes
"""

from __future__ import annotations

import hashlib

from typing import Literal


SnapshotType = Literal["resource", "release", "announcement"]
HASH_ALGORITHM = hashlib.sha256


def ident_hash(uri_string: str) -> str:
    """SHA-256 hex digest of an identifier URI string.

    Example:
        ident_hash("resource://tranquility/proto/ships.bin")
        → 64 lowercase hex chars
    """
    return HASH_ALGORITHM(uri_string.encode("utf-8")).hexdigest()


def content_hash(data: bytes) -> str:
    """SHA-256 hex digest of raw bytes (blob content)."""
    return HASH_ALGORITHM(data).hexdigest()


def _file_hash(filename: str, data: bytes) -> str:
    """Return 'filename <sha256_hex>' line for structured hash assembly."""
    return f"{filename} {HASH_ALGORITHM(data).hexdigest()}"


def snapshot_hash(snapshot_type: SnapshotType, files: dict[str, bytes]) -> str:
    """Compute structured snapshot hash.

    The hash input is built as:
        "efa:{type}:v2\\n"
        "metadata.json <sha256>\\n"
        "{type}.pb2 <sha256>\\n"

    Lines are sorted lexicographically by filename.

    Args:
        snapshot_type: One of "resource", "release", "announcement".
        files: Dict mapping filenames to their raw bytes.
               Must contain at least "metadata.json" and the .pb2 file.
    """
    prefix = f"efa:{snapshot_type}:v2"
    lines = [_file_hash(name, data) for name, data in sorted(files.items())]
    payload = prefix + "\n" + "\n".join(lines) + "\n"
    return HASH_ALGORITHM(payload.encode("utf-8")).hexdigest()


def generation_hash(files: dict[str, bytes]) -> str:
    """Compute structured generation hash.

    The hash input is built from all five constituent files:
        "efa:generation:v2\\n"
        "announcements.pb2 <sha256>\\n"
        "metadata.json <sha256>\\n"
        "releases.pb2 <sha256>\\n"
        "resources.pb2 <sha256>\\n"
        "server.pb2 <sha256>\\n"

    Lines are sorted lexicographically by filename.
    All five files must be present.
    """
    required = {
        "announcements.pb2",
        "metadata.json",
        "releases.pb2",
        "resources.pb2",
        "server.pb2",
    }
    actual = set(files.keys())
    if missing := required - actual:
        raise ValueError(f"Missing required generation files: {sorted(missing)}")

    prefix = "efa:generation:v2"
    lines = [_file_hash(name, data) for name, data in sorted(files.items())]
    payload = prefix + "\n" + "\n".join(lines) + "\n"
    return HASH_ALGORITHM(payload.encode("utf-8")).hexdigest()
