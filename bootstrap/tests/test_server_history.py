"""Tests for ServerHistory protobuf — schema, round-trip, and merge logic."""

from __future__ import annotations

from bootstrap.remote.models import GenerationResources
from bootstrap.remote.models import ServerHistory
from bootstrap.remote.models import ServerIndex
from bootstrap.remote.models import make_server_history
from bootstrap.remote.models import merge_generation_into_history


def _server_index(
    *servers: tuple[str, str, str],
) -> ServerIndex:
    idx = ServerIndex()
    idx.schema_version = 1
    for sid, build, version in servers:
        e = idx.servers.add()
        e.server_id = sid
        e.game_build = build
        e.game_version = version
    return idx


def _generation_resources(
    *mappings: tuple[str, str],
) -> GenerationResources:
    res = GenerationResources()
    res.schema_version = 1
    for sid, snap_hash in mappings:
        e = res.entries.add()
        e.server_id = sid
        e.snapshot_hash = snap_hash
    return res


class TestServerHistoryRoundTrip:
    def test_empty_round_trip(self) -> None:
        h = make_server_history()
        data = h.SerializeToString()
        h2 = ServerHistory()
        h2.ParseFromString(data)
        assert h2.schema_version == 1
        assert len(h2.servers) == 0

    def test_with_one_entry_round_trip(self) -> None:
        h = make_server_history()
        e = h.servers.add()
        e.server_id = "tranquility"
        s = e.snapshots.add()
        s.snapshot_hash = "aa" * 32
        s.generation_hash = "bb" * 32
        s.timestamp = "2026-06-14T12:00:00Z"
        s.game_build = "1.0.0"
        s.game_version = "v1.0.0"

        data = h.SerializeToString()
        h2 = ServerHistory()
        h2.ParseFromString(data)
        assert h2.schema_version == 1
        assert len(h2.servers) == 1
        assert h2.servers[0].server_id == "tranquility"
        assert len(h2.servers[0].snapshots) == 1
        assert h2.servers[0].snapshots[0].snapshot_hash == "aa" * 32
        assert h2.servers[0].snapshots[0].generation_hash == "bb" * 32
        assert h2.servers[0].snapshots[0].timestamp == "2026-06-14T12:00:00Z"
        assert h2.servers[0].snapshots[0].game_build == "1.0.0"
        assert h2.servers[0].snapshots[0].game_version == "v1.0.0"


