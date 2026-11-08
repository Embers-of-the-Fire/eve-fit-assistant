"""Lighting-profile extraction and catalog generation.

Binary Black descriptors are decoded only by the Carbon runtime through the
converter's metadata-only ``--batch-scene-metadata`` verb. This module resolves
Carbon defaults and item-preview runtime overrides, maps each descriptor's
``NebulaMap`` through the dynamically scanned skybox sources, validates every
emitted value, and writes the versioned protobuf catalog.

The catalog is deliberately independent of environment-pair caching: callers
must regenerate it on every run and pass exactly the environment ids available
in the final snapshot (cache hits plus newly produced pairs).
"""

from __future__ import annotations

import asyncio
import json
import math
import shutil
import struct

from typing import TYPE_CHECKING

from bootstrap.data.schema import skybox_pb2
from bootstrap.log import info
from bootstrap.log import warning

from .models import _ensure_converter_installed
from .models import _run_converter


if TYPE_CHECKING:
    from pathlib import Path

    from bootstrap.data.workspace.generate import GeneratorDatasource
    from bootstrap.data.workspace.generate.skyboxes import SkyboxSource


LIGHTING_CATALOG_SCHEMA_VERSION = 1
PREVIEW_SCENE_ROOT = "res:/dx9/scene/preview"
FITTING_SCENE_RESOURCE = "res:/dx9/scene/fitting/fitting.black"

_DEFAULT_AMBIENT = (0.25, 0.25, 0.25)
_ITEM_PREVIEW_SUN_COLOR = (3.0, 3.0, 3.0)
_FITTING_SUN_COLOR = (2.0, 2.0, 2.0)
_DOWNLOAD_CONCURRENCY = 32


class LightingProfileError(ValueError):
    """A deterministic, build-fatal lighting descriptor or catalog error."""


def discover_lighting_descriptors(data: GeneratorDatasource) -> list[str]:
    """Find direct children of ``preview/`` plus the explicit fitting scene."""
    preview = [
        path
        for path in data.resources.res.list_resources(PREVIEW_SCENE_ROOT)
        if path.rsplit("/", 1)[0] == PREVIEW_SCENE_ROOT and path.endswith(".black")
    ]
    if data.resources.res.get_resource(FITTING_SCENE_RESOURCE) is None:
        raise LightingProfileError(f"Missing fitting lighting descriptor: {FITTING_SCENE_RESOURCE}")
    return sorted([*preview, FITTING_SCENE_RESOURCE])


