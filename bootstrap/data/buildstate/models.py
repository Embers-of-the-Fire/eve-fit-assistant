"""Models build-state map: skip re-converting ship GLBs whose inputs are unchanged.

The models step converts every ship's GR2/DDS sources into two GLB variants per
server build, then the blob store dedupes identical outputs *after* the CPU cost
is spent. This module moves the check *before* the build: a per-server JSON map
in CI storage records, per output resource id, the input hashes and the output
blob hash::

    {
      "schema_version": 3,
      "server_id": "tranquility",
      "entries": {
        "resource://static/models/ships/587.full.glb": {
          "model": "<md5 of the GR2, from resfileindex.txt>",
          "texture": {"res:/.../albedo.dds": "<md5>", ...},
          "dna": "mf4_t1:minmatarbase:minmatar",
          "sof": "<sha256 of the DNA's resolved SOF values, from converter phase 1>",
          "output": "<sha256 of the GLB blob>"
        },
        ...
      }
    }

The map lives in CI storage (``build-state/models/<server>.json``); the output
hash references blobs in the *production* remote store — artifacts are never
duplicated into the CI bucket.

Invalidation rules, all fail-open (any doubt converts):

1. The GR2 hash or any texture hash differs from the recorded entry.
2. The texture key set differs (a texture was added or removed).
   (Rules 1 and 2 both fold into ``entry != computed inputs``.)
3. The DNA or SOF fingerprint differs. The fingerprint (the converter's
   ``sofHash``) hashes exactly the values the converter derives from the DNA
   against data.black — materials, shaders, glow values, and area mappings —
   so catalog changes that leave a DNA's resolved values untouched (e.g. a
   new unrelated hull) do not invalidate the entry.
4. The recorded output blob does not exist in the production store.

The map deliberately carries no converter identity: the converter submodule or
encoder environment changing output bytes with unchanged inputs is the accepted
human gate — invalidate the map manually (``./x ci build-state invalidate``)
when the converter or its toolchain changes.

Test-mode / PR builds must never write the map: they publish to a mock, so the
outputs they "produce" do not exist in the production store and rule 3 would
mass-invalidate the map on the next real run.
"""

from __future__ import annotations

import hashlib
import json

from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from dataclasses import field
from typing import TYPE_CHECKING

from pydantic import BaseModel
from pydantic import Field

from bootstrap.log import info
from bootstrap.log import warning
from bootstrap.remote.hash import ident_hash


if TYPE_CHECKING:
    from collections.abc import Callable
    from pathlib import Path

    from bootstrap.remote.s3client import S3Client

#: Bump when the map layout or a field's semantics change; mismatched maps are
#: discarded (fail-open).
MAP_SCHEMA_VERSION = 3


def map_remote_key(server_id: str) -> str:
    """CI-storage key of the per-server models build-state map."""
    return f"build-state/models/{server_id}.json"


def ship_resource_id(type_id: int, variant: str) -> str:
    """Output resource id of a baked ship model (mirrors PathManager layout)."""
    return f"resource://static/models/ships/{type_id}.{variant}.glb"


def blob_remote_key(resource_root: str, resource_id: str, content_hash: str) -> str:
    """Production-store key of a content-addressed blob."""
    ident = ident_hash(resource_id)
    return f"{resource_root}/assets/blobs/{ident[:2]}/{ident}/{content_hash}"


@dataclass(frozen=True)
class ModelInputs:
    """Full converter input identity for one DNA/variant.

    ``model``/``texture`` are the staged asset hashes from the resource index;
    ``dna`` and ``sof`` pin the SOF resolution. ``sof`` is the converter
    resolve phase's ``sofHash``: a sha256 over the resolved SOF values
    (materials, shaders, glow values, area mappings) — the converter's only
    catalog input — so catalog changes that do not alter a DNA's resolved
    values keep the fingerprint (and the cache entry) valid.
    """

    model: str
    texture: dict[str, str]
    dna: str
    sof: str

    def without_textures(self) -> ModelInputs:
        """Geometry-only (``base``) variant identity: same mesh/SOF, no textures."""
        return ModelInputs(model=self.model, texture={}, dna=self.dna, sof=self.sof)


