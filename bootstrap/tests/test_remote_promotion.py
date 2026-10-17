"""Tests for the stable-channel promotion path (snap.plan.md §3).

Covers ``SessionManager.promote`` semantics, suppression list management,
eligibility computation for ``ci release-data promote``, the
``remote promote`` CLI family, and the GC retention invariant for promoted
history snapshots.
"""

from __future__ import annotations

import datetime
import shutil
import tempfile

from pathlib import Path

import click
import click.testing
import pytest

from bootstrap.cli import register_all_commands
from bootstrap.remote import SessionManager
from bootstrap.remote.blob import BlobStore
from bootstrap.remote.gc import GarbageCollector
from bootstrap.remote.generation import GenerationStore
from bootstrap.remote.hash import content_hash
from bootstrap.remote.hash import ident_hash
from bootstrap.remote.models import GenerationMetadata
from bootstrap.remote.models import GenerationPointer
from bootstrap.remote.models import GenerationResources
from bootstrap.remote.models import ResourceSnapshotMetadata
from bootstrap.remote.models import ServerHistory
from bootstrap.remote.models import ServerIndex
from bootstrap.remote.models import SuppressionEntry
from bootstrap.remote.models import SuppressionList
from bootstrap.remote.models import make_resource_index
from bootstrap.remote.models import read_pb2
from bootstrap.remote.paths import channel_head_dir
from bootstrap.remote.paths import generation_dir
from bootstrap.remote.paths import head_suppressions_path
from bootstrap.remote.paths import resource_snapshot_dir
from bootstrap.remote.promote import PromotionError
from bootstrap.remote.promote import compute_promotion_eligibility
from bootstrap.remote.snapshot import SnapshotStore
from bootstrap.remote.sync import SyncResult


@pytest.fixture
def tmp_root() -> Path:
    d = tempfile.mkdtemp(prefix="efa-promote-")
    yield Path(d)
    shutil.rmtree(d, ignore_errors=True)


def _make_resource_snapshot(
    snap_store: SnapshotStore,
    blob_store: BlobStore,
    server_id: str,
    tag: str,
) -> str:
    rid = f"resource://{server_id}/{tag}.bin"
    ihash = ident_hash(rid)
    data = f"blob-{server_id}-{tag}".encode()
    chash = content_hash(data)
    meta = ResourceSnapshotMetadata(
        serverId=server_id,
        gameBuild=f"build-{tag}",
        gameVersion=f"v{tag}",
        resourceCount=1,
        createdAt="2026-06-14T12:00:00Z",
        description=tag,
    )
    index = make_resource_index([(rid, chash, len(data))])
    snap_hash = snap_store.create_resource_snapshot(meta, index)
    blob_store.store(data, ihash)
    return snap_hash


def _create_generation(
    gen_store: GenerationStore,
    entries: dict[str, str],
    parent: str | None,
    ts: str,
    *,
    channel: str = "testing",
    release_hash: str = "",
    builds: dict[str, str] | None = None,
) -> str:
    gen_meta = GenerationMetadata(channel=channel, timestamp=ts, parent=parent)

    server_index = ServerIndex()
    server_index.schema_version = 1
    for server_id in entries:
        srv = server_index.servers.add()
        srv.server_id = server_id
        srv.game_build = (builds or {}).get(server_id, "1.0.0")
        srv.game_version = "v1.0.0"

    resources = GenerationResources()
    resources.schema_version = 1
    for server_id, snap_hash in entries.items():
        r = resources.entries.add()
        r.server_id = server_id
        r.snapshot_hash = snap_hash

    release_ptr = GenerationPointer()
    release_ptr.schema_version = 1
    release_ptr.snapshot_hash = release_hash

    return gen_store.create(
        metadata=gen_meta,
        server_index_msg=server_index,
        resources_msg=resources,
        release_pointer=release_ptr,
    )


def _load_history(root: Path, gen_hash: str) -> ServerHistory:
    return read_pb2(generation_dir(root, gen_hash) / "history.pb2", ServerHistory)


def _history_map(history: ServerHistory) -> dict[str, list[tuple[str, str]]]:
    """{server_id: [(snapshot_hash, timestamp), ...]} newest first."""
    return {
        entry.server_id: [(s.snapshot_hash, s.timestamp) for s in entry.snapshots]
        for entry in history.servers
    }


