"""Tests for the skyboxes build-state map (bootstrap.data.buildstate.skyboxes)."""

from __future__ import annotations

import hashlib
import json

import pytest

from bootstrap.data.buildstate import skyboxes as buildstate_skyboxes
from bootstrap.data.buildstate.skyboxes import MAP_SCHEMA_VERSION
from bootstrap.data.buildstate.skyboxes import SkyboxArtifactEntry
from bootstrap.data.buildstate.skyboxes import SkyboxesBuildStateMap
from bootstrap.data.buildstate.skyboxes import SkyboxesCacheContext
from bootstrap.data.buildstate.skyboxes import SkyboxInputs
from bootstrap.data.buildstate.skyboxes import inputs_match
from bootstrap.data.buildstate.skyboxes import load_map
from bootstrap.data.buildstate.skyboxes import map_remote_key
from bootstrap.data.buildstate.skyboxes import skybox_hdr_resource_id
from bootstrap.data.buildstate.skyboxes import skybox_sidecar_resource_id


HDR_RID = "resource://static/skyboxes/a01.hdr"
SIDECAR_RID = "resource://static/skyboxes/a01.pb2"


def _entry(cube: str = "c1", black: str = "b1", output: str = "o1", sidecar: str = "s1"):
    return SkyboxArtifactEntry(cube=cube, black=black, output=output, sidecar_output=sidecar)


def _inputs(cube: str = "c1", black: str = "b1") -> SkyboxInputs:
    return SkyboxInputs(cube=cube, black=black)


class TestResourceIds:
    def test_hdr_resource_id(self):
        assert skybox_hdr_resource_id("a01") == HDR_RID
        assert skybox_hdr_resource_id("wormhole_class_01") == (
            "resource://static/skyboxes/wormhole_class_01.hdr"
        )

    def test_sidecar_resource_id(self):
        assert skybox_sidecar_resource_id("a01") == SIDECAR_RID

    def test_map_remote_key(self):
        assert map_remote_key("tranquility") == "build-state/skyboxes/tranquility.json"


class TestInputsMatch:
    def test_identical_inputs_match(self):
        assert inputs_match(_entry(), _inputs())

    def test_cube_change_invalidates(self):
        assert not inputs_match(_entry(), _inputs(cube="c2"))

    def test_black_hash_change_invalidates(self):
        assert not inputs_match(_entry(), _inputs(black="b2"))

    def test_absent_black_descriptor_matches_empty(self):
        assert inputs_match(_entry(black=""), _inputs(black=""))
        assert not inputs_match(_entry(black=""), _inputs(black="b1"))


class TestMapSerialization:
    def test_roundtrip(self):
        state_map = SkyboxesBuildStateMap(server_id="tranquility", entries={HDR_RID: _entry()})
        parsed = SkyboxesBuildStateMap.from_json(state_map.to_json())
        assert parsed == state_map
        assert parsed.schema_version == MAP_SCHEMA_VERSION

    def test_json_shape(self):
        raw = json.loads(
            SkyboxesBuildStateMap(server_id="s", entries={HDR_RID: _entry()}).to_json()
        )
        assert raw["schema_version"] == MAP_SCHEMA_VERSION
        assert raw["server_id"] == "s"
        assert raw["entries"][HDR_RID] == {
            "cube": "c1",
            "black": "b1",
            "output": "o1",
            "sidecar_output": "s1",
        }


class _FakeClient:
    def __init__(self, payload: bytes | None = None):
        self.payload = payload

    def read_bytes(self, key: str) -> bytes:
        if self.payload is None:
            raise FileNotFoundError(key)
        return self.payload


class _StatProdClient:
    """Prod client stub: HEAD returns per-blob sizes, None for missing blobs.

    Blob keys are content-addressed, so sizes key on the recorded output
    content hash.
    """

    def __init__(self, sizes: dict[str, int | None] | None = None, default: int | None = 100):
        self.sizes = sizes or {}
        self.default = default

    def object_size(self, key: str) -> int | None:
        for content_hash, size in self.sizes.items():
            if key.endswith(content_hash):
                return size
        return self.default


