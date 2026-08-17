"""Tests for the platform D1 snapshot syncer (bootstrap/data/d1)."""

from __future__ import annotations

import json
import sqlite3
import tempfile

from pathlib import Path
from typing import Any

import pytest


pytest.importorskip("google.protobuf", reason="protobuf runtime required for pb2 bindings")


@pytest.fixture
def schema_root(tmp_path: Path) -> Path:
    return tmp_path / "remote"


def _write_blob(schema_root: Path, resource_id: str, data: bytes) -> None:
    from bootstrap.remote.hash import content_hash
    from bootstrap.remote.hash import ident_hash
    from bootstrap.remote.paths import blob_path

    path = blob_path(schema_root, ident_hash(resource_id), content_hash(data))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)


def _make_localization_db(strings: dict[tuple[str, int], str]) -> bytes:
    with tempfile.NamedTemporaryFile(suffix=".db") as tmp:
        connection = sqlite3.connect(tmp.name)
        try:
            connection.execute("CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT NOT NULL)")
            connection.execute(
                "CREATE TABLE strings("
                "locale TEXT NOT NULL, id INTEGER NOT NULL, value TEXT NOT NULL, "
                "PRIMARY KEY(locale, id)) WITHOUT ROWID"
            )
            connection.executemany(
                "INSERT INTO strings(locale, id, value) VALUES (?, ?, ?)",
                [(locale, entry_id, value) for (locale, entry_id), value in strings.items()],
            )
            connection.commit()
        finally:
            connection.close()
        return Path(tmp.name).read_bytes()


def _build_snapshot(schema_root: Path, snapshot_hash: str) -> dict[str, bytes]:
    """Write a minimal snapshot (5 engine blobs + collection + localization)."""
    from bootstrap.data.d1.sync import COLLECTION_RESOURCE_ID
    from bootstrap.data.d1.sync import ENGINE_FAMILIES
    from bootstrap.data.d1.sync import LOCALIZATION_RESOURCE_ID
    from bootstrap.data.d1.sync import _load_efos_pb2
    from bootstrap.data.schema import collections_pb2
    from bootstrap.data.schema import resource_index_pb2

    efos_pb2 = _load_efos_pb2()

    types = efos_pb2.Types()
    types.entries[587].groupID = 25
    types.entries[587].categoryID = 6

    type_dogma = efos_pb2.TypeDogma()
    type_dogma.entries[587].dogmaAttributes.add(attributeID=9, value=100.0)
    type_dogma.entries[587].dogmaEffects.add(effectID=10, isDefault=False)

    dogma_attributes = efos_pb2.DogmaAttributes()
    attr = dogma_attributes.entries[9]
    attr.published = True
    attr.defaultValue = 0.0
    attr.highIsGood = True
    attr.stackable = True
    attr.name = "shieldCapacity"

    dogma_effects = efos_pb2.DogmaEffects()
    effect = dogma_effects.entries[10]
    effect.effectCategory = 1
    effect.name = "shipModuleRemoteArmorRepairer"

    buffs = efos_pb2.BuffCollections()
    buff = buffs.entries[20]
    buff.aggregateMode = efos_pb2.BuffCollections.Buff.MAXIMUM
    buff.buffID = 20
    buff.operationName = efos_pb2.BuffCollections.Buff.POST_MUL
    buff.showOutputValueInUI = efos_pb2.BuffCollections.Buff.SHOW_NORMAL

    collection = collections_pb2.Collection()
    ctype = collection.types[587]
    ctype.type_id = 587
    ctype.icon.icon_id = 46
    ctype.group_id = 25
    ctype.is_dynamic_type = False
    ctype.published = True
    ctype.type_name.id = 100587
    cattr = collection.dogma_attributes[9]
    cattr.dogma_attribute_id = 9
    cattr.name = "shieldCapacity"
    cattr.description = "..."
    cattr.icon.icon_id = 105
    cattr.display_name.id = 200009
    cattr.published = True
    cattr.high_is_good = True
    cattr.display_when_zero = False
    cattr.stackable = True
    collection.slots.SetInParent()

    localization = _make_localization_db(
        {
            ("en-us", 100587): "Rifter",
            ("zh", 100587): "裂谷级",
            ("en-us", 200009): "Shield Capacity",
        }
    )

    blobs: dict[str, bytes] = {
        "types": types.SerializeToString(),
        "type_dogma": type_dogma.SerializeToString(),
        "dogma_attributes": dogma_attributes.SerializeToString(),
        "dogma_effects": dogma_effects.SerializeToString(),
        "buffs": buffs.SerializeToString(),
        COLLECTION_RESOURCE_ID: collection.SerializeToString(),
        LOCALIZATION_RESOURCE_ID: localization,
    }

    index = resource_index_pb2.ResourceIndex()
    index.schema_version = 1
    index.format_version = 2
    for family, (resource_id, _msg) in ENGINE_FAMILIES.items():
        blobs[resource_id] = blobs.pop(family)
    for resource_id, data in blobs.items():
        _write_blob(schema_root, resource_id, data)
        from bootstrap.remote.hash import content_hash

        entry = index.entries.add()
        entry.resource_id = resource_id
        entry.content_hash = content_hash(data)
        entry.size = len(data)

    snapshot_dir = schema_root / "assets" / "resources" / snapshot_hash
    snapshot_dir.mkdir(parents=True, exist_ok=True)
    (snapshot_dir / "resources.pb2").write_bytes(index.SerializeToString())
    return blobs


