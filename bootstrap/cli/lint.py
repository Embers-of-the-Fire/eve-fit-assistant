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
    @click.option(
        "--changed",
        is_flag=True,
        default=False,
        help="Only lint packages affected by changes since the base ref.",
    )
    @click.option(
        "--base-ref",
        default=None,
        help="Git ref to diff against (default: merge-base with origin/dev).",
    )
    @click.option(
        "--packages",
        default=None,
        help="Comma-separated monorepo package ids to restrict linting to.",
    )
    def lint(
        no_check: bool,
        check_only: bool,
        lang: str,
        changed: bool,
        base_ref: str | None,
        packages: str | None,
    ):
        """Lint, fix and format code"""
        if no_check and check_only:
            raise click.ClickException("--no-check and --check cannot be used together.")
        package_ids, files = runtime.resolve_change_scope(changed, base_ref, packages)
        run_lint(
            lang,
            no_check=no_check,
            check_only=check_only,
            dry_run=runtime.is_dry_run(),
            packages=package_ids,
            files=files,
        )

    @cli_group.command("format")
    @click.option(
        "--changed",
        is_flag=True,
        default=False,
        help="Only format packages affected by changes since the base ref.",
    )
    @click.option(
        "--base-ref",
        default=None,
        help="Git ref to diff against (default: merge-base with origin/dev).",
    )
    @click.option(
        "--packages",
        default=None,
        help="Comma-separated monorepo package ids to restrict formatting to.",
    )
    @click.pass_context
    def format_cmd(ctx: click.Context, changed: bool, base_ref: str | None, packages: str | None):
        """Format the code. This is equivalent to `x lint --no-check`."""
        ctx.invoke(lint, no_check=True, changed=changed, base_ref=base_ref, packages=packages)
