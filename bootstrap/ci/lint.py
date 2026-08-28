from __future__ import annotations

import json

from pathlib import Path

import click

from colorama import Fore
from colorama import Style

from bootstrap.color import styled
from bootstrap.constant import PROJECT_ROOT
from bootstrap.monorepo import PACKAGES
from bootstrap.utils import execute_command
from bootstrap.utils import get_command


__all__ = ["run_lint", "run_site_checks", "run_snapshot_ts_checks"]


_PACKAGES_BY_ID = {p.id: p for p in PACKAGES}


def _scoped_ids(packages: tuple[str, ...] | None, ecosystem: str) -> list[str] | None:
    """Filter a package scope down to one ecosystem.

    Returns ``None`` when unscoped (legacy full behavior) and a possibly
    empty list when scoped (empty means: nothing to do for this ecosystem).
    """
    if packages is None:
        return None
    return sorted(p for p in packages if _PACKAGES_BY_ID[p].ecosystem == ecosystem)


def _packages_with_script(ids: list[str], script: str) -> list[str]:
    """Return the subset of pnpm package ids that define the given script."""
    result = []
    for package_id in ids:
        manifest = PROJECT_ROOT / _PACKAGES_BY_ID[package_id].path / "package.json"
        if not manifest.is_file():
            continue
        scripts = json.loads(manifest.read_text(encoding="utf-8")).get("scripts") or {}
        if script in scripts:
            result.append(package_id)
    return result


def _biome_targets(ids: list[str], prefix: str) -> list[str]:
    """Render biome path arguments for the scoped packages under ``prefix``."""
    return [
        f"{_PACKAGES_BY_ID[p].path}/" for p in ids if _PACKAGES_BY_ID[p].path.startswith(prefix)
    ]


def run_lint(
    lang: str,
    *,
    no_check: bool = False,
    check_only: bool = False,
    dry_run: bool = False,
    packages: tuple[str, ...] | None = None,
    files: tuple[str, ...] | None = None,
) -> None:
    """Shared lint/format logic parameterized by mode and scope.

    check_only=True: read-only verification (CI mode); exits non-zero on failures.
    check_only=False: auto-fix mode; formatters modify in-place.

    ``packages`` restricts the work to the given monorepo package ids (see
    ``bootstrap.monorepo``); ``files`` restricts the Python checks to the
    given changed files. Both default to the legacy full behavior.
    """

    def _echo(cmd_str: str) -> None:
        click.echo(styled([Style.BRIGHT, Fore.GREEN], "Executing command: ") + cmd_str)

    uv = get_command("uv")

    if lang in ("all", "python"):
        python_files: list[str] | None = None
        if files is not None:
            python_files = [f for f in files if f.endswith(".py") and (PROJECT_ROOT / f).is_file()]
        if python_files is None or python_files:
            targets = python_files if python_files is not None else ["."]
            if not no_check or check_only:
                if check_only:
                    _echo(f"uv run ruff check {' '.join(targets)}")
                    execute_command(
                        [uv, "run", "ruff", "check", *targets], "RUFF CHECK OUTPUT", dry_run
                    )
                else:
                    _echo(f"uv run ruff check --fix {' '.join(targets)}")
                    execute_command(
                        [uv, "run", "ruff", "check", "--fix", *targets],
                        "RUFF CHECK OUTPUT",
                        dry_run,
                    )

            if check_only:
                _echo(f"uv run ruff format --check {' '.join(targets)}")
                execute_command(
                    [uv, "run", "ruff", "format", "--check", *targets],
                    "RUFF FORMAT OUTPUT",
                    dry_run,
                )
            else:
                _echo(f"uv run ruff format {' '.join(targets)}")
                execute_command(
                    [uv, "run", "ruff", "format", *targets], "RUFF FORMAT OUTPUT", dry_run
                )

    dart_scope = _scoped_ids(packages, "dart")
    if lang in ("all", "dart") and dart_scope != []:
        from bootstrap.cli.runtime import run_melos
        from bootstrap.docs import build_bundled_docs
        from bootstrap.docs import build_manual

        # The bundled docs/manual are only analyzed as part of the app.
        if dart_scope is None or "eve_fit_assistant" in dart_scope:
            _echo("build bundled docs")
            if dry_run:
                click.echo(
                    styled([Style.BRIGHT, Fore.YELLOW], "[Dry-Run] Skipping build bundled docs")
                )
            else:
                try:
                    build_bundled_docs()
                    build_manual()
                except (ValueError, TypeError, FileNotFoundError) as exception:
                    raise click.ClickException(str(exception)) from exception

        if not no_check or check_only:
            if not check_only:
                _echo("melos run app:fix")
                run_melos("app:fix", "DART FIX OUTPUT", scope=dart_scope)
            _echo("melos run app:analyze")
            run_melos("app:analyze", "DART ANALYZE OUTPUT", scope=dart_scope)

        if check_only:
            _echo("melos run app:format:check")
            run_melos("app:format:check", "DART FORMAT OUTPUT", scope=dart_scope)
        else:
            _echo("melos run app:format")
            run_melos("app:format", "DART FORMAT OUTPUT", scope=dart_scope)

    rust_scope = _scoped_ids(packages, "rust")
    if lang in ("all", "rust") and rust_scope != []:
        cargo = get_command("cargo")
        # Unscoped keeps the legacy behavior (the FRB crate only).
        crates = rust_scope if rust_scope is not None else ["rust_lib_eve_fit_assistant"]
        for crate in crates:
            if check_only:
                _echo(f"cargo fmt --check --package {crate}")
                execute_command(
                    [cargo, "fmt", "--check", "--package", crate],
                    "CARGO FMT OUTPUT",
                    dry_run,
                )
            else:
                _echo(f"cargo fmt --package {crate}")
                execute_command(
                    [cargo, "fmt", "--package", crate],
                    "CARGO FMT OUTPUT",
                    dry_run,
                )

            if not no_check or check_only:
                if check_only:
                    _echo(f"cargo clippy --package {crate}")
                    execute_command(
                        [cargo, "clippy", "--package", crate],
                        "CARGO CLIPPY OUTPUT",
                        dry_run,
                    )
                else:
                    _echo(f"cargo clippy --fix --allow-dirty --package {crate}")
                    execute_command(
                        [
                            cargo,
                            "clippy",
                            "--fix",
                            "--allow-dirty",
                            "--package",
                            crate,
                        ],
                        "CARGO CLIPPY OUTPUT",
                        dry_run,
                    )

    ts_scope = _scoped_ids(packages, "ts")
    if lang in ("all", "site") and Path("site/package.json").exists():
        pnpm = get_command("pnpm")
        if ts_scope is None:
            run_site_checks(pnpm, no_check=no_check, check_only=check_only, dry_run=dry_run)
        else:
            targets = _biome_targets(ts_scope, "site/")
            if targets:
                _run_biome(pnpm, targets, no_check=no_check, check_only=check_only, dry_run=dry_run)
                for package_id in _packages_with_script(
                    [p for p in ts_scope if _PACKAGES_BY_ID[p].path.startswith("site/")], "check"
                ):
                    _echo(f"pnpm --filter {package_id} check")
                    execute_command(
                        [pnpm, "--filter", package_id, "check"], "SITE CHECK OUTPUT", dry_run
                    )

    if (
        lang in ("all", "snapshot-ts")
        and Path("packages/efa_fit_snapshot_ts/package.json").exists()
        and ts_scope != []
    ):
        pnpm = get_command("pnpm")
        if ts_scope is None:
            run_snapshot_ts_checks(pnpm, no_check=no_check, check_only=check_only, dry_run=dry_run)
        else:
            targets = _biome_targets(ts_scope, "packages/")
            if targets:
                _run_biome(pnpm, targets, no_check=no_check, check_only=check_only, dry_run=dry_run)
                for package_id in _packages_with_script(
                    [p for p in ts_scope if _PACKAGES_BY_ID[p].path.startswith("packages/")],
                    "check",
                ):
                    _echo(f"pnpm --filter {package_id} check")
                    execute_command(
                        [pnpm, "--filter", package_id, "check"], "SNAPSHOT TS CHECK OUTPUT", dry_run
                    )

    if lang in ("all", "l10n") and (not no_check or check_only):
        from bootstrap.ci.lint_l10n import run_l10n_lint

        run_l10n_lint(dry_run=dry_run)

    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Linting completed successfully."))