class _Fixture:
    """A schema root with a testing channel carrying two servers."""

    def __init__(self, root: Path) -> None:
        self.mgr = SessionManager(root)
        self.root = root
        self.snap_store = SnapshotStore(root)
        self.blob_store = BlobStore(root)
        self.gen_store = GenerationStore(root)
        self.mgr.ensure_channel("testing")
        self.mgr.ensure_channel("stable")

        self.snap_a1 = _make_resource_snapshot(self.snap_store, self.blob_store, "alpha", "a1")
        self.snap_b1 = _make_resource_snapshot(self.snap_store, self.blob_store, "beta", "b1")
        self.gen_t1 = _create_generation(
            self.gen_store,
            {"alpha": self.snap_a1, "beta": self.snap_b1},
            None,
            "2026-06-01T00:00:00Z",
        )
        self.mgr.push("testing", self.gen_t1)

        self.snap_a2 = _make_resource_snapshot(self.snap_store, self.blob_store, "alpha", "a2")
        self.gen_t2 = _create_generation(
            self.gen_store,
            {"alpha": self.snap_a2, "beta": self.snap_b1},
            self.gen_t1,
            "2026-06-02T00:00:00Z",
        )
        self.mgr.push("testing", self.gen_t2)


@pytest.fixture
def fixture(tmp_root: Path) -> _Fixture:
    return _Fixture(tmp_root)


