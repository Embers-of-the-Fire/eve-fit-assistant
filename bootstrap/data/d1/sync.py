"""Sync resource snapshot engine data into the platform D1 database.

Splits the snapshot's native engine protobuf collections (types, type dogma,
dogma attributes, dogma effects, buff collections) into per-entry rows and
builds per-entry name/icon metadata from the snapshot's collection and
localization database, then uploads everything to the platform data-sync
worker (``api.efa-tech.dev/platform/storage/data-sync``), which stores them in
the ``efa-snapshot-registry`` D1 database.

Storage layout (v2; see worker/efa-platform-data-sync/migrations):
  - ``entries``:          (content_id, family, content_hash BLOB, content)
                          content-addressed payloads; content_id is a dense
                          database-local integer assigned by the worker
  - ``snapshot_entries``: (snapshot_id, family, entry_id, content_id)
                          registration rows referencing integer ids only
  - ``snapshots``:        (snapshot_id, server_id, snapshot_hash BLOB,
                          entry_count, completed_at) completeness registry

Uploads run over a single WebSocket to the worker's ``SyncSession`` Durable
Object: every frame is a small JSON message (``content``/``lookup``/
``register``/``complete``/``snapshot``) answered by one JSON reply carrying
the same client-chosen ``id``. Each frame is a separate Durable Object event
with its own CPU budget, which replaced the old multi-request HTTP API whose
large per-request batches regularly failed with 503s.

Registration rows reference content ids rather than content hashes, so the
``content`` and ``lookup`` replies carry ``ids`` maps (content hash ->
content id) that this driver accumulates before emitting ``register`` frames.

All operations are idempotent, so the transport reconnects and resends an
unacknowledged frame on connection failures, and a rerun of the whole sync
converges: the ``snapshot`` frame skips already-completed snapshots and the
``lookup`` frame skips already-uploaded content rows. A snapshot is only
complete once the uploader has posted every content and registration frame
and then frozen it in the ``snapshots`` registry (``complete``); readers must
check that registry before serving data.
"""

from __future__ import annotations

import base64
import contextlib
import json
import random
import sqlite3
import sys
import tempfile
import time

from dataclasses import dataclass
from dataclasses import field
from pathlib import Path
from typing import TYPE_CHECKING
from typing import Any
from typing import Protocol
from typing import Self

from bootstrap.constant import NATIVE_LIB_ROOT
from bootstrap.log import info
from bootstrap.log import warning
from bootstrap.remote.hash import content_hash
from bootstrap.remote.hash import ident_hash
from bootstrap.remote.models import read_pb2
from bootstrap.remote.paths import blob_path
from bootstrap.remote.paths import resource_snapshot_dir


if TYPE_CHECKING:
    from collections.abc import Iterable


#: Engine data families, mapped to their snapshot resource IDs and the efos
#: protobuf message used to decode the whole collection.
ENGINE_FAMILIES: dict[str, tuple[str, str]] = {
    "types": ("resource://static/native/types.pb2", "Types"),
    "type_dogma": ("resource://static/native/typeDogma.pb2", "TypeDogma"),
    "dogma_attributes": ("resource://static/native/dogmaAttributes.pb2", "DogmaAttributes"),
    "dogma_effects": ("resource://static/native/dogmaEffects.pb2", "DogmaEffects"),
    "buffs": ("resource://static/native/dbuffcollections.pb2", "BuffCollections"),
}

COLLECTION_RESOURCE_ID = "resource://static/collection.pb2"
LOCALIZATION_RESOURCE_ID = "resource://localization/localization.db"

#: Metadata families built at sync time (not present as snapshot resources).
META_FAMILIES = ("type_meta", "dogma_attribute_meta", "dogma_effect_meta")

ALL_FAMILIES = tuple(ENGINE_FAMILIES) + META_FAMILIES


@dataclass(frozen=True)
class Entry:
    """A single D1 content row candidate."""

    family: str
    entry_id: int
    content: bytes
    hash: str = field(init=False)

    def __post_init__(self) -> None:
        object.__setattr__(self, "hash", content_hash(self.content))