class TestLoadSnapshotEntries:
    def test_splits_engine_and_meta_families(self, schema_root: Path) -> None:
        from bootstrap.data.d1.sync import load_snapshot_entries

        snapshot_hash = "ab" * 32
        _build_snapshot(schema_root, snapshot_hash)

        entries = load_snapshot_entries(schema_root, snapshot_hash)
        by_family: dict[str, dict[int, bytes]] = {}
        for entry in entries:
            by_family.setdefault(entry.family, {})[entry.entry_id] = entry.content

        assert set(by_family) == {
            "types",
            "type_dogma",
            "dogma_attributes",
            "dogma_effects",
            "buffs",
            "type_meta",
            "dogma_attribute_meta",
            "dogma_effect_meta",
        }
        assert set(by_family["types"]) == {587}
        assert set(by_family["dogma_effect_meta"]) == {10}

    def test_meta_content(self, schema_root: Path) -> None:
        from bootstrap.data.d1.sync import load_snapshot_entries
        from bootstrap.data.schema import platform_data_pb2

        snapshot_hash = "cd" * 32
        _build_snapshot(schema_root, snapshot_hash)
        entries = load_snapshot_entries(schema_root, snapshot_hash)

        type_meta = platform_data_pb2.PlatformTypeMeta()
        type_meta.ParseFromString(
            next(e.content for e in entries if e.family == "type_meta" and e.entry_id == 587)
        )
        assert dict(type_meta.name) == {"en-us": "Rifter", "zh": "裂谷级"}
        assert type_meta.icon_id == 46

        attr_meta = platform_data_pb2.PlatformDogmaAttributeMeta()
        attr_meta.ParseFromString(
            next(e.content for e in entries if e.family == "dogma_attribute_meta")
        )
        assert attr_meta.dogma_attribute_id == 9
        assert attr_meta.name["en-us"] == "Shield Capacity"
        assert attr_meta.name["zh"] == "shieldCapacity"  # fallback to internal name
        assert attr_meta.icon_id == 105

        effect_meta = platform_data_pb2.PlatformDogmaEffectMeta()
        effect_meta.ParseFromString(
            next(e.content for e in entries if e.family == "dogma_effect_meta")
        )
        assert effect_meta.name == "shipModuleRemoteArmorRepairer"


class _FakeTransport:
    def __init__(self) -> None:
        self.posts: list[tuple[str, dict[str, Any]]] = []

    def post(self, path: str, payload: dict[str, Any]) -> dict[str, Any]:
        self.posts.append((path, payload))
        return {"ok": True, "inserted": len(payload.get("entries", []))}


class TestRunSync:
    def test_dedup_and_register(self, schema_root: Path) -> None:
        from bootstrap.data.d1.sync import run_sync

        hash_a = "aa" * 32
        hash_b = "bb" * 32
        _build_snapshot(schema_root, hash_a)
        _build_snapshot(schema_root, hash_b)

        transport = _FakeTransport()
        run_sync({"alpha": hash_a, "beta": hash_b}, schema_root, transport, batch_size=5000)

        content_posts = [p for p in transport.posts if p[0] == "content"]
        register_posts = [p for p in transport.posts if p[0] == "register"]

        # Identical snapshots: content uploaded once, deduplicated by hash.
        content_hashes = [
            e["content_hash"] for _path, payload in content_posts for e in payload["entries"]
        ]
        assert len(content_hashes) == len(set(content_hashes))
        assert len(content_hashes) == 8  # one entry per family

        assert len(register_posts) == 2
        servers = {payload["server_id"] for _path, payload in register_posts}
        assert servers == {"alpha", "beta"}
        for _path, payload in register_posts:
            assert len(payload["entries"]) == 8

    def test_dry_run_uploads_nothing(self, schema_root: Path) -> None:
        from bootstrap.data.d1.sync import run_sync

        snapshot_hash = "ee" * 32
        _build_snapshot(schema_root, snapshot_hash)
        run_sync({"alpha": snapshot_hash}, schema_root, None, dry_run=True)

    def test_requires_transport(self, schema_root: Path) -> None:
        from bootstrap.data.d1.sync import run_sync

        snapshot_hash = "ef" * 32
        _build_snapshot(schema_root, snapshot_hash)
        with pytest.raises(ValueError, match="transport is required"):
            run_sync({"alpha": snapshot_hash}, schema_root, None)


class TestCli:
    def test_d1_sync_dry_run(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        import click
        import click.testing

        from bootstrap.cli import register_all_commands

        monkeypatch.setattr("bootstrap.ci.commands.PROJECT_ROOT", tmp_path)
        schema_root = tmp_path / "cache" / "remote"
        snapshot_hash = "12" * 32
        _build_snapshot(schema_root, snapshot_hash)
        (tmp_path / "snapshot-hashes.json").write_text(
            json.dumps({"alpha": snapshot_hash}), encoding="utf-8"
        )

        @click.group()
        def cli() -> None:
            pass

        register_all_commands(cli)
        result = click.testing.CliRunner().invoke(
            cli,
            [
                "ci",
                "release-data",
                "d1-sync",
                "--hashes",
                str(tmp_path / "snapshot-hashes.json"),
                "--dry-run",
            ],
        )
        assert result.exit_code == 0, result.output
