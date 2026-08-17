"""Sync resource snapshot engine data into the platform D1 database.

Splits the snapshot's native engine protobuf collections (types, type dogma,
dogma attributes, dogma effects, buff collections) into per-entry rows and
builds per-entry name/icon metadata from the snapshot's collection and
localization database, then uploads everything to the platform data-sync
worker (``api.efa-tech.dev/platform/storage/data-sync``), which stores them in
the ``efa-platform-prod`` D1 database.

Layout per family ``<f>``:
  - table ``<f>``:     (content_hash TEXT PRIMARY KEY, content BLOB)
  - table ``<f>_reg``: (server_id, snapshot_hash, entry_id, content_hash)

A snapshot is only complete once the uploader has posted every content and
registration batch and then marked it in the ``snapshots`` registry table
(``POST complete``); readers must check that registry before serving data.
"""

from __future__ import annotations

import base64
import sqlite3
import sys
import tempfile

from dataclasses import dataclass
from dataclasses import field
from pathlib import Path
from typing import TYPE_CHECKING
from typing import Any
from typing import Protocol

from bootstrap.constant import NATIVE_LIB_ROOT
from bootstrap.log import info
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
    """A single ``<family>_reg`` row."""

    family: str
    entry_id: int
    hash: str


class SyncTransport(Protocol):
    """POST a JSON payload to a worker endpoint path and return the decoded reply."""

    def post(self, path: str, payload: dict[str, Any]) -> dict[str, Any]: ...


class HttpTransport:
    """requests-based transport for the platform data-sync worker."""

    def __init__(self, base_url: str, token: str, timeout: float = 120.0) -> None:
        import requests

        from requests.adapters import HTTPAdapter
        from urllib3.util.retry import Retry

        self._base_url = base_url.rstrip("/")
        self._token = token
        self._timeout = timeout
        self._session = requests.Session()
        # Both endpoints are idempotent (INSERT OR IGNORE / INSERT OR REPLACE),
        # so retrying a POST on transient failures is safe.
        retry = Retry(
            total=5,
            backoff_factor=1.0,
            status_forcelist=(429, 500, 502, 503, 504),
            allowed_methods=frozenset({"POST"}),
        )
        adapter = HTTPAdapter(max_retries=retry)
        self._session.mount("https://", adapter)
        self._session.mount("http://", adapter)

    def post(self, path: str, payload: dict[str, Any]) -> dict[str, Any]:
        resp = self._session.post(
            f"{self._base_url}/{path.lstrip('/')}",
            json=payload,
            headers={"Authorization": f"Bearer {self._token}"},
            timeout=self._timeout,
        )
        if resp.status_code != 200:
            raise RuntimeError(
                f"D1 sync request to {path} failed with HTTP {resp.status_code}: {resp.text[:500]}"
            )
        body = resp.json()
        if not body.get("ok", False):
            raise RuntimeError(f"D1 sync request to {path} returned error: {body}")
        return body


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
    batch_size: int = 2000,
    dry_run: bool = False,
) -> None:
    """Sync every server snapshot in ``hashes`` to the platform D1 database.

    Content rows are deduplicated across servers before uploading (identical
    entries share a content hash); registration rows are uploaded per server.
    """
    if not 1 <= batch_size <= 10_000:
        raise ValueError(f"batch_size must be between 1 and 10000, got {batch_size}")

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

    content_rows = [
        {
            "family": family,
            "content_hash": entry_hash,
            "content_b64": base64.b64encode(data).decode("ascii"),
        }
        for (family, entry_hash), data in sorted(content.items())
    ]
    for batch in _batched(content_rows, batch_size):
        reply = transport.post("content", {"entries": batch})
        info(f"Uploaded {len(batch)} content rows (inserted: {reply.get('inserted', '?')})")

    for (server_id, snapshot_hash), regs in sorted(registrations.items()):
        reg_rows = [
            {"family": reg.family, "entry_id": reg.entry_id, "content_hash": reg.hash}
            for reg in regs
        ]
        for batch in _batched(reg_rows, batch_size):
            reply = transport.post(
                "register",
                {"server_id": server_id, "snapshot_hash": snapshot_hash, "entries": batch},
            )
        info(f"Registered {len(reg_rows)} rows for {server_id} ({snapshot_hash[:16]}...)")

        # Completeness marker: only reached when every content batch and every
        # registration batch for this snapshot succeeded. Readers treat a
        # snapshot without this marker as incomplete.
        transport.post(
            "complete",
            {
                "server_id": server_id,
                "snapshot_hash": snapshot_hash,
                "entry_count": len(reg_rows),
            },
        )
        info(f"Marked snapshot complete for {server_id} ({snapshot_hash[:16]}...)")
