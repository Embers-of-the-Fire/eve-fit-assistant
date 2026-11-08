"""Tests for the skyboxes generator step (bootstrap.data.workspace.generate.skyboxes)."""

from __future__ import annotations

import pytest

from bootstrap.data.schema import skybox_pb2
from bootstrap.data.workspace.generate import skyboxes as skybox_step
from bootstrap.data.workspace.generate.skyboxes import SkyboxSource
from bootstrap.data.workspace.generate.skyboxes import build_sidecar
from bootstrap.data.workspace.generate.skyboxes import gather_skybox_inputs
from bootstrap.data.workspace.generate.skyboxes import scan_skybox_sources


class _FakeNode:
    def __init__(self, file_hash: str | None = None):
        self.file_hash = file_hash


class _FakeResIndex:
    def __init__(self, listing: dict[str, list[str]], nodes: dict[str, _FakeNode | None]):
        self._listing = listing
        self._nodes = nodes

    def list_resources(self, prefix: str) -> list[str]:
        return self._listing.get(prefix, [])

    def get_resource(self, resource_id: str):
        if resource_id in self._nodes:
            return self._nodes[resource_id]
        # The listing and the lookup consult the same tree in the real index:
        # a listed path resolves to a node.
        if any(resource_id in paths for paths in self._listing.values()):
            return _FakeNode(None)
        return None


class _FakeResources:
    def __init__(self, res: _FakeResIndex):
        self.res = res


class _FakeData:
    def __init__(self, res: _FakeResIndex):
        self.resources = _FakeResources(res)


def _listing() -> dict[str, list[str]]:
    return {
        "res:/dx9/scene/universe": [
            "res:/dx9/scene/universe/a01_cube.dds",
            # The blur/refl/lowdetail variants must not scan as skyboxes.
            "res:/dx9/scene/universe/a01_cube_lowdetail.dds",
            "res:/dx9/scene/universe/a01_cube_blur.dds",
            "res:/dx9/scene/universe/a01_cube_refl.dds",
            "res:/dx9/scene/universe/a01_cube.black",
            "res:/dx9/scene/universe/c02_cube.dds",
            "res:/dx9/scene/universe/not_a_skybox.dds",
        ],
        "res:/dx9/scene/wormholes": [
            "res:/dx9/scene/wormholes/wormhole_class_01_cube.dds",
            "res:/dx9/scene/wormholes/wormhole_class_01.black",
            # The legacy suffix-less full-detail cube scans too; its variants do not.
            "res:/dx9/scene/wormholes/wormhole_class_00.dds",
            "res:/dx9/scene/wormholes/wormhole_class_00.black",
            "res:/dx9/scene/wormholes/wormhole_class_00_blur.dds",
            "res:/dx9/scene/wormholes/wormhole_class_00_refl.dds",
            "res:/dx9/scene/wormholes/wormhole_class_00_lowdetail.dds",
        ],
        "res:/dx9/scene/abyssal": [
            "res:/dx9/scene/abyssal/ad01_a_cube.dds",
        ],
        "res:/dx9/scene/fitting": [
            "res:/dx9/scene/fitting/fitting_cube.dds",
            "res:/dx9/scene/fitting/fitting_cube.black",
            "res:/dx9/scene/fitting/previewturrets_cube.dds",
            "res:/dx9/scene/fitting/previewturrets.black",
        ],
    }


class TestScanSkyboxSources:
    def test_ids_derive_from_cube_filenames(self):
        data = _FakeData(_FakeResIndex(_listing(), {}))
        sources = scan_skybox_sources(data)
        assert set(sources) == {
            "a01",
            "c02",
            "wormhole_class_01",
            "wormhole_class_00",
            "ad01_a",
            "fitting",
            "previewturrets",
        }
        assert sources["a01"].family == "universe"
        assert sources["wormhole_class_01"].family == "wormholes"
        assert sources["wormhole_class_00"].family == "wormholes"
        assert sources["ad01_a"].family == "abyssal"
        assert sources["fitting"].family == "fitting"
        assert sources["fitting"].black_res == "res:/dx9/scene/fitting/fitting_cube.black"
        assert sources["previewturrets"].black_res == "res:/dx9/scene/fitting/previewturrets.black"
        assert (
            sources["wormhole_class_00"].black_res
            == "res:/dx9/scene/wormholes/wormhole_class_00.black"
        )
        # The .black descriptor is picked up only when present in the index.
        assert sources["a01"].black_res == "res:/dx9/scene/universe/a01_cube.black"
        assert sources["ad01_a"].black_res is None

    def test_empty_index_yields_no_sources(self):
        data = _FakeData(_FakeResIndex({}, {}))
        assert scan_skybox_sources(data) == {}