def _finite_float32(value: object, profile_id: str, field: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise LightingProfileError(f"Lighting profile {profile_id!r}: {field} must be a number.")
    try:
        resolved = float(value)
    except OverflowError:
        raise LightingProfileError(
            f"Lighting profile {profile_id!r}: {field} must be finite."
        ) from None
    if not math.isfinite(resolved):
        raise LightingProfileError(f"Lighting profile {profile_id!r}: {field} must be finite.")
    try:
        resolved = struct.unpack("!f", struct.pack("!f", resolved))[0]
    except OverflowError, struct.error:
        raise LightingProfileError(
            f"Lighting profile {profile_id!r}: {field} must fit a finite float32."
        ) from None
    if not math.isfinite(resolved):
        raise LightingProfileError(
            f"Lighting profile {profile_id!r}: {field} must fit a finite float32."
        )
    return resolved


def _scalar(meta: dict, key: str, profile_id: str, default: float) -> float:
    if key not in meta:
        return default
    return _finite_float32(meta[key], profile_id, key)


def _color(value: object, profile_id: str, field: str) -> tuple[float, float, float]:
    if not isinstance(value, list) or len(value) not in (3, 4):
        raise LightingProfileError(
            f"Lighting profile {profile_id!r}: {field} must be an RGB/RGBA array."
        )
    channels: list[float] = []
    for index, channel in enumerate(value[:3]):
        component = f"{field}[{index}]"
        resolved = _finite_float32(channel, profile_id, component)
        if resolved < 0:
            raise LightingProfileError(
                f"Lighting profile {profile_id!r}: {component} must be non-negative."
            )
        channels.append(resolved)
    return channels[0], channels[1], channels[2]


def _resolved_ambient(meta: dict, profile_id: str) -> tuple[float, float, float]:
    if "ambientColor" not in meta:
        return _DEFAULT_AMBIENT
    return _color(meta["ambientColor"], profile_id, "ambientColor")


def _fixed_sun_direction(meta: dict, profile_id: str) -> tuple[float, float, float]:
    if "sunDirection" not in meta:
        raise LightingProfileError(
            f"Lighting profile {profile_id!r}: fixed sunDirection is required."
        )
    value = meta["sunDirection"]
    if not isinstance(value, list) or len(value) != 3:
        raise LightingProfileError(
            f"Lighting profile {profile_id!r}: sunDirection must be a three-component array."
        )
    eve: list[float] = []
    for index, component in enumerate(value):
        eve.append(_finite_float32(component, profile_id, f"sunDirection[{index}]"))
    # Apply the EVE-to-app handedness conversion (x, y, -z).
    app = (eve[0], eve[1], -eve[2])
    length = math.sqrt(math.fsum(component * component for component in app))
    if not math.isfinite(length) or length == 0:
        raise LightingProfileError(
            f"Lighting profile {profile_id!r}: fixed sunDirection must be finite and non-zero."
        )
    normalized = tuple(component / length for component in app)
    if not all(math.isfinite(component) for component in normalized):
        raise LightingProfileError(
            f"Lighting profile {profile_id!r}: fixed sunDirection could not be normalized."
        )
    return normalized


def _environment_id(
    meta: dict,
    profile_id: str,
    cube_to_skybox: dict[str, str],
    environment_ids: set[str],
) -> str:
    nebula_map = meta.get("nebulaMap")
    if not isinstance(nebula_map, str) or not nebula_map:
        raise LightingProfileError(
            f"Lighting profile {profile_id!r}: backgroundEffect NebulaMap resourcePath is required."
        )
    skybox_id = cube_to_skybox.get(nebula_map)
    if skybox_id is None:
        raise LightingProfileError(
            f"Lighting profile {profile_id!r}: NebulaMap {nebula_map!r} has no scanned skybox id."
        )
    if skybox_id not in environment_ids:
        raise LightingProfileError(
            f"Lighting profile {profile_id!r}: environment {skybox_id!r} is absent from "
            "the final skybox set (cache hits plus produced pairs)."
        )
    return skybox_id


def _reflection_resource(meta: dict, profile_id: str) -> str:
    value = meta.get("envMapResPath")
    if not isinstance(value, str) or not value:
        raise LightingProfileError(
            f"Lighting profile {profile_id!r}: envMapResPath must be a non-empty string."
        )
    return value


def _set_color(target: skybox_pb2.RgbColor, color: tuple[float, float, float]) -> None:
    target.r, target.g, target.b = color


def build_lighting_profile_catalog(
    descriptors: dict[str, dict],
    sources: dict[str, SkyboxSource],
    environment_ids: set[str],
) -> bytes:
    """Resolve, validate, and deterministically serialize the profile catalog.

    ``descriptors`` maps official Black resource paths to the converter's raw
    metadata. ``sources`` is the result of ``scan_skybox_sources``; no static
    filename-to-id mapping is duplicated here.
    """
    cube_to_skybox: dict[str, str] = {}
    for skybox_id in sorted(sources):
        cube_res = sources[skybox_id].cube_res
        previous = cube_to_skybox.setdefault(cube_res, skybox_id)
        if previous != skybox_id:
            raise LightingProfileError(
                f"Skybox cube {cube_res!r} maps to duplicate ids {previous!r} and {skybox_id!r}."
            )

    resolved_profiles: list[skybox_pb2.SceneLightingProfile] = []
    seen_ids: set[str] = set()
    for descriptor_path in sorted(descriptors):
        meta = descriptors[descriptor_path]
        if not isinstance(meta, dict):
            raise LightingProfileError(
                f"Lighting descriptor {descriptor_path!r}: metadata must be an object."
            )
        profile_id = descriptor_path.rsplit("/", 1)[-1].removesuffix(".black")
        if not profile_id:
            raise LightingProfileError(
                f"Lighting descriptor {descriptor_path!r} has an empty profile id."
            )
        if profile_id in seen_ids:
            raise LightingProfileError(f"Duplicate lighting profile id {profile_id!r}.")
        seen_ids.add(profile_id)

        is_fitting = descriptor_path == FITTING_SCENE_RESOURCE
        if not is_fitting and not descriptor_path.startswith(f"{PREVIEW_SCENE_ROOT}/"):
            raise LightingProfileError(f"Unsupported lighting descriptor path {descriptor_path!r}.")
        skybox_id = _environment_id(meta, profile_id, cube_to_skybox, environment_ids)
        if is_fitting and skybox_id != "fitting":
            raise LightingProfileError(
                f"Fitting lighting descriptor must resolve environment 'fitting', got {skybox_id!r}."
            )

        reflection = _scalar(meta, "reflectionIntensity", profile_id, 1.0)
        if reflection <= 0:
            raise LightingProfileError(
                f"Lighting profile {profile_id!r}: reflectionIntensity must be positive."
            )
        nebula = _scalar(meta, "nebulaIntensity", profile_id, 1.0)
        if nebula < 0:
            raise LightingProfileError(
                f"Lighting profile {profile_id!r}: nebulaIntensity must be non-negative."
            )
        ambient = _resolved_ambient(meta, profile_id)

        profile = skybox_pb2.SceneLightingProfile()
        profile.id = profile_id
        profile.kind = (
            skybox_pb2.LightingProfileKind.FITTING
            if is_fitting
            else skybox_pb2.LightingProfileKind.ITEM_PREVIEW
        )
        profile.skybox_id = skybox_id
        profile.reflection_resource = _reflection_resource(meta, profile_id)
        profile.reflection_intensity = reflection
        _set_color(profile.ambient_color, ambient)

        if is_fitting:
            profile.nebula_intensity = nebula
            _set_color(profile.sun_color, _FITTING_SUN_COLOR)
            profile.sun_direction_mode = skybox_pb2.SunDirectionMode.FIXED
            direction = _fixed_sun_direction(meta, profile_id)
            profile.fixed_sun_direction.x = direction[0]
            profile.fixed_sun_direction.y = direction[1]
            profile.fixed_sun_direction.z = direction[2]
        else:
            # EVE's item-preview runtime applies these on every update, even
            # when the authored descriptor contains different sun parameters.
            profile.nebula_intensity = 1.0
            _set_color(profile.sun_color, _ITEM_PREVIEW_SUN_COLOR)
            profile.sun_direction_mode = skybox_pb2.SunDirectionMode.CAMERA_FORWARD
        resolved_profiles.append(profile)

    catalog = skybox_pb2.LightingProfileCatalog()
    catalog.schema_version = LIGHTING_CATALOG_SCHEMA_VERSION
    for profile in sorted(resolved_profiles, key=lambda value: value.id):
        catalog.profiles.add().CopyFrom(profile)
    return catalog.SerializeToString()


async def _stage_descriptor(
    data: GeneratorDatasource, res_path: str, semaphore: asyncio.Semaphore
) -> Path | None:
    node = data.resources.res.get_resource(res_path)
    if node is None:
        warning(f"Lighting descriptor {res_path} not found in the resource index.")
        return None
    try:
        async with semaphore:
            await node.download()
    except Exception as exc:  # noqa: BLE001 - reported as a sorted build-fatal list below
        warning(f"Lighting descriptor {res_path} could not be downloaded: {exc}")
        return None
    return node.local_path


def _metadata_from_report(report_path: Path, descriptor_paths: list[str]) -> dict[str, dict]:
    try:
        report = json.loads(report_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise LightingProfileError(
            f"Could not read scene metadata report {report_path}: {exc}"
        ) from exc
    if not isinstance(report, dict) or not isinstance(report.get("jobs"), list):
        raise LightingProfileError("Scene metadata report must contain a jobs array.")

    expected = set(descriptor_paths)
    metadata: dict[str, dict] = {}
    seen: set[str] = set()
    failures: list[str] = []
    for row in report["jobs"]:
        if not isinstance(row, dict) or not isinstance(row.get("id"), str):
            raise LightingProfileError("Scene metadata report contains a job without a string id.")
        descriptor_path = row["id"]
        if descriptor_path not in expected:
            raise LightingProfileError(
                f"Scene metadata report contains unexpected descriptor {descriptor_path!r}."
            )
        if descriptor_path in seen:
            raise LightingProfileError(
                f"Scene metadata report contains duplicate descriptor {descriptor_path!r}."
            )
        seen.add(descriptor_path)
        if row.get("ok") is not True:
            failures.append(f"{descriptor_path} ({row.get('error', 'unknown converter error')})")
            continue
        metadata[descriptor_path] = {
            key: value for key, value in row.items() if key not in {"id", "ok"}
        }
    missing = sorted(expected - seen)
    failures.extend(f"{path} (no converter output)" for path in missing)
    if failures:
        raise LightingProfileError(
            "Scene metadata extraction failed: " + "; ".join(sorted(failures))
        )
    return metadata


async def generate_lighting_catalog(
    data: GeneratorDatasource,
    sources: dict[str, SkyboxSource],
    environment_ids: set[str],
) -> None:
    """Extract every descriptor and regenerate the catalog on every data run."""
    descriptor_paths = discover_lighting_descriptors(data)
    _ensure_converter_installed()

    work_dir = data.config.paths.cache / "lighting-profiles"
    shutil.rmtree(work_dir, ignore_errors=True)
    work_dir.mkdir(parents=True, exist_ok=True)

    semaphore = asyncio.Semaphore(_DOWNLOAD_CONCURRENCY)
    tasks = {
        path: asyncio.create_task(_stage_descriptor(data, path, semaphore))
        for path in descriptor_paths
    }
    staged = {path: await task for path, task in tasks.items()}
    failed = sorted(path for path, local_path in staged.items() if local_path is None)
    if failed:
        raise LightingProfileError("Could not stage lighting descriptors: " + ", ".join(failed))

    manifest_path = work_dir / "manifest.json"
    metadata_path = work_dir / "metadata.json"
    manifest_path.write_text(
        json.dumps(
            {"jobs": [{"id": path, "black": str(staged[path])} for path in descriptor_paths]},
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    await asyncio.to_thread(
        _run_converter,
        ["--batch-scene-metadata", str(manifest_path), "--meta-out", str(metadata_path)],
        "LIGHTING PROFILE EXTRACTION",
    )
    metadata = _metadata_from_report(metadata_path, descriptor_paths)
    catalog_bytes = build_lighting_profile_catalog(metadata, sources, environment_ids)
    data.paths.lighting_profile_catalog_path.write_bytes(catalog_bytes)
    info(f"Generated {len(metadata)} scene-lighting profiles.")
