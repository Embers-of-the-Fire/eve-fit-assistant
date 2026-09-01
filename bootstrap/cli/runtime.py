"""Shared runtime state and helpers for the EFA workspace manager CLI.

This module holds the cross-cutting state (the ``--dry-run`` flag) and the
helper functions reused by more than one command group. Command modules under
``bootstrap.cli`` import from here instead of duplicating the wrappers that used
to live at module scope in ``x.py``.
"""

from __future__ import annotations

import sys

from typing import TYPE_CHECKING

import click

from colorama import Fore
from colorama import Style

import bootstrap.config

from bootstrap.color import styled
from bootstrap.constant import PROJECT_ROOT
from bootstrap.data.workspace.config import WorkspaceConfig
from bootstrap.log import info
from bootstrap.utils import execute_command
from bootstrap.utils import get_command


if TYPE_CHECKING:
    from pathlib import Path


_DRY_RUN = False


def set_dry_run(value: bool) -> None:
    global _DRY_RUN
    _DRY_RUN = value


def is_dry_run() -> bool:
    return _DRY_RUN


def execute(
    cmd: list,
    title: str,
    capture_stdout: bool = False,
    live_stdout: bool = False,
    cwd: Path | None = None,
) -> str:
    return execute_command(cmd, title, _DRY_RUN, capture_stdout, live_stdout, cwd=cwd)


def run_melos(
    script: str,
    title: str,
    args: list[str] | None = None,
    live_stdout: bool = False,
    scope: list[str] | None = None,
) -> str:
    """Run a melos script from the workspace root (see root pubspec.yaml).

    Extra ``args`` are appended after ``--`` and forwarded to the script's
    command. ``scope`` restricts the run to the named workspace packages,
    overriding/further restricting the script's ``packageFilters`` (see
    https://melos.invertase.dev/commands/run).
    """
    from bootstrap.utils import get_melos_command

    cmd = [*get_melos_command(), "run", script]
    if scope:
        cmd += [f"--scope={name}" for name in scope]
    if args:
        cmd += ["--", *args]
    return execute(cmd, title, live_stdout=live_stdout, cwd=PROJECT_ROOT)


def run_melos_exec(cmd: list[str], title: str, scope: str = "eve_fit_assistant") -> str:
    """Run an arbitrary command inside a workspace package via ``melos exec``."""
    from bootstrap.utils import get_melos_command

    return execute(
        [*get_melos_command(), "exec", f"--scope={scope}", "--", *cmd],
        title,
        cwd=PROJECT_ROOT,
    )


def execute_redacted(cmd: list[str], redacted_cmd: list[str], title: str) -> None:
    import subprocess

    if _DRY_RUN:
        info(f"[Dry-Run] {title}: " + " ".join(redacted_cmd))
        return

    out = subprocess.run(
        cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", check=False
    )
    if out.returncode != 0:
        message = f"Failed to execute command [{out.returncode}]: " + " ".join(redacted_cmd)
        stderr = (out.stderr or "").strip()
        if stderr:
            message += f"\n{stderr}"
        raise click.ClickException(message)


def resolve_dev_path(path: Path) -> Path:
    bootstrap.config.DeveloperConfiguration.ensure_loaded()
    if path.is_absolute():
        return path
    return bootstrap.config.DEV_CONFIGURATION.paths.root / path


def resolve_schema_root(schema_root: Path | None) -> Path:
    bootstrap.config.DeveloperConfiguration.ensure_loaded()
    if schema_root is not None:
        if schema_root.is_absolute():
            return schema_root
        return (PROJECT_ROOT / schema_root).resolve()
    return resolve_dev_path(bootstrap.config.DEV_CONFIGURATION.paths.schema_dir)


