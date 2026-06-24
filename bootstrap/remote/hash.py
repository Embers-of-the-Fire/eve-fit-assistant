"""Structured hash engine for EFA V2/V3/V4 schema.

Primitives:
  ident_hash(uri_string)  → SHA-256 hex of identifier URI
  content_hash(bytes)     → SHA-256 hex of raw bytes

Structured hashes:
  v3 (legacy, metadata-only — still callable for reads/verification):
    snapshot_hash(type, files)  → "efa:{type}:v3\\n" + metadata.json hash
    generation_hash(files)      → "efa:generation:v3\\n" + metadata.json hash
  v4 (canonical for new snapshots — also binds the typed .pb2 index, spec §7):
    snapshot_hash_v4(type, files)
      → "efa:{type}:v4\\n" + metadata.json hash + "\\n" + {proto}.pb2 hash

Dual-read: ``verify_snapshot_hash`` accepts an entity addressed by either
protocol (v4 preferred, v3 legacy fallback), enabling a greenfield migration
where new commits are v4 while pre-existing v3 entities still verify (spec §7).

Note: ``generation_hash`` intentionally remains v3. The v4 generation protocol
(spec §7) would cover ``history.pb2``, but each generation's ``history.pb2``
records the generation's own hash in its newest snapshot entries
(``merge_generation_into_history``), making a v4 generation hash self-referential.
That is deferred until the §5 revert feature mandates it.
"""

from __future__ import annotations

import hashlib

from typing import Literal


SnapshotType = Literal["resource", "release"]
HASH_ALGORITHM = hashlib.sha256

# Typed .pb2 index file bound into the v4 snapshot hash, per snapshot type.
SNAPSHOT_PROTO_NAME: dict[SnapshotType, str] = {
    "resource": "resources.pb2",
    "release": "releases.pb2",
}


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


def snapshot_hash_v4(snapshot_type: SnapshotType, files: dict[str, bytes]) -> str:
    """Compute the v4 structured snapshot hash (spec §7).

    The hash input binds both the canonical ``metadata.json`` and the typed
    ``.pb2`` index file, so tampering with the resource/release index now
    changes the address (v3 covered only ``metadata.json``):

        "efa:{type}:v4\\n"
        "metadata.json <sha256>\\n"
        "{resources|releases}.pb2 <sha256>\\n"

    Args:
        snapshot_type: One of "resource", "release".
        files: Dict containing at least "metadata.json" and the type's
            ``.pb2`` index (``resources.pb2`` / ``releases.pb2``) → bytes.
    """
    proto_name = SNAPSHOT_PROTO_NAME[snapshot_type]
    if "metadata.json" not in files:
        raise ValueError("Missing required file: metadata.json")
    if proto_name not in files:
        raise ValueError(f"Missing required file: {proto_name}")
    meta_line = _file_hash("metadata.json", files["metadata.json"])
    proto_line = _file_hash(proto_name, files[proto_name])
    payload = f"efa:{snapshot_type}:v4\n{meta_line}\n{proto_line}\n"
    return HASH_ALGORITHM(payload.encode("utf-8")).hexdigest()


def verify_snapshot_hash(
    snapshot_type: SnapshotType, files: dict[str, bytes], expected: str
) -> bool:
    """Return whether ``expected`` matches this snapshot under v4 or legacy v3.

    Dual-read for the greenfield migration (spec §7): new snapshots are v4, but
    pre-existing v3-addressed snapshots must still verify. v4 is preferred when
    the typed ``.pb2`` index is available; v3 is the metadata-only fallback.
    """
    proto_name = SNAPSHOT_PROTO_NAME[snapshot_type]
    if proto_name in files and snapshot_hash_v4(snapshot_type, files) == expected:
        return True
    return snapshot_hash(snapshot_type, files) == expected


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
