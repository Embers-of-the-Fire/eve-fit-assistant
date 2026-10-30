"""Baked ship model (GLB) generator.

Converts every ship type's SOF appearance into self-contained GLBs via the
``tools/carbon-gr2-to-glb`` converter (Node.js). All asset acquisition goes
through the workspace ``ResourceManager`` (resfileindex-backed, per-server CDN
URLs from the descriptor); the converter itself never touches the network.

Two variants are emitted per ship under
``static/models/ships/<typeID>.<variant>.glb`` (see
:class:`~bootstrap.data.workspace.generate.paths.ShipModelVariant`):

- ``full`` — the textured model: WebP PBR texture set + meshopt geometry.
- ``base`` — the geometry-only model: same mesh, factor-only materials, no
  textures. Mobile clients use it as the cheap default; both are lazy
  (NON_FORCE) blobs fetched on first access.

The conversion is a two-phase batch protocol (see ``src/batch.js`` in the
converter):

1. ``--batch-resolve`` maps each ship DNA to its authoritative ``res:/``
   geometry/texture paths against ``data.black`` (loaded once per run).
2. The reported files are downloaded/staged through the ``ResourceManager``
   cache, then ``--batch`` converts everything offline (once per variant).

Skins (material sets) are intentionally not baked yet; the manifest schema
carries per-job DNA strings, so skin jobs can be added without converter
changes.

Build-state memoization
-----------------------

Conversion is the dominant cost of a data build (~2 s/ship/variant), so the
step accepts an optional :class:`~bootstrap.data.buildstate.models.ModelsCacheContext`.
With a cache, phase 1 always runs (cheap), per-DNA input hashes are read from
the resource index's MD5 column, and DNAs whose inputs *and* recorded output
blob are unchanged are rehydrated from the production blob store instead of
re-converted. Only misses pay the conversion cost. A ``full`` conversion whose
textures did not all stage (a failed download degrades to a textureless GLB)
is never recorded, so the DNA is reconverted on the next run instead of
memoizing the defect. See ``bootstrap.data.buildstate.models`` for the
invalidation rules and the manual-invalidation contract (the map carries no
converter identity).
"""

from __future__ import annotations

import asyncio
import json
import shutil

from typing import TYPE_CHECKING

from bootstrap.constant import GR2_TO_GLB_ROOT
from bootstrap.data.buildstate.models import ModelsCacheContext
from bootstrap.data.buildstate.models import ship_resource_id
from bootstrap.data.workspace.generate.paths import ShipModelVariant
from bootstrap.log import error
from bootstrap.log import info
from bootstrap.log import warning
from bootstrap.utils import execute_command
from bootstrap.utils import get_command


if TYPE_CHECKING:
    from collections.abc import Iterable
    from pathlib import Path

    from bootstrap.data.workspace.generate import GeneratorDatasource


SHIP_CATEGORY_ID = 6

DATA_BLACK_RESOURCE_ID = "res:/dx9/model/spaceobjectfactory/data.black"

_DOWNLOAD_CONCURRENCY = 32


def build_ship_jobs(types: dict, groups: dict, graphicids: dict) -> dict[int, str]:
    """Build ``{type_id: sof_dna}`` for every ship type with a SOF-backed graphic.

    ``types``/``groups``/``graphicids`` are the raw FSD msgpack tables. Ship
    types are selected by ``categoryID == 6`` on their group; types whose
    graphic has no ``sofHullName`` (legacy ``graphicFile`` path) are skipped.
    """
    jobs: dict[int, str] = {}
    for type_id, type_entry in types.items():
        group = groups.get(type_entry.get("groupID"))
        if group is None or group.get("categoryID") != SHIP_CATEGORY_ID:
            continue
        graphic = graphicids.get(type_entry.get("graphicID"))
        if graphic is None:
            continue
        hull = graphic.get("sofHullName")
        faction = graphic.get("sofFactionName")
        race = graphic.get("sofRaceName")
        if not hull or not faction or not race:
            warning(f"Ship type {type_id} has no SOF-backed graphic; skipping.")
            continue
        jobs[type_id] = f"{hull}:{faction}:{race}"
    return jobs