class TestPromoteCore:
    def test_bootstrap_promotion_requires_flag(self, fixture: _Fixture) -> None:
        with pytest.raises(PromotionError, match="allow_missing_head"):
            fixture.mgr.promote(
                candidates={"alpha": fixture.snap_a2},
                actor="tester",
            )

    def test_bootstrap_promotion(self, fixture: _Fixture) -> None:
        result = fixture.mgr.promote(
            candidates={"alpha": fixture.snap_a2, "beta": fixture.snap_b1},
            actor="tester",
            allow_missing_head=True,
        )

        assert not result.noop
        assert result.admitted == {"alpha": fixture.snap_a2, "beta": fixture.snap_b1}

        head = fixture.mgr.get_head("stable")
        assert head.generation_hash == result.generation_hash

        gen = fixture.mgr.load_generation(result.generation_hash)
        assert gen.metadata.parent is None
        assert gen.metadata.channel == "stable"
        assert not gen.release_pointer.snapshot_hash
        assert {e.server_id: e.snapshot_hash for e in gen.resources.entries} == result.admitted
        assert f"promote {fixture.gen_t2}" in gen.metadata.subject
        assert "actor=tester" in gen.metadata.subject

        history = _history_map(_load_history(fixture.root, result.generation_hash))
        assert [h for h, _ in history["alpha"]] == [fixture.snap_a2]
        assert [h for h, _ in history["beta"]] == [fixture.snap_b1]
        assert history["alpha"][0][1] == gen.metadata.timestamp

    def test_selective_promotion_overlays(self, fixture: _Fixture) -> None:
        first = fixture.mgr.promote(
            candidates={"alpha": fixture.snap_a2},
            actor="tester",
            allow_missing_head=True,
        )
        # Advance testing so beta has a new snapshot not yet on stable.
        snap_b2 = _make_resource_snapshot(fixture.snap_store, fixture.blob_store, "beta", "b2")
        gen_t3 = _create_generation(
            fixture.gen_store,
            {"alpha": fixture.snap_a2, "beta": snap_b2},
            fixture.gen_t2,
            "2026-06-03T00:00:00Z",
        )
        fixture.mgr.push("testing", gen_t3)

        second = fixture.mgr.promote(candidates={"beta": snap_b2}, actor="tester")

        gen = fixture.mgr.load_generation(second.generation_hash)
        assert gen.metadata.parent == first.generation_hash
        # Resources overlay: alpha unchanged from the stable parent, beta admitted.
        assert {e.server_id: e.snapshot_hash for e in gen.resources.entries} == {
            "alpha": fixture.snap_a2,
            "beta": snap_b2,
        }
        # ServerIndex: admitted server entry rebuilt from its snapshot metadata.
        index = {e.server_id: e.game_build for e in gen.server_index.servers}
        assert index["beta"] == "build-b2"
        assert index["alpha"] == "build-a2"
        # History: alpha gained no entry; beta prepended the admitted snapshot.
        history = _history_map(_load_history(fixture.root, second.generation_hash))
        assert [h for h, _ in history["alpha"]] == [fixture.snap_a2]
        assert [h for h, _ in history["beta"]] == [snap_b2, fixture.snap_b1] or [
            h for h, _ in history["beta"]
        ] == [snap_b2]

    def test_explicit_historical_checkout(self, fixture: _Fixture) -> None:
        result = fixture.mgr.promote(
            candidates={"alpha": fixture.snap_a1},
            actor="tester",
            allow_missing_head=True,
        )
        assert result.admitted == {"alpha": fixture.snap_a1}

    def test_historical_checkout_index_matches_admitted_snapshot(self, fixture: _Fixture) -> None:
        result = fixture.mgr.promote(
            candidates={"alpha": fixture.snap_a1},
            actor="tester",
            allow_missing_head=True,
        )

        gen = fixture.mgr.load_generation(result.generation_hash)
        index = {e.server_id: e for e in gen.server_index.servers}
        assert index["alpha"].game_build == "build-a1"
        assert index["alpha"].game_version == "va1"

    def test_history_only_server_gets_index_entry(self, fixture: _Fixture) -> None:
        snap_g1 = _make_resource_snapshot(fixture.snap_store, fixture.blob_store, "gamma", "g1")
        gen_t3 = _create_generation(
            fixture.gen_store,
            {"alpha": fixture.snap_a2, "beta": fixture.snap_b1, "gamma": snap_g1},
            fixture.gen_t2,
            "2026-06-03T00:00:00Z",
        )
        fixture.mgr.push("testing", gen_t3)
        # Advance testing head so gamma survives only in history.
        gen_t4 = _create_generation(
            fixture.gen_store,
            {"alpha": fixture.snap_a2, "beta": fixture.snap_b1},
            gen_t3,
            "2026-06-04T00:00:00Z",
        )
        fixture.mgr.push("testing", gen_t4)

        result = fixture.mgr.promote(
            candidates={"gamma": snap_g1},
            actor="tester",
            allow_missing_head=True,
        )

        gen = fixture.mgr.load_generation(result.generation_hash)
        assert {e.server_id: e.snapshot_hash for e in gen.resources.entries} == {"gamma": snap_g1}
        index = {e.server_id: e for e in gen.server_index.servers}
        assert index["gamma"].game_build == "build-g1"
        assert index["gamma"].game_version == "vg1"

    def test_unknown_checkout_rejected(self, fixture: _Fixture) -> None:
        with pytest.raises(PromotionError, match="Unknown candidate"):
            fixture.mgr.promote(
                candidates={"alpha": "0" * 64},
                actor="tester",
                allow_missing_head=True,
            )

    def test_unknown_server_rejected(self, fixture: _Fixture) -> None:
        with pytest.raises(PromotionError, match="Unknown candidate"):
            fixture.mgr.promote(
                candidates={"gamma": fixture.snap_a2},
                actor="tester",
                allow_missing_head=True,
            )

    def test_idempotent_rerun(self, fixture: _Fixture) -> None:
        first = fixture.mgr.promote(
            candidates={"alpha": fixture.snap_a2},
            actor="tester",
            allow_missing_head=True,
        )
        refs_before = {d.name for d in (fixture.root / "channels" / "refs").iterdir()}

        second = fixture.mgr.promote(
            candidates={"alpha": fixture.snap_a2},
            actor="tester",
        )
        assert second.noop
        assert second.skipped_idempotent == {"alpha": fixture.snap_a2}
        assert fixture.mgr.get_head("stable").generation_hash == first.generation_hash
        refs_after = {d.name for d in (fixture.root / "channels" / "refs").iterdir()}
        assert refs_before == refs_after

    def test_suppression_vetoes_and_force_overrides(self, fixture: _Fixture) -> None:
        fixture.mgr.save_suppressions(
            "stable",
            SuppressionList(
                suppressions=[
                    SuppressionEntry(
                        server="alpha",
                        checkout=fixture.snap_a2,
                        reason="bad bundle",
                        suppressedAt="2026-06-14T12:00:00Z",
                        actor="tester",
                    )
                ]
            ),
        )

        blocked = fixture.mgr.promote(
            candidates={"alpha": fixture.snap_a2, "beta": fixture.snap_b1},
            actor="tester",
            allow_missing_head=True,
        )
        assert blocked.admitted == {"beta": fixture.snap_b1}
        assert blocked.skipped_suppressed == {"alpha": fixture.snap_a2}

        forced = fixture.mgr.promote(
            candidates={"alpha": fixture.snap_a2},
            actor="tester",
            respect_suppressions=False,
        )
        assert forced.admitted == {"alpha": fixture.snap_a2}

    def test_release_pointer_inherited(self, fixture: _Fixture) -> None:
        # Simulate a release-only stable publish (bin.md): same resources, new
        # release pointer.
        bootstrap = fixture.mgr.promote(
            candidates={"alpha": fixture.snap_a2},
            actor="tester",
            allow_missing_head=True,
        )
        release_gen = _create_generation(
            fixture.gen_store,
            {"alpha": fixture.snap_a2},
            bootstrap.generation_hash,
            "2026-06-10T00:00:00Z",
            channel="stable",
            release_hash="f" * 64,
        )
        fixture.mgr.push("stable", release_gen)

        # Release-only publish adds no history entries.
        history = _history_map(_load_history(fixture.root, release_gen))
        assert [h for h, _ in history["alpha"]] == [fixture.snap_a2]

        # A later data promotion inherits the release pointer unchanged.
        snap_a3 = _make_resource_snapshot(fixture.snap_store, fixture.blob_store, "alpha", "a3")
        gen_t3 = _create_generation(
            fixture.gen_store,
            {"alpha": snap_a3, "beta": fixture.snap_b1},
            fixture.gen_t2,
            "2026-06-11T00:00:00Z",
        )
        fixture.mgr.push("testing", gen_t3)

        promoted = fixture.mgr.promote(candidates={"alpha": snap_a3}, actor="tester")
        gen = fixture.mgr.load_generation(promoted.generation_hash)
        assert gen.metadata.parent == release_gen
        assert gen.release_pointer.snapshot_hash == "f" * 64

    def test_history_is_exactly_the_admitted_sequence(self, fixture: _Fixture) -> None:
        first = fixture.mgr.promote(
            candidates={"alpha": fixture.snap_a1},
            actor="tester",
            allow_missing_head=True,
        )
        second = fixture.mgr.promote(candidates={"alpha": fixture.snap_a2}, actor="tester")

        history = _history_map(_load_history(fixture.root, second.generation_hash))
        entries = history["alpha"]
        assert [h for h, _ in entries] == [fixture.snap_a2, fixture.snap_a1]
        first_gen = fixture.mgr.load_generation(first.generation_hash)
        second_gen = fixture.mgr.load_generation(second.generation_hash)
        assert entries[0][1] == second_gen.metadata.timestamp
        assert entries[1][1] == first_gen.metadata.timestamp

    def test_gc_retains_advertised_history_snapshots(self, fixture: _Fixture) -> None:
        fixture.mgr.promote(
            candidates={"alpha": fixture.snap_a1},
            actor="tester",
            allow_missing_head=True,
        )
        fixture.mgr.promote(candidates={"alpha": fixture.snap_a2}, actor="tester")

        GarbageCollector(fixture.root).prune()

        assert resource_snapshot_dir(fixture.root, fixture.snap_a1).is_dir()
        assert resource_snapshot_dir(fixture.root, fixture.snap_a2).is_dir()