@dataclass(frozen=True)
class Registration:
    """A single ``snapshot_entries`` row candidate."""

    family: str
    entry_id: int
    hash: str


class SyncTransport(Protocol):
    """Send one frame payload to the worker and return the decoded reply.

    ``path`` is the frame type (``content``, ``lookup``, ``register``,
    ``complete``, ``snapshot``); the payload carries the frame's remaining
    fields. Raises on ``ok: false`` replies.
    """

    def post(self, path: str, payload: dict[str, Any]) -> dict[str, Any]: ...

    def close(self) -> None: ...


class WebSocketTransport:
    """WebSocket transport for the platform data-sync worker's SyncSession.

    Holds one persistent connection and correlates each request frame with its
    reply via a client-chosen ``id``. All sync operations are idempotent, so
    on connection failures the transport transparently reconnects and resends
    the unacknowledged frame with exponential backoff.
    """

    def __init__(
        self,
        base_url: str,
        token: str,
        timeout: float = 120.0,
        max_attempts: int = 10,
    ) -> None:
        self._ws_url = self._to_ws_url(base_url)
        self._token = token
        self._timeout = timeout
        self._max_attempts = max_attempts
        self._next_id = 0
        self._connection: Any = None

    @staticmethod
    def _to_ws_url(base_url: str) -> str:
        base = base_url.rstrip("/")
        if base.startswith("https://"):
            base = "wss://" + base[len("https://") :]
        elif base.startswith("http://"):
            base = "ws://" + base[len("http://") :]
        if not base.startswith(("ws://", "wss://")):
            raise ValueError(f"Unsupported data-sync URL scheme: {base_url}")
        return f"{base}/sync"

    def _connect(self) -> None:
        from websockets.sync.client import connect

        self.close()
        self._connection = connect(
            self._ws_url,
            additional_headers={"Authorization": f"Bearer {self._token}"},
            open_timeout=30.0,
            close_timeout=5.0,
        )

    def close(self) -> None:
        if self._connection is not None:
            with contextlib.suppress(Exception):
                # Closing must never raise; the connection may be broken.
                self._connection.close()
            self._connection = None

    def __enter__(self) -> Self:
        return self

    def __exit__(self, *exc_info: object) -> None:
        self.close()

    def post(self, path: str, payload: dict[str, Any]) -> dict[str, Any]:
        from websockets.exceptions import ConnectionClosed
        from websockets.exceptions import InvalidStatus

        last_error: Exception | None = None
        for attempt in range(1, self._max_attempts + 1):
            try:
                return self._roundtrip(path, payload)
            except (ConnectionClosed, TimeoutError, OSError, InvalidStatus) as exc:
                # 5xx handshake responses are transient; other handshake
                # failures (notably 401/403 authentication errors) are
                # permanent and must not burn retry attempts.
                if isinstance(exc, InvalidStatus) and exc.response.status_code < 500:
                    raise
                last_error = exc
                delay = min(2.0 ** (attempt - 1), 30.0) + random.uniform(0.0, 1.0)
                warning(
                    f"D1 sync '{path}' frame failed ({exc}); "
                    f"reconnecting in {delay:.1f}s (attempt {attempt}/{self._max_attempts})"
                )
                time.sleep(delay)
                # Drop the broken connection so the next attempt reconnects
                # inside the try block; a failed reconnect is retried too.
                self.close()
        raise RuntimeError(
            f"D1 sync '{path}' frame failed after {self._max_attempts} attempts: {last_error}"
        ) from last_error

    def _roundtrip(self, path: str, payload: dict[str, Any]) -> dict[str, Any]:
        if self._connection is None:
            self._connect()
        connection = self._connection
        self._next_id += 1
        request_id = self._next_id
        connection.send(json.dumps({"id": request_id, "type": path, **payload}))
        # Replies are serialized per connection, so the next message is almost
        # always ours; correlate by id defensively anyway.
        while True:
            raw = connection.recv(timeout=self._timeout)
            reply: dict[str, Any] = json.loads(raw)
            if reply.get("id") == request_id:
                break
            warning(f"D1 sync: discarding unexpected reply: {str(reply)[:200]}")
        if not reply.get("ok", False):
            raise RuntimeError(f"D1 sync '{path}' frame returned error: {reply}")
        return reply


