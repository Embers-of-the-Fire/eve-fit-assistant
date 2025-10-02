"""
EVE Fit Assistant Workspace Manager

This script is used to manage all workspace-level operations,
including code generating, data processing and application bundling.

This file, `x.py`, shares the virtual environment with other sub projects.
You should use `uv run x.py` to execute the script.

To synchronize the python environment, execute `uv sync` from the commandline.

**About Env-Vars**
Some of the commands support environment variables to pass parameters,
but that's not recommended. And the script itself won't load dotenv files.
Please use the configuration files to configure the tool, or pass parameters directly.
"""

# ruff: noqa: E402
# Allow monkey patch to global PYTHON PATH for schema imports

from __future__ import annotations

import subprocess

from typing import TYPE_CHECKING

import click

from click_aliases import ClickAliasedGroup
from colorama import Fore
from colorama import Style
from colorama import init

from data.lib.constant import PROJECT_ROOT
from data.lib.constant import PROTOBUF_DART_OUT_PATH
from data.lib.constant import PROTOBUF_PYTHON_OUT_PATH
from data.lib.constant import PROTOBUF_SCHEMA_PATH
from data.lib.constant import WORKSPACE_NAME_ENV_VAR


def __fix_env():
    import sys

    sys.path.insert(0, PROJECT_ROOT / "data" / "lib" / "schema")


__fix_env()

import data.lib.config

from data.lib.color import styled
from data.lib.config import ProjectConfiguration
from data.lib.config import WorkspaceCache
from data.lib.log import error
from data.lib.log import info
from data.lib.utils import get_command
from data.lib.workspace.config import WorkspaceConfig


if TYPE_CHECKING:
    from pathlib import Path


init(autoreset=True)

if __name__ != "__main__":
    print(
        styled([Style.BRIGHT, Fore.RED], "Invalid Usage: ")
        + "`x.py` must be used as a script, not a module!"
    )
    exit(0)

ProjectConfiguration.load_from_global()
WorkspaceCache.load_from_global()


@click.group(cls=ClickAliasedGroup)
def cli():
    """EFA Workspace Manager."""


@cli.command()
@click.option("--no-check", "no_check", is_flag=True, default=False, help="Skip linting step.")
def lint(no_check: bool):
    """Lint, fix and format code"""
    # run ruff to format rust code

    uv = get_command("uv")
    if not no_check:
        click.echo(
            styled([Style.BRIGHT, Fore.GREEN], "Executing command: ") + "uv run ruff check --fix"
        )
        out = subprocess.run([uv, "run", "ruff", "check", "--fix"], capture_output=True, text=True)
        info("------ RUFF CHECK OUTPUT ------")
        for line in out.stdout.splitlines():
            info(line)
        if out.returncode != 0:
            error(f"Failed to execute ruff [{out.returncode}]:")
            for line in out.stderr.splitlines():
                error(line)
            exit(out.returncode)
        info("-------------------------------")

    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Executing command: ") + "uv run ruff format")
    out = subprocess.run([uv, "run", "ruff", "format"], capture_output=True, text=True)
    info("----- RUFF FORMAT OUTPUT ------")
    for line in out.stdout.splitlines():
        info(line)
    if out.returncode != 0:
        error(f"Failed to execute ruff [{out.returncode}]:")
        for line in out.stderr.splitlines():
            error(line)
        exit(out.returncode)
    info("-------------------------------")

    dart = get_command("dart")

    if not no_check:
        click.echo(styled([Style.BRIGHT, Fore.GREEN], "Executing command: ") + "dart fix --apply")
        out = subprocess.run([dart, "fix", "--apply"], capture_output=True, text=True)
        info("------- DART FIX OUTPUT -------")
        for line in out.stdout.splitlines():
            info(line)
        if out.returncode != 0:
            error(f"Failed to execute dart fix [{out.returncode}]:")
            for line in out.stderr.splitlines():
                error(line)
            exit(out.returncode)
        info("-------------------------------")

    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Executing command: ") + "dart format lib/")
    out = subprocess.run([dart, "format", "lib/"], capture_output=True, text=True)
    info("----- DART FORMAT OUTPUT ------")
    for line in out.stdout.splitlines():
        info(line)
    if out.returncode != 0:
        error(f"Failed to execute dart format [{out.returncode}]:")
        for line in out.stderr.splitlines():
            error(line)
        exit(out.returncode)
    info("-------------------------------")

    cargo = get_command("cargo")
    click.echo(
        styled([Style.BRIGHT, Fore.GREEN], "Executing command: ")
        + "cargo fmt --package rust_lib_eve_fit_assistant"
    )
    out = subprocess.run(
        [cargo, "fmt", "--package", "rust_lib_eve_fit_assistant"],
        capture_output=True,
        text=True,
    )
    info("------ CARGO FMT OUTPUT -------")
    for line in out.stdout.splitlines():
        info(line)
    if out.returncode != 0:
        error(f"Failed to execute cargo fmt [{out.returncode}]:")
        for line in out.stderr.splitlines():
            error(line)
        exit(out.returncode)
    info("-------------------------------")

    if not no_check:
        click.echo(
            styled([Style.BRIGHT, Fore.GREEN], "Executing command: ")
            + "cargo clippy --fix --allow-dirty --package rust_lib_eve_fit_assistant"
        )
        out = subprocess.run(
            [
                cargo,
                "clippy",
                "--fix",
                "--allow-dirty",
                "--package",
                "rust_lib_eve_fit_assistant",
            ],
            capture_output=True,
            text=True,
        )
        info("----- CARGO CLIPPY OUTPUT -----")
        for line in out.stdout.splitlines():
            info(line)
        if out.returncode != 0:
            error(f"Failed to execute cargo clippy [{out.returncode}]:")
            for line in out.stderr.splitlines():
                error(line)
            exit(out.returncode)
        info("-------------------------------")

    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Linting completed successfully."))


