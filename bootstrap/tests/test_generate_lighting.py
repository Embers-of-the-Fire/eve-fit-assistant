"""Data-generation tests for resolved scene-lighting profile catalogs."""

from __future__ import annotations

import math

import pytest

from bootstrap.data.schema import skybox_pb2
from bootstrap.data.workspace.generate.lighting import FITTING_SCENE_RESOURCE
from bootstrap.data.workspace.generate.lighting import LightingProfileError
from bootstrap.data.workspace.generate.lighting import _metadata_from_report
from bootstrap.data.workspace.generate.lighting import build_lighting_profile_catalog
from bootstrap.data.workspace.generate.skyboxes import SkyboxSource


AMARR = "res:/dx9/scene/preview/amarr.black"
CALDARI = "res:/dx9/scene/preview/caldari.black"
GENERIC = "res:/dx9/scene/preview/generic.black"
TALOCAN = "res:/dx9/scene/preview/talocan.black"


def _source(skybox_id: str, cube_res: str) -> SkyboxSource:
    return SkyboxSource(
        id=skybox_id,
        family="universe",
        cube_res=cube_res,
        black_res=None,
    )


def _sources() -> dict[str, SkyboxSource]:
    return {
        "a05": _source("a05", "res:/dx9/scene/universe/a05_cube.dds"),
        "m10": _source("m10", "res:/dx9/scene/universe/m10_cube.dds"),
        "wormhole_class_00": _source(
            "wormhole_class_00", "res:/dx9/scene/wormholes/wormhole_class_00.dds"
        ),
        "fitting": _source("fitting", "res:/dx9/scene/fitting/fitting_cube.dds"),
    }


def _preview(cube_res: str, **overrides) -> dict:
    metadata = {
        "nebulaMap": cube_res,
        "envMapResPath": cube_res.removesuffix(".dds") + "_refl.dds",
        "sunDirection": [-1.0, -1.0, 1.0],
        "sunDiffuseColor": [1.5, 1.5, 1.5, 1.0],
    }
    metadata.update(overrides)
    return metadata


def _fitting(**overrides) -> dict:
    metadata = _preview(
        "res:/dx9/scene/fitting/fitting_cube.dds",
        ambientColor=[0.30408299, 0.45882350, 0.45336211, 1.0],
        sunDirection=[-0.53916383, -0.53916383, -0.64699662],
        sunDiffuseColor=[2.0, 2.0, 2.0, 1.0],
    )
    metadata.update(overrides)
    return metadata


def _catalog(descriptors: dict[str, dict], environment_ids: set[str] | None = None):
    if FITTING_SCENE_RESOURCE not in descriptors:
        descriptors[FITTING_SCENE_RESOURCE] = _fitting()
    environments = set(_sources()) if environment_ids is None else environment_ids
    payload = build_lighting_profile_catalog(descriptors, _sources(), environments)
    return skybox_pb2.LightingProfileCatalog.FromString(payload)


def _profiles(catalog) -> dict[str, skybox_pb2.SceneLightingProfile]:
    return {profile.id: profile for profile in catalog.profiles}


