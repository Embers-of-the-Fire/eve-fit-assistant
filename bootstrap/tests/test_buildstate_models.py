"""Tests for the models build-state map (bootstrap.data.buildstate.models)."""

from __future__ import annotations

import json

import pytest

from bootstrap.data.buildstate import models as buildstate_models
from bootstrap.data.buildstate.models import MAP_SCHEMA_VERSION
from bootstrap.data.buildstate.models import ModelArtifactEntry
from bootstrap.data.buildstate.models import ModelInputs
from bootstrap.data.buildstate.models import ModelsBuildStateMap
from bootstrap.data.buildstate.models import ModelsCacheContext
from bootstrap.data.buildstate.models import blob_remote_key
from bootstrap.data.buildstate.models import inputs_match
from bootstrap.data.buildstate.models import load_map
from bootstrap.data.buildstate.models import map_remote_key
from bootstrap.data.buildstate.models import partition_entries
from bootstrap.data.buildstate.models import ship_resource_id


RID = "resource://static/models/ships/587.full.glb"

DNA = "mf4_t1:minmatarbase:minmatar"
SOF = "sof1"


def _entry(
    model: str = "m1",
    texture: dict[str, str] | None = None,
    dna: str = DNA,
    sof: str = SOF,
    output: str = "o1",
):
    return ModelArtifactEntry(model=model, texture=texture or {}, dna=dna, sof=sof, output=output)


def _inputs(
    model: str = "m1",
    texture: dict[str, str] | None = None,
    dna: str = DNA,
    sof: str = SOF,
) -> ModelInputs:
    return ModelInputs(model=model, texture=texture or {}, dna=dna, sof=sof)


class TestInputsMatch:
    def test_identical_inputs_match(self):
        assert inputs_match(_entry(texture={"a": "1"}), _inputs(texture={"a": "1"}))

    def test_model_hash_change_invalidates(self):
        assert not inputs_match(_entry(), _inputs(model="m2"))

    def test_texture_value_change_invalidates(self):
        assert not inputs_match(_entry(texture={"a": "1"}), _inputs(texture={"a": "2"}))

    def test_texture_key_added_invalidates(self):
        assert not inputs_match(_entry(texture={"a": "1"}), _inputs(texture={"a": "1", "b": "2"}))

    def test_texture_key_removed_invalidates(self):
        assert not inputs_match(_entry(texture={"a": "1", "b": "2"}), _inputs(texture={"a": "1"}))

    def test_dna_change_invalidates(self):
        assert not inputs_match(_entry(), _inputs(dna="mf4_t2:minmatarbase:minmatar"))

    def test_sof_fingerprint_change_invalidates(self):
        assert not inputs_match(_entry(), _inputs(sof="sof2"))


class TestPartitionEntries:
    def _map(self, entries: dict[str, ModelArtifactEntry]) -> ModelsBuildStateMap:
        return ModelsBuildStateMap(server_id="tranquility", entries=entries)

    def test_hit_when_inputs_match_and_output_exists(self):
        state_map = self._map({RID: _entry(texture={"a": "1"})})
        desired = {RID: _inputs(texture={"a": "1"})}
        hits, misses = partition_entries(desired, state_map, lambda _rid, _out: True)
        assert set(hits) == {RID}
        assert misses == set()

    def test_miss_when_entry_absent(self):
        hits, misses = partition_entries({RID: _inputs()}, self._map({}), lambda _r, _o: True)
        assert hits == {}
        assert misses == {RID}

    def test_miss_when_inputs_differ(self):
        state_map = self._map({RID: _entry()})
        hits, misses = partition_entries({RID: _inputs(model="m2")}, state_map, lambda _r, _o: True)
        assert hits == {}
        assert misses == {RID}

    def test_miss_when_output_missing(self):
        """Rule 4: a recorded output that no longer exists invalidates."""
        state_map = self._map({RID: _entry()})
        hits, misses = partition_entries({RID: _inputs()}, state_map, lambda _r, _o: False)
        assert hits == {}
        assert misses == {RID}

    def test_mixed_partition(self):
        other = "resource://static/models/ships/588.base.glb"
        state_map = self._map({RID: _entry(), other: _entry(model="old")})
        desired = {RID: _inputs(), other: _inputs(model="new")}
        hits, misses = partition_entries(desired, state_map, lambda _r, _o: True)
        assert set(hits) == {RID}
        assert misses == {other}


class TestMapSerialization:
    def test_roundtrip(self):
        state_map = ModelsBuildStateMap(
            server_id="tranquility", entries={RID: _entry(texture={"a": "1"})}
        )
        parsed = ModelsBuildStateMap.from_json(state_map.to_json())
        assert parsed == state_map
        assert parsed.schema_version == MAP_SCHEMA_VERSION

    def test_json_shape(self):
        raw = json.loads(ModelsBuildStateMap(server_id="s", entries={RID: _entry()}).to_json())
        assert raw["schema_version"] == MAP_SCHEMA_VERSION
        assert raw["server_id"] == "s"
        assert raw["entries"][RID] == {
            "model": "m1",
            "texture": {},
            "dna": DNA,
            "sof": SOF,
            "output": "o1",
        }


