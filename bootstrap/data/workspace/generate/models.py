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
   cache, then ``--batch`` converts everything offline (once per variant),
   sharded across parallel converter processes — ``threads`` workers (default:
   CPU count) converting shards of ``batch_size`` jobs (default: derived from
   the worker count for load balancing).

Skins (material sets) are intentionally not baked yet; the manifest schema
carries per-job DNA strings, so skin jobs can be added without converter
changes.

Build-state memoization
-----------------------

Conversion is the dominant cost of a data build (~2 s/ship/variant), so the
step accepts an optional :class:`~bootstrap.data.buildstate.models.ModelsCacheContext`.
With a cache, phase 1 always runs (cheap), per-DNA input identities combine
the resource index's MD5 column (GR2/texture hashes) with the DNA itself and
the phase-1 ``sofHash`` — a sha256 over the DNA's resolved SOF values
(materials/shaders/glow/areas, exactly what the converter derives from
data.black) — and DNAs whose inputs *and* recorded output blob are unchanged
are referenced in place (the snapshot index points at the existing production
blob; nothing is downloaded) instead of re-converted. Only misses pay the
conversion cost. See ``bootstrap.data.buildstate.models`` for the
invalidation rules and the manual-invalidation contract (the map carries no
converter identity).

Conversion verification and diagnostics
---------------------------------------