def _ensure_converter_installed() -> None:
    node_modules = GR2_TO_GLB_ROOT / "node_modules"
    if node_modules.is_dir():
        return
    info("Installing carbon-gr2-to-glb dependencies (pnpm install --frozen-lockfile)...")
    execute_command(
        [get_command("pnpm"), "install", "--frozen-lockfile"],
        "CONVERTER INSTALL",
        cwd=GR2_TO_GLB_ROOT,
    )


def _run_converter(args: list[str], title: str) -> None:
    execute_command([get_command("node"), str(GR2_TO_GLB_ROOT / "cli.js"), *args], title)


async def __stage_resource(data: GeneratorDatasource, res_path: str, semaphore: asyncio.Semaphore):
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


async def resolve_ship_jobs(data: GeneratorDatasource) -> tuple[dict[int, str], list[dict]]:
    """Build ship DNA jobs and resolve their assets (converter phase 1).

    Shared by the models step and the build-state seed/push-models commands.
    Returns ``(type_id -> dna, resolved job dicts)``; ``({}, [])`` when no
    ship types have SOF-backed graphics.
    """
    types = await data.resources.fsd.get("types")
    groups = await data.resources.fsd.get("groups")
    graphicids = await data.resources.fsd.get("graphicids")
    jobs = build_ship_jobs(types, groups, graphicids)
    if not jobs:
        return {}, []
    info(f"Resolved {len(jobs)} ship DNAs.")

    data_black = data.resources.res.get_resource(DATA_BLACK_RESOURCE_ID)
    if data_black is None:
        error(f"{DATA_BLACK_RESOURCE_ID} not found in the resource index.")
        raise FileNotFoundError(DATA_BLACK_RESOURCE_ID)
    await data_black.download()

    _ensure_converter_installed()

    work_dir = data.config.paths.cache / "models"
    shutil.rmtree(work_dir, ignore_errors=True)
    work_dir.mkdir(parents=True, exist_ok=True)

    resolve_manifest = work_dir / "manifest_resolve.json"
    resolve_manifest.write_text(
        json.dumps(
            {
                "dataBlack": str(data_black.local_path),
                "jobs": [{"id": str(type_id), "dna": dna} for type_id, dna in jobs.items()],
            }
        ),
        encoding="utf-8",
    )
    resolved_path = work_dir / "resolved.json"
    info("Resolving ship model assets (phase 1: batch-resolve)...")
    _run_converter(
        ["--batch-resolve", str(resolve_manifest), "--resolve-out", str(resolved_path)],
        "MODEL RESOLVE",
    )
    resolved = json.loads(resolved_path.read_text(encoding="utf-8"))

    failed_resolve = [job for job in resolved["jobs"] if job.get("error")]
    for job in failed_resolve:
        warning(f"DNA resolution failed for job {job['id']} ({job['dna']}): {job['error']}")

    return jobs, resolved["jobs"]


def gather_dna_inputs(
    data: GeneratorDatasource, resolved_jobs: list[dict]
) -> tuple[dict[str, list[int]], dict[str, dict], dict[str, tuple[str, dict[str, str]] | None]]:
    """Group resolved jobs by DNA and hash their inputs from the resource index.

    Returns ``(dna_aliases, dna_jobs, dna_inputs)``:

    - ``dna_aliases``: DNA -> type ids sharing it (identical GLBs; convert once).
    - ``dna_jobs``: DNA -> the representative resolved job dict.
    - ``dna_inputs``: DNA -> ``(gr2 md5, {texture res path: md5})``, or ``None``
      when any source is missing from the index or carries no hash. ``None``
      inputs are un-cacheable: the DNA is always a miss (fail-open).
    """
    dna_aliases: dict[str, list[int]] = {}
    dna_jobs: dict[str, dict] = {}
    for job in resolved_jobs:
        if job.get("error"):
            continue
        dna = job["dna"]
        dna_aliases.setdefault(dna, []).append(int(job["id"]))
        dna_jobs.setdefault(dna, job)

    dna_inputs: dict[str, tuple[str, dict[str, str]] | None] = {}
    for dna, job in dna_jobs.items():
        geometry = job.get("geometryResPath")
        if not geometry:
            dna_inputs[dna] = None
            continue
        geo_node = data.resources.res.get_resource(geometry)
        if geo_node is None or not geo_node.file_hash:
            dna_inputs[dna] = None
            continue
        textures: dict[str, str] = {}
        hashable = True
        for tex_path in job.get("textureResPaths", []):
            tex_node = data.resources.res.get_resource(tex_path)
            if tex_node is None or not tex_node.file_hash:
                hashable = False
                break
            textures[tex_path_normalize(tex_path)] = tex_node.file_hash
        dna_inputs[dna] = (geo_node.file_hash, textures) if hashable else None
    return dna_aliases, dna_jobs, dna_inputs