class TestEligibility:
    def _now(self) -> datetime.datetime:
        return datetime.datetime(2026, 6, 15, 12, 0, 0, tzinfo=datetime.UTC)

    def test_boundary_and_quiet_period(self, fixture: _Fixture) -> None:
        """Eligible iff publish timestamp <= now - 24h; boundary-inclusive."""
        now = self._now()
        gen = fixture.gen_store.load(fixture.gen_t2)
        history = _load_history(fixture.root, fixture.gen_t2)

        # gen_t2 alpha entry: 2026-06-02 → eligible; beta's newest entry is
        # 2026-06-01 (gen_t1) → also eligible at this clock.
        eligible = compute_promotion_eligibility(history, gen.resources, now)
        assert eligible == {"alpha": fixture.snap_a2, "beta": fixture.snap_b1}

        # Within the soak window → quiet period.
        recent_now = datetime.datetime(2026, 6, 2, 12, 0, 0, tzinfo=datetime.UTC)
        eligible = compute_promotion_eligibility(history, gen.resources, recent_now)
        assert "alpha" not in eligible
        assert eligible == {"beta": fixture.snap_b1}

        boundary = datetime.datetime(2026, 6, 3, 0, 0, 0, tzinfo=datetime.UTC)
        eligible = compute_promotion_eligibility(history, gen.resources, boundary)
        assert eligible["alpha"] == fixture.snap_a2


