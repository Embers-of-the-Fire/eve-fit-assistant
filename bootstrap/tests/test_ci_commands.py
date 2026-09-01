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


def _invoke_codegen(*args: str) -> click.testing.Result:
    @click.group()
    def cli():
        pass

    register_all_commands(cli)
    runner = click.testing.CliRunner()
    return runner.invoke(cli, ["ci", "codegen", *args])


def test_codegen_rejects_empty_packages_selector() -> None:
    result = _invoke_codegen("--packages=,")
    assert result.exit_code != 0
    assert "--packages must contain at least one package id." in result.output


def test_codegen_rejects_empty_steps_selector() -> None:
    result = _invoke_codegen("--steps=,")
    assert result.exit_code != 0
    assert "--steps must contain at least one step name." in result.output