Every convert shard runs the converter with ``--stats-out``; the per-shard
reports are merged into ``cache/models/conversion_diagnostics.json`` together
with the shard process results (return code + stderr tail), per-job failures,
and an overall ``complete`` flag. A conversion counts only when its batch
result carries no ``error`` and reports ``stats.complete`` — output file
existence is never accepted as evidence. Jobs whose required inputs did not
all stage (geometry, or any texture for the ``full`` variant) never enter a
convert manifest; missing inputs are failures, not degraded textureless
conversions. If any required conversion failed or stayed unverified, the step
raises :class:`IncompleteConversionError` before the snapshot is generated,
so an incomplete model set can never be indexed.
"""

from __future__ import annotations

import asyncio
import json
import os
import shutil
import subprocess

from dataclasses import asdict
from dataclasses import dataclass
from typing import TYPE_CHECKING

from bootstrap.constant import GR2_TO_GLB_ROOT
from bootstrap.data.buildstate.models import ModelInputs
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

#: Filename of the per-run conversion diagnostics report under
#: ``cache/models/`` (written by ``generate`` after the convert phase).
_DIAGNOSTICS_FILENAME = "conversion_diagnostics.json"

#: Trailing stderr characters retained per convert shard in the diagnostics.
_SHARD_STDERR_TAIL_CHARS = 4000

#: Maximum number of failures spelled out in the incomplete-conversion error.
_FAILURE_PREVIEW_COUNT = 5


class IncompleteConversionError(RuntimeError):
    """Raised when any required model conversion failed or stayed unverified.

    Raising before snapshot generation guarantees that an incomplete or
    partially regenerated model set is never indexed as a successful build.
    """


@dataclass(frozen=True)
class ConversionFailure:
    """One required conversion that failed or could not be verified."""

    type_id: int
    dna: str
    variant: str
    reason: str


@dataclass(frozen=True)
class ShardProcessResult:
    """Converter process outcome for one convert shard (never exits the caller)."""

    returncode: int
    stderr_tail: str


@dataclass(frozen=True)
class ShardReport:
    """Diagnostics record for one convert shard invocation."""

    variant: ShipModelVariant
    index: int
    manifest_name: str
    stats_name: str
    returncode: int
    stderr_tail: str
    results: tuple[dict, ...]
    parse_error: str | None


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


def _run_converter(args: list[str], title: str, env: dict[str, str] | None = None) -> None:
    kwargs = {}
    if env is not None:
        kwargs["env"] = env
    execute_command([get_command("node"), str(GR2_TO_GLB_ROOT / "cli.js"), *args], title, **kwargs)


def _run_converter_shard(args: list[str], env: dict[str, str] | None = None) -> ShardProcessResult:
    """Run one convert shard and report the outcome instead of exiting.

    Unlike the resolve phase (:func:`_run_converter`), a failing convert shard
    must not abort the other shards: its jobs are marked unverified and every
    failure is surfaced in the run diagnostics.
    """
    process = subprocess.run(
        [get_command("node"), str(GR2_TO_GLB_ROOT / "cli.js"), *args],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        env=env,
        check=False,  # the return code is reported and surfaced in the diagnostics
    )
    return ShardProcessResult(
        returncode=process.returncode,
        stderr_tail=(process.stderr or "")[-_SHARD_STDERR_TAIL_CHARS:],
    )


#: Shard granularity relative to the worker count: shards are finer than the
#: worker count so slow ships rebalance across workers instead of leaving a
#: worker idle on the tail of one large shard.
_SHARDS_PER_WORKER = 4


def chunk_convert_jobs(jobs: list[dict], threads: int, batch_size: int | None) -> list[list[dict]]:
    """Split convert jobs into shard manifests of ``batch_size`` jobs each.

    ``batch_size=None`` derives the shard size from the worker count
    (``_SHARDS_PER_WORKER`` times finer than an even split, min 1) so slow
    ships rebalance across workers. Shard contents keep the input order.
    """
    if not jobs:
        return []
    size = (
        batch_size
        if batch_size and batch_size > 0
        else max(1, -(-len(jobs) // (max(1, threads) * _SHARDS_PER_WORKER)))
    )
    return [jobs[i : i + size] for i in range(0, len(jobs), size)]


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
    ship types have SOF-backed graphics. Resolved job dicts carry
    ``geometryResPath``/``textureResPaths`` plus ``sof`` (the resolved SOF
    values the convert phase consumes) and ``sofHash`` (its fingerprint).
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
    process = _run_converter_shard(
        ["--batch-resolve", str(resolve_manifest), "--resolve-out", str(resolved_path)]
    )
    if not resolved_path.is_file():
        raise RuntimeError(
            f"Model resolution failed without a report (return code {process.returncode}): "
            f"{process.stderr_tail}"
        )
    try:
        resolved = json.loads(resolved_path.read_text(encoding="utf-8"))
        if not isinstance(resolved, dict) or not isinstance(resolved.get("jobs"), list):
            raise TypeError("resolve report has no jobs list")
    except (json.JSONDecodeError, TypeError) as exc:
        raise RuntimeError(
            f"Model DNA resolution report is invalid (return code {process.returncode}): "
            f"{exc}; {process.stderr_tail}"
        ) from exc

    failed_resolve = [job for job in resolved["jobs"] if job.get("error")]
    for job in failed_resolve:
        warning(f"DNA resolution failed for job {job['id']} ({job['dna']}): {job['error']}")

    return jobs, resolved["jobs"]


def gather_dna_inputs(
    data: GeneratorDatasource, resolved_jobs: list[dict]
) -> tuple[dict[str, list[int]], dict[str, dict], dict[str, ModelInputs | None]]:
    """Group resolved jobs by DNA and hash their inputs from the resource index.

    Returns ``(dna_aliases, dna_jobs, dna_inputs)``:

    - ``dna_aliases``: DNA -> type ids sharing it (identical GLBs; convert once).
    - ``dna_jobs``: DNA -> the representative resolved job dict.
    - ``dna_inputs``: DNA -> the ``full``-variant :class:`ModelInputs` (GR2 md5,
      texture md5s, the DNA itself, and the phase-1 ``sofHash`` fingerprint of
      the resolved SOF values), or ``None`` when any source is missing from the
      index or carries no hash. ``None`` inputs are un-cacheable: the DNA is
      always a miss (fail-open).
    """
    dna_aliases: dict[str, list[int]] = {}
    dna_jobs: dict[str, dict] = {}
    for job in resolved_jobs:
        if job.get("error"):
            continue
        dna = job["dna"]
        dna_aliases.setdefault(dna, []).append(int(job["id"]))
        dna_jobs.setdefault(dna, job)

    dna_inputs: dict[str, ModelInputs | None] = {}
    for dna, job in dna_jobs.items():
        geometry = job.get("geometryResPath")
        sof_hash = job.get("sofHash")
        if not geometry or not sof_hash:
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
        dna_inputs[dna] = (
            ModelInputs(model=geo_node.file_hash, texture=textures, dna=dna, sof=sof_hash)
            if hashable
            else None
        )
    return dna_aliases, dna_jobs, dna_inputs


def tex_path_normalize(res_path: str) -> str:
    """Normalize a resolved res path for stable map keys (index keys are lowercase)."""
    return res_path.replace("\\", "/").lower()


def staged_requirement_missing(
    job: dict, staged: dict[str, Path | None], variant: ShipModelVariant
) -> str | None:
    """Failure reason when required staged inputs are missing, else ``None``.

    FULL conversions need the geometry and every resolved texture; a missing
    texture must fail the job instead of degrading to a textureless GLB. BASE
    conversions need only the geometry.
    """
    geometry = job.get("geometryResPath")
    if not geometry or staged.get(geometry) is None:
        return "geometry-missing"
    if variant is ShipModelVariant.FULL:
        for res_path in job.get("textureResPaths", []):
            if staged.get(res_path) is None:
                return f"texture-missing:{res_path}"
    return None


def fully_staged_textures(job: dict, staged: dict[str, Path | None]) -> bool:
    """Whether every texture of the resolved job staged (no failed downloads)."""
    return all(staged.get(res_path) is not None for res_path in job.get("textureResPaths", []))


def parse_stats_report(raw: str) -> tuple[list[dict], str | None]:
    """Parse a converter ``--stats-out`` report into ``(results, parse_error)``.

    A missing ``results`` list or invalid JSON is reported, never raised, so
    one corrupt shard report cannot hide the remaining shards' results.
    """
    try:
        document = json.loads(raw)
    except json.JSONDecodeError as exc:
        return [], f"invalid stats report: {exc}"
    results = document.get("results") if isinstance(document, dict) else None
    if not isinstance(results, list):
        return [], "stats report has no results list"
    return [result for result in results if isinstance(result, dict)], None


def conversion_failure_reason(
    result: dict | None, *, variant: ShipModelVariant | None = None, dna: str | None = None
) -> str | None:
    """None when the batch result verifies the requested complete conversion.

    Success requires the batch result for the job's id to carry no ``error``
    and to report ``stats.complete``. Output file existence is never consulted:
    the converter writes complete GLBs via temp+rename, so a file on disk alone
    cannot distinguish a current verified artifact from a leftover.
    """
    if result is None:
        return "no-batch-result"
    if result.get("error"):
        return f"converter-error:{result['error']}"
    if result.get("incomplete") is True:
        return "incomplete"
    stats = result.get("stats")
    if not isinstance(stats, dict) or stats.get("complete") is not True:
        return "incomplete"
    if variant is not None and stats.get("variant") != variant.value:
        return f"variant-mismatch:{stats.get('variant')}"
    if dna is not None and stats.get("dna") != dna:
        return "dna-mismatch"
    return None


def evaluate_conversion_jobs(
    convert_jobs: list[dict],
    results_by_id: dict[str, dict],
    variant: ShipModelVariant,
) -> tuple[set[str], list[ConversionFailure]]:
    """Split convert jobs into verified produced DNAs and failures."""
    produced: set[str] = set()
    failures: list[ConversionFailure] = []
    for job in convert_jobs:
        reason = conversion_failure_reason(
            results_by_id.get(str(job["id"])), variant=variant, dna=job["dna"]
        )
        if reason is None:
            produced.add(job["dna"])
        else:
            failures.append(ConversionFailure(int(job["id"]), job["dna"], variant.value, reason))
    return produced, failures


def merge_variant_results(shard_reports: Iterable[ShardReport]) -> dict[str, dict]:
    """Merge per-shard batch results into one ``job id -> result`` map."""
    merged: dict[str, dict] = {}
    for report in shard_reports:
        for result in report.results:
            result_id = result.get("id")
            if result_id is not None:
                merged[str(result_id)] = result
    return merged


def cache_eligible(variant: ShipModelVariant, textures_staged: bool) -> bool:
    """Whether a verified conversion may be recorded in the build-state map.

    Only verified conversions reach this check (see
    :func:`evaluate_conversion_jobs`). A FULL conversion whose textures did
    not all stage must never be memoized: recording the desired hashes would
    reference degraded output forever. BASE conversions carry no texture
    identity, so their staging state does not gate eligibility.
    """
    return variant is not ShipModelVariant.FULL or textures_staged


def classify_resolve_error(job: dict) -> tuple[ConversionFailure | None, dict | None]:
    """Classify one failed DNA resolution as a hard failure or explicit skip.

    The converter's structured ``NO_SOURCE_MESH`` code identifies candidates that
    have no displayable geometry. Other errors remain hard failures. One failed
    DNA produces one diagnostic, not a duplicate failure per output variant.
    """
    reason = job.get("error")
    if not reason:
        return None, None
    if job.get("errorCode") == "NO_SOURCE_MESH":
        return None, {
            "type_id": int(job["id"]),
            "dna": job["dna"],
            "reason": "no-source-mesh",
        }
    return (
        ConversionFailure(int(job["id"]), job["dna"], "resolve", f"resolve-error:{reason}"),
        None,
    )


def shard_report_entry(report: ShardReport) -> dict:
    """Serializable diagnostics entry for one convert shard."""
    return {
        "variant": report.variant.value,
        "index": report.index,
        "manifest": report.manifest_name,
        "stats": report.stats_name,
        "returncode": report.returncode,
        "stderr_tail": report.stderr_tail,
        "results": len(report.results),
        "parse_error": report.parse_error,
    }


def build_conversion_diagnostics(
    shard_reports: list[ShardReport],
    failures: list[ConversionFailure],
    converted_counts: dict[ShipModelVariant, int],
    cache_hit_counts: dict[ShipModelVariant, int],
    skipped: list[dict] | None = None,
) -> dict:
    """Assemble the per-run ``conversion_diagnostics.json`` document."""
    jobs = [
        {**result, "variant": report.variant.value}
        for report in shard_reports
        for result in report.results
    ]
    jobs.sort(key=lambda result: (result["variant"], str(result.get("id", ""))))
    return {
        "complete": not failures,
        "converted": {variant.value: count for variant, count in converted_counts.items()},
        "cache_hits": {variant.value: count for variant, count in cache_hit_counts.items()},
        "shards": [shard_report_entry(report) for report in shard_reports],
        "failures": [asdict(failure) for failure in failures],
        "skipped": skipped or [],
        "stale_outputs_removed": [],
        "jobs": jobs,
    }


def remove_stale_ship_model_outputs(model_dir: Path, retained_type_ids: set[int]) -> list[str]:
    """Remove obsolete full/base GLBs while leaving unrelated files untouched.

    Snapshot generation walks the output directory, so a model for a skipped or
    removed type must not survive merely because this run did not convert it.
    """
    removed: list[str] = []
    for variant in (ShipModelVariant.FULL, ShipModelVariant.BASE):
        for path in model_dir.glob(f"*.{variant.value}.glb"):
            try:
                type_id = int(path.name.split(".", maxsplit=1)[0])
            except ValueError:
                continue
            if type_id not in retained_type_ids:
                path.unlink()
                removed.append(path.name)
    for path in model_dir.glob("*.glb.tmp-*"):
        if path.is_file():
            path.unlink()
            removed.append(path.name)
    return sorted(removed)


async def generate(
    data: GeneratorDatasource,
    cache: ModelsCacheContext | None = None,
    threads: int | None = None,
    batch_size: int | None = None,
) -> list[tuple[str, str, int]]:
    """Generate ship GLBs; return external blob references for cache hits.

    The returned ``(resource_id, content_hash, size)`` tuples address cache-hit
    models whose blobs already exist in the production store: they belong in
    the resource snapshot's index but have no local file (nothing is
    downloaded). Converted models appear as regular files in the build output
    instead.
    """
    info("Generating ship models...")

    jobs, resolved_jobs = await resolve_ship_jobs(data)
    if not jobs:
        warning("No ship types with SOF-backed graphics found; skipping model generation.")
        return []

    dna_aliases, dna_jobs, dna_inputs = gather_dna_inputs(data, resolved_jobs)

    n_threads = max(1, threads) if threads is not None else (os.cpu_count() or 4)
    # libvips (sharp) defaults to one thread per core *per converter process*;
    # cap it so shard processes do not oversubscribe the machine.
    cpu_count = os.cpu_count() or 4
    converter_env = {
        **os.environ,
        "GR2_TO_GLB_SHARP_THREADS": str(max(1, cpu_count // n_threads)),
    }

    work_dir = data.config.paths.cache / "models"
    data_black = data.resources.res.get_resource(DATA_BLACK_RESOURCE_ID)

    variants: tuple[tuple[ShipModelVariant, dict[str, str]], ...] = (
        (ShipModelVariant.FULL, {"format": "webp"}),
        (ShipModelVariant.BASE, {"format": "none"}),
    )

    # Partition DNAs into cache hits / misses per variant. A DNA hits only when
    # every alias of it hits (entries are per resource id; aliases share bytes).
    hit_dnas: dict[ShipModelVariant, set[str]] = {variant: set() for variant, _ in variants}
    if cache is not None:
        cache.load()
        desired: dict[str, ModelInputs] = {}
        for dna, aliases in dna_aliases.items():
            inputs = dna_inputs[dna]
            if inputs is None:
                continue  # un-hashable inputs: implicit miss (fail-open)
            for alias in aliases:
                for variant, _tex in variants:
                    desired[ship_resource_id(alias, variant)] = (
                        inputs if variant is ShipModelVariant.FULL else inputs.without_textures()
                    )
        hits, _misses = cache.partition(desired)
        for variant, _tex in variants:
            for dna, aliases in dna_aliases.items():
                rids = [ship_resource_id(alias, variant) for alias in aliases]
                if rids and all(rid in hits for rid in rids):
                    hit_dnas[variant].add(dna)

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
    ) -> tuple[set[str], list[ConversionFailure], list[ShardReport]]:
        """Stage + batch-convert the given DNAs.

        Jobs whose required inputs did not all stage (geometry, or any
        texture for ``full``) never enter a convert manifest — missing inputs
        are failures, not degraded conversions. A job counts as produced only
        when its batch result carries no ``error`` and reports
        ``stats.complete``; output file existence is never accepted as
        evidence. Returns ``(produced dnas, failures, shard reports)``; a
        shard process failure is recorded so the remaining shards still
        finish and their stats can be collected.
        """
        if not dnas:
            return set(), [], []
        await stage_dnas(dnas)
        convert_jobs = []
        failures: list[ConversionFailure] = []
        for dna in sorted(dnas):
            job = dna_jobs[dna]
            missing = staged_requirement_missing(job, staged, variant)
            if missing is not None:
                warning(f"Job {job['id']} ({variant}) not converted: {missing}.")
                failures.append(ConversionFailure(int(job["id"]), dna, variant.value, missing))
                continue
            convert_jobs.append(
                {
                    "id": job["id"],
                    "dna": dna,
                    # Pre-resolved SOF values: the converter converts from
                    # exactly the object the cache fingerprinted (sofHash).
                    "sof": job.get("sof"),
                    "gr2": str(staged[job["geometryResPath"]]),
                    "textures": {
                        res_path: str(staged[res_path])
                        for res_path in job.get("textureResPaths", [])
                        if staged.get(res_path) is not None
                    },
                }
            )
        if not convert_jobs:
            return set(), failures, []

        shards = chunk_convert_jobs(convert_jobs, n_threads, batch_size)
        info(
            f"Converting {len(convert_jobs)} ship models ({variant}, phase 2: "
            f"{len(shards)} shard(s) on {n_threads} worker(s))..."
        )
        semaphore = asyncio.Semaphore(n_threads)

        async def run_shard(index: int, shard: list[dict]) -> ShardReport:
            convert_manifest = work_dir / f"manifest_convert_{variant}_{tag}_{index}.json"
            stats_path = work_dir / f"stats_convert_{variant}_{tag}_{index}.json"
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
                            for job in shard
                        ],
                    }
                ),
                encoding="utf-8",
            )
            async with semaphore:
                process = await asyncio.to_thread(
                    _run_converter_shard,
                    ["--batch", str(convert_manifest), "--stats-out", str(stats_path)],
                    converter_env,
                )
            results: list[dict] = []
            parse_error: str | None = None
            if stats_path.is_file():
                try:
                    raw_stats = stats_path.read_text(encoding="utf-8")
                except (OSError, UnicodeError) as exc:
                    parse_error = f"could not read stats report: {exc}"
                else:
                    results, parse_error = parse_stats_report(raw_stats)
            else:
                parse_error = "converter wrote no stats report"
            return ShardReport(
                variant=variant,
                index=index,
                manifest_name=convert_manifest.name,
                stats_name=stats_path.name,
                returncode=process.returncode,
                stderr_tail=process.stderr_tail,
                results=tuple(results),
                parse_error=parse_error,
            )

        reports = list(
            await asyncio.gather(*(run_shard(i, shard) for i, shard in enumerate(shards, 1)))
        )
        produced, job_failures = evaluate_conversion_jobs(
            convert_jobs, merge_variant_results(reports), variant
        )
        failures.extend(job_failures)
        return produced, failures, reports

    all_miss = {variant: set(dna_jobs) - hit_dnas[variant] for variant, _ in variants}
    info("Staging model assets via the resource manager...")
    await stage_dnas(set().union(*all_miss.values()))
    n_failed_stage = sum(1 for local in staged.values() if local is None)
    info(f"Staged {len(staged) - n_failed_stage}/{len(staged)} assets.")

    produced: dict[ShipModelVariant, set[str]] = {}
    converted: dict[ShipModelVariant, set[str]] = {}
    failures: list[ConversionFailure] = []
    skipped: list[dict] = []
    for job in resolved_jobs:
        failure, skip = classify_resolve_error(job)
        if failure is not None:
            failures.append(failure)
        if skip is not None:
            skipped.append(skip)
    shard_reports: list[ShardReport] = []
    for variant, texture in variants:
        converted_v, failures_v, reports_v = await convert_dnas(
            variant, texture, all_miss[variant], "main"
        )
        failures.extend(failures_v)
        shard_reports.extend(reports_v)

        # Types sharing one DNA produce byte-identical GLBs; copy to aliases.
        for dna in converted_v:
            aliases = dna_aliases[dna]
            source = data.paths.get_ship_model_path(aliases[0], variant)
            for alias_id in aliases[1:]:
                shutil.copy2(source, data.paths.get_ship_model_path(alias_id, variant))

        produced[variant] = converted_v | hit_dnas[variant]
        converted[variant] = converted_v

    diagnostics = build_conversion_diagnostics(
        shard_reports,
        failures,
        converted_counts={variant: len(converted[variant]) for variant, _ in variants},
        cache_hit_counts={variant: len(hit_dnas[variant]) for variant, _ in variants},
        skipped=skipped,
    )
    diagnostics_path = work_dir / _DIAGNOSTICS_FILENAME
    diagnostics_path.write_text(json.dumps(diagnostics, indent=2) + "\n", encoding="utf-8")

    if failures:
        preview = ", ".join(
            f"{failure.type_id} ({failure.variant}: {failure.reason})"
            for failure in failures[:_FAILURE_PREVIEW_COUNT]
        )
        remaining = len(failures) - _FAILURE_PREVIEW_COUNT
        suffix = f", and {remaining} more" if remaining > 0 else ""
        message = (
            f"Model conversion incomplete: {len(failures)} failure(s): {preview}{suffix}. "
            f"Diagnostics: {diagnostics_path}"
        )
        error(message)
        raise IncompleteConversionError(message)

    skipped_type_ids = {entry["type_id"] for entry in skipped}
    model_dir = data.paths.get_ship_model_path(0, ShipModelVariant.FULL).parent
    removed_stale = remove_stale_ship_model_outputs(
        model_dir, set(jobs).difference(skipped_type_ids)
    )
    diagnostics["stale_outputs_removed"] = removed_stale
    if removed_stale:
        diagnostics_path.write_text(json.dumps(diagnostics, indent=2) + "\n", encoding="utf-8")
        info(f"Removed {len(removed_stale)} stale model variant artifact(s).")
    if skipped:
        info(f"Skipped {len(skipped)} non-displayable SOF candidates with no source mesh.")
    info(f"Model conversion diagnostics written to {diagnostics_path}")

    # Cache hits are referenced in place: no GLB is downloaded or written
    # locally. The snapshot index points at the existing production blob, and
    # publish HEAD-checks each reference again before accepting it. This runs
    # only after every miss verified: a failed run must not delete the local
    # known-good artifacts of hits it never regenerated.
    external_entries: list[tuple[str, str, int]] = []
    if cache is not None:
        for variant, _tex in variants:
            for dna in sorted(hit_dnas[variant]):
                for alias in dna_aliases[dna]:
                    external_entries.append(cache.hit_reference(ship_resource_id(alias, variant)))
                    # Drop any stale local GLB at the same path: the output
                    # directory is not cleared between runs, so an earlier
                    # conversion may have left one behind. The snapshot walk
                    # would index it alongside the external reference, making
                    # the resource id appear twice with different content
                    # hashes.
                    data.paths.get_ship_model_path(alias, variant).unlink(missing_ok=True)
        if external_entries:
            info(f"Referenced {len(external_entries)} cached models in place (no download).")

    if cache is not None:
        for variant, _tex in variants:
            for dna in produced[variant]:
                inputs = dna_inputs[dna]
                textures_staged = fully_staged_textures(dna_jobs[dna], staged)
                for alias in dna_aliases[dna]:
                    rid = ship_resource_id(alias, variant)
                    if dna in converted[variant]:
                        if inputs is None:
                            continue  # un-hashable inputs stay uncached
                        # Only verified conversions reach this point; a FULL
                        # conversion with unstaged textures would reference
                        # degraded output forever, so it stays uncached.
                        if not cache_eligible(variant, textures_staged):
                            continue
                        cache.record_conversion(
                            rid,
                            inputs
                            if variant is ShipModelVariant.FULL
                            else inputs.without_textures(),
                            data.paths.get_ship_model_path(alias, variant),
                        )
                    else:
                        cache.record_hit(rid)
        cache.save()

    total_ships = sum(len(aliases) for aliases in dna_aliases.values())
    info(f"Generated {total_ships} ship models x2 variants ({len(dna_jobs)} unique DNAs).")
    return external_entries