class TestSuppressionStore:
    def test_round_trip(self, tmp_root: Path) -> None:
        mgr = SessionManager(tmp_root)
        mgr.ensure_channel("stable")

        assert mgr.get_suppressions("stable").suppressions == []

        entries = SuppressionList(
            suppressions=[
                SuppressionEntry(
                    server="alpha",
                    checkout="a" * 64,
                    reason="",
                    suppressedAt="2026-06-14T12:00:00Z",
                    actor="tester",
                )
            ]
        )
        mgr.save_suppressions("stable", entries)
        loaded = mgr.get_suppressions("stable")
        assert len(loaded.suppressions) == 1
        assert loaded.suppressions[0].server == "alpha"
        assert loaded.suppressions[0].checkout == "a" * 64


def _make_cli() -> click.Group:
    @click.group()
    def cli() -> None:
        pass

    register_all_commands(cli)
    return cli


def _invoke(root: Path, *args: str) -> click.testing.Result:
    runner = click.testing.CliRunner()
    return runner.invoke(_make_cli(), [*args, "--schema-root", str(root)])


class TestPromoteCli:
    def test_promote_all_test_mode(self, fixture: _Fixture) -> None:
        result = _invoke(
            fixture.root, "remote", "promote", "--all", "--test-mode", "--allow-missing-head"
        )
        assert result.exit_code == 0, result.output
        assert "Promoted generation:" in result.output

        head = fixture.mgr.get_head("stable")
        gen = fixture.mgr.load_generation(head.generation_hash)
        assert {e.server_id: e.snapshot_hash for e in gen.resources.entries} == {
            "alpha": fixture.snap_a2,
            "beta": fixture.snap_b1,
        }

        second = _invoke(fixture.root, "remote", "promote", "--all", "--test-mode")
        assert second.exit_code == 0, second.output
        assert "Nothing to promote" in second.output
        assert fixture.mgr.get_head("stable").generation_hash == head.generation_hash

    def test_promote_requires_selection(self, fixture: _Fixture) -> None:
        result = _invoke(fixture.root, "remote", "promote", "--test-mode")
        assert result.exit_code != 0
        assert "Pass --server/--all or --checkout" in result.output

    def test_promote_server_and_checkout(self, fixture: _Fixture) -> None:
        result = _invoke(
            fixture.root,
            "remote",
            "promote",
            "--checkout",
            f"alpha:{fixture.snap_a1}",
            "--server",
            "beta",
            "--test-mode",
            "--allow-missing-head",
        )
        assert result.exit_code == 0, result.output
        gen = fixture.mgr.load_generation(fixture.mgr.get_head("stable").generation_hash)
        assert {e.server_id: e.snapshot_hash for e in gen.resources.entries} == {
            "alpha": fixture.snap_a1,
            "beta": fixture.snap_b1,
        }

    def test_promote_unknown_server(self, fixture: _Fixture) -> None:
        result = _invoke(fixture.root, "remote", "promote", "--server", "gamma", "--test-mode")
        assert result.exit_code != 0
        assert "Unknown server" in result.output

    def test_dry_run_writes_nothing(self, fixture: _Fixture) -> None:
        result = _invoke(fixture.root, "remote", "promote", "--all", "--dry-run")
        assert result.exit_code == 0, result.output
        assert "admit" in result.output
        assert "Dry run" in result.output
        assert fixture.mgr.get_head("stable").generation_hash == ""

    def test_actor_recorded(self, fixture: _Fixture) -> None:
        result = _invoke(
            fixture.root,
            "remote",
            "promote",
            "--server",
            "alpha",
            "--actor",
            "release-bot",
            "--test-mode",
            "--allow-missing-head",
        )
        assert result.exit_code == 0, result.output
        gen = fixture.mgr.load_generation(fixture.mgr.get_head("stable").generation_hash)
        assert "actor=release-bot" in gen.metadata.subject

    def test_suppress_unsuppress_cycle(self, fixture: _Fixture) -> None:
        pair = f"alpha:{fixture.snap_a2}"
        result = _invoke(
            fixture.root, "remote", "promote", "suppress", pair, "--reason", "bad", "--test-mode"
        )
        assert result.exit_code == 0, result.output

        listed = _invoke(fixture.root, "remote", "promote", "suppressions")
        assert listed.exit_code == 0
        assert "alpha" in listed.output
        assert "bad" in listed.output

        suppressed = fixture.mgr.get_suppressions("stable")
        assert [(e.server, e.checkout, e.reason) for e in suppressed.suppressions] == [
            ("alpha", fixture.snap_a2, "bad")
        ]

        # Suppressed pair is skipped; --force overrides.
        blocked = _invoke(
            fixture.root, "remote", "promote", "--all", "--test-mode", "--allow-missing-head"
        )
        assert blocked.exit_code == 0, blocked.output
        assert "skip (suppressed)  alpha" in blocked.output

        forced = _invoke(fixture.root, "remote", "promote", "--all", "--force", "--test-mode")
        assert forced.exit_code == 0, forced.output
        assert "admit              alpha" in forced.output

        removed = _invoke(fixture.root, "remote", "promote", "unsuppress", pair, "--test-mode")
        assert removed.exit_code == 0, removed.output
        assert fixture.mgr.get_suppressions("stable").suppressions == []

        again = _invoke(fixture.root, "remote", "promote", "unsuppress", pair, "--test-mode")
        assert again.exit_code != 0
        assert "Not suppressed" in again.output

    def test_suppress_warns_when_already_promoted(self, fixture: _Fixture) -> None:
        promoted = _invoke(
            fixture.root, "remote", "promote", "--all", "--test-mode", "--allow-missing-head"
        )
        assert promoted.exit_code == 0, promoted.output
        result = _invoke(
            fixture.root,
            "remote",
            "promote",
            "suppress",
            f"alpha:{fixture.snap_a2}",
            "--test-mode",
        )
        assert result.exit_code == 0, result.output
        assert "already promoted" in result.output

    def test_set_default_channel(self, fixture: _Fixture) -> None:
        result = _invoke(fixture.root, "remote", "set-default-channel", "stable", "--test-mode")
        assert result.exit_code == 0, result.output
        assert fixture.mgr.get_channels().default_channel == "stable"

        bad = _invoke(fixture.root, "remote", "set-default-channel", "nope", "--test-mode")
        assert bad.exit_code != 0


