"""Baked environment skybox (HDR equirect + sidecar) generator.

Converts every scene skybox cubemap under ``res:/dx9/scene/{universe,
wormholes,abyssal}/`` into a Radiance ``.hdr`` equirect plus a
``SkyboxMetadata`` protobuf sidecar via the ``tools/carbon-gr2-to-glb``
converter's ``--batch-skybox`` verb (Node.js). All asset acquisition goes
through the workspace ``ResourceManager`` (resfileindex-backed, per-server CDN
URLs from the descriptor); the converter itself never touches the network.

One blob pair is emitted per skybox under ``static/skyboxes/`` (see
:meth:`~bootstrap.data.workspace.generate.paths.PathManager.skyboxes_root_path`):

- ``<id>.hdr`` — the 2048x1024 RGBE equirect baked from the
  ``*_cube.dds`` BC6H cube (a plain Radiance file, consumed by
  flutter_scene's stock loader);
- ``<id>.pb2`` — the ``SkyboxMetadata`` sidecar (schema_version 1): the
  ``.black`` descriptor's ``nebulaIntensity``/``reflectionIntensity``/
  ``ambientColor``/``Tint`` (unset when the descriptor lacks them, never
  zero-filled) plus the precomputed
  diffuse SH projection in flutter_scene's convention, so the runtime — the
  web build above all — never runs the SH quadrature.

Both blobs are lazy (NON_FORCE) resources fetched on first access, exactly
like the baked ship models.

Build-state memoization
-----------------------

The step accepts an optional
:class:`~bootstrap.data.buildstate.skyboxes.SkyboxesCacheContext`. Each skybox
keys on the resindex MD5 columns of its inputs (the cube DDS and its ``.black``
descriptor); skyboxes whose inputs *and* recorded output blobs are unchanged
are referenced in place (the snapshot index points at the existing production
blobs; nothing is downloaded) instead of re-baked. See
``bootstrap.data.buildstate.skyboxes`` for the invalidation rules and the
manual-invalidation contract (the map carries no baker identity).
"""

from __future__ import annotations

import asyncio
import json
import os
import shutil

from dataclasses import dataclass
from typing import TYPE_CHECKING

from bootstrap.data.buildstate.skyboxes import SkyboxesCacheContext
from bootstrap.data.buildstate.skyboxes import SkyboxInputs
from bootstrap.data.buildstate.skyboxes import skybox_hdr_resource_id
from bootstrap.data.schema import skybox_pb2
from bootstrap.log import info
from bootstrap.log import warning

from .models import _ensure_converter_installed
from .models import _run_converter


if TYPE_CHECKING:
    from pathlib import Path

    from bootstrap.data.workspace.generate import GeneratorDatasource


#: The resindex directories skybox cubemaps come from.
SKYBOX_FAMILIES = ("universe", "wormholes", "abyssal")

#: Skybox ids derive from the full-detail cube filename with this suffix
#: removed. The suffix also excludes the `_cube_blur`/`_cube_refl`/
#: `_cube_lowdetail` variants.
CUBE_SUFFIX = "_cube.dds"

#: The sidecar schema version emitted by this generator.
SKYBOX_SIDECAR_SCHEMA_VERSION = 1

_SCENE_ROOT = "res:/dx9/scene"

_DOWNLOAD_CONCURRENCY = 32

#: Shard granularity relative to the worker count (mirrors the models step).
_SHARDS_PER_WORKER = 4


@dataclass(frozen=True)
class SkyboxSource:
    """One skybox in the resindex: its canonical id, family, and res paths."""

    id: str
    family: str
    cube_res: str
    black_res: str | None


def scan_skybox_sources(data: GeneratorDatasource) -> dict[str, SkyboxSource]:
    """Enumerate skyboxes by scanning the resindex for ``*_cube.dds``
    under each family directory; the id derives from the filename (no
    hand-maintained list). The ``.black`` descriptor is picked up when present.
    """
    sources: dict[str, SkyboxSource] = {}
    for family in SKYBOX_FAMILIES:
        prefix = f"{_SCENE_ROOT}/{family}"
        for res_path in data.resources.res.list_resources(prefix):
            filename = res_path.rsplit("/", 1)[-1]
            if not filename.endswith(CUBE_SUFFIX):
                continue
            skybox_id = filename[: -len(CUBE_SUFFIX)]
            # The descriptor is `<id>_cube.black` for universe/abyssal but
            # `<id>.black` for wormholes.
            black_res: str | None = None
            for candidate in (
                f"{_SCENE_ROOT}/{family}/{skybox_id}_cube.black",
                f"{_SCENE_ROOT}/{family}/{skybox_id}.black",
            ):
                if data.resources.res.get_resource(candidate) is not None:
                    black_res = candidate
                    break
            sources[skybox_id] = SkyboxSource(
                id=skybox_id, family=family, cube_res=res_path, black_res=black_res
            )
    return sources


