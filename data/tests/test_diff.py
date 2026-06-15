from __future__ import annotations

import json
import tempfile

from pathlib import Path

import pytest

from data.lib.remote.diff import GenerationSnapshot
from data.lib.remote.diff import diff_generations
from data.lib.remote.diff import read_generation_from_remote
from data.lib.remote.diff import read_generation_from_staged


def _write_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


class TestReadGenerationFromStaged:
    def test_reads_servers_and_checkouts(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            staged = Path(tmpdir)
            gen_id = "gen-test"
            resources = staged / "manifest" / ".generations" / gen_id / "resources"

            _write_json(
                resources / "servers" / "serenity.json",
                {
                    "id": "serenity",
                    "checkouts": [
                        {"id": "aaa000"},
                        {"id": "bbb111"},
                    ],
                },
            )
            _write_json(
                resources / "servers" / "tranquility.json",
                {"id": "tranquility", "checkouts": [{"id": "ccc222"}]},
            )

            _write_json(
                resources / "checkouts" / "aaa000.json",
                {
                    "id": "aaa000",
                    "serverId": "serenity",
                    "files": {
                        "a.txt": {"pathHash": "p1", "hash": "h1", "size": 10},
                        "b.txt": {"pathHash": "p2", "hash": "h2", "size": 20},
                    },
                },
            )
            _write_json(
                resources / "checkouts" / "bbb111.json",
                {"id": "bbb111", "serverId": "serenity", "files": {}},
            )
            _write_json(
                resources / "checkouts" / "ccc222.json",
                {
                    "id": "ccc222",
                    "serverId": "tranquility",
                    "files": {
                        "c.txt": {"pathHash": "p3", "hash": "h3", "size": 30},
                    },
                },
            )

            snap = read_generation_from_staged(staged, gen_id)

            assert snap.gen_id == gen_id
            assert snap.servers == {
                "serenity": ["aaa000", "bbb111"],
                "tranquility": ["ccc222"],
            }
            assert snap.checkouts["aaa000"]["fileCount"] == 2
            assert snap.checkouts["aaa000"]["totalSize"] == 30
            assert snap.checkouts["bbb111"]["fileCount"] == 0
            assert snap.checkouts["ccc222"]["totalSize"] == 30

    def test_empty_staged(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            staged = Path(tmpdir)
            gen_id = "gen-empty"
            snap = read_generation_from_staged(staged, gen_id)
            assert snap.servers == {}
            assert snap.checkouts == {}


class TestReadGenerationFromRemote:
    def test_reads_activated_generation(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            remote_dir = Path(tmpdir)
            channel = "testing"
            gen_id = "gen-activated"

            ch = remote_dir / channel
            _write_json(
                ch / "manifest" / "index.json",
                {"manifestVersion": 1, "activatedGeneration": gen_id},
            )
            resources = ch / "manifest" / ".generations" / gen_id / "resources"
            _write_json(
                resources / "servers" / "serenity.json",
                {"id": "serenity", "checkouts": [{"id": "abc123"}]},
            )
            _write_json(
                resources / "checkouts" / "abc123.json",
                {"id": "abc123", "serverId": "serenity", "files": {}},
            )

            snap = read_generation_from_remote(remote_dir, channel)

            assert snap.gen_id == gen_id
            assert snap.servers == {"serenity": ["abc123"]}

    def test_reads_specific_generation(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            remote_dir = Path(tmpdir)
            channel = "testing"
            gen_id = "gen-specific"

            ch = remote_dir / channel
            resources = ch / "manifest" / ".generations" / gen_id / "resources"
            _write_json(
                resources / "servers" / "s.json",
                {"id": "s", "checkouts": []},
            )

            snap = read_generation_from_remote(remote_dir, channel, gen_id)
            assert snap.gen_id == gen_id

    def test_no_activated_generation_raises(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            remote_dir = Path(tmpdir)
            channel = "testing"

            ch = remote_dir / channel
            _write_json(
                ch / "manifest" / "index.json",
                {"manifestVersion": 1, "activatedGeneration": ""},
            )

            with pytest.raises(ValueError, match="activated generation"):
                read_generation_from_remote(remote_dir, channel)


class TestDiffGenerations:
    def test_empty_equal(self):
        pending = GenerationSnapshot(
            gen_id="g1", servers={}, checkouts={}, releases={}, announcements={}
        )
        baseline = GenerationSnapshot(
            gen_id="g0", servers={}, checkouts={}, releases={}, announcements={}
        )
        diff = diff_generations(pending, baseline)

        assert len(diff.servers) == 0
        assert diff.releases.added == []
        assert diff.announcements.added == []

    def test_server_added(self):
        pending = GenerationSnapshot(
            gen_id="g1", servers={"new-srv": []}, checkouts={}, releases={}, announcements={}
        )
        baseline = GenerationSnapshot(
            gen_id="g0", servers={}, checkouts={}, releases={}, announcements={}
        )
        diff = diff_generations(pending, baseline)

        assert len(diff.servers) == 1
        assert diff.servers[0].server_id == "new-srv"
        assert diff.servers[0].status == "added"

    def test_server_removed(self):
        pending = GenerationSnapshot(
            gen_id="g1", servers={}, checkouts={}, releases={}, announcements={}
        )
        baseline = GenerationSnapshot(
            gen_id="g0", servers={"old-srv": []}, checkouts={}, releases={}, announcements={}
        )
        diff = diff_generations(pending, baseline)

        assert len(diff.servers) == 1
        assert diff.servers[0].server_id == "old-srv"
        assert diff.servers[0].status == "removed"

    def test_server_unchanged(self):
        both_servers = {"srv": ["ck1"]}
        pending = GenerationSnapshot(
            gen_id="g1", servers=both_servers, checkouts={}, releases={}, announcements={}
        )
        baseline = GenerationSnapshot(
            gen_id="g0", servers=both_servers, checkouts={}, releases={}, announcements={}
        )
        diff = diff_generations(pending, baseline)

        assert len(diff.servers) == 1
        assert diff.servers[0].status == "unchanged"

    def test_server_checkouts_changed(self):
        pending = GenerationSnapshot(
            gen_id="g1",
            servers={"srv": ["ck1", "ck2"]},
            checkouts={
                "ck1": {"id": "ck1", "fileCount": 5, "totalSize": 100},
                "ck2": {"id": "ck2", "fileCount": 3, "totalSize": 50},
            },
            releases={},
            announcements={},
        )
        baseline = GenerationSnapshot(
            gen_id="g0",
            servers={"srv": ["ck1", "ck3"]},
            checkouts={
                "ck1": {"id": "ck1", "fileCount": 5, "totalSize": 100},
                "ck3": {"id": "ck3", "fileCount": 1, "totalSize": 10},
            },
            releases={},
            announcements={},
        )
        diff = diff_generations(pending, baseline)

        assert len(diff.servers) == 1
        assert diff.servers[0].status == "changed"
        assert diff.servers[0].checkout_changes is not None
        assert diff.servers[0].checkout_changes.added == ["ck2"]
        assert diff.servers[0].checkout_changes.removed == ["ck3"]
        assert diff.servers[0].checkout_changes.unchanged == ["ck1"]

    def test_release_added_and_removed(self):
        pending = GenerationSnapshot(
            gen_id="g1",
            servers={},
            checkouts={},
            releases={"rel-1": {"version": "1.0", "apk_hash": "abc"}},
            announcements={},
        )
        baseline = GenerationSnapshot(
            gen_id="g0",
            servers={},
            checkouts={},
            releases={"rel-0": {"version": "0.9", "apk_hash": "def"}},
            announcements={},
        )
        diff = diff_generations(pending, baseline)

        assert diff.releases.added == ["rel-1"]
        assert diff.releases.removed == ["rel-0"]
        assert diff.releases.unchanged == []
        assert diff.releases.changed == []

    def test_announcement_added_removed_changed(self):
        pending = GenerationSnapshot(
            gen_id="g1",
            servers={},
            checkouts={},
            releases={},
            announcements={"ann-1": "hash-a", "ann-2": "hash-b-v2"},
        )
        baseline = GenerationSnapshot(
            gen_id="g0",
            servers={},
            checkouts={},
            releases={},
            announcements={"ann-2": "hash-b-v1", "ann-3": "hash-c"},
        )
        diff = diff_generations(pending, baseline)

        assert diff.announcements.added == ["ann-1"]
        assert diff.announcements.removed == ["ann-3"]
        assert diff.announcements.unchanged == []
        assert diff.announcements.changed == ["ann-2"]

    def test_announcement_unchanged(self):
        both = {"ann-1": "hash-a"}
        pending = GenerationSnapshot(
            gen_id="g1", servers={}, checkouts={}, releases={}, announcements=both
        )
        baseline = GenerationSnapshot(
            gen_id="g0", servers={}, checkouts={}, releases={}, announcements=both
        )
        diff = diff_generations(pending, baseline)

        assert diff.announcements.unchanged == ["ann-1"]
        assert diff.announcements.changed == []
