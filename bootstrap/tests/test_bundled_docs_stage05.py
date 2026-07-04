from __future__ import annotations

from unittest.mock import patch

import click
import pytest

from click.testing import CliRunner

from bootstrap.cli.build import register_build_commands


@pytest.fixture
def cli() -> click.Group:
    group = click.Group()
    register_build_commands(group)
    return group


@pytest.fixture
def runner() -> CliRunner:
    return CliRunner()


class TestBuildDocsCommand:
    def test_build_docs_command_registered(self, cli: click.Group) -> None:
        build_group = cli.commands["build"]
        assert isinstance(build_group, click.Group)
        assert "docs" in build_group.commands

    def test_build_announcements_command_removed(self, cli: click.Group) -> None:
        build_group = cli.commands["build"]
        assert isinstance(build_group, click.Group)
        assert "announcements" not in build_group.commands

    def test_build_docs_invokes_builder(self, cli: click.Group, runner: CliRunner) -> None:
        with patch("bootstrap.docs.build_bundled_docs") as mock_builder:
            result = runner.invoke(cli, ["build", "docs"])

        assert result.exit_code == 0
        mock_builder.assert_called_once_with()

    def test_build_docs_propagates_value_error(self, cli: click.Group, runner: CliRunner) -> None:
        with patch(
            "bootstrap.docs.build_bundled_docs", side_effect=ValueError("boom")
        ) as mock_builder:
            result = runner.invoke(cli, ["build", "docs"])

        assert result.exit_code == 1
        assert "boom" in result.output
        mock_builder.assert_called_once_with()