def _load_efos_pb2():
    """Import the checked-in efos protobuf bindings from the engine crate."""
    root = str(NATIVE_LIB_ROOT)
    if root not in sys.path:
        sys.path.insert(0, root)
    import efos_pb2

    return efos_pb2


def _load_resource_index(schema_root: Path, snapshot_hash: str):
    from bootstrap.remote.models import ResourceIndex

    index_path = resource_snapshot_dir(schema_root, snapshot_hash) / "resources.pb2"
    if not index_path.exists():
        raise FileNotFoundError(f"Resource index not found: {index_path}")
    return read_pb2(index_path, ResourceIndex)


def _resolve_blob(schema_root: Path, index, resource_id: str) -> bytes:
    """Read a blob from the schema root addressed by its snapshot resource entry."""
    for entry in index.entries:
        if entry.resource_id == resource_id:
            path = blob_path(schema_root, ident_hash(resource_id), entry.content_hash)
            if not path.exists():
                raise FileNotFoundError(f"Blob missing for {resource_id}: {path}")
            return path.read_bytes()
    raise KeyError(f"Resource {resource_id} not present in snapshot index")


def split_engine_entries(family: str, data: bytes) -> list[Entry]:
    """Split a whole-collection efos protobuf into per-entry rows."""
    efos_pb2 = _load_efos_pb2()
    _resource_id, message_name = ENGINE_FAMILIES[family]
    msg = getattr(efos_pb2, message_name)()
    msg.ParseFromString(data)
    return [
        Entry(family, int(entry_id), value.SerializeToString())
        for entry_id, value in sorted(msg.entries.items())
    ]


def _load_localized_strings(db_path: Path) -> tuple[list[str], dict[tuple[str, int], str]]:
    """Load all localization strings: (locales, (locale, id) -> value)."""
    connection = sqlite3.connect(db_path)
    try:
        locales = [row[0] for row in connection.execute("SELECT DISTINCT locale FROM strings")]
        strings = {
            (locale, entry_id): value
            for locale, entry_id, value in connection.execute(
                "SELECT locale, id, value FROM strings"
            )
        }
    finally:
        connection.close()
    return sorted(locales), strings


def build_meta_entries(
    collection_data: bytes,
    localization_db_data: bytes,
    effect_names: dict[int, str],
) -> list[Entry]:
    """Build per-entry name/icon metadata rows from collection + localization data.

    ``effect_names`` maps dogma effect IDs to their internal effect names,
    taken from the native dogmaEffects collection (effects carry no display
    name or icon in the source data).
    """
    from bootstrap.data.schema import collections_pb2
    from bootstrap.data.schema import platform_data_pb2

    collection = collections_pb2.Collection()
    collection.ParseFromString(collection_data)

    with tempfile.TemporaryDirectory() as tmp_dir:
        db_path = Path(tmp_dir) / "localization.db"
        db_path.write_bytes(localization_db_data)
        locales, strings = _load_localized_strings(db_path)

    entries: list[Entry] = []

    def _names(loc_id: int) -> dict[str, str]:
        return {
            locale: strings[(locale, loc_id)] for locale in locales if (locale, loc_id) in strings
        }

    for type_id, type_pb in sorted(collection.types.items()):
        meta = platform_data_pb2.PlatformTypeMeta(type_id=type_id)
        for locale, value in _names(type_pb.type_name.id).items():
            meta.name[locale] = value
        if type_pb.icon.HasField("icon_id"):
            meta.icon_id = type_pb.icon.icon_id
        if type_pb.icon.HasField("graphic_id"):
            meta.graphic_id = type_pb.icon.graphic_id
        entries.append(Entry("type_meta", int(type_id), meta.SerializeToString()))

    for attribute_id, attribute_pb in sorted(collection.dogma_attributes.items()):
        meta = platform_data_pb2.PlatformDogmaAttributeMeta(dogma_attribute_id=attribute_id)
        if attribute_pb.HasField("display_name"):
            names = _names(attribute_pb.display_name.id)
        else:
            names = {}
        for locale in locales:
            meta.name[locale] = names.get(locale, attribute_pb.name)
        if attribute_pb.icon.HasField("icon_id"):
            meta.icon_id = attribute_pb.icon.icon_id
        entries.append(Entry("dogma_attribute_meta", int(attribute_id), meta.SerializeToString()))

    for effect_id, name in sorted(effect_names.items()):
        meta = platform_data_pb2.PlatformDogmaEffectMeta(dogma_effect_id=effect_id, name=name)
        entries.append(Entry("dogma_effect_meta", int(effect_id), meta.SerializeToString()))

    return entries