class TestCiPromoteCommand:
    def test_promotes_eligible_and_quiet_period(self, fixture: _Fixture) -> None:
        # All testing history entries are dated 2026-06-01/02 — far past the
        # 24h soak, so everything is eligible.
        result = _invoke(
            fixture.root, "ci", "release-data", "promote", "--test-mode", "--allow-missing-head"
        )
        assert result.exit_code == 0, result.output
        assert "Promoted alpha" in result.output
        assert "Promoted beta" in result.output

        # Second run: stable head == testing head → nothing to admit.
        second = _invoke(fixture.root, "ci", "release-data", "promote", "--test-mode")
        assert second.exit_code == 0, second.output
        assert "quiet period" in second.output

    def test_suppressed_candidate_skipped(self, fixture: _Fixture) -> None:
        fixture.mgr.save_suppressions(
            "stable",
            SuppressionList(
                suppressions=[
                    SuppressionEntry(
                        server="alpha",
                        checkout=fixture.snap_a2,
                        suppressedAt="2026-06-14T12:00:00Z",
                    )
                ]
            ),
        )
        result = _invoke(
            fixture.root, "ci", "release-data", "promote", "--test-mode", "--allow-missing-head"
        )
        assert result.exit_code == 0, result.output
        assert "Suppressed alpha" in result.output

        gen = fixture.mgr.load_generation(fixture.mgr.get_head("stable").generation_hash)
        assert {e.server_id: e.snapshot_hash for e in gen.resources.entries} == {
            "beta": fixture.snap_b1
        }

    def test_missing_testing_head_fails(self, tmp_root: Path) -> None:
        SessionManager(tmp_root).ensure_channel("stable")
        result = _invoke(tmp_root, "ci", "release-data", "promote", "--test-mode")
        assert result.exit_code != 0
        assert "remote sync" in result.output


class TestVerifySuppressions:
    def test_unknown_suppressed_checkout_warns(self, fixture: _Fixture) -> None:
        fixture.mgr.promote(
            candidates={"alpha": fixture.snap_a2},
            actor="tester",
            allow_missing_head=True,
        )
        fixture.mgr.save_suppressions(
            "stable",
            SuppressionList(
                suppressions=[
                    SuppressionEntry(
                        server="alpha",
                        checkout=fixture.snap_a2,
                        suppressedAt="2026-06-14T12:00:00Z",
                    ),
                    SuppressionEntry(
                        server="alpha",
                        checkout="b" * 64,
                        suppressedAt="2026-06-14T12:00:00Z",
                    ),
                ]
            ),
        )

        issues = fixture.mgr.verify()["suppressions"]
        assert len(issues) == 1
        assert issues[0].severity == "warning"
        assert "b" * 12 in issues[0].entity

    def test_preemptive_suppression_of_testing_checkout_ok(self, fixture: _Fixture) -> None:
        # Suppression vetoes a testing checkout before it reaches stable.
        fixture.mgr.save_suppressions(
            "stable",
            SuppressionList(
                suppressions=[
                    SuppressionEntry(
                        server="alpha",
                        checkout=fixture.snap_a2,
                        suppressedAt="2026-06-14T12:00:00Z",
                    ),
                    SuppressionEntry(
                        server="alpha",
                        checkout=fixture.snap_a1,
                        suppressedAt="2026-06-14T12:00:00Z",
                    ),
                ]
            ),
        )

        issues = fixture.mgr.verify()["suppressions"]
        assert issues == []


