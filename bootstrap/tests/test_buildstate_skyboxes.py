"""Tests for the skyboxes build-state map (bootstrap.data.buildstate.skyboxes)."""

from __future__ import annotations

import hashlib
import json

import click
import pytest

from click.testing import CliRunner

from bootstrap.cli.ci import buildstate as buildstate_cli
from bootstrap.data.buildstate import skyboxes as buildstate_skyboxes
from bootstrap.data.buildstate.models import ModelsBuildStateMap
from bootstrap.data.buildstate.models import blob_remote_key
from bootstrap.data.buildstate.skyboxes import MAP_SCHEMA_VERSION
from bootstrap.data.buildstate.skyboxes import SkyboxArtifactEntry
from bootstrap.data.buildstate.skyboxes import SkyboxesBuildStateMap
from bootstrap.data.buildstate.skyboxes import SkyboxesCacheContext
from bootstrap.data.buildstate.skyboxes import SkyboxInputs
from bootstrap.data.buildstate.skyboxes import inputs_match
from bootstrap.data.buildstate.skyboxes import load_map
from bootstrap.data.buildstate.skyboxes import map_remote_key
from bootstrap.data.buildstate.skyboxes import seed_artifact_entries
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


class TestNonRebuildSeeding:
    def test_seeds_only_complete_pairs_from_current_inputs(self):
        inputs = {
            "a01": _inputs(cube="current-cube", black="current-black"),
            "new_id": _inputs(cube="new-cube"),
            "unhashable": None,
        }
        entries = seed_artifact_entries(
            inputs,
            {
                HDR_RID: "published-hdr",
                SIDECAR_RID: "published-sidecar",
                # The independently regenerated lighting catalog is not an
                # environment-pair input and must not be seeded as one.
                "resource://static/skyboxes/lighting_profiles.pb2": "catalog-hash",
            },
        )
        assert entries == {
            HDR_RID: SkyboxArtifactEntry(
                cube="current-cube",
                black="current-black",
                output="published-hdr",
                sidecar_output="published-sidecar",
            )
        }

    @pytest.mark.parametrize("missing", [HDR_RID, SIDECAR_RID])
    def test_incomplete_pair_remains_a_miss(self, missing: str):
        outputs = {HDR_RID: "hdr", SIDECAR_RID: "sidecar"}
        del outputs[missing]
        assert seed_artifact_entries({"a01": _inputs()}, outputs) == {}


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


class _UploadProdClient:
    """Prod client stub recording uploads; existence keys on content hash."""

    def __init__(self, existing: set[str] | None = None):
        self.existing = existing or set()
        self.uploads: list[tuple[str, bytes]] = []

    def object_exists(self, key: str) -> bool:
        return any(key.endswith(content_hash) for content_hash in self.existing)

    def upload_file(self, src, key: str) -> None:
        self.uploads.append((key, src.read_bytes()))


