"""Structured hash engine for EFA V2/V3 schema.

Primitives:
  ident_hash(uri_string)  → SHA-256 hex of identifier URI
  content_hash(bytes)     → SHA-256 hex of raw bytes

Structured hashes (v3 — only canonical JSON files are hashed):
  snapshot_hash(type, files)  → "efa:{type}:v3\\n" + metadata.json hash
  generation_hash(files)      → "efa:generation:v3\\n" + metadata.json hash
"""

from __future__ import annotations

import hashlib

from typing import Literal


SnapshotType = Literal["resource", "release"]
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

    The hash input is built from only the canonical ``metadata.json`` file:

        "efa:{type}:v3\\n"
        "metadata.json <sha256>\\n"

    Args:
        snapshot_type: One of "resource", "release".
        files: Dict containing at least "metadata.json" → bytes.
    """
    if "metadata.json" not in files:
        raise ValueError("Missing required file: metadata.json")
    line = _file_hash("metadata.json", files["metadata.json"])
    payload = f"efa:{snapshot_type}:v3\n{line}\n"
    return HASH_ALGORITHM(payload.encode("utf-8")).hexdigest()


def generation_hash(files: dict[str, bytes]) -> str:
    """Compute structured generation hash.

    The hash input is built from the canonical ``metadata.json`` file only:

        "efa:generation:v3\\n"
        "metadata.json <sha256>\\n"
    """
    if "metadata.json" not in files:
        raise ValueError("Missing required file: metadata.json")
    line = _file_hash("metadata.json", files["metadata.json"])
    payload = f"efa:generation:v3\n{line}\n"
    return HASH_ALGORITHM(payload.encode("utf-8")).hexdigest()