class _FakePublisher:
    """Publisher stand-in: copies uploads into a remote-mirror directory."""

    def __init__(self, local_root: Path, remote_root: Path) -> None:
        self.local_root = local_root
        self.remote_root = remote_root
        self.calls: list[str] = []

    def publish_generation(self, channel: str, gen_hash: str) -> None:
        self.calls.append("generation")
        shutil.copytree(
            generation_dir(self.local_root, gen_hash),
            generation_dir(self.remote_root, gen_hash),
            dirs_exist_ok=True,
        )

    def publish_head(self, channel: str) -> None:
        self.calls.append("head")
        shutil.copytree(
            channel_head_dir(self.local_root, channel),
            channel_head_dir(self.remote_root, channel),
            dirs_exist_ok=True,
        )

    def publish_suppressions(self, channel: str) -> None:
        self.calls.append("suppressions")
        src = head_suppressions_path(self.local_root, channel)
        dst = head_suppressions_path(self.remote_root, channel)
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)


class _FakeSyncer:
    """Syncer stand-in: downloads head files from a remote-mirror directory."""

    def __init__(self, local_root: Path, remote_root: Path) -> None:
        self.local_root = local_root
        self.remote_root = remote_root

    def sync_head(self, channel: str) -> SyncResult:
        result = SyncResult(channel=channel)
        src_dir = channel_head_dir(self.remote_root, channel)
        if not (src_dir / "metadata.json").is_file():
            return result
        result.head_meta = True
        dst_dir = channel_head_dir(self.local_root, channel)
        dst_dir.mkdir(parents=True, exist_ok=True)
        for name in ("metadata.json", "reflog.pb2", "suppressions.json"):
            src = src_dir / name
            if src.is_file():
                shutil.copy2(src, dst_dir / name)
        return result

    def sync_channel(self, channel: str, *, max_depth: int = -1) -> SyncResult:
        result = self.sync_head(channel)
        if result.head_meta:
            gen_hash = SessionManager(self.local_root).get_head(channel).generation_hash
            src = generation_dir(self.remote_root, gen_hash)
            if src.is_dir():
                shutil.copytree(src, generation_dir(self.local_root, gen_hash), dirs_exist_ok=True)
        return result


def _patch_fake_remote(monkeypatch: pytest.MonkeyPatch, remote_root: Path) -> list[_FakePublisher]:
    monkeypatch.setattr(
        "bootstrap.cli.remote.promotion._resolve_remote_target",
        lambda *args: ("https://s3.invalid", "bucket", "key", "secret", "alias"),
    )
    monkeypatch.setattr(
        SessionManager,
        "make_syncer",
        lambda self, **kwargs: _FakeSyncer(self.root, remote_root),
    )
    publishers: list[_FakePublisher] = []

    def _make_publisher(self, **kwargs) -> _FakePublisher:
        pub = _FakePublisher(self.root, remote_root)
        publishers.append(pub)
        return pub

    monkeypatch.setattr(SessionManager, "make_publisher", _make_publisher)
    return publishers