def gather_skybox_inputs(
    data: GeneratorDatasource, sources: dict[str, SkyboxSource]
) -> dict[str, SkyboxInputs | None]:
    """Hash each skybox's inputs from the resindex MD5 columns.

    Returns ``{skybox_id: SkyboxInputs}``; a skybox whose cube is missing from
    the index or carries no hash maps to ``None`` (un-cacheable: always a miss,
    fail-open). A skybox without a ``.black`` descriptor records ``black=""``.
    """
    inputs: dict[str, SkyboxInputs | None] = {}
    for skybox_id, source in sources.items():
        cube_node = data.resources.res.get_resource(source.cube_res)
        if cube_node is None or not cube_node.file_hash:
            inputs[skybox_id] = None
            continue
        black_hash = ""
        if source.black_res is not None:
            black_node = data.resources.res.get_resource(source.black_res)
            if black_node is not None and black_node.file_hash:
                black_hash = black_node.file_hash
            else:
                # The descriptor exists but is un-hashable: fail open.
                inputs[skybox_id] = None
                continue
        inputs[skybox_id] = SkyboxInputs(cube=cube_node.file_hash, black=black_hash)
    return inputs


def build_sidecar(source: SkyboxSource, meta: dict) -> bytes:
    """Assemble the SkyboxMetadata sidecar bytes from the converter's metadata.

    ``meta`` is the converter's per-job JSON (``nebulaIntensity``,
    ``reflectionIntensity``, ``ambientColor``, ``tint``, ``diffuseSh``).
    Absent values stay unset (proto2 presence); a malformed SH list (not 27
    floats) is dropped rather than shipped.
    """
    pb = skybox_pb2.SkyboxMetadata()
    pb.schema_version = SKYBOX_SIDECAR_SCHEMA_VERSION
    pb.id = source.id
    pb.family = source.family
    pb.source_resource = source.cube_res

    intensity = meta.get("nebulaIntensity")
    if intensity is not None:
        pb.nebula_intensity = float(intensity)
    reflection = meta.get("reflectionIntensity")
    if reflection is not None:
        pb.reflection_intensity = float(reflection)
    for field_name, key in (("ambient_color", "ambientColor"), ("tint", "tint")):
        color = meta.get(key)
        if isinstance(color, list) and len(color) >= 3:
            target = getattr(pb, field_name)
            target.r = float(color[0])
            target.g = float(color[1])
            target.b = float(color[2])
    sh = meta.get("diffuseSh")
    if isinstance(sh, list) and len(sh) == 27 and all(isinstance(v, (int, float)) for v in sh):
        pb.diffuse_sh.extend(float(v) for v in sh)
    else:
        warning(f"Skybox {source.id}: converter reported no usable diffuse SH; sidecar lacks it.")
    return pb.SerializeToString()


async def _stage(
    data: GeneratorDatasource, res_path: str, semaphore: asyncio.Semaphore
) -> Path | None:
    node = data.resources.res.get_resource(res_path)
    if node is None:
        warning(f"Resource {res_path} not found in the resource index.")
        return None
    try:
        async with semaphore:
            await node.download()
    except Exception as exc:  # noqa: BLE001 - any download failure degrades to a missing asset
        warning(f"Resource {res_path} could not be downloaded: {exc}")
        return None
    return node.local_path


async def generate(
    data: GeneratorDatasource,
    cache: SkyboxesCacheContext | None = None,
    threads: int | None = None,
) -> list[tuple[str, str, int]]:
    """Bake skyboxes; return external blob references for cache hits.

    The returned ``(resource_id, content_hash, size)`` tuples address
    cache-hit skyboxes whose blobs already exist in the production store: they
    belong in the resource snapshot's index but have no local file (nothing is
    downloaded). Freshly baked skyboxes appear as regular files in the build
    output instead.
    """
    info("Generating skyboxes...")

    sources = scan_skybox_sources(data)
    if not sources:
        warning("No skybox cubemaps found in the resource index; skipping skybox generation.")
        return []
    info(f"Found {len(sources)} skyboxes ({', '.join(SKYBOX_FAMILIES)}).")

    inputs_by_id = gather_skybox_inputs(data, sources)

    hit_ids: set[str] = set()
    if cache is not None:
        cache.load()
        desired = {
            skybox_hdr_resource_id(skybox_id): inputs
            for skybox_id, inputs in inputs_by_id.items()
            if inputs is not None
        }
        hits, _misses = cache.partition(desired)
        hit_ids = {_skybox_id_of_hdr_rid(rid) for rid in hits}

    miss_ids = sorted(set(sources) - hit_ids)
    external_entries: list[tuple[str, str, int]] = []
    if cache is not None:
        for skybox_id in sorted(hit_ids):
            external_entries.extend(cache.hit_reference(skybox_hdr_resource_id(skybox_id)))
            # Drop stale local blobs: the output directory is not cleared
            # between runs, and the snapshot walk would otherwise index them
            # alongside the external references (duplicate resource ids).
            data.paths.get_skybox_hdr_path(skybox_id).unlink(missing_ok=True)
            data.paths.get_skybox_sidecar_path(skybox_id).unlink(missing_ok=True)
        if external_entries:
            info(f"Referenced {len(hit_ids)} cached skyboxes in place (no download).")

    produced: set[str] = set()
    if miss_ids:
        produced = await _bake(data, sources, miss_ids, threads)

    if cache is not None:
        for skybox_id in sorted(hit_ids):
            cache.record_hit(skybox_hdr_resource_id(skybox_id))
        for skybox_id in sorted(produced):
            inputs = inputs_by_id[skybox_id]
            if inputs is None:
                continue  # un-hashable inputs stay uncached
            cache.record_conversion(
                skybox_hdr_resource_id(skybox_id),
                inputs,
                data.paths.get_skybox_hdr_path(skybox_id),
                data.paths.get_skybox_sidecar_path(skybox_id),
            )
        cache.save()

    info(f"Generated {len(produced) + len(hit_ids)} skyboxes ({len(produced)} baked).")
    return external_entries


