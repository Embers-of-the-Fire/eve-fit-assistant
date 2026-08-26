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
    with tempfile.TemporaryDirectory() as tmp_dir:
        db_path = Path(tmp_dir) / "localization.db"
        connection = sqlite3.connect(db_path)
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
        return db_path.read_bytes()


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
    negative_effect = dogma_effects.entries[-64]
    negative_effect.effectCategory = 1
    negative_effect.name = "shipModularity"

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
        assert set(by_family["dogma_effect_meta"]) == {10, -64}

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
            next(e.content for e in entries if e.family == "dogma_effect_meta" and e.entry_id == 10)
        )
        assert effect_meta.dogma_effect_id == 10
        assert effect_meta.name == "shipModuleRemoteArmorRepairer"

        negative_effect_meta = platform_data_pb2.PlatformDogmaEffectMeta()
        negative_effect_meta.ParseFromString(
            next(
                e.content for e in entries if e.family == "dogma_effect_meta" and e.entry_id == -64
            )
        )
        assert negative_effect_meta.dogma_effect_id == -64
        assert negative_effect_meta.name == "shipModularity"


class _FakeTransport:
    def __init__(
        self,
        existing: set[tuple[str, str]] | None = None,
        completed: set[tuple[str, str]] | None = None,
    ) -> None:
        self.posts: list[tuple[str, dict[str, Any]]] = []
        self.closed = False
        # (family, content_hash) rows the server already holds.
        self._existing = existing or set()
        # (server_id, snapshot_hash) pairs already marked complete.
        self._completed = completed or set()

    def post(self, path: str, payload: dict[str, Any]) -> dict[str, Any]:
        self.posts.append((path, payload))
        if path == "lookup":
            missing = [
                h for h in payload["content_hashes"] if (payload["family"], h) not in self._existing
            ]
            return {"ok": True, "missing": missing}
        if path == "snapshot":
            complete = (payload["server_id"], payload["snapshot_hash"]) in self._completed
            return {"ok": True, "complete": complete}
        return {"ok": True, "inserted": len(payload.get("entries", []))}

    def close(self) -> None:
        self.closed = True


class _FakeConnection:
    """In-memory stand-in for websockets' sync Connection (no real sockets)."""

    def __init__(self, replies: list[Any]) -> None:
        self.sent: list[str] = []
        self._replies = list(replies)
        self.closed = False

    def send(self, message: str) -> None:
        self.sent.append(message)

    def recv(self, timeout: float | None = None) -> str:
        del timeout
        reply = self._replies.pop(0)
        if isinstance(reply, Exception):
            raise reply
        return json.dumps(reply)

    def close(self) -> None:
        self.closed = True