class TestItemPreviewProfiles:
    def test_amarr_uses_runtime_overrides_and_carbon_ambient_default(self):
        catalog = _catalog(
            {
                AMARR: _preview(
                    "res:/dx9/scene/universe/a05_cube.dds",
                    # Authored scene values and the universe sidecar's values
                    # must not leak into the item-preview runtime profile.
                    nebulaIntensity=1.25,
                    sunDirection=[9.0, 8.0, 7.0],
                    sunDiffuseColor=[1.5, 1.5, 1.5, 1.0],
                )
            }
        )
        amarr = _profiles(catalog)["amarr"]
        assert amarr.kind == skybox_pb2.LightingProfileKind.ITEM_PREVIEW
        assert amarr.skybox_id == "a05"
        assert amarr.nebula_intensity == 1
        assert amarr.reflection_intensity == 1
        assert (amarr.ambient_color.r, amarr.ambient_color.g, amarr.ambient_color.b) == (
            0.25,
            0.25,
            0.25,
        )
        assert (amarr.sun_color.r, amarr.sun_color.g, amarr.sun_color.b) == (3, 3, 3)
        assert amarr.sun_direction_mode == skybox_pb2.SunDirectionMode.CAMERA_FORWARD
        assert not amarr.HasField("fixed_sun_direction")
        assert amarr.reflection_resource == "res:/dx9/scene/universe/a05_cube_refl.dds"

    def test_caldari_preserves_explicit_ambient(self):
        catalog = _catalog(
            {
                CALDARI: _preview(
                    "res:/dx9/scene/universe/m10_cube.dds",
                    ambientColor=[0.0509804, 0.0588235, 0.0705882, 1.0],
                    nebulaIntensity=8.0,
                )
            }
        )
        caldari = _profiles(catalog)["caldari"]
        assert caldari.skybox_id == "m10"
        assert caldari.nebula_intensity == 1
        assert caldari.reflection_intensity == 1
        assert caldari.ambient_color.r == pytest.approx(0.0509804)
        assert caldari.ambient_color.g == pytest.approx(0.0588235)
        assert caldari.ambient_color.b == pytest.approx(0.0705882)
        assert caldari.sun_color.r == 3
        assert caldari.sun_direction_mode == skybox_pb2.SunDirectionMode.CAMERA_FORWARD

    def test_every_item_preview_gets_key_and_nebula_overrides(self):
        catalog = _catalog(
            {
                AMARR: _preview("res:/dx9/scene/universe/a05_cube.dds", nebulaIntensity=2.0),
                CALDARI: _preview("res:/dx9/scene/universe/m10_cube.dds", nebulaIntensity=3.0),
                GENERIC: _preview("res:/dx9/scene/universe/m10_cube.dds", nebulaIntensity=4.0),
            }
        )
        for profile in catalog.profiles:
            if profile.kind != skybox_pb2.LightingProfileKind.ITEM_PREVIEW:
                continue
            assert profile.nebula_intensity == 1
            assert (profile.sun_color.r, profile.sun_color.g, profile.sun_color.b) == (3, 3, 3)
            assert profile.sun_direction_mode == skybox_pb2.SunDirectionMode.CAMERA_FORWARD
            assert not profile.HasField("fixed_sun_direction")


class TestFittingProfile:
    def test_authored_ambient_fixed_key_and_handedness(self):
        fitting = _profiles(_catalog({}))["fitting"]
        assert fitting.kind == skybox_pb2.LightingProfileKind.FITTING
        assert fitting.skybox_id == "fitting"
        assert fitting.nebula_intensity == 1
        assert fitting.reflection_intensity == 1
        assert fitting.ambient_color.r == pytest.approx(0.30408299)
        assert fitting.ambient_color.g == pytest.approx(0.45882350)
        assert fitting.ambient_color.b == pytest.approx(0.45336211)
        assert (fitting.sun_color.r, fitting.sun_color.g, fitting.sun_color.b) == (2, 2, 2)
        assert fitting.sun_direction_mode == skybox_pb2.SunDirectionMode.FIXED
        direction = fitting.fixed_sun_direction
        expected_length = math.sqrt(0.53916383**2 + 0.53916383**2 + 0.64699662**2)
        assert direction.x == pytest.approx(-0.53916383 / expected_length)
        assert direction.y == pytest.approx(-0.53916383 / expected_length)
        assert direction.z == pytest.approx(0.64699662 / expected_length)
        assert math.sqrt(direction.x**2 + direction.y**2 + direction.z**2) == pytest.approx(1)


class TestEnvironmentResolution:
    def test_shared_and_suffix_less_mappings_come_from_scanned_sources(self):
        catalog = _catalog(
            {
                GENERIC: _preview("res:/dx9/scene/universe/m10_cube.dds"),
                # A second profile deliberately shares generic's environment.
                AMARR: _preview("res:/dx9/scene/universe/m10_cube.dds"),
                TALOCAN: _preview("res:/dx9/scene/wormholes/wormhole_class_00.dds"),
            }
        )
        profiles = _profiles(catalog)
        assert profiles["generic"].skybox_id == "m10"
        assert profiles["amarr"].skybox_id == "m10"
        assert profiles["talocan"].skybox_id == "wormhole_class_00"
        assert {profile.skybox_id for profile in catalog.profiles} <= set(_sources())

    def test_unavailable_final_environment_is_a_build_error(self):
        with pytest.raises(LightingProfileError, match="final skybox set") as exc_info:
            _catalog({}, environment_ids=set(_sources()) - {"fitting"})
        assert "fitting" in str(exc_info.value)

    def test_unknown_nebula_mapping_is_a_build_error(self):
        with pytest.raises(LightingProfileError, match="has no scanned skybox id"):
            _catalog({AMARR: _preview("res:/dx9/scene/universe/not_baked_cube.dds")})