class TestGatherSkyboxInputs:
    def test_hashes_come_from_the_resindex_md5_columns(self):
        nodes = {
            "res:/dx9/scene/universe/a01_cube.dds": _FakeNode("cube-md5"),
            "res:/dx9/scene/universe/a01_cube.black": _FakeNode("black-md5"),
        }
        data = _FakeData(_FakeResIndex(_listing(), nodes))
        sources = {"a01": scan_skybox_sources(data)["a01"]}
        inputs = gather_skybox_inputs(data, sources)
        assert inputs["a01"] is not None
        assert inputs["a01"].cube == "cube-md5"
        assert inputs["a01"].black == "black-md5"

    def test_missing_black_descriptor_records_empty(self):
        nodes = {"res:/dx9/scene/abyssal/ad01_a_cube.dds": _FakeNode("cube-md5")}
        data = _FakeData(_FakeResIndex(_listing(), nodes))
        sources = {"ad01_a": scan_skybox_sources(data)["ad01_a"]}
        inputs = gather_skybox_inputs(data, sources)
        assert inputs["ad01_a"] is not None
        assert inputs["ad01_a"].black == ""

    def test_unhashable_cube_fails_open(self):
        nodes = {"res:/dx9/scene/universe/a01_cube.dds": _FakeNode(None)}
        data = _FakeData(_FakeResIndex(_listing(), nodes))
        sources = {"a01": scan_skybox_sources(data)["a01"]}
        assert gather_skybox_inputs(data, sources)["a01"] is None

    def test_unhashable_black_descriptor_fails_open(self):
        nodes = {
            "res:/dx9/scene/universe/a01_cube.dds": _FakeNode("cube-md5"),
            "res:/dx9/scene/universe/a01_cube.black": _FakeNode(None),
        }
        data = _FakeData(_FakeResIndex(_listing(), nodes))
        sources = {"a01": scan_skybox_sources(data)["a01"]}
        assert gather_skybox_inputs(data, sources)["a01"] is None


def _source() -> SkyboxSource:
    return SkyboxSource(
        id="a01",
        family="universe",
        cube_res="res:/dx9/scene/universe/a01_cube.dds",
        black_res="res:/dx9/scene/universe/a01_cube.black",
    )


class TestBuildSidecar:
    def test_full_metadata(self):
        meta = {
            "nebulaIntensity": 1.25,
            "reflectionIntensity": 1.4,
            "ambientColor": [0.09, 0.07, 0.04],
            "tint": [1.0, 0.5, 0.25],
            "diffuseSh": [float(i) for i in range(27)],
        }
        pb = skybox_pb2.SkyboxMetadata.FromString(build_sidecar(_source(), meta))
        assert pb.schema_version == 1
        assert pb.id == "a01"
        assert pb.family == "universe"
        assert pb.source_resource == "res:/dx9/scene/universe/a01_cube.dds"
        assert pb.nebula_intensity == pytest.approx(1.25)
        assert pb.reflection_intensity == pytest.approx(1.4)
        assert pb.ambient_color.r == pytest.approx(0.09)
        assert pb.ambient_color.g == pytest.approx(0.07)
        assert pb.ambient_color.b == pytest.approx(0.04)
        assert pb.tint.r == pytest.approx(1.0)
        assert pb.tint.g == pytest.approx(0.5)
        assert pb.tint.b == pytest.approx(0.25)
        assert list(pb.diffuse_sh) == [float(i) for i in range(27)]

    def test_absent_values_stay_unset(self):
        pb = skybox_pb2.SkyboxMetadata.FromString(
            build_sidecar(_source(), {"diffuseSh": [0.0] * 27})
        )
        assert not pb.HasField("nebula_intensity")
        assert not pb.HasField("reflection_intensity")
        assert not pb.HasField("ambient_color")
        assert not pb.HasField("tint")
        assert len(pb.diffuse_sh) == 27

    def test_malformed_sh_is_dropped(self):
        pb = skybox_pb2.SkyboxMetadata.FromString(build_sidecar(_source(), {"diffuseSh": [0.0]}))
        assert len(pb.diffuse_sh) == 0
        pb = skybox_pb2.SkyboxMetadata.FromString(build_sidecar(_source(), {}))
        assert len(pb.diffuse_sh) == 0