def _baked_pair(tmp_path):
    hdr = tmp_path / "a01.hdr"
    sidecar = tmp_path / "a01.pb2"
    hdr.write_bytes(b"hdr-bytes")
    sidecar.write_bytes(b"sidecar-bytes")
    return hdr, sidecar


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
        hdr, sidecar = _baked_pair(tmp_path)
        cache.record_conversion(HDR_RID, _inputs(), hdr, sidecar)
        cache.save()
        entry = cache._new_entries[HDR_RID]
        assert entry.output == hashlib.sha256(b"hdr-bytes").hexdigest()
        assert entry.sidecar_output == hashlib.sha256(b"sidecar-bytes").hexdigest()

    def test_record_conversion_uploads_both_blobs(self, tmp_path):
        client = _UploadProdClient()
        cache = SkyboxesCacheContext(
            server_id="tranquility",
            resource_root="efa/v2",
            ci_client=_FakeClient(),  # type: ignore[arg-type]
            prod_client=client,  # type: ignore[arg-type]
            upload_blobs=True,
        )
        hdr, sidecar = _baked_pair(tmp_path)
        cache.record_conversion(HDR_RID, _inputs(), hdr, sidecar)
        hdr_hash = hashlib.sha256(b"hdr-bytes").hexdigest()
        sidecar_hash = hashlib.sha256(b"sidecar-bytes").hexdigest()
        assert client.uploads == [
            (blob_remote_key("efa/v2", HDR_RID, hdr_hash), b"hdr-bytes"),
            (blob_remote_key("efa/v2", SIDECAR_RID, sidecar_hash), b"sidecar-bytes"),
        ]
        entry = cache._new_entries[HDR_RID]
        assert entry.output == hdr_hash
        assert entry.sidecar_output == sidecar_hash

    def test_record_conversion_skips_blobs_already_in_prod(self, tmp_path):
        hdr_hash = hashlib.sha256(b"hdr-bytes").hexdigest()
        client = _UploadProdClient(existing={hdr_hash})
        cache = SkyboxesCacheContext(
            server_id="tranquility",
            resource_root="efa/v2",
            ci_client=_FakeClient(),  # type: ignore[arg-type]
            prod_client=client,  # type: ignore[arg-type]
            upload_blobs=True,
        )
        hdr, sidecar = _baked_pair(tmp_path)
        cache.record_conversion(HDR_RID, _inputs(), hdr, sidecar)
        sidecar_hash = hashlib.sha256(b"sidecar-bytes").hexdigest()
        assert client.uploads == [
            (blob_remote_key("efa/v2", SIDECAR_RID, sidecar_hash), b"sidecar-bytes")
        ]

    def test_record_conversion_uploads_when_prod_probe_fails(
        self, tmp_path, monkeypatch: pytest.MonkeyPatch
    ):
        """A transient probe failure must not abort the push: the key is
        content-addressed, so uploading unconditionally is safe."""

        class FlakyProdClient(_UploadProdClient):
            def object_exists(self, key: str) -> bool:
                raise ConnectionError("transient S3 error")

        monkeypatch.setattr(buildstate_skyboxes, "warning", lambda *_args: None)
        client = FlakyProdClient()
        cache = SkyboxesCacheContext(
            server_id="tranquility",
            resource_root="efa/v2",
            ci_client=_FakeClient(),  # type: ignore[arg-type]
            prod_client=client,  # type: ignore[arg-type]
            upload_blobs=True,
        )
        hdr, sidecar = _baked_pair(tmp_path)
        cache.record_conversion(HDR_RID, _inputs(), hdr, sidecar)
        hdr_hash = hashlib.sha256(b"hdr-bytes").hexdigest()
        sidecar_hash = hashlib.sha256(b"sidecar-bytes").hexdigest()
        assert client.uploads == [
            (blob_remote_key("efa/v2", HDR_RID, hdr_hash), b"hdr-bytes"),
            (blob_remote_key("efa/v2", SIDECAR_RID, sidecar_hash), b"sidecar-bytes"),
        ]
        assert cache._new_entries[HDR_RID].output == hdr_hash

    def test_record_conversion_without_upload_blobs_touches_no_prod(self, tmp_path):
        client = _UploadProdClient()
        cache = SkyboxesCacheContext(
            server_id="tranquility",
            resource_root="efa/v2",
            ci_client=_FakeClient(),  # type: ignore[arg-type]
            prod_client=client,  # type: ignore[arg-type]
        )
        hdr, sidecar = _baked_pair(tmp_path)
        cache.record_conversion(HDR_RID, _inputs(), hdr, sidecar)
        assert client.uploads == []
        assert cache._new_entries[HDR_RID].output == hashlib.sha256(b"hdr-bytes").hexdigest()

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