class ModelArtifactEntry(BaseModel):
    """One memoized artifact: input identity plus the output blob reference."""

    model: str
    texture: dict[str, str] = Field(default_factory=dict)
    dna: str
    sof: str
    output: str


class ModelsBuildStateMap(BaseModel):
    """The per-server models build-state map stored in CI storage."""

    schema_version: int = Field(default=MAP_SCHEMA_VERSION)
    server_id: str = ""
    entries: dict[str, ModelArtifactEntry] = Field(default_factory=dict)

    def to_json(self) -> bytes:
        return (self.model_dump_json(indent=2) + "\n").encode("utf-8")

    @staticmethod
    def from_json(raw: bytes) -> ModelsBuildStateMap:
        return ModelsBuildStateMap.model_validate(json.loads(raw.decode("utf-8")))


def inputs_match(entry: ModelArtifactEntry, inputs: ModelInputs) -> bool:
    """Invalidation rules 1-3: hashes, texture key set, and SOF identity unchanged."""
    return (
        entry.model == inputs.model
        and entry.texture == inputs.texture
        and entry.dna == inputs.dna
        and entry.sof == inputs.sof
    )


def partition_entries(
    desired: dict[str, ModelInputs],
    existing: ModelsBuildStateMap,
    output_exists: Callable[[str, str], bool],
) -> tuple[dict[str, ModelArtifactEntry], set[str]]:
    """Split ``desired`` (resource id -> inputs) into (hits, misses).

    A resource id is a hit only when the map has an entry with matching inputs
    (rules 1-3) *and* the recorded output blob still exists (rule 4, via the
    ``output_exists`` callback). Everything else is a miss.
    """
    hits: dict[str, ModelArtifactEntry] = {}
    misses: set[str] = set()
    for resource_id, inputs in desired.items():
        entry = existing.entries.get(resource_id)
        if entry is None or not inputs_match(entry, inputs):
            misses.add(resource_id)
            continue
        if not output_exists(resource_id, entry.output):
            misses.add(resource_id)
            continue
        hits[resource_id] = entry
    return hits, misses


def load_map(ci_client: S3Client, server_id: str) -> ModelsBuildStateMap:
    """Fetch the map from CI storage; missing/corrupt/stale maps read as empty."""
    key = map_remote_key(server_id)
    try:
        raw = ci_client.read_bytes(key)
    except Exception as exc:  # noqa: BLE001 - any read failure means "no cache"
        info(f"No models build-state map at {key} ({exc}); starting cold.")
        return ModelsBuildStateMap(server_id=server_id)
    try:
        state_map = ModelsBuildStateMap.from_json(raw)
    except Exception as exc:  # noqa: BLE001 - corrupt map must not block builds
        warning(f"Discarding corrupt models build-state map {key}: {exc}")
        return ModelsBuildStateMap(server_id=server_id)
    if state_map.schema_version != MAP_SCHEMA_VERSION or state_map.server_id != server_id:
        warning(f"Discarding incompatible models build-state map {key}.")
        return ModelsBuildStateMap(server_id=server_id)
    info(f"Loaded models build-state map: {len(state_map.entries)} entries.")
    return state_map


