"""Skybox build-state map: skip re-baking skyboxes whose inputs are unchanged.

The skyboxes step bakes every scene cubemap into a Radiance HDR equirect plus
a SkyboxMetadata sidecar per server build, then the blob store dedupes
identical outputs *after* the CPU cost is spent. This module moves the check
*before* the build, mirroring ``bootstrap.data.buildstate.models``: a
per-server JSON map in CI storage records, per output resource id (the `.hdr`
blob; the sidecar is keyed alongside it), the input hashes and the output blob
hashes::

    {
      "schema_version": 1,
      "server_id": "tranquility",
      "entries": {
        "resource://static/skyboxes/a01.hdr": {
          "cube": "<md5 of the *_cube.dds, from resfileindex.txt>",
          "black": "<md5 of the *_cube.black, or '' when absent>",
          "output": "<sha256 of the .hdr blob>",
          "sidecar_output": "<sha256 of the .pb2 sidecar blob>"
        },
        ...
      }
    }

The map lives in CI storage (``build-state/skyboxes/<server>.json``); the
output hashes reference blobs in the *production* remote store — artifacts are
never duplicated into the CI bucket.

Invalidation rules, all fail-open (any doubt re-bakes):

1. The cube or `.black` hash differs from the recorded entry.
2. Either recorded output blob does not exist in the production store.

The map deliberately carries no baker identity: the converter
(``tools/carbon-gr2-to-glb``) or encoder environment changing output bytes
with unchanged inputs is the accepted human gate — rebuild the map with the
release-data ``--rebuild-models`` flag (which covers both the models and
skyboxes maps) when the baker or its toolchain changes.

Test-mode / PR builds must never write the map: they publish to a mock, so the
outputs they "produce" do not exist in the production store and rule 2 would
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

from bootstrap.data.buildstate.models import blob_remote_key
from bootstrap.log import info
from bootstrap.log import warning


if TYPE_CHECKING:
    from pathlib import Path

    from bootstrap.remote.s3client import S3Client

#: Bump when the map layout or a field's semantics change; mismatched maps are
#: discarded (fail-open).
MAP_SCHEMA_VERSION = 1


def map_remote_key(server_id: str) -> str:
    """CI-storage key of the per-server skyboxes build-state map."""
    return f"build-state/skyboxes/{server_id}.json"


def skybox_hdr_resource_id(skybox_id: str) -> str:
    """Output resource id of a baked skybox equirect (mirrors PathManager)."""
    return f"resource://static/skyboxes/{skybox_id}.hdr"


def skybox_sidecar_resource_id(skybox_id: str) -> str:
    """Output resource id of a baked skybox metadata sidecar."""
    return f"resource://static/skyboxes/{skybox_id}.pb2"


@dataclass(frozen=True)
class SkyboxInputs:
    """Baker input identity for one skybox: the resindex MD5 columns of the
    low-detail cube and its `.black` descriptor (empty when the skybox has no
    descriptor)."""

    cube: str
    black: str = ""


class SkyboxArtifactEntry(BaseModel):
    """One memoized artifact pair: input identity plus both output blob hashes."""

    cube: str
    black: str = ""
    output: str
    sidecar_output: str


class SkyboxesBuildStateMap(BaseModel):
    """The per-server skyboxes build-state map stored in CI storage."""

    schema_version: int = Field(default=MAP_SCHEMA_VERSION)
    server_id: str = ""
    entries: dict[str, SkyboxArtifactEntry] = Field(default_factory=dict)

    def to_json(self) -> bytes:
        return (self.model_dump_json(indent=2) + "\n").encode("utf-8")

    @staticmethod
    def from_json(raw: bytes) -> SkyboxesBuildStateMap:
        return SkyboxesBuildStateMap.model_validate(json.loads(raw.decode("utf-8")))


def inputs_match(entry: SkyboxArtifactEntry, inputs: SkyboxInputs) -> bool:
    """Invalidation rule 1: the cube and `.black` hashes are unchanged."""
    return entry.cube == inputs.cube and entry.black == inputs.black


def load_map(ci_client: S3Client, server_id: str) -> SkyboxesBuildStateMap:
    """Fetch the map from CI storage; missing/corrupt/stale maps read as empty."""
    key = map_remote_key(server_id)
    try:
        raw = ci_client.read_bytes(key)
    except Exception as exc:  # noqa: BLE001 - any read failure means "no cache"
        info(f"No skyboxes build-state map at {key} ({exc}); starting cold.")
        return SkyboxesBuildStateMap(server_id=server_id)
    try:
        state_map = SkyboxesBuildStateMap.from_json(raw)
    except Exception as exc:  # noqa: BLE001 - corrupt map must not block builds
        warning(f"Discarding corrupt skyboxes build-state map {key}: {exc}")
        return SkyboxesBuildStateMap(server_id=server_id)
    if state_map.schema_version != MAP_SCHEMA_VERSION or state_map.server_id != server_id:
        warning(f"Discarding incompatible skyboxes build-state map {key}.")
        return SkyboxesBuildStateMap(server_id=server_id)
    info(f"Loaded skyboxes build-state map: {len(state_map.entries)} entries.")
    return state_map


@dataclass
class SkyboxesCacheContext:
    """Cache wiring passed into the skyboxes generator step.

    Mirrors :class:`~bootstrap.data.buildstate.models.ModelsCacheContext`:
    ``ci_client`` reads (and optionally writes) the build-state map in CI
    storage; ``prod_client`` HEADs output blobs in the production store
    (existence + size — hits are referenced in place and never downloaded).
    Set ``rebuild`` to treat every entry as a miss while still rewriting the
    map. ``workers`` sizes the probe pool in ``partition``.
    """

    server_id: str
    resource_root: str
    ci_client: S3Client
    prod_client: S3Client
    rebuild: bool = False
    map_path: Path | None = None
    upload_map: bool = False
    workers: int = 16

    _map: SkyboxesBuildStateMap = field(default_factory=SkyboxesBuildStateMap)
    _hits: dict[str, SkyboxArtifactEntry] = field(default_factory=dict)
    _hit_sizes: dict[str, int] = field(default_factory=dict)
    _new_entries: dict[str, SkyboxArtifactEntry] = field(default_factory=dict)

    def load(self) -> None:
        self._map = (
            SkyboxesBuildStateMap(server_id=self.server_id)
            if self.rebuild
            else load_map(self.ci_client, self.server_id)
        )

    def partition(
        self, desired: dict[str, SkyboxInputs]
    ) -> tuple[dict[str, SkyboxArtifactEntry], set[str]]:
        """Split desired entries (keyed by the .hdr resource id) into
        (hits, misses), HEAD-checking both output blobs of each hit.

        A skybox hits only when its inputs match (rule 1) *and* both recorded
        output blobs still exist in the production store (rule 2). The HEADs
        capture each blob's size (Content-Length), which ``hit_reference``
        later stamps into the resource index.
        """

        def stat(resource_id: str, output_hash: str) -> int | None:
            key = blob_remote_key(self.resource_root, resource_id, output_hash)
            try:
                return self.prod_client.object_size(key)
            except Exception as exc:  # noqa: BLE001 - any probe failure means "miss"
                warning(f"Skyboxes cache probe failed for {key}; re-baking: {exc}")
                return None

        candidates = (
            self._map if not self.rebuild else SkyboxesBuildStateMap(server_id=self.server_id)
        )
        # Cheap pre-filter on inputs so HEAD checks only run for candidate hits.
        pre_hits = {
            rid: entry
            for rid, inputs in desired.items()
            if (entry := candidates.entries.get(rid)) is not None and inputs_match(entry, inputs)
        }
        probes: dict[str, list[tuple[str, str]]] = {
            rid: [
                (rid, entry.output),
                (skybox_sidecar_resource_id(_skybox_id_of(rid)), entry.sidecar_output),
            ]
            for rid, entry in pre_hits.items()
        }
        flat = [(rid, probe) for rid, pair in probes.items() for probe in pair]
        with ThreadPoolExecutor(max_workers=self.workers) as pool:
            sizes = list(pool.map(lambda item: stat(item[1][0], item[1][1]), flat))
        size_of = {(rid, probe[0]): size for (rid, probe), size in zip(flat, sizes, strict=True)}
        hits: dict[str, SkyboxArtifactEntry] = {}
        for rid, entry in pre_hits.items():
            sidecar_rid = skybox_sidecar_resource_id(_skybox_id_of(rid))
            hdr_size = size_of.get((rid, rid))
            sidecar_size = size_of.get((rid, sidecar_rid))
            if hdr_size is None or sidecar_size is None:
                continue
            hits[rid] = entry
            self._hit_sizes[rid] = hdr_size
            self._hit_sizes[sidecar_rid] = sidecar_size
        misses = set(desired) - set(hits)
        self._hits = hits
        info(f"Skyboxes build-state: {len(hits)} hits, {len(misses)} misses.")
        return hits, misses

    def hit_reference(self, resource_id: str) -> list[tuple[str, str, int]]:
        """The two ``(resource_id, content_hash, size)`` index tuples of a cache
        hit: the .hdr blob and its .pb2 sidecar. Both reference production
        blobs in place — nothing is materialized locally.
        """
        entry = self._hits[resource_id]
        sidecar_rid = skybox_sidecar_resource_id(_skybox_id_of(resource_id))
        return [
            (resource_id, entry.output, self._hit_sizes[resource_id]),
            (sidecar_rid, entry.sidecar_output, self._hit_sizes[sidecar_rid]),
        ]

    def record_conversion(
        self, resource_id: str, inputs: SkyboxInputs, output: Path, sidecar_output: Path
    ) -> None:
        """Record a freshly baked artifact pair."""
        self._new_entries[resource_id] = SkyboxArtifactEntry(
            cube=inputs.cube,
            black=inputs.black,
            output=hashlib.sha256(output.read_bytes()).hexdigest(),
            sidecar_output=hashlib.sha256(sidecar_output.read_bytes()).hexdigest(),
        )

    def record_hit(self, resource_id: str) -> None:
        """Carry a cache hit's entry over into the updated map."""
        entry = self._hits.get(resource_id)
        if entry is not None:
            self._new_entries[resource_id] = entry

    def save(self) -> None:
        """Write the updated map locally and/or to CI storage."""
        updated = SkyboxesBuildStateMap(server_id=self.server_id, entries=self._new_entries)
        raw = updated.to_json()
        if self.map_path is not None:
            self.map_path.parent.mkdir(parents=True, exist_ok=True)
            self.map_path.write_bytes(raw)
            info(f"Wrote skyboxes build-state map to {self.map_path}")
        if self.upload_map:
            self.ci_client.write_bytes(map_remote_key(self.server_id), raw)
            info(f"Uploaded skyboxes build-state map for {self.server_id} to CI storage.")


def _skybox_id_of(hdr_resource_id: str) -> str:
    """Recover the skybox id from its .hdr resource id."""
    return hdr_resource_id.removeprefix("resource://static/skyboxes/").removesuffix(".hdr")