class TestBuildStateCommitCommand:
    def test_commit_uploads_models_and_skyboxes(self, tmp_path, monkeypatch: pytest.MonkeyPatch):
        models_dir = tmp_path / "models"
        skyboxes_dir = tmp_path / "skyboxes"
        models_dir.mkdir()
        skyboxes_dir.mkdir()
        models_raw = ModelsBuildStateMap(server_id="tranquility").to_json()
        skyboxes_raw = SkyboxesBuildStateMap(server_id="tranquility").to_json()
        (models_dir / "tranquility.json").write_bytes(models_raw)
        (skyboxes_dir / "tranquility.json").write_bytes(skyboxes_raw)

        writes = []

        class Client:
            def write_bytes(self, key: str, raw: bytes):
                writes.append((key, raw))

        monkeypatch.setattr(buildstate_cli, "_ci_client", Client)

        @click.group()
        def root():
            pass

        @root.group()
        def ci():
            pass

        buildstate_cli.register_build_state_commands(ci)
        result = CliRunner().invoke(root, ["ci", "build-state", "commit", "--from", str(tmp_path)])
        assert result.exit_code == 0, result.output
        assert writes == [
            ("build-state/models/tranquility.json", models_raw),
            ("build-state/skyboxes/tranquility.json", skyboxes_raw),
        ]


class TestPushSkyboxesCommand:
    @staticmethod
    def _install_fakes(monkeypatch: pytest.MonkeyPatch) -> dict:
        calls: dict = {}

        ci_client = object()
        prod_client = object()
        monkeypatch.setattr(buildstate_cli, "_ci_client", lambda: ci_client)
        monkeypatch.setattr(buildstate_cli, "_prod_client", lambda: prod_client)
        calls["ci_client"] = ci_client
        calls["prod_client"] = prod_client

        class FakeDataSchema:
            resource_root = "efa/v2"

        class FakeConfiguration:
            data_schema = FakeDataSchema()

        monkeypatch.setattr(buildstate_cli.bootstrap.config, "CONFIGURATION", FakeConfiguration())
        monkeypatch.setattr(
            buildstate_cli.bootstrap.config.ProjectConfiguration,
            "ensure_loaded",
            classmethod(lambda cls: None),
        )

        monkeypatch.setattr(buildstate_cli.runtime, "get_workspace", lambda server: f"ws:{server}")

        class FakeWorkspaceConfig:
            @staticmethod
            def load_from_descriptor(descriptor):
                calls["descriptor"] = descriptor
                return "ws-config"

        monkeypatch.setattr(buildstate_cli, "WorkspaceConfig", FakeWorkspaceConfig)

        class FakeDatasource:
            def __init__(self, ws_config):
                calls["ws_config"] = ws_config

            async def aclose(self):
                calls["closed"] = True

        async def fake_generate(data, cache=None, threads=None):
            calls["cache"] = cache
            calls["threads"] = threads

        monkeypatch.setattr("bootstrap.data.workspace.generate.GeneratorDatasource", FakeDatasource)
        monkeypatch.setattr("bootstrap.data.workspace.generate.skyboxes.generate", fake_generate)
        return calls

    def _invoke(self, monkeypatch: pytest.MonkeyPatch, *args: str):
        calls = self._install_fakes(monkeypatch)

        @click.group()
        def root():
            pass

        @root.group()
        def ci():
            pass

        buildstate_cli.register_build_state_commands(ci)
        result = CliRunner().invoke(root, ["ci", "build-state", "push-skyboxes", *args])
        return result, calls

    def test_push_skyboxes_rebuilds_uploads_and_commits(self, monkeypatch: pytest.MonkeyPatch):
        result, calls = self._invoke(monkeypatch, "--server", "tranquility")
        assert result.exit_code == 0, result.output
        cache = calls["cache"]
        assert cache.server_id == "tranquility"
        assert cache.resource_root == "efa/v2"
        assert cache.ci_client is calls["ci_client"]
        assert cache.prod_client is calls["prod_client"]
        assert cache.rebuild is True
        assert cache.upload_map is True
        assert cache.upload_blobs is True
        assert calls["descriptor"] == "ws:tranquility"
        assert calls["ws_config"] == "ws-config"
        assert calls["threads"] is None
        assert calls.get("closed") is True
        assert "Pushed pre-built skyboxes for tranquility" in result.output

    def test_push_skyboxes_passes_threads(self, monkeypatch: pytest.MonkeyPatch):
        result, calls = self._invoke(monkeypatch, "--server", "tranquility", "--threads", "8")
        assert result.exit_code == 0, result.output
        assert calls["threads"] == 8


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