@dataclass
class ModelsCacheContext:
    """Cache wiring passed into the models generator step.

    ``ci_client`` reads (and optionally writes) the build-state map in CI
    storage; ``prod_client`` HEADs output blobs in the production store
    (existence + size — hits are referenced in place and never downloaded).
    Set ``rebuild`` to treat every entry as a miss while still rewriting the
    map (manual invalidation for converter/toolchain changes).
    ``upload_blobs`` additionally pushes every produced GLB to the production
    store — the local pre-build path (``./x ci build-state push-models``).
    ``workers`` sizes the probe pool in ``partition``.
    """

    server_id: str
    resource_root: str
    ci_client: S3Client
    prod_client: S3Client
    rebuild: bool = False
    map_path: Path | None = None
    upload_map: bool = False
    upload_blobs: bool = False
    workers: int = 16

    _map: ModelsBuildStateMap = field(default_factory=ModelsBuildStateMap)
    _hits: dict[str, ModelArtifactEntry] = field(default_factory=dict)
    _hit_sizes: dict[str, int] = field(default_factory=dict)
    _new_entries: dict[str, ModelArtifactEntry] = field(default_factory=dict)

    def load(self) -> None:
        self._map = (
            ModelsBuildStateMap(server_id=self.server_id)
            if self.rebuild
            else load_map(self.ci_client, self.server_id)
        )

    def partition(
        self, desired: dict[str, ModelInputs]
    ) -> tuple[dict[str, ModelArtifactEntry], set[str]]:
        """Split desired entries into (hits, misses), HEAD-checking hit outputs.

        The HEAD also captures each hit's blob size (Content-Length), which
        ``hit_reference`` later stamps into the resource index — hits are
        referenced in place and never downloaded.
        """

        def stat(resource_id: str, output_hash: str) -> int | None:
            key = blob_remote_key(self.resource_root, resource_id, output_hash)
            try:
                return self.prod_client.object_size(key)
            except Exception as exc:  # noqa: BLE001 - any probe failure means "miss"
                warning(f"Models cache probe failed for {key}; reconverting: {exc}")
                return None

        candidates = (
            self._map if not self.rebuild else ModelsBuildStateMap(server_id=self.server_id)
        )
        # Cheap pre-filter on inputs so HEAD checks only run for candidate hits.
        pre_hits = {
            rid: entry
            for rid, inputs in desired.items()
            if (entry := candidates.entries.get(rid)) is not None and inputs_match(entry, inputs)
        }
        with ThreadPoolExecutor(max_workers=self.workers) as pool:
            sizes = list(pool.map(lambda rid: stat(rid, pre_hits[rid].output), list(pre_hits)))
        hits = {
            rid: pre_hits[rid]
            for rid, size in zip(pre_hits, sizes, strict=True)
            if size is not None
        }
        misses = set(desired) - set(hits)
        self._hits = hits
        self._hit_sizes = {
            rid: size for rid, size in zip(pre_hits, sizes, strict=True) if size is not None
        }
        info(f"Models build-state: {len(hits)} hits, {len(misses)} misses.")
        return hits, misses

    def hit_reference(self, resource_id: str) -> tuple[str, str, int]:
        """``(resource_id, content_hash, size)`` index tuple for a cache hit.

        The snapshot references the production blob in place — no local file
        is materialized, and publish HEAD-checks the reference again before
        accepting it.
        """
        entry = self._hits[resource_id]
        return resource_id, entry.output, self._hit_sizes[resource_id]

    def blob_key(self, resource_id: str, output_hash: str) -> str:
        return blob_remote_key(self.resource_root, resource_id, output_hash)

    def record_conversion(self, resource_id: str, inputs: ModelInputs, output: Path) -> None:
        """Record a freshly converted artifact; optionally push the blob to prod."""
        output_hash = hashlib.sha256(output.read_bytes()).hexdigest()
        if self.upload_blobs:
            key = self.blob_key(resource_id, output_hash)
            if not self.prod_client.object_exists(key):
                self.prod_client.upload_file(output, key)
        self._new_entries[resource_id] = ModelArtifactEntry(
            model=inputs.model,
            texture=dict(inputs.texture),
            dna=inputs.dna,
            sof=inputs.sof,
            output=output_hash,
        )

    def record_hit(self, resource_id: str) -> None:
        """Carry a cache hit's entry over into the updated map."""
        entry = self._hits.get(resource_id)
        if entry is not None:
            self._new_entries[resource_id] = entry

    def save(self) -> None:
        """Write the updated map locally and/or to CI storage."""
        updated = ModelsBuildStateMap(server_id=self.server_id, entries=self._new_entries)
        raw = updated.to_json()
        if self.map_path is not None:
            self.map_path.parent.mkdir(parents=True, exist_ok=True)
            self.map_path.write_bytes(raw)
            info(f"Wrote models build-state map to {self.map_path}")
        if self.upload_map:
            self.ci_client.write_bytes(map_remote_key(self.server_id), raw)
            info(f"Uploaded models build-state map for {self.server_id} to CI storage.")