class TestCacheContext:
    def _context(self, prod_client, entries=None) -> SkyboxesCacheContext:
        state_map = SkyboxesBuildStateMap(
            server_id="tranquility", entries=entries if entries is not None else {HDR_RID: _entry()}
        )
        cache = SkyboxesCacheContext(
            server_id="tranquility",
            resource_root="efa/v2",
            ci_client=_FakeClient(state_map.to_json()),  # type: ignore[arg-type]
            prod_client=prod_client,
        )
        cache.load()
        return cache

    def test_hit_reference_returns_both_blobs(self):
        cache = self._context(_StatProdClient({"o1": 111, "s1": 222}))
        hits, misses = cache.partition({HDR_RID: _inputs()})
        assert set(hits) == {HDR_RID}
        assert misses == set()
        assert cache.hit_reference(HDR_RID) == [
            (HDR_RID, "o1", 111),
            (SIDECAR_RID, "s1", 222),
        ]

    def test_missing_sidecar_blob_is_a_miss(self, monkeypatch: pytest.MonkeyPatch):
        """Rule 2: either recorded output missing invalidates the pair."""
        monkeypatch.setattr(buildstate_skyboxes, "warning", lambda *_args: None)
        cache = self._context(_StatProdClient({"s1": None}, default=111))
        hits, misses = cache.partition({HDR_RID: _inputs()})
        assert hits == {}
        assert misses == {HDR_RID}

    def test_inputs_differ_is_a_miss(self):
        cache = self._context(_StatProdClient())
        hits, misses = cache.partition({HDR_RID: _inputs(cube="c2")})
        assert hits == {}
        assert misses == {HDR_RID}

    def test_record_and_hit_roundtrip(self, tmp_path):
        cache = self._context(_StatProdClient(), entries={})
        cache.partition({HDR_RID: _inputs()})
        hdr = tmp_path / "a01.hdr"
        sidecar = tmp_path / "a01.pb2"
        hdr.write_bytes(b"hdr-bytes")
        sidecar.write_bytes(b"sidecar-bytes")
        cache.record_conversion(HDR_RID, _inputs(), hdr, sidecar)
        cache.save()
        entry = cache._new_entries[HDR_RID]
        assert entry.output == hashlib.sha256(b"hdr-bytes").hexdigest()
        assert entry.sidecar_output == hashlib.sha256(b"sidecar-bytes").hexdigest()

    def test_record_hit_carries_entry(self):
        cache = self._context(_StatProdClient())
        cache.partition({HDR_RID: _inputs()})
        cache.record_hit(HDR_RID)
        assert cache._new_entries[HDR_RID] == _entry()

    def test_save_writes_map(self, tmp_path):
        map_path = tmp_path / "skyboxes" / "tranquility.json"
        cache = SkyboxesCacheContext(
            server_id="tranquility",
            resource_root="efa/v2",
            ci_client=_FakeClient(),  # type: ignore[arg-type]
            prod_client=_StatProdClient(),  # type: ignore[arg-type]
            map_path=map_path,
        )
        cache.load()
        cache.partition({})
        cache.save()
        parsed = SkyboxesBuildStateMap.from_json(map_path.read_bytes())
        assert parsed.server_id == "tranquility"
        assert parsed.schema_version == MAP_SCHEMA_VERSION


class TestLoadMap:
    def test_missing_map_reads_empty(self):
        state_map = load_map(_FakeClient(), "tranquility")  # type: ignore[arg-type]
        assert state_map.entries == {}
        assert state_map.server_id == "tranquility"

    def test_corrupt_map_reads_empty(self):
        state_map = load_map(_FakeClient(b"not json"), "tranquility")  # type: ignore[arg-type]
        assert state_map.entries == {}

    def test_schema_mismatch_reads_empty(self):
        raw = json.dumps({"schema_version": 999, "server_id": "tranquility", "entries": {}})
        state_map = load_map(_FakeClient(raw.encode()), "tranquility")  # type: ignore[arg-type]
        assert state_map.entries == {}

    def test_server_mismatch_reads_empty(self):
        raw = SkyboxesBuildStateMap(server_id="serenity").to_json()
        state_map = load_map(_FakeClient(raw), "tranquility")  # type: ignore[arg-type]
        assert state_map.entries == {}


if __name__ == "__main__":
    raise SystemExit(pytest.main([__file__]))