def load_snapshot_entries(schema_root: Path, snapshot_hash: str) -> list[Entry]:
    """Decode every D1-bound entry (engine families + metadata) for a snapshot."""
    index = _load_resource_index(schema_root, snapshot_hash)

    entries: list[Entry] = []
    for family, (resource_id, _message_name) in ENGINE_FAMILIES.items():
        blob = _resolve_blob(schema_root, index, resource_id)
        family_entries = split_engine_entries(family, blob)
        info(f"Snapshot {snapshot_hash[:16]}...: {len(family_entries)} {family} entries")
        entries.extend(family_entries)

    effect_names = {
        entry.entry_id: _decode_effect_name(entry.content)
        for entry in entries
        if entry.family == "dogma_effects"
    }

    collection_blob = _resolve_blob(schema_root, index, COLLECTION_RESOURCE_ID)
    localization_blob = _resolve_blob(schema_root, index, LOCALIZATION_RESOURCE_ID)
    meta_entries = build_meta_entries(collection_blob, localization_blob, effect_names)
    info(f"Snapshot {snapshot_hash[:16]}...: {len(meta_entries)} metadata entries")
    entries.extend(meta_entries)

    return entries


def _decode_effect_name(entry_content: bytes) -> str:
    efos_pb2 = _load_efos_pb2()
    effect = efos_pb2.DogmaEffects.DogmaEffect()
    effect.ParseFromString(entry_content)
    return effect.name


def _batched(items: list, batch_size: int) -> Iterable[list]:
    for offset in range(0, len(items), batch_size):
        yield items[offset : offset + batch_size]