def get_workspace(name) -> Path:
    if not isinstance(name, str):
        raise click.ClickException(f"Invalid name: {name!r}")
    name = name.strip()

    if len(name) == 0:
        click.echo(styled([Style.BRIGHT, Fore.RED], "Invalid name: ") + "empty")
        sys.exit(1)

    workspaces = bootstrap.config.CONFIGURATION.resources
    ws = workspaces.get(name)

    if ws is None:
        click.echo(styled([Style.BRIGHT, Fore.RED], "Unknown workspace identifier: ") + name)
        click.echo("Please check if the workspace is registered in the configuration.")
        sys.exit(1)

    if not ws.descriptor.exists():
        click.echo(
            styled([Style.BRIGHT, Fore.YELLOW], "Warning: ") + f"Descriptor for {name} not found."
        )

    return ws.descriptor


def current_workspace_descriptor() -> WorkspaceConfig:
    name = bootstrap.config.WORKSPACE_CACHE.current_workspace
    if not name:
        click.echo(styled([Style.BRIGHT, Fore.RED], "No workspace selected."))
        click.echo("Please select a workspace using `x workspace list` and `x workspace default`.")
        sys.exit(1)

    ws = get_workspace(name)
    info(f"Resolving workspace: {name} ({ws})")
    return WorkspaceConfig.load_from_descriptor(ws)


def env_install() -> None:
    protoc_gen_dart = get_command("protoc-gen-dart")
    if protoc_gen_dart is None:
        click.echo(
            styled([Style.BRIGHT, Fore.RED], "Warning: ") + "protoc-gen-dart not found, installing"
        )
        dart = get_command("dart")
        execute([dart, "pub", "global", "activate", "protoc_plugin"], "DART ACTIVATE OUTPUT")

    uv = get_command("uv")
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Executing command: ") + "uv sync")
    execute([uv, "sync"], "UV SYNC OUTPUT")

    flutter = get_command("flutter")
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Executing command: ") + "flutter pub get")
    execute([flutter, "pub", "get"], "FLUTTER PUB GET OUTPUT")

    from pathlib import Path

    if Path("package.json").exists():
        pnpm = get_command("pnpm")
        click.echo(styled([Style.BRIGHT, Fore.GREEN], "Executing command: ") + "pnpm install")
        execute([pnpm, "install"], "PNPM INSTALL OUTPUT")


def env_upgrade() -> None:
    uv = get_command("uv")
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Executing command: ") + "uv sync --upgrade")
    execute([uv, "sync", "--upgrade"], "UV UPGRADE OUTPUT")

    flutter = get_command("flutter")
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Executing command: ") + "flutter pub upgrade")
    execute([flutter, "pub", "upgrade"], "FLUTTER PUB UPGRADE OUTPUT")

    cargo = get_command("cargo")
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Executing command: ") + "cargo update")
    execute([cargo, "update"], "CARGO UPDATE OUTPUT")


def run_format() -> None:
    from bootstrap.ci.lint import run_lint

    run_lint("all", no_check=True, check_only=False, dry_run=_DRY_RUN)


def resolve_change_scope(
    changed: bool, base_ref: str | None, packages: str | None
) -> tuple[tuple[str, ...] | None, tuple[str, ...] | None]:
    """Resolve ``--changed``/``--packages`` CLI options into a work scope.

    Returns ``(package ids, changed files)``; both are ``None`` for the
    unscoped full behavior. Escalating changes resolve to a full (unscoped)
    run. Change detection is the single merge-base implementation in
    ``bootstrap.ci.resolve``.
    """
    import bootstrap.ci.resolve as resolver

    if changed and packages:
        raise click.ClickException("--changed and --packages cannot be used together.")
    if packages:
        ids = tuple(p.strip() for p in packages.split(",") if p.strip())
        return (ids or None), None
    if not changed:
        return None, None

    try:
        files = resolver.changed_files_local(base_ref)
    except RuntimeError as exception:
        raise click.ClickException(str(exception)) from exception
    resolution = resolver.resolve(files)
    if resolution.escalated:
        click.echo(
            styled(
                [Style.BRIGHT, Fore.YELLOW],
                "Infrastructure files changed; running the full pass.",
            )
        )
        return None, None
    click.echo(
        styled([Style.BRIGHT, Fore.GREEN], "Affected packages: ")
        + (", ".join(sorted(resolution.packages)) or "(none)")
    )
    return tuple(sorted(resolution.packages)), resolution.files
