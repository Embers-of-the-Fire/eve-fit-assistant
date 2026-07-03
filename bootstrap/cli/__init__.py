from __future__ import annotations

from typing import TYPE_CHECKING

from bootstrap.ci import register_ci_commands
from bootstrap.cli.build import register_build_commands
from bootstrap.cli.dev import register_dev_commands
from bootstrap.cli.etc import register_etc_commands
from bootstrap.cli.generate import register_generate_commands
from bootstrap.cli.lint import register_lint_commands
from bootstrap.cli.remote import register_remote_commands
from bootstrap.cli.test import register_test_commands
from bootstrap.cli.workspace import register_workspace_commands


if TYPE_CHECKING:
    import click


def register_all_commands(cli_group: click.Group) -> None:
    """Attach every command group to the root CLI group."""
    register_lint_commands(cli_group)
    register_workspace_commands(cli_group)
    register_generate_commands(cli_group)
    register_dev_commands(cli_group)
    register_remote_commands(cli_group)
    register_build_commands(cli_group)
    register_etc_commands(cli_group)
    register_test_commands(cli_group)
    register_ci_commands(cli_group)


__all__ = ["register_all_commands"]