def run_sync(
    hashes: dict[str, str],
    schema_root: Path,
    transport: SyncTransport | None,
    batch_size: int = 500,
    dry_run: bool = False,
) -> None:
    """Sync every server snapshot in ``hashes`` to the platform D1 database.

    Content rows are deduplicated across servers before uploading (identical
    entries share a content hash); registration rows are uploaded per server.
    Reruns converge: snapshots already marked complete are skipped, and
    already-uploaded content rows are filtered out via ``lookup`` frames.
    """
    if not 1 <= batch_size <= 2_000:
        raise ValueError(f"batch_size must be between 1 and 2000, got {batch_size}")

    content: dict[tuple[str, str], bytes] = {}
    registrations: dict[tuple[str, str], list[Registration]] = {}

    for server_id, snapshot_hash in sorted(hashes.items()):
        info(f"Loading snapshot entries for {server_id} ({snapshot_hash[:16]}...)...")
        entries = load_snapshot_entries(schema_root, snapshot_hash)
        regs: list[Registration] = []
        for entry in entries:
            content.setdefault((entry.family, entry.hash), entry.content)
            regs.append(Registration(entry.family, entry.entry_id, entry.hash))
        registrations[(server_id, snapshot_hash)] = regs

    info(f"Total unique content rows: {len(content)}")
    info(f"Total registration rows: {sum(len(r) for r in registrations.values())}")

    if dry_run:
        per_family: dict[str, int] = {}
        for family, _hash in content:
            per_family[family] = per_family.get(family, 0) + 1
        for family in ALL_FAMILIES:
            info(f"  {family}: {per_family.get(family, 0)} content rows")
        info("Dry run: skipped upload.")
        return

    if transport is None:
        raise ValueError("transport is required unless dry_run is set")

    try:
        # Skip snapshots a previous run already finished: their registration
        # set is frozen and the worker would reject further register frames.
        pending = dict(registrations)
        for server_id, snapshot_hash in sorted(registrations):
            reply = transport.post(
                "snapshot", {"server_id": server_id, "snapshot_hash": snapshot_hash}
            )
            if reply.get("complete", False):
                info(f"Snapshot already complete, skipping: {server_id} ({snapshot_hash[:16]}...)")
                del pending[(server_id, snapshot_hash)]

        pending_hashes = {(reg.family, reg.hash) for regs in pending.values() for reg in regs}

        # The worker's `ids` reply maps content hash -> content id, keyed by
        # hash alone. That is only sound when no content hash appears under
        # two families (identical bytes in two per-family protobuf schemas);
        # enforce the invariant before relying on it.
        families_by_hash: dict[str, set[str]] = {}
        for family, entry_hash in pending_hashes:
            families_by_hash.setdefault(entry_hash, set()).add(family)
        ambiguous = [h for h, families in families_by_hash.items() if len(families) > 1]
        if ambiguous:
            raise ValueError(
                f"content hashes shared across families are not supported: {ambiguous[:5]}"
            )

        # Resume support: content rows already present on the server (from
        # earlier runs or shared with completed snapshots) are not resent.
        rows_to_check = sorted(
            (family, entry_hash)
            for (family, entry_hash) in content
            if (family, entry_hash) in pending_hashes
        )
        missing: set[tuple[str, str]] = set()
        content_ids: dict[tuple[str, str], int] = {}
        for family in ALL_FAMILIES:
            family_hashes = [h for f, h in rows_to_check if f == family]
            if not family_hashes:
                continue
            for chunk in _batched(family_hashes, 5_000):
                reply = transport.post("lookup", {"family": family, "content_hashes": chunk})
                missing.update((family, h) for h in reply.get("missing", []))
                for h, content_id in reply.get("ids", {}).items():
                    content_ids[(family, h)] = content_id
        info(f"Content rows missing on the server: {len(missing)} of {len(rows_to_check)}")

        content_rows = [
            {
                "family": family,
                "content_hash": entry_hash,
                "content_b64": base64.b64encode(content[(family, entry_hash)]).decode("ascii"),
            }
            for family, entry_hash in sorted(missing)
        ]
        for batch in _batched(content_rows, batch_size):
            reply = transport.post("content", {"entries": batch})
            info(f"Uploaded {len(batch)} content rows (inserted: {reply.get('inserted', '?')})")
            # Content frames may mix families, but the cross-family hash
            # invariant above keeps the flat ids map unambiguous.
            family_by_hash = {row["content_hash"]: row["family"] for row in batch}
            for h, content_id in reply.get("ids", {}).items():
                content_ids[(family_by_hash[h], h)] = content_id

        unresolved = pending_hashes - set(content_ids)
        if unresolved:
            raise RuntimeError(
                f"server did not return content ids for {len(unresolved)} content rows "
                f"(first: {min(unresolved)})"
            )

        for (server_id, snapshot_hash), regs in sorted(pending.items()):
            reg_rows = [
                {
                    "family": reg.family,
                    "entry_id": reg.entry_id,
                    "content_id": content_ids[(reg.family, reg.hash)],
                }
                for reg in regs
            ]
            for batch in _batched(reg_rows, batch_size):
                transport.post(
                    "register",
                    {"server_id": server_id, "snapshot_hash": snapshot_hash, "entries": batch},
                )
            info(f"Registered {len(reg_rows)} rows for {server_id} ({snapshot_hash[:16]}...)")

            # Completeness marker: only reached when every content frame and
            # every registration frame for this snapshot succeeded. Readers
            # treat a snapshot without this marker as incomplete.
            transport.post(
                "complete",
                {
                    "server_id": server_id,
                    "snapshot_hash": snapshot_hash,
                    "entry_count": len(reg_rows),
                },
            )
            info(f"Marked snapshot complete for {server_id} ({snapshot_hash[:16]}...)")
    finally:
        transport.close()