@cli.command("format", aliases=["fmt"])
@click.pass_context
def format_cmd(ctx: click.Context):
    """Format the code. This is equivalent to `x lint --no-check`."""
    ctx.invoke(lint, no_check=True)


@cli.group(aliases=["ws"], cls=ClickAliasedGroup)
def workspace():
    """Workspace related commands."""


@workspace.command("list", aliases=["ls"])
def list_cmd():
    """List configured workspaces."""
    workspaces = data.lib.config.CONFIGURATION.resources
    if len(workspaces) == 0:
        click.echo(
            styled([Style.BRIGHT + Fore.RED], "Error: ")
            + styled(Fore.RED, "No workspace configured.")
        )
        exit(1)

    click.echo(
        styled(Fore.GREEN, "Found ")
        + styled([Style.BRIGHT, Fore.GREEN], f"{len(workspaces)}")
        + styled(Fore.GREEN, " workspace configurations.")
    )
    has_not_found = set()
    has_warning = set()
    has_error = set()
    for ws_key, ws_def in workspaces.items():
        if ws_def.descriptor.exists():
            click.echo(
                styled([Style.BRIGHT, Fore.GREEN], "- [√] ") + f"{ws_key}: {ws_def.descriptor}"
            )
            descriptor = WorkspaceConfig.load_from_descriptor(ws_def.descriptor, no_check=True)

            if descriptor.ignore:
                click.echo(
                    styled([Style.BRIGHT, Fore.YELLOW], "  [!] Warning: ")
                    + "workspace is marked as ignored.",
                )
                has_warning.add(ws_key)
                continue

            if not descriptor.paths.fsd.exists() or not descriptor.paths.fsd.is_dir():
                click.echo(
                    styled([Style.BRIGHT, Fore.RED], "  [!] Error: ")
                    + f"FSD path '{descriptor.paths.fsd}' does not exist or is not a directory.",
                )
                has_error.add(ws_key)

            if (
                not descriptor.resources.resource_index.exists()
                or not descriptor.resources.resource_index.is_file()
            ):
                click.echo(
                    styled([Style.BRIGHT, Fore.RED], "  [!] Error: ")
                    + f"Resource index '{descriptor.resources.resource_index}' does not exist or is not a file.",
                )
                has_error.add(ws_key)

            if (
                not descriptor.resources.application_index.exists()
                or not descriptor.resources.application_index.is_file()
            ):
                click.echo(
                    styled([Style.BRIGHT, Fore.RED], "  [!] Error: ")
                    + f"Application index '{descriptor.resources.application_index}' does not exist or is not a file.",
                )
                has_error.add(ws_key)

            if (
                not descriptor.metadata.start_cfg.exists()
                or not descriptor.metadata.start_cfg.is_file()
            ):
                click.echo(
                    styled([Style.BRIGHT, Fore.RED], "  [!] Error: ")
                    + f"Start configuration '{descriptor.metadata.start_cfg}' does not exist or is not a file.",
                )
                has_error.add(ws_key)
        else:
            click.echo(
                styled([Style.BRIGHT, Fore.RED], "- [!] ")
                + f"{ws_key}: "
                + styled([Style.BRIGHT, Fore.RED], "Descriptor not found: ")
                + f"{ws_def.descriptor}"
            )
            has_not_found.add(ws_key)

    if len(has_not_found) > 0:
        click.echo(
            styled(Fore.RED, "Missing ")
            + styled([Style.BRIGHT, Fore.RED], f"{len(has_not_found)}")
            + styled(
                Fore.RED,
                " descriptor" + ("s" if len(has_not_found) > 1 else "") + ": ",
            )
            + ", ".join(has_not_found)
        )
    if len(has_warning) > 0:
        click.echo(
            styled(Fore.YELLOW, "Warning in ")
            + styled([Style.BRIGHT, Fore.YELLOW], f"{len(has_warning)}")
            + styled(
                Fore.YELLOW,
                " workspace" + ("s" if len(has_warning) > 1 else "") + ": ",
            )
            + ", ".join(has_warning)
        )
    if len(has_error) > 0:
        click.echo(
            styled(Fore.RED, "Error in ")
            + styled([Style.BRIGHT, Fore.RED], f"{len(has_error)}")
            + styled(
                Fore.RED,
                " workspace" + ("s" if len(has_error) > 1 else "") + ": ",
            )
            + ", ".join(has_error)
        )

    if has_error or has_not_found:
        exit(1)