class _FakeClient:
    def __init__(self, payload: bytes | None = None):
        self.payload = payload

    def read_bytes(self, key: str) -> bytes:
        if self.payload is None:
            raise FileNotFoundError(key)
        return self.payload


class _FailingProdClient:
    def object_size(self, key: str) -> int | None:
        raise RuntimeError(f"cannot probe {key}")


class _StatProdClient:
    """Prod client stub: HEAD returns a fixed size, or None for a missing blob."""

    def __init__(self, size: int | None):
        self.size = size

    def object_size(self, key: str) -> int | None:
        return self.size


class TestHitReference:
    def _context(self, prod_client) -> ModelsCacheContext:
        state_map = ModelsBuildStateMap(server_id="tranquility", entries={RID: _entry()})
        cache = ModelsCacheContext(
            server_id="tranquility",
            resource_root="efa/v2",
            ci_client=_FakeClient(state_map.to_json()),  # type: ignore[arg-type]
            prod_client=prod_client,
        )
        cache.load()
        return cache

    def test_hit_captures_size_from_head(self):
        cache = self._context(_StatProdClient(size=4321))
        hits, misses = cache.partition({RID: _inputs()})
        assert set(hits) == {RID}
        assert misses == set()
        assert cache.hit_reference(RID) == (RID, "o1", 4321)

    def test_missing_output_is_a_miss_without_warning(self, monkeypatch: pytest.MonkeyPatch):
        """Rule 4: a recorded output that no longer exists invalidates."""
        warnings = []
        monkeypatch.setattr(buildstate_models, "warning", warnings.append)
        hits, misses = self._context(_StatProdClient(size=None)).partition({RID: _inputs()})
        assert hits == {}
        assert misses == {RID}
        assert warnings == []


class TestCacheFailOpen:
    def _context(self) -> ModelsCacheContext:
        state_map = ModelsBuildStateMap(server_id="tranquility", entries={RID: _entry()})
        cache = ModelsCacheContext(
            server_id="tranquility",
            resource_root="efa/v2",
            ci_client=_FakeClient(state_map.to_json()),  # type: ignore[arg-type]
            prod_client=_FailingProdClient(),  # type: ignore[arg-type]
        )
        cache.load()
        return cache

    def test_probe_failure_is_a_miss(self, monkeypatch: pytest.MonkeyPatch):
        warnings = []
        monkeypatch.setattr(buildstate_models, "warning", warnings.append)
        hits, misses = self._context().partition({RID: _inputs()})
        assert hits == {}
        assert misses == {RID}
        assert len(warnings) == 1
        assert "Models cache probe failed" in warnings[0]


class TestLoadMap:
    def test_missing_map_reads_empty(self):
        state_map = load_map(_FakeClient(), "tranquility")  # type: ignore[arg-type]
        assert state_map.entries == {}
        assert state_map.server_id == "tranquility"

    def test_corrupt_map_reads_empty(self):
        state_map = load_map(_FakeClient(b"not json"), "tranquility")  # type: ignore[arg-type]
        assert state_map.entries == {}

    @pytest.mark.parametrize("version", [2, 999])
    def test_schema_mismatch_reads_empty(self, version: int):
        """Old (2) and unknown (999) schemas fail open against the new semantics."""
        raw = json.dumps(
            {
                "schema_version": version,
                "server_id": "tranquility",
                "entries": {
                    RID: {"model": "m1", "texture": {}, "dna": DNA, "sof": SOF, "output": "o1"}
                },
            }
        ).encode()
        state_map = load_map(_FakeClient(raw), "tranquility")  # type: ignore[arg-type]
        assert state_map.entries == {}

    def test_pre_sof_map_reads_empty(self):
        """Schema-1 entries (no dna/sof fields) fail validation: fail-open."""
        raw = json.dumps(
            {
                "schema_version": 1,
                "server_id": "tranquility",
                "entries": {RID: {"model": "m1", "texture": {}, "output": "o1"}},
            }
        ).encode()
        state_map = load_map(_FakeClient(raw), "tranquility")  # type: ignore[arg-type]
        assert state_map.entries == {}

    def test_server_mismatch_reads_empty(self):
        raw = ModelsBuildStateMap(server_id="serenity", entries={RID: _entry()}).to_json()
        state_map = load_map(_FakeClient(raw), "tranquility")  # type: ignore[arg-type]
        assert state_map.entries == {}

    def test_valid_map_loads(self):
        original = ModelsBuildStateMap(server_id="tranquility", entries={RID: _entry()})
        state_map = load_map(_FakeClient(original.to_json()), "tranquility")  # type: ignore[arg-type]
        assert state_map.entries == original.entries


class TestKeys:
    def test_map_remote_key(self):
        assert map_remote_key("tranquility") == "build-state/models/tranquility.json"

    def test_ship_resource_id(self):
        assert ship_resource_id(587, "full") == RID

    def test_blob_remote_key_layout(self):
        key = blob_remote_key("efa/v2", RID, "ab" * 32)
        assert key.startswith("efa/v2/assets/blobs/")
        assert key.endswith(f"/{'ab' * 32}")
        shards = key.split("/")
        # efa/v2 / assets / blobs / <2c> / <ident> / <content>
        assert len(shards) == 7
        assert shards[4] == shards[5][:2]


if __name__ == "__main__":
    raise SystemExit(pytest.main([__file__]))
