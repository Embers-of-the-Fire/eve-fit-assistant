"""Regression tests for `ci release-data publish` missing-head handling.

Covers the fail-loud guard added to prevent partial generations: when
--merge is on (the default) but no local channel head exists under the
schema root, the publish must abort unless --allow-missing-head is given.
"""

from __future__ import annotations

import json
import shutil
import tempfile

from pathlib import Path

import click
import click.testing
import pytest

from bootstrap.cli import register_all_commands
from bootstrap.tests.test_session_cli import _make_resource_snapshot


@pytest.fixture
def tmp_project() -> Path:
    d = tempfile.mkdtemp(prefix="efa-release-data-publish-")
    yield Path(d)
    shutil.rmtree(d, ignore_errors=True)


def _make_cli() -> click.Group:
    @click.group()
    def cli() -> None:
        pass

    register_all_commands(cli)
    return cli


def _write_hashes(tmp_project: Path, hashes: dict[str, str]) -> Path:
    hashes_path = tmp_project / "snapshot-hashes.json"
    hashes_path.write_text(json.dumps(hashes), encoding="utf-8")
    return hashes_path


class TestMissingHeadGuard:
    def test_rejects_missing_head_by_default(
        self, tmp_project: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        monkeypatch.setattr("bootstrap.ci.commands.PROJECT_ROOT", tmp_project)
        hashes_path = _write_hashes(tmp_project, {"tranquility": "ab" * 32})

        runner = click.testing.CliRunner()
        result = runner.invoke(
            _make_cli(),
            [
                "ci",
                "release-data",
                "publish",
                "testing",
                "--hashes",
                str(hashes_path),
                "--schema-root",
                "cache/remote",
                "--test-mode",
            ],
        )

        assert result.exit_code != 0
        assert "No local channel head found for 'testing'" in result.output
        assert "refusing to publish a partial generation" in result.output
        assert "Staged" not in result.output

    def test_proceeds_with_allow_missing_head(
        self, tmp_project: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        monkeypatch.setattr("bootstrap.ci.commands.PROJECT_ROOT", tmp_project)
        schema_root = tmp_project / "cache" / "remote"
        schema_root.mkdir(parents=True)
        snap_hash = _make_resource_snapshot(schema_root, server_id="tranquility")
        hashes_path = _write_hashes(tmp_project, {"tranquility": snap_hash})

        runner = click.testing.CliRunner()
        result = runner.invoke(
            _make_cli(),
            [
                "ci",
                "release-data",
                "publish",
                "testing",
                "--hashes",
                str(hashes_path),
                "--schema-root",
                "cache/remote",
                "--test-mode",
                "--allow-missing-head",
            ],
        )

        assert result.exit_code == 0, result.output
        assert "Staged tranquility snapshot" in result.output
        assert "Test mode: skipped publish/sync/verify." in result.output
        refs_dir = schema_root / "channels" / "refs"
        generations = [p for p in refs_dir.iterdir() if p.is_dir() and not p.name.startswith("tmp")]
        assert len(generations) == 1
