"""Baked ship model (GLB) generator.

Converts every ship type's SOF appearance into a self-contained GLB via the
``tools/carbon-gr2-to-glb`` converter (Node.js). All asset acquisition goes
through the workspace ``ResourceManager`` (resfileindex-backed, per-server CDN
URLs from the descriptor); the converter itself never touches the network.

The conversion is a two-phase batch protocol (see ``src/batch.js`` in the
converter):

1. ``--batch-resolve`` maps each ship DNA to its authoritative ``res:/``
   geometry/texture paths against ``data.black`` (loaded once per run).
2. The reported files are downloaded/staged through the ``ResourceManager``
   cache, then ``--batch`` converts everything offline.

Skins (material sets) are intentionally not baked yet; the manifest schema
carries per-job DNA strings, so skin jobs can be added without converter
changes.
"""

from __future__ import annotations

import asyncio
import json
import shutil

from typing import TYPE_CHECKING

from bootstrap.constant import GR2_TO_GLB_ROOT
from bootstrap.log import error
from bootstrap.log import info
from bootstrap.log import warning
from bootstrap.utils import execute_command
from bootstrap.utils import get_command


if TYPE_CHECKING:
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
    async with semaphore:
        await node.download()
    return node.local_path


async def generate(data: GeneratorDatasource):
    info("Generating ship models...")

    types = await data.resources.fsd.get("types")
    groups = await data.resources.fsd.get("groups")
    graphicids = await data.resources.fsd.get("graphicids")
    jobs = build_ship_jobs(types, groups, graphicids)
    if not jobs:
        warning("No ship types with SOF-backed graphics found; skipping model generation.")
        return
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

    semaphore = asyncio.Semaphore(_DOWNLOAD_CONCURRENCY)
    stage_tasks: dict[str, asyncio.Task] = {}

    def stage(res_path: str) -> asyncio.Task:
        if res_path not in stage_tasks:
            stage_tasks[res_path] = asyncio.create_task(__stage_resource(data, res_path, semaphore))
        return stage_tasks[res_path]

    info("Staging model assets via the resource manager...")
    for job in resolved["jobs"]:
        if job.get("error"):
            continue
        if job.get("geometryResPath"):
            stage(job["geometryResPath"])
        for texture_path in job.get("textureResPaths", []):
            stage(texture_path)
    staged = {res_path: await task for res_path, task in stage_tasks.items()}
    missing = [res_path for res_path, local in staged.items() if local is None]
    if missing:
        for res_path in missing:
            warning(f"Asset {res_path} could not be staged; dependent jobs will fail.")
    info(f"Staged {len(staged) - len(missing)}/{len(staged)} assets.")

    convert_jobs = []
    dna_aliases: dict[str, list[int]] = {}
    for job in resolved["jobs"]:
        if job.get("error"):
            continue
        geometry = job.get("geometryResPath")
        if not geometry or staged.get(geometry) is None:
            warning(f"Skipping job {job['id']}: geometry could not be staged.")
            continue
        textures = {
            res_path: str(staged[res_path])
            for res_path in job.get("textureResPaths", [])
            if staged.get(res_path) is not None
        }
        type_id = int(job["id"])
        # Types sharing one DNA produce byte-identical GLBs; convert once.
        if job["dna"] in dna_aliases:
            dna_aliases[job["dna"]].append(type_id)
            continue
        dna_aliases[job["dna"]] = [type_id]
        convert_jobs.append(
            {
                "id": job["id"],
                "dna": job["dna"],
                "gr2": str(staged[geometry]),
                "textures": textures,
                "out": str(data.paths.get_ship_model_path(type_id)),
            }
        )

    convert_manifest = work_dir / "manifest_convert.json"
    convert_manifest.write_text(
        json.dumps(
            {
                "dataBlack": str(data_black.local_path),
                "texture": {"format": "webp", "quality": 90},
                "geometry": "meshopt",
                "jobs": convert_jobs,
            }
        ),
        encoding="utf-8",
    )
    info(f"Converting {len(convert_jobs)} ship models (phase 2: batch)...")
    _run_converter(["--batch", str(convert_manifest)], "MODEL CONVERT")

    failures = [
        job["id"]
        for job in convert_jobs
        if not data.paths.get_ship_model_path(int(job["id"])).is_file()
    ]
    if failures:
        error(f"Model conversion failed for {len(failures)} type(s): {', '.join(failures)}")
        raise RuntimeError(f"ship model conversion failed for {len(failures)} type(s)")

    for job in convert_jobs:
        aliases = dna_aliases[job["dna"]]
        source = data.paths.get_ship_model_path(aliases[0])
        for alias_id in aliases[1:]:
            shutil.copy2(source, data.paths.get_ship_model_path(alias_id))

    info(f"Generated {len(jobs)} ship models ({len(convert_jobs)} unique DNAs).")
