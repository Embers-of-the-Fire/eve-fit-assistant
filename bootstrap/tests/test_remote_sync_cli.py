"""Tests for `remote sync` fail-loud behavior on missing channel heads.

A silent head-miss previously exited 0, letting downstream steps (e.g.
`ci release-data publish`) build partial generations from an empty local
state. The sync command must now fail when the channel head metadata
cannot be downloaded.
"""

from __future__ import annotations

import shutil
import tempfile

from pathlib import Path

import click
import click.testing
import pytest

from bootstrap.cli import register_all_commands
from bootstrap.remote import SessionManager
from bootstrap.remote.sync import SyncResult


@pytest.fixture
def tmp_project() -> Path:
    d = tempfile.mkdtemp(prefix="efa-remote-sync-")
    yield Path(d)
    shutil.rmtree(d, ignore_errors=True)


def _make_cli() -> click.Group:
    @click.group()
    def cli() -> None:
        pass

    register_all_commands(cli)
    return cli


class _FakeSyncer:
    def __init__(self, results: dict[str, SyncResult]) -> None:
        self._results = results

    def sync_channel(self, channel: str, *, max_depth: int = -1) -> SyncResult:
        return self._results[channel]

    def sync_all_channels(self, *, max_depth: int = -1) -> dict[str, SyncResult]:
        return self._results


def _invoke_sync(
    tmp_project: Path,
    monkeypatch: pytest.MonkeyPatch,
    results: dict[str, SyncResult],
    *extra_args: str,
) -> click.testing.Result:
    monkeypatch.setattr(
        "bootstrap.cli.remote.lifecycle._resolve_remote_target",
        lambda *args: ("https://s3.invalid", "bucket", "key", "secret", "alias"),
    )
    fake = _FakeSyncer(results)
    monkeypatch.setattr(SessionManager, "make_syncer", lambda self, **kwargs: fake)

    schema_root = tmp_project / "cache" / "remote"
    schema_root.mkdir(parents=True, exist_ok=True)

    runner = click.testing.CliRunner()
    return runner.invoke(
        _make_cli(),
        [
            "remote",
            "sync",
            "--target",
            "s3",
            "--schema-root",
            str(schema_root),
            *extra_args,
        ],
    )


class TestSyncMissingHead:
    def test_channel_sync_fails_when_head_missing(
        self, tmp_project: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        results = {"testing": SyncResult(channel="testing", registry=True, head_meta=False)}
        result = _invoke_sync(tmp_project, monkeypatch, results, "--channel", "testing")

        assert result.exit_code != 0
        assert "Channel head not found on remote" in result.output
        assert "testing" in result.output

    def test_channel_sync_succeeds_with_head(
        self, tmp_project: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        results = {"testing": SyncResult(channel="testing", registry=True, head_meta=True)}
        result = _invoke_sync(tmp_project, monkeypatch, results, "--channel", "testing")

        assert result.exit_code == 0, result.output
        assert "Sync complete." in result.output

    def test_sync_all_fails_when_any_head_missing(
        self, tmp_project: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        results = {
            "testing": SyncResult(channel="testing", registry=True, head_meta=True),
            "stable": SyncResult(channel="stable", registry=True, head_meta=False),
        }
        result = _invoke_sync(tmp_project, monkeypatch, results)

        assert result.exit_code != 0
        assert "stable" in result.output

    def test_sync_all_succeeds_when_all_heads_present(
        self, tmp_project: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        results = {
            "testing": SyncResult(channel="testing", registry=True, head_meta=True),
            "stable": SyncResult(channel="stable", registry=True, head_meta=True),
        }
        result = _invoke_sync(tmp_project, monkeypatch, results)

        assert result.exit_code == 0, result.output
        assert "Sync complete." in result.output