class TestMergeGenerationIntoHistory:
    def test_from_empty_creates_one_snapshot(self) -> None:
        history = make_server_history()
        resources = _generation_resources(("tranquility", "aa" * 32))
        server_index = _server_index(
            ("tranquility", "1.0.0", "v1.0.0"),
        )

        result = merge_generation_into_history(
            history,
            generation_hash="gen001",
            timestamp="2026-06-14T12:00:00Z",
            resources=resources,
            server_index=server_index,
        )

        assert len(result.servers) == 1
        assert result.servers[0].server_id == "tranquility"
        assert len(result.servers[0].snapshots) == 1
        snap = result.servers[0].snapshots[0]
        assert snap.snapshot_hash == "aa" * 32
        assert snap.generation_hash == "gen001"
        assert snap.timestamp == "2026-06-14T12:00:00Z"
        assert snap.game_build == "1.0.0"
        assert snap.game_version == "v1.0.0"

    def test_merge_same_snapshot_is_noop(self) -> None:
        history = make_server_history()
        resources = _generation_resources(("tranquility", "aa" * 32))
        server_index = _server_index(("tranquility", "1.0.0", "v1.0.0"))

        result1 = merge_generation_into_history(
            history,
            generation_hash="gen001",
            timestamp="2026-06-14T12:00:00Z",
            resources=resources,
            server_index=server_index,
        )

        result2 = merge_generation_into_history(
            result1,
            generation_hash="gen002",
            timestamp="2026-06-15T12:00:00Z",
            resources=resources,
            server_index=server_index,
        )

        assert len(result2.servers) == 1
        assert len(result2.servers[0].snapshots) == 1
        assert result2.servers[0].snapshots[0].snapshot_hash == "aa" * 32
        assert result2.servers[0].snapshots[0].generation_hash == "gen001"

    def test_merge_changed_snapshot_prepends(self) -> None:
        history = make_server_history()
        resources1 = _generation_resources(("tranquility", "aa" * 32))
        server_index = _server_index(("tranquility", "1.0.0", "v1.0.0"))

        result1 = merge_generation_into_history(
            history,
            generation_hash="gen001",
            timestamp="2026-06-14T12:00:00Z",
            resources=resources1,
            server_index=server_index,
        )

        resources2 = _generation_resources(("tranquility", "bb" * 32))
        result2 = merge_generation_into_history(
            result1,
            generation_hash="gen002",
            timestamp="2026-06-15T12:00:00Z",
            resources=resources2,
            server_index=server_index,
        )

        assert len(result2.servers) == 1
        snaps = result2.servers[0].snapshots
        assert len(snaps) == 2
        assert snaps[0].snapshot_hash == "bb" * 32
        assert snaps[0].generation_hash == "gen002"
        assert snaps[0].timestamp == "2026-06-15T12:00:00Z"
        assert snaps[1].snapshot_hash == "aa" * 32
        assert snaps[1].generation_hash == "gen001"
        assert snaps[1].timestamp == "2026-06-14T12:00:00Z"

    def test_server_absent_carried_forward(self) -> None:
        history = make_server_history()
        resources1 = _generation_resources(("tranquility", "aa" * 32))
        server_index = _server_index(
            ("tranquility", "1.0.0", "v1.0.0"),
            ("serenity", "2.0.0", "v2.0.0"),
        )

        result1 = merge_generation_into_history(
            history,
            generation_hash="gen001",
            timestamp="2026-06-14T12:00:00Z",
            resources=resources1,
            server_index=server_index,
        )

        resources2 = _generation_resources(("serenity", "bb" * 32))
        result2 = merge_generation_into_history(
            result1,
            generation_hash="gen002",
            timestamp="2026-06-15T12:00:00Z",
            resources=resources2,
            server_index=server_index,
        )

        assert len(result2.servers) == 2
        found = {e.server_id: e for e in result2.servers}
        assert len(found["tranquility"].snapshots) == 1
        assert found["tranquility"].snapshots[0].snapshot_hash == "aa" * 32
        assert len(found["serenity"].snapshots) == 1
        assert found["serenity"].snapshots[0].snapshot_hash == "bb" * 32

    def test_game_build_version_from_server_index(self) -> None:
        history = make_server_history()
        resources = _generation_resources(("tranquility", "aa" * 32))
        server_index = _server_index(
            ("tranquility", "1.5.0", "v2026.1"),
        )

        result = merge_generation_into_history(
            history,
            generation_hash="gen001",
            timestamp="2026-06-14T12:00:00Z",
            resources=resources,
            server_index=server_index,
        )

        snap = result.servers[0].snapshots[0]
        assert snap.game_build == "1.5.0"
        assert snap.game_version == "v2026.1"

    def test_original_history_not_mutated(self) -> None:
        history = make_server_history()
        resources = _generation_resources(("tranquility", "aa" * 32))
        server_index = _server_index(("tranquility", "1.0.0", "v1.0.0"))

        merge_generation_into_history(
            history,
            generation_hash="gen001",
            timestamp="2026-06-14T12:00:00Z",
            resources=resources,
            server_index=server_index,
        )

        assert len(history.servers) == 0

    def test_multi_server_merge(self) -> None:
        history = make_server_history()
        res1 = _generation_resources(
            ("tranquility", "aa" * 32),
            ("serenity", "bb" * 32),
        )
        si = _server_index(
            ("tranquility", "1.0.0", "v1.0.0"),
            ("serenity", "1.0.0", "v1.0.0"),
        )
        result1 = merge_generation_into_history(
            history,
            generation_hash="gen001",
            timestamp="2026-06-14T12:00:00Z",
            resources=res1,
            server_index=si,
        )
        assert len(result1.servers) == 2
        assert len(result1.servers[0].snapshots) == 1
        assert len(result1.servers[1].snapshots) == 1

        res2 = _generation_resources(("serenity", "cc" * 32))
        result2 = merge_generation_into_history(
            result1,
            generation_hash="gen002",
            timestamp="2026-06-15T12:00:00Z",
            resources=res2,
            server_index=si,
        )
        # tranquility unchanged, serenity gets prepended
        found = {e.server_id: e for e in result2.servers}
        assert len(found["tranquility"].snapshots) == 1
        assert found["tranquility"].snapshots[0].snapshot_hash == "aa" * 32
        assert len(found["serenity"].snapshots) == 2
        assert found["serenity"].snapshots[0].snapshot_hash == "cc" * 32
        assert found["serenity"].snapshots[1].snapshot_hash == "bb" * 32