@pytest.mark.parametrize("reflection", [0, -0.1, math.nan, math.inf, 1e39, 1e-50])
def test_invalid_reflection_intensity_fails_deterministically(reflection: float):
    descriptors = {
        AMARR: _preview("res:/dx9/scene/universe/a05_cube.dds", reflectionIntensity=reflection)
    }
    messages = []
    for _ in range(2):
        with pytest.raises(LightingProfileError, match="reflectionIntensity") as exc_info:
            build_lighting_profile_catalog(descriptors, _sources(), set(_sources()))
        messages.append(str(exc_info.value))
    assert messages[0] == messages[1]


@pytest.mark.parametrize(
    "ambient",
    [None, [1, 2], [-0.1, 0, 0], [1, 2, math.nan], [1, 2, 3, 4, 5]],
)
def test_malformed_ambient_color_is_a_build_error(ambient):
    descriptors = {AMARR: _preview("res:/dx9/scene/universe/a05_cube.dds", ambientColor=ambient)}
    with pytest.raises(LightingProfileError, match="ambientColor"):
        build_lighting_profile_catalog(descriptors, _sources(), set(_sources()))


@pytest.mark.parametrize(
    "direction",
    [None, [1, 2], [1, 2, 3, 4], [0, 0, 0], [1, math.inf, 2], [1, "2", 3]],
)
def test_invalid_fixed_direction_is_a_build_error(direction):
    descriptors = {FITTING_SCENE_RESOURCE: _fitting(sunDirection=direction)}
    with pytest.raises(LightingProfileError, match="sunDirection"):
        build_lighting_profile_catalog(descriptors, _sources(), set(_sources()))


def test_duplicate_profile_ids_are_rejected():
    descriptors = {
        FITTING_SCENE_RESOURCE: _fitting(),
        "res:/dx9/scene/preview/fitting.black": _preview("res:/dx9/scene/fitting/fitting_cube.dds"),
    }
    with pytest.raises(LightingProfileError, match="Duplicate lighting profile id 'fitting'"):
        build_lighting_profile_catalog(descriptors, _sources(), set(_sources()))


def test_catalog_round_trip_preserves_ids_enums_values_and_provenance():
    descriptors = {
        CALDARI: _preview(
            "res:/dx9/scene/universe/m10_cube.dds",
            ambientColor=[0.0509804, 0.0588235, 0.0705882, 1.0],
        ),
        FITTING_SCENE_RESOURCE: _fitting(reflectionIntensity=1.125),
    }
    payload = build_lighting_profile_catalog(descriptors, _sources(), set(_sources()))
    parsed = skybox_pb2.LightingProfileCatalog.FromString(payload)
    assert parsed.schema_version == 1
    assert [profile.id for profile in parsed.profiles] == ["caldari", "fitting"]
    assert [profile.kind for profile in parsed.profiles] == [
        skybox_pb2.LightingProfileKind.ITEM_PREVIEW,
        skybox_pb2.LightingProfileKind.FITTING,
    ]
    assert parsed.profiles[0].reflection_resource.endswith("m10_cube_refl.dds")
    assert parsed.profiles[1].reflection_resource.endswith("fitting_cube_refl.dds")
    assert parsed.profiles[1].reflection_intensity == pytest.approx(1.125)
    assert parsed.profiles[1].fixed_sun_direction.z > 0
    assert parsed.SerializeToString() == payload


def test_metadata_report_rejects_missing_and_duplicate_jobs(tmp_path):
    report = tmp_path / "metadata.json"
    report.write_text('{"jobs": []}', encoding="utf-8")
    with pytest.raises(LightingProfileError, match="no converter output"):
        _metadata_from_report(report, [AMARR])

    report.write_text(
        '{"jobs": [{"id": "a", "ok": true}, {"id": "a", "ok": true}]}',
        encoding="utf-8",
    )
    with pytest.raises(LightingProfileError, match="duplicate descriptor 'a'"):
        _metadata_from_report(report, ["a"])
