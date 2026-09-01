"""Tests for the CI change-set CLI options."""

from __future__ import annotations

from typing import TYPE_CHECKING

import click
import click.testing

from bootstrap.cli import register_all_commands


if TYPE_CHECKING:
    from pathlib import Path


def test_from_file_rejects_directory(tmp_path: Path) -> None:
    @click.group()
    def cli():
        pass

    register_all_commands(cli)
    runner = click.testing.CliRunner()
    result = runner.invoke(cli, ["ci", "matrix", "--from-file", str(tmp_path)])
    assert result.exit_code == 2
    assert "is a directory" in result.output