def tex_path_normalize(res_path: str) -> str:
    """Normalize a resolved res path for stable map keys (index keys are lowercase)."""
    return res_path.replace("\\", "/").lower()


async def generate(data: GeneratorDatasource, cache: ModelsCacheContext | None = None):
    info("Generating ship models...")

    jobs, resolved_jobs = await resolve_ship_jobs(data)
    if not jobs:
        warning("No ship types with SOF-backed graphics found; skipping model generation.")
        return

    dna_aliases, dna_jobs, dna_inputs = gather_dna_inputs(data, resolved_jobs)
    if not dna_jobs:
        warning("No resolvable ship model jobs; skipping model generation.")
        return

    work_dir = data.config.paths.cache / "models"
    data_black = data.resources.res.get_resource(DATA_BLACK_RESOURCE_ID)

    variants: tuple[tuple[ShipModelVariant, dict[str, str]], ...] = (
        (ShipModelVariant.FULL, {"format": "webp"}),
        (ShipModelVariant.BASE, {"format": "none"}),
    )

    # Partition DNAs into cache hits / misses per variant. A DNA hits only when
    # every alias of it hits (entries are per resource id; aliases share bytes).
    hit_outputs: dict[ShipModelVariant, dict[str, str]] = {variant: {} for variant, _ in variants}
    if cache is not None:
        cache.load()
        desired: dict[str, tuple[str, dict[str, str]]] = {}
        for dna, aliases in dna_aliases.items():
            inputs = dna_inputs[dna]
            if inputs is None:
                continue  # un-hashable inputs: implicit miss (fail-open)
            model_hash, textures = inputs
            for alias in aliases:
                for variant, _tex in variants:
                    desired[ship_resource_id(alias, variant)] = (
                        model_hash,
                        textures if variant is ShipModelVariant.FULL else {},
                    )
        hits, _misses = cache.partition(desired)
        for variant, _tex in variants:
            for dna, aliases in dna_aliases.items():
                rids = [ship_resource_id(alias, variant) for alias in aliases]
                if rids and all(rid in hits for rid in rids):
                    hit_outputs[variant][dna] = hits[rids[0]].output

    semaphore = asyncio.Semaphore(_DOWNLOAD_CONCURRENCY)
    stage_tasks: dict[str, asyncio.Task] = {}
    staged: dict[str, Path | None] = {}

    async def stage_dnas(dnas: Iterable[str]) -> None:
        pending: list[tuple[str, asyncio.Task]] = []
        for dna in dnas:
            job = dna_jobs[dna]
            for res_path in filter(
                None, [job.get("geometryResPath"), *job.get("textureResPaths", [])]
            ):
                if res_path not in stage_tasks:
                    stage_tasks[res_path] = asyncio.create_task(
                        __stage_resource(data, res_path, semaphore)
                    )
                pending.append((res_path, stage_tasks[res_path]))
        for res_path, task in pending:
            staged[res_path] = await task

    async def convert_dnas(
        variant: ShipModelVariant, texture: dict[str, str], dnas: set[str], tag: str
    ) -> set[str]:
        """Stage + batch-convert the given DNAs; return the DNAs actually produced."""
        if not dnas:
            return set()
        await stage_dnas(dnas)
        convert_jobs = []
        for dna in sorted(dnas):
            job = dna_jobs[dna]
            geometry = job.get("geometryResPath")
            if not geometry or staged.get(geometry) is None:
                warning(f"Skipping job {job['id']}: geometry could not be staged.")
                continue
            convert_jobs.append(
                {
                    "id": job["id"],
                    "dna": dna,
                    "gr2": str(staged[geometry]),
                    "textures": {
                        res_path: str(staged[res_path])
                        for res_path in job.get("textureResPaths", [])
                        if staged.get(res_path) is not None
                    },
                }
            )
        if not convert_jobs:
            return set()
        convert_manifest = work_dir / f"manifest_convert_{variant}_{tag}.json"
        convert_manifest.write_text(
            json.dumps(
                {
                    "dataBlack": str(data_black.local_path),
                    "texture": texture,
                    "geometry": "meshopt",
                    "jobs": [
                        {
                            **job,
                            "out": str(data.paths.get_ship_model_path(int(job["id"]), variant)),
                        }
                        for job in convert_jobs
                    ],
                }
            ),
            encoding="utf-8",
        )
        info(f"Converting {len(convert_jobs)} ship models ({variant}, phase 2: batch)...")
        _run_converter(["--batch", str(convert_manifest)], f"MODEL CONVERT ({variant})")

        produced = set()
        failures = []
        for job in convert_jobs:
            if data.paths.get_ship_model_path(int(job["id"]), variant).is_file():
                produced.add(job["dna"])
            else:
                failures.append(int(job["id"]))
        if failures:
            warning(
                f"Model conversion ({variant}) failed for "
                f"{len(failures)} type(s): {', '.join(str(t) for t in sorted(failures))}"
            )
        return produced

    def fully_staged_textures(dna: str) -> bool:
        """Whether every texture of the DNA staged (no failed downloads)."""
        return all(
            staged.get(res_path) is not None
            for res_path in dna_jobs[dna].get("textureResPaths", [])
        )

    all_miss = {variant: set(dna_jobs) - set(hit_outputs[variant]) for variant, _ in variants}
    info("Staging model assets via the resource manager...")
    await stage_dnas(set().union(*all_miss.values()))
    n_failed_stage = sum(1 for local in staged.values() if local is None)
    info(f"Staged {len(staged) - n_failed_stage}/{len(staged)} assets.")

    produced: dict[ShipModelVariant, set[str]] = {}
    converted: dict[ShipModelVariant, set[str]] = {}
    for variant, texture in variants:
        converted_v = await convert_dnas(variant, texture, all_miss[variant], "main")
        rehydrated_v: set[str] = set()
        if cache is not None and hit_outputs[variant]:
            demoted: set[str] = set()
            for dna, output_hash in sorted(hit_outputs[variant].items()):
                canonical = dna_aliases[dna][0]
                rid = ship_resource_id(canonical, variant)
                dest = data.paths.get_ship_model_path(canonical, variant)
                if cache.download_output(rid, output_hash, dest):
                    rehydrated_v.add(dna)
                else:
                    warning(f"Cached output {rid} unavailable; reconverting.")
                    demoted.add(dna)
            if demoted:
                converted_v |= await convert_dnas(variant, texture, demoted, "retry")
        produced_v = converted_v | rehydrated_v

        # Types sharing one DNA produce byte-identical GLBs; copy to aliases.
        for dna in produced_v:
            aliases = dna_aliases[dna]
            source = data.paths.get_ship_model_path(aliases[0], variant)
            for alias_id in aliases[1:]:
                shutil.copy2(source, data.paths.get_ship_model_path(alias_id, variant))

        produced[variant] = produced_v
        converted[variant] = converted_v

    if cache is not None:
        for variant, _tex in variants:
            for dna in produced[variant]:
                inputs = dna_inputs[dna]
                for alias in dna_aliases[dna]:
                    rid = ship_resource_id(alias, variant)
                    if dna in converted[variant]:
                        if inputs is None:
                            continue  # un-hashable inputs stay uncached
                        # A texture that failed to stage is silently omitted
                        # from the FULL GLB; recording the full desired hashes
                        # would rehydrate the degraded output forever.
                        if variant is ShipModelVariant.FULL and not fully_staged_textures(dna):
                            continue  # degraded output stays uncached; reconverted next run
                        model_hash, textures = inputs
                        cache.record_conversion(
                            rid,
                            model_hash,
                            textures if variant is ShipModelVariant.FULL else {},
                            data.paths.get_ship_model_path(alias, variant),
                        )
                    else:
                        cache.record_hit(rid)
        cache.save()

    total_ships = sum(len(aliases) for aliases in dna_aliases.values())
    info(f"Generated {total_ships} ship models x2 variants ({len(dna_jobs)} unique DNAs).")