class _FakePaths:
    def __init__(self, root):
        self.root = root

    def get_skybox_hdr_path(self, skybox_id: str):
        return self.root / f"{skybox_id}.hdr"

    def get_skybox_sidecar_path(self, skybox_id: str):
        return self.root / f"{skybox_id}.pb2"


class _FakeCache:
    def __init__(self, hit_ids: set[str]):
        self.hit_ids = hit_ids
        self.recorded_hits: list[str] = []
        self.saved = False

    def load(self):
        pass

    def partition(self, desired):
        hits = {
            resource_id: object()
            for resource_id in desired
            if resource_id.removeprefix("resource://static/skyboxes/").removesuffix(".hdr")
            in self.hit_ids
        }
        return hits, set(desired) - set(hits)

    def hit_reference(self, resource_id: str):
        skybox_id = resource_id.removeprefix("resource://static/skyboxes/").removesuffix(".hdr")
        sidecar_id = f"resource://static/skyboxes/{skybox_id}.pb2"
        return [(resource_id, "hdr-hash", 10), (sidecar_id, "pb2-hash", 20)]

    def record_hit(self, resource_id: str):
        self.recorded_hits.append(resource_id)

    def record_conversion(self, *_args):
        pass

    def save(self):
        self.saved = True


class _FakeGenerateData:
    def __init__(self, paths):
        self.paths = paths


async def test_all_environment_cache_hits_still_regenerate_lighting_catalog(
    tmp_path, monkeypatch: pytest.MonkeyPatch
):
    sources = {"a05": _source()}
    monkeypatch.setattr(skybox_step, "scan_skybox_sources", lambda _data: sources)
    monkeypatch.setattr(
        skybox_step, "gather_skybox_inputs", lambda _data, _sources: {"a05": object()}
    )

    async def unexpected_bake(*_args):
        raise AssertionError("cache-hit environments must not be baked")

    catalog_environments = []

    async def fake_catalog(_data, actual_sources, environment_ids):
        assert actual_sources == sources
        catalog_environments.append(environment_ids)

    monkeypatch.setattr(skybox_step, "_bake", unexpected_bake)
    monkeypatch.setattr(skybox_step, "generate_lighting_catalog", fake_catalog)
    cache = _FakeCache({"a05"})
    external = await skybox_step.generate(_FakeGenerateData(_FakePaths(tmp_path)), cache=cache)
    assert catalog_environments == [{"a05"}]
    assert external == [
        ("resource://static/skyboxes/a05.hdr", "hdr-hash", 10),
        ("resource://static/skyboxes/a05.pb2", "pb2-hash", 20),
    ]
    assert cache.recorded_hits == ["resource://static/skyboxes/a05.hdr"]
    assert cache.saved


async def test_lighting_references_validate_against_hits_and_produced_only(
    tmp_path, monkeypatch: pytest.MonkeyPatch
):
    sources = {
        "a05": _source(),
        "m10": SkyboxSource(
            id="m10",
            family="universe",
            cube_res="res:/dx9/scene/universe/m10_cube.dds",
            black_res=None,
        ),
    }
    monkeypatch.setattr(skybox_step, "scan_skybox_sources", lambda _data: sources)
    monkeypatch.setattr(
        skybox_step,
        "gather_skybox_inputs",
        lambda _data, _sources: {"a05": object(), "m10": object()},
    )

    async def bake_only_miss(*_args):
        return {"m10"}

    catalog_environments = []

    async def fake_catalog(_data, _sources, environment_ids):
        catalog_environments.append(environment_ids)

    monkeypatch.setattr(skybox_step, "_bake", bake_only_miss)
    monkeypatch.setattr(skybox_step, "generate_lighting_catalog", fake_catalog)
    cache = _FakeCache({"a05"})
    await skybox_step.generate(_FakeGenerateData(_FakePaths(tmp_path)), cache=cache)
    assert catalog_environments == [{"a05", "m10"}]


if __name__ == "__main__":
    raise SystemExit(pytest.main([__file__]))
