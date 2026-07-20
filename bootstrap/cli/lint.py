from __future__ import annotations

import click

from bootstrap.ci.lint import run_lint
from bootstrap.cli import runtime


def register_lint_commands(cli_group: click.Group) -> None:
    @cli_group.command()
    @click.option("--no-check", "no_check", is_flag=True, default=False, help="Skip linting step.")
    @click.option(
        "--check",
        "check_only",
        is_flag=True,
        default=False,
        help="Check-only mode: verify without modifying files.",
    )
    @click.option(
        "--lang",
        type=click.Choice(["all", "python", "dart", "rust", "site", "l10n"]),
        default="all",
        help="Limit linting to a specific language (default: all).",
    )
    def lint(no_check: bool, check_only: bool, lang: str):
        """Lint, fix and format code"""
        if no_check and check_only:
            raise click.ClickException("--no-check and --check cannot be used together.")
        run_lint(lang, no_check=no_check, check_only=check_only, dry_run=runtime.is_dry_run())

    @cli_group.command("format")
    @click.pass_context
    def format_cmd(ctx: click.Context):
        """Format the code. This is equivalent to `x lint --no-check`."""
        ctx.invoke(lint, no_check=True)