def _run_biome(
    pnpm: str,
    targets: list[str],
    *,
    no_check: bool = False,
    check_only: bool = False,
    dry_run: bool = False,
) -> None:
    """Run biome format + check over the given path arguments."""

    def _echo(cmd_str: str) -> None:
        click.echo(styled([Style.BRIGHT, Fore.GREEN], "Executing command: ") + cmd_str)

    if check_only:
        _echo(f"pnpm biome format {' '.join(targets)}")
        execute_command([pnpm, "biome", "format", *targets], "BIOME FORMAT OUTPUT", dry_run)
    else:
        _echo(f"pnpm biome format --write {' '.join(targets)}")
        execute_command(
            [pnpm, "biome", "format", "--write", *targets], "BIOME FORMAT OUTPUT", dry_run
        )

    if not no_check or check_only:
        _echo(f"pnpm biome check {' '.join(targets)}")
        execute_command([pnpm, "biome", "check", *targets], "BIOME CHECK OUTPUT", dry_run)


def run_site_checks(
    pnpm: str, *, no_check: bool = False, check_only: bool = False, dry_run: bool = False
) -> None:
    """Format and lint the SvelteKit site (biome + svelte-check).

    check_only=True: read-only verification (CI mode); exits non-zero on failures.
    check_only=False: auto-fix mode; formatters modify in-place.
    """

    def _echo(cmd_str: str) -> None:
        click.echo(styled([Style.BRIGHT, Fore.GREEN], "Executing command: ") + cmd_str)

    _run_biome(pnpm, ["site/"], no_check=no_check, check_only=check_only, dry_run=dry_run)

    if not no_check or check_only:
        _echo("pnpm --filter efa-tech check")
        execute_command([pnpm, "--filter", "efa-tech", "check"], "SVELTE CHECK OUTPUT", dry_run)


def run_snapshot_ts_checks(
    pnpm: str, *, no_check: bool = False, check_only: bool = False, dry_run: bool = False
) -> None:
    """Format and lint the snapshot TypeScript package (biome + svelte-check).

    check_only=True: read-only verification (CI mode); exits non-zero on failures.
    check_only=False: auto-fix mode; formatters modify in-place.
    """

    def _echo(cmd_str: str) -> None:
        click.echo(styled([Style.BRIGHT, Fore.GREEN], "Executing command: ") + cmd_str)

    _run_biome(
        pnpm,
        ["packages/efa_fit_snapshot_ts/"],
        no_check=no_check,
        check_only=check_only,
        dry_run=dry_run,
    )

    if not no_check or check_only:
        _echo("pnpm --filter efa-fit-snapshot-ts check")
        execute_command(
            [pnpm, "--filter", "efa-fit-snapshot-ts", "check"],
            "SNAPSHOT TS CHECK OUTPUT",
            dry_run,
        )