def __get_workspace(name) -> Path:
    if not isinstance(name, str):
        click.echo(styled([Style.BRIGHT, Fore.RED], "Invalid name: ") + f"{name!r}")
    name = name.strip()

    if len(name) == 0:
        click.echo(styled([Style.BRIGHT, Fore.RED], "Invalid name: ") + "empty")
        exit(1)

    workspaces = data.lib.config.CONFIGURATION.resources
    ws = workspaces.get(name)

    if ws is None:
        click.echo(styled([Style.BRIGHT, Fore.RED], "Unknown workspace identifier: ") + name)
        click.echo("Please check if the workspace is registered in the configuration.")
        exit(1)

    if not ws.descriptor.exists():
        click.echo(
            styled([Style.BRIGHT, Fore.YELLOW], "Warning: ") + f"Descriptor for {name} not found."
        )

    return ws.descriptor


@workspace.command()
@click.argument("name")
def default(name: str):
    """Set default build target resource."""
    _ = __get_workspace(name)  # check

    ws_cache = data.lib.config.WORKSPACE_CACHE
    if ws_cache.default_workspace is not None:
        click.echo(f"Switch default workspace from {ws_cache.default_workspace} to {name}.")
    else:
        click.echo(f"Set default workspace to {name}.")
    ws_cache.default_workspace = name
    ws_cache.synchronize()


@workspace.command()
@click.argument(
    "name",
    default=data.lib.config.WORKSPACE_CACHE.default_workspace,
    envvar=WORKSPACE_NAME_ENV_VAR,
)
def inspect_json(name: str | None):
    """Resolve the workspace configurations and print in JSON format."""
    ws = __get_workspace(name)
    info(f"Resolving workspace: {name} ({ws})")
    descriptor = WorkspaceConfig.load_from_descriptor(ws)
    click.echo(descriptor.model_dump_json())


@workspace.command()
def cache():
    """Print current workspace cache in JSON format."""
    click.echo(data.lib.config.WORKSPACE_CACHE.model_dump_json(indent=4))