def _skybox_id_of_hdr_rid(resource_id: str) -> str:
    return resource_id.removeprefix("resource://static/skyboxes/").removesuffix(".hdr")


async def _bake(
    data: GeneratorDatasource,
    sources: dict[str, SkyboxSource],
    skybox_ids: list[str],
    threads: int | None,
) -> set[str]:
    """Stage + batch-bake the given skyboxes; return the ids actually produced."""
    _ensure_converter_installed()

    work_dir = data.config.paths.cache / "skyboxes"
    shutil.rmtree(work_dir, ignore_errors=True)
    work_dir.mkdir(parents=True, exist_ok=True)

    semaphore = asyncio.Semaphore(_DOWNLOAD_CONCURRENCY)
    staged: dict[str, Path | None] = {}

    async def stage_all() -> None:
        tasks: dict[str, asyncio.Task] = {}
        for skybox_id in skybox_ids:
            source = sources[skybox_id]
            for res_path in filter(None, [source.cube_res, source.black_res]):
                if res_path not in tasks:
                    tasks[res_path] = asyncio.create_task(_stage(data, res_path, semaphore))
        for res_path, task in tasks.items():
            staged[res_path] = await task

    info(f"Staging skybox assets for {len(skybox_ids)} skyboxes...")
    await stage_all()
    failed_stage = sum(1 for local in staged.values() if local is None)
    if failed_stage:
        warning(f"{failed_stage} skybox asset(s) could not be staged.")

    jobs = []
    for skybox_id in skybox_ids:
        source = sources[skybox_id]
        cube_local = staged.get(source.cube_res)
        if cube_local is None:
            warning(f"Skipping skybox {skybox_id}: cube could not be staged.")
            continue
        job = {
            "id": skybox_id,
            "cube": str(cube_local),
            "outHdr": str(data.paths.get_skybox_hdr_path(skybox_id)),
        }
        if source.black_res is not None and staged.get(source.black_res) is not None:
            job["black"] = str(staged[source.black_res])
        jobs.append(job)
    if not jobs:
        return set()

    n_threads = max(1, threads) if threads is not None else (os.cpu_count() or 4)
    shard_size = max(1, -(-len(jobs) // (n_threads * _SHARDS_PER_WORKER)))
    shards = [jobs[i : i + shard_size] for i in range(0, len(jobs), shard_size)]
    info(f"Baking {len(jobs)} skyboxes ({len(shards)} shard(s) on {n_threads} worker(s))...")

    run_semaphore = asyncio.Semaphore(n_threads)

    async def run_shard(index: int, shard: list[dict]) -> None:
        manifest_path = work_dir / f"manifest_skybox_{index}.json"
        meta_path = work_dir / f"meta_skybox_{index}.json"
        manifest_path.write_text(json.dumps({"jobs": shard}), encoding="utf-8")
        async with run_semaphore:
            await asyncio.to_thread(
                _run_converter,
                ["--batch-skybox", str(manifest_path), "--meta-out", str(meta_path)],
                f"SKYBOX BAKE (#{index})",
            )

    await asyncio.gather(*(run_shard(i, shard) for i, shard in enumerate(shards, 1)))

    # Merge the per-shard metadata and assemble the sidecars.
    meta_by_id: dict[str, dict] = {}
    for index in range(1, len(shards) + 1):
        meta_path = work_dir / f"meta_skybox_{index}.json"
        if not meta_path.is_file():
            continue
        for job_meta in json.loads(meta_path.read_text(encoding="utf-8"))["jobs"]:
            meta_by_id[job_meta["id"]] = job_meta

    produced: set[str] = set()
    failures: list[str] = []
    for job in jobs:
        skybox_id = job["id"]
        meta = meta_by_id.get(skybox_id)
        hdr_path = data.paths.get_skybox_hdr_path(skybox_id)
        if meta is None or not meta.get("ok") or not hdr_path.is_file():
            error_detail = (meta or {}).get("error", "no converter output")
            failures.append(f"{skybox_id} ({error_detail})")
            hdr_path.unlink(missing_ok=True)
            continue
        sidecar = build_sidecar(sources[skybox_id], meta)
        data.paths.get_skybox_sidecar_path(skybox_id).write_bytes(sidecar)
        produced.add(skybox_id)
    if failures:
        warning(f"Skybox baking failed for {len(failures)} skybox(es): {', '.join(failures)}")
    return produced
