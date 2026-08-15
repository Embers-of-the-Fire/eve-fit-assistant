from __future__ import annotations

from pathlib import Path

import click

from colorama import Fore
from colorama import Style

from bootstrap.color import styled
from bootstrap.utils import execute_command
from bootstrap.utils import get_command


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
                execute_command([uv, "run", "ruff", "check", "--fix"], "RUFF CHECK OUTPUT", dry_run)

        if check_only:
            _echo("uv run ruff format --check")
            execute_command([uv, "run", "ruff", "format", "--check"], "RUFF FORMAT OUTPUT", dry_run)
        else:
            _echo("uv run ruff format")
            execute_command([uv, "run", "ruff", "format"], "RUFF FORMAT OUTPUT", dry_run)

    if lang in ("all", "dart"):
        from bootstrap.cli.runtime import run_melos
        from bootstrap.docs import build_bundled_docs
        from bootstrap.docs import build_manual

        _echo("build bundled docs")
        if dry_run:
            click.echo(styled([Style.BRIGHT, Fore.YELLOW], "[Dry-Run] Skipping build bundled docs"))
        else:
            try:
                build_bundled_docs()
                build_manual()
            except (ValueError, TypeError, FileNotFoundError) as exception:
                raise click.ClickException(str(exception)) from exception

        if not no_check or check_only:
            if not check_only:
                _echo("melos run app:fix")
                run_melos("app:fix", "DART FIX OUTPUT")
            _echo("melos run app:analyze")
            run_melos("app:analyze", "DART ANALYZE OUTPUT")

        if check_only:
            _echo("melos run app:format:check")
            run_melos("app:format:check", "DART FORMAT OUTPUT")
        else:
            _echo("melos run app:format")
            run_melos("app:format", "DART FORMAT OUTPUT")

    if lang in ("all", "rust"):
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

    if lang in ("all", "l10n") and (not no_check or check_only):
        from bootstrap.ci.lint_l10n import run_l10n_lint

        run_l10n_lint(dry_run=dry_run)

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