@cli.group()
def config():
    """Configuration related commands."""


@config.command()
def display():
    """Print loaded configuration in JSON format."""
    click.echo(data.lib.config.CONFIGURATION.model_dump_json(indent=4))


@cli.group(aliases=["gen"], cls=ClickAliasedGroup)
def generate():
    """Code generation related commands."""


@generate.command("all")
@click.pass_context
def all_cmd(ctx: click.Context):
    """Generate all code."""
    ctx.invoke(protobuf)
    ctx.invoke(rust)
    ctx.invoke(dart_build_runner)


@generate.command(aliases=["proto", "pb"])
def protobuf():
    """Generate protobuf code for all supported languages."""
    protoc = get_command("protoc")

    total = 0
    failed = set()
    for file in PROTOBUF_SCHEMA_PATH.glob("*.proto"):
        click.echo(styled([Style.BRIGHT, Fore.GREEN], "Generating protobuf code for: ") + f"{file}")
        out = subprocess.run(
            [
                protoc,
                f"--proto_path={PROTOBUF_SCHEMA_PATH}",
                f"--python_out={PROTOBUF_PYTHON_OUT_PATH}",
                f"--dart_out={PROTOBUF_DART_OUT_PATH}",
                file.name,
            ],
            capture_output=True,
            text=True,
        )
        if out.returncode != 0:
            error(f"Failed to execute protoc [{out.returncode}]:")
            for line in out.stderr.splitlines():
                error(line)
            failed.add(file.name)
        total += 1

    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Protobuf code generation completed."))
    if len(failed) == 0:
        click.echo(styled([Style.BRIGHT, Fore.GREEN], "All files generated successfully."))

    else:
        click.echo(
            styled(Fore.GREEN, "Successfully generated: ")
            + styled([Style.BRIGHT, Fore.GREEN], f"{total - len(failed)}")
            + Fore.GREEN
            + f" file{'s' if total - len(failed) > 1 else ''}."
        )
        click.echo(
            styled(Fore.RED, "Failed to generate: ")
            + styled([Style.BRIGHT, Fore.RED], f"{len(failed)}")
            + Fore.RED
            + f" file{'s' if len(failed) > 1 else ''}: "
            + ", ".join(failed)
            + "."
        )


@generate.command(aliases=["rs"])
def rust():
    """Generate flutter-rust-bridge glue code."""
    flutter_rust_bridge_codegen = get_command("flutter_rust_bridge_codegen")
    click.echo(
        styled([Style.BRIGHT, Fore.GREEN], "Executing command: ")
        + "flutter_rust_bridge_codegen generate"
    )
    out = subprocess.run(
        [
            flutter_rust_bridge_codegen,
            "generate",
        ],
        capture_output=True,
        text=True,
    )
    info("----- FRB CODEGEN OUTPUT ------")
    for line in out.stdout.splitlines():
        info(line)
    if out.returncode != 0:
        error(f"Failed to execute flutter_rust_bridge_codegen [{out.returncode}]:")
        for line in out.stderr.splitlines():
            error(line)
        exit(out.returncode)
    info("-------------------------------")
    click.echo(
        styled([Style.BRIGHT, Fore.GREEN], "Rust bridge code generation completed successfully.")
    )


@generate.command("dart")
def dart_build_runner():
    """Run `dart run build_runner build`."""
    dart = get_command("dart")
    click.echo(
        styled([Style.BRIGHT, Fore.GREEN], "Executing command: ")
        + "dart run build_runner build --delete-conflicting-outputs"
    )
    out = subprocess.run(
        [
            dart,
            "run",
            "build_runner",
            "build",
            "--delete-conflicting-outputs",
        ],
        capture_output=True,
        text=True,
    )
    info("--- DART BUILDRUNNER OUTPUT ---")
    for line in out.stdout.splitlines():
        info(line)
    if out.returncode != 0:
        error(f"Failed to execute dart build_runner [{out.returncode}]:")
        for line in out.stderr.splitlines():
            error(line)
        exit(out.returncode)
    info("-------------------------------")
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Dart build runner completed successfully."))


cli()