class TestWebSocketTransport:
    def _make_transport(self, connection: Any = None) -> Any:
        from bootstrap.data.d1.sync import WebSocketTransport

        transport: Any = WebSocketTransport("https://worker.example/data-sync", "test-token")
        transport._connection = connection
        return transport

    def test_url_normalization(self) -> None:
        from bootstrap.data.d1.sync import WebSocketTransport

        assert (
            WebSocketTransport._to_ws_url("https://api.example.com/platform/storage/data-sync")
            == "wss://api.example.com/platform/storage/data-sync/sync"
        )
        assert (
            WebSocketTransport._to_ws_url("http://localhost:8790/platform/storage/data-sync/")
            == "ws://localhost:8790/platform/storage/data-sync/sync"
        )
        assert (
            WebSocketTransport._to_ws_url("wss://api.example.com/data-sync")
            == "wss://api.example.com/data-sync/sync"
        )
        with pytest.raises(ValueError, match="Unsupported data-sync URL scheme"):
            WebSocketTransport._to_ws_url("ftp://example.com")

    def test_roundtrip_sends_typed_frame_with_id(self) -> None:
        connection = _FakeConnection(replies=[{"id": 1, "ok": True, "inserted": 2}])
        transport = self._make_transport(connection)

        reply = transport.post("content", {"entries": [{"family": "types"}]})

        assert reply["inserted"] == 2
        sent = json.loads(connection.sent[0])
        assert sent == {"id": 1, "type": "content", "entries": [{"family": "types"}]}

    def test_discards_unrelated_replies(self) -> None:
        connection = _FakeConnection(
            replies=[{"id": 99, "ok": True}, {"id": 1, "ok": True, "missing": []}]
        )
        transport = self._make_transport(connection)

        reply = transport.post("lookup", {"family": "types", "content_hashes": ["ab" * 32]})

        assert reply == {"id": 1, "ok": True, "missing": []}

    def test_error_reply_raises(self) -> None:
        connection = _FakeConnection(replies=[{"id": 1, "ok": False, "error": "bad"}])
        transport = self._make_transport(connection)
        with pytest.raises(RuntimeError, match="returned error"):
            transport.post("register", {})

    def test_reconnects_and_resends_on_connection_failure(
        self, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        from websockets.exceptions import ConnectionClosed

        monkeypatch.setattr("time.sleep", lambda _seconds: None)
        failing = _FakeConnection(replies=[ConnectionClosed(None, None)])
        recovered = _FakeConnection(replies=[{"id": 2, "ok": True}])
        transport = self._make_transport(failing)

        transport._connect = lambda: setattr(transport, "_connection", recovered)

        reply = transport.post("complete", {"entry_count": 1})

        assert reply["ok"] is True
        # The same frame is resent after reconnecting, with a fresh id.
        assert len(failing.sent) == 1
        assert len(recovered.sent) == 1
        assert json.loads(failing.sent[0])["type"] == "complete"
        assert json.loads(recovered.sent[0])["type"] == "complete"

    def test_retries_when_reconnect_fails(self, monkeypatch: pytest.MonkeyPatch) -> None:
        from websockets.exceptions import ConnectionClosed

        monkeypatch.setattr("time.sleep", lambda _seconds: None)
        failing = _FakeConnection(replies=[ConnectionClosed(None, None)])
        recovered = _FakeConnection(replies=[{"id": 2, "ok": True}])
        transport = self._make_transport(failing)

        connect_calls = 0

        def flaky_connect() -> None:
            nonlocal connect_calls
            connect_calls += 1
            if connect_calls == 1:
                raise OSError("network unreachable")
            transport._connection = recovered

        transport._connect = flaky_connect

        reply = transport.post("complete", {"entry_count": 1})

        assert reply["ok"] is True
        # The first reconnect attempt fails and is retried inside post().
        assert connect_calls == 2
        assert len(recovered.sent) == 1
        assert json.loads(recovered.sent[0])["type"] == "complete"

    def test_does_not_retry_permanent_handshake_failure(
        self, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        from websockets.datastructures import Headers
        from websockets.exceptions import InvalidStatus
        from websockets.http11 import Response

        monkeypatch.setattr("time.sleep", lambda _seconds: None)
        transport = self._make_transport()
        connect_calls = 0

        def unauthorized_connect() -> None:
            nonlocal connect_calls
            connect_calls += 1
            raise InvalidStatus(Response(401, "Unauthorized", Headers(), b""))

        transport._connect = unauthorized_connect

        with pytest.raises(InvalidStatus):
            transport.post("complete", {})

        # Authentication failures are permanent: a single attempt, no retries.
        assert connect_calls == 1

    def test_retries_transient_handshake_failure(self, monkeypatch: pytest.MonkeyPatch) -> None:
        from websockets.datastructures import Headers
        from websockets.exceptions import InvalidStatus
        from websockets.http11 import Response

        monkeypatch.setattr("time.sleep", lambda _seconds: None)
        recovered = _FakeConnection(replies=[{"id": 1, "ok": True}])
        transport = self._make_transport()
        connect_calls = 0

        def flaky_connect() -> None:
            nonlocal connect_calls
            connect_calls += 1
            if connect_calls == 1:
                raise InvalidStatus(Response(503, "Service Unavailable", Headers(), b""))
            transport._connection = recovered

        transport._connect = flaky_connect

        reply = transport.post("complete", {})

        assert reply["ok"] is True
        assert connect_calls == 2

    def test_gives_up_after_max_attempts(self, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setattr("time.sleep", lambda _seconds: None)
        connection = _FakeConnection(replies=[TimeoutError("slow")] * 3)
        transport = self._make_transport(connection)
        transport._max_attempts = 3
        transport._connect = lambda: setattr(transport, "_connection", connection)

        with pytest.raises(RuntimeError, match="after 3 attempts"):
            transport.post("content", {"entries": []})


class TestRunSync:
    def test_dedup_and_register(self, schema_root: Path) -> None:
        from bootstrap.data.d1.sync import run_sync

        hash_a = "aa" * 32
        hash_b = "bb" * 32
        _build_snapshot(schema_root, hash_a)
        _build_snapshot(schema_root, hash_b)

        transport = _FakeTransport()
        run_sync({"alpha": hash_a, "beta": hash_b}, schema_root, transport, batch_size=2000)

        content_posts = [p for p in transport.posts if p[0] == "content"]
        register_posts = [p for p in transport.posts if p[0] == "register"]

        # Identical snapshots: content uploaded once, deduplicated by hash.
        content_hashes = [
            e["content_hash"] for _path, payload in content_posts for e in payload["entries"]
        ]
        assert len(content_hashes) == len(set(content_hashes))
        assert len(content_hashes) == 10  # one entry per family

        assert len(register_posts) == 2
        servers = {payload["server_id"] for _path, payload in register_posts}
        assert servers == {"alpha", "beta"}
        for _path, payload in register_posts:
            assert len(payload["entries"]) == 10

        complete_posts = [p for p in transport.posts if p[0] == "complete"]
        assert len(complete_posts) == 2
        complete_servers = {payload["server_id"] for _path, payload in complete_posts}
        assert complete_servers == {"alpha", "beta"}
        for _path, payload in complete_posts:
            assert payload["entry_count"] == 10

        assert transport.closed

    def test_skips_completed_snapshots(self, schema_root: Path) -> None:
        from bootstrap.data.d1.sync import run_sync

        hash_a = "aa" * 32
        hash_b = "bb" * 32
        _build_snapshot(schema_root, hash_a)
        _build_snapshot(schema_root, hash_b)

        transport = _FakeTransport(completed={("alpha", hash_a)})
        run_sync({"alpha": hash_a, "beta": hash_b}, schema_root, transport, batch_size=2000)

        # Nothing is re-registered or re-completed for the finished snapshot.
        register_posts = [p for p in transport.posts if p[0] == "register"]
        complete_posts = [p for p in transport.posts if p[0] == "complete"]
        assert {payload["server_id"] for _path, payload in register_posts} == {"beta"}
        assert {payload["server_id"] for _path, payload in complete_posts} == {"beta"}

    def test_lookup_skips_existing_content(self, schema_root: Path) -> None:
        from bootstrap.data.d1.sync import load_snapshot_entries
        from bootstrap.data.d1.sync import run_sync

        snapshot_hash = "cc" * 32
        _build_snapshot(schema_root, snapshot_hash)

        existing = {
            (entry.family, entry.hash)
            for entry in load_snapshot_entries(schema_root, snapshot_hash)
            if entry.family == "types"
        }
        assert existing  # fixture sanity check

        transport = _FakeTransport(existing=existing)
        run_sync({"alpha": snapshot_hash}, schema_root, transport, batch_size=2000)

        content_posts = [p for p in transport.posts if p[0] == "content"]
        uploaded = [e for _path, payload in content_posts for e in payload["entries"]]
        assert "types" not in {e["family"] for e in uploaded}
        assert len(uploaded) == 9  # 10 rows minus the existing types row

    def test_complete_not_posted_when_register_fails(self, schema_root: Path) -> None:
        from bootstrap.data.d1.sync import run_sync

        snapshot_hash = "dd" * 32
        _build_snapshot(schema_root, snapshot_hash)

        class _FailingTransport(_FakeTransport):
            def post(self, path: str, payload: dict[str, Any]) -> dict[str, Any]:
                if path == "register":
                    raise RuntimeError("boom")
                return super().post(path, payload)

        transport = _FailingTransport()
        with pytest.raises(RuntimeError, match="boom"):
            run_sync({"alpha": snapshot_hash}, schema_root, transport, batch_size=2000)
        assert [p for p in transport.posts if p[0] == "complete"] == []

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

    @pytest.mark.parametrize("batch_size", [0, -1, 2_001])
    def test_rejects_invalid_batch_size(self, schema_root: Path, batch_size: int) -> None:
        from bootstrap.data.d1.sync import run_sync

        # Validation happens before any snapshot is loaded, so no snapshot
        # fixtures are needed here.
        with pytest.raises(ValueError, match="batch_size must be between 1 and 2000"):
            run_sync({"alpha": "ab" * 32}, schema_root, None, batch_size=batch_size)

    @pytest.mark.parametrize("batch_size", [1, 2_000])
    def test_accepts_boundary_batch_size(self, schema_root: Path, batch_size: int) -> None:
        from bootstrap.data.d1.sync import run_sync

        snapshot_hash = "f0" * 32
        _build_snapshot(schema_root, snapshot_hash)

        transport = _FakeTransport()
        run_sync({"alpha": snapshot_hash}, schema_root, transport, batch_size=batch_size)

        for path, payload in transport.posts:
            if path in ("content", "register"):
                assert len(payload["entries"]) <= batch_size
        assert [p for p in transport.posts if p[0] == "complete"] != []


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