class TestPromoteCliRemoteGuard:
    """Manual promote/suppress must never overwrite a newer remote stable head."""

    def test_promote_publishes_over_matching_head(
        self, fixture: _Fixture, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        remote_root = tmp_path / "remote"
        publishers = _patch_fake_remote(monkeypatch, remote_root)

        result = _invoke(fixture.root, "remote", "promote", "--all", "--allow-missing-head")
        assert result.exit_code == 0, result.output
        assert "Remote head verified" in result.output
        assert publishers[-1].calls == ["generation", "head"]
        remote_mgr = SessionManager(remote_root)
        assert (
            remote_mgr.get_head("stable").generation_hash
            == fixture.mgr.get_head("stable").generation_hash
        )

    def test_promote_refuses_when_remote_head_moved(
        self, fixture: _Fixture, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        remote_root = tmp_path / "remote"
        _patch_fake_remote(monkeypatch, remote_root)
        first = _invoke(fixture.root, "remote", "promote", "--all", "--allow-missing-head")
        assert first.exit_code == 0, first.output
        stale_head = fixture.mgr.get_head("stable").generation_hash

        # The hourly workflow advances the remote stable head past the local cache.
        snap_b2 = _make_resource_snapshot(fixture.snap_store, fixture.blob_store, "beta", "b2")
        gen_t3 = _create_generation(
            fixture.gen_store,
            {"alpha": fixture.snap_a2, "beta": snap_b2},
            fixture.gen_t2,
            "2026-06-03T00:00:00Z",
        )
        fixture.mgr.push("testing", gen_t3)
        moved = fixture.mgr.promote(candidates={"beta": snap_b2}, actor="workflow")
        publisher = _FakePublisher(fixture.root, remote_root)
        publisher.publish_generation("stable", moved.generation_hash)
        publisher.publish_head("stable")
        fixture.mgr.revert("stable", stale_head)

        result = _invoke(fixture.root, "remote", "promote", "--all")
        assert result.exit_code != 0
        assert "stale" in result.output
        # The guard refreshed the local cache instead of mutating over it.
        assert fixture.mgr.get_head("stable").generation_hash == moved.generation_hash

    def test_suppress_uploads_only_suppressions_file(
        self, fixture: _Fixture, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        remote_root = tmp_path / "remote"
        publishers = _patch_fake_remote(monkeypatch, remote_root)
        first = _invoke(fixture.root, "remote", "promote", "--all", "--allow-missing-head")
        assert first.exit_code == 0, first.output

        pair = f"alpha:{fixture.snap_a2}"
        result = _invoke(fixture.root, "remote", "promote", "suppress", pair, "--reason", "bad")
        assert result.exit_code == 0, result.output
        assert publishers[-1].calls == ["suppressions"]

        remote_mgr = SessionManager(remote_root)
        remote_suppressions = remote_mgr.get_suppressions("stable")
        assert [(e.server, e.checkout) for e in remote_suppressions.suppressions] == [
            ("alpha", fixture.snap_a2)
        ]
        assert (
            remote_mgr.get_head("stable").generation_hash
            == fixture.mgr.get_head("stable").generation_hash
        )

    def test_unsuppress_uploads_only_suppressions_file(
        self, fixture: _Fixture, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        remote_root = tmp_path / "remote"
        publishers = _patch_fake_remote(monkeypatch, remote_root)
        first = _invoke(fixture.root, "remote", "promote", "--all", "--allow-missing-head")
        assert first.exit_code == 0, first.output
        pair = f"alpha:{fixture.snap_a2}"
        suppressed = _invoke(fixture.root, "remote", "promote", "suppress", pair)
        assert suppressed.exit_code == 0, suppressed.output

        result = _invoke(fixture.root, "remote", "promote", "unsuppress", pair)
        assert result.exit_code == 0, result.output
        assert publishers[-1].calls == ["suppressions"]
        assert SessionManager(remote_root).get_suppressions("stable").suppressions == []

    def test_suppress_refuses_when_remote_suppressions_drifted(
        self, fixture: _Fixture, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        remote_root = tmp_path / "remote"
        _patch_fake_remote(monkeypatch, remote_root)
        first = _invoke(fixture.root, "remote", "promote", "--all", "--allow-missing-head")
        assert first.exit_code == 0, first.output

        # Another operator adds a suppression directly against the remote state.
        remote_mgr = SessionManager(remote_root)
        remote_mgr.save_suppressions(
            "stable",
            SuppressionList(
                suppressions=[
                    SuppressionEntry(
                        server="beta",
                        checkout=fixture.snap_b1,
                        reason="other",
                        suppressedAt="2026-06-14T12:00:00Z",
                        actor="other-op",
                    )
                ]
            ),
        )

        result = _invoke(fixture.root, "remote", "promote", "suppress", f"alpha:{fixture.snap_a2}")
        assert result.exit_code != 0
        assert "stale" in result.output
        # The guard refreshed the local cache; the remote list was not clobbered.
        assert [e.server for e in fixture.mgr.get_suppressions("stable").suppressions] == ["beta"]
        assert [e.server for e in remote_mgr.get_suppressions("stable").suppressions] == ["beta"]
