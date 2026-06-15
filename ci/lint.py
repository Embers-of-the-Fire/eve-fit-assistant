from __future__ import annotations

import click

from colorama import Fore
from colorama import Style
from data.lib.color import styled
from data.lib.utils import execute_command
from data.lib.utils import get_command
from pathlib import Path

__all__ = ["run_lint", "run_site_checks"]


def run_lint(
    lang: str, *, no_check: bool = False, check_only: bool = False, dry_run: bool = False
) -> None:
    """Shared lint/format logic parameterized by mode.

    check_only=True: read-only verification (CI mode); exits non-zero on failures.
    check_only=False: auto-fix mode; formatters modify in-place.
    """

    def _echo(cmd_str: str) -> None:
        click.echo(styled([Style.BRIGHT, Fore.GREEN], "Executing command: ") + cmd_str)

    uv = get_command("uv")

    if lang in ("all", "python"):
        if not no_check or check_only:
            if check_only:
                _echo("uv run ruff check")
                execute_command([uv, "run", "ruff", "check"], "RUFF CHECK OUTPUT", dry_run)
            else:
                _echo("uv run ruff check --fix")
                execute_command(
                    [uv, "run", "ruff", "check", "--fix"], "RUFF CHECK OUTPUT", dry_run
                )

        if check_only:
            _echo("uv run ruff format --check")
            execute_command(
                [uv, "run", "ruff", "format", "--check"], "RUFF FORMAT OUTPUT", dry_run
            )
        else:
            _echo("uv run ruff format")
            execute_command([uv, "run", "ruff", "format"], "RUFF FORMAT OUTPUT", dry_run)

    if lang in ("all", "dart", "rust"):
        dart = get_command("dart")

        if lang in ("all", "dart"):
            if not no_check or check_only:
                if not check_only:
                    _echo("dart fix --apply")
                    execute_command([dart, "fix", "--apply"], "DART FIX OUTPUT", dry_run)
                _echo("dart analyze")
                execute_command([dart, "analyze"], "DART ANALYZE OUTPUT", dry_run)

            if check_only:
                _echo("dart format --set-exit-if-changed lib/")
                execute_command(
                    [dart, "format", "--set-exit-if-changed", "lib/"], "DART FORMAT OUTPUT", dry_run
                )
            else:
                _echo("dart format lib/")
                execute_command([dart, "format", "lib/"], "DART FORMAT OUTPUT", dry_run)

        cargo = get_command("cargo")
        if check_only:
            _echo("cargo fmt --check --package rust_lib_eve_fit_assistant")
            execute_command(
                [cargo, "fmt", "--check", "--package", "rust_lib_eve_fit_assistant"],
                "CARGO FMT OUTPUT",
                dry_run,
            )
        else:
            _echo("cargo fmt --package rust_lib_eve_fit_assistant")
            execute_command(
                [cargo, "fmt", "--package", "rust_lib_eve_fit_assistant"],
                "CARGO FMT OUTPUT",
                dry_run,
            )

        if not no_check or check_only:
            if check_only:
                _echo("cargo clippy --package rust_lib_eve_fit_assistant")
                execute_command(
                    [cargo, "clippy", "--package", "rust_lib_eve_fit_assistant"],
                    "CARGO CLIPPY OUTPUT",
                    dry_run,
                )
            else:
                _echo("cargo clippy --fix --allow-dirty --package rust_lib_eve_fit_assistant")
                execute_command(
                    [
                        cargo,
                        "clippy",
                        "--fix",
                        "--allow-dirty",
                        "--package",
                        "rust_lib_eve_fit_assistant",
                    ],
                    "CARGO CLIPPY OUTPUT",
                    dry_run,
                )

    if lang in ("all", "site") and Path("site/package.json").exists():
        pnpm = get_command("pnpm")
        run_site_checks(pnpm, no_check=no_check, check_only=check_only, dry_run=dry_run)

    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Linting completed successfully."))


def run_site_checks(
    pnpm: str, *, no_check: bool = False, check_only: bool = False, dry_run: bool = False
) -> None:
    """Format and lint the SvelteKit site (biome + svelte-check).

    check_only=True: read-only verification (CI mode); exits non-zero on failures.
    check_only=False: auto-fix mode; formatters modify in-place.
    """

    def _echo(cmd_str: str) -> None:
        click.echo(styled([Style.BRIGHT, Fore.GREEN], "Executing command: ") + cmd_str)

    if check_only:
        _echo("pnpm biome format site/")
        execute_command([pnpm, "biome", "format", "site/"], "BIOME FORMAT OUTPUT", dry_run)
    else:
        _echo("pnpm biome format --write site/")
        execute_command(
            [pnpm, "biome", "format", "--write", "site/"], "BIOME FORMAT OUTPUT", dry_run
        )

    if not no_check or check_only:
        _echo("pnpm biome check site/")
        execute_command([pnpm, "biome", "check", "site/"], "BIOME CHECK OUTPUT", dry_run)

        _echo("pnpm --filter efa-tech check")
        execute_command([pnpm, "--filter", "efa-tech", "check"], "SVELTE CHECK OUTPUT", dry_run)
