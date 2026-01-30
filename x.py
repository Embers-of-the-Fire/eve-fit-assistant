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

import asyncio
import shutil
import sys

from pathlib import Path

import click

from click_aliases import ClickAliasedGroup
from colorama import Fore
from colorama import Style
from colorama import init
from dotenv import load_dotenv
from watchfiles import awatch

from data.lib.codegen import CODEGEN_DART
from data.lib.constant import DEFAULT_WORKSPACE_HASHLIST_ENV_VAR
from data.lib.constant import I18N_ROOT
from data.lib.constant import PROJECT_ROOT
from data.lib.constant import SKIP_FULL_HASHLIST_UPDATE_ENV_VAR
from data.lib.etc.codeart import generate_codeart


def __fix_env():
    sys.path.insert(0, str((PROJECT_ROOT / "data" / "lib" / "schema").resolve()))
    load_dotenv()


__fix_env()

import data.lib.config

from data.lib.color import styled
from data.lib.config import ProjectConfiguration
from data.lib.config import WorkspaceCache
from data.lib.constant import PROTOBUF_DART_OUT_PATH
from data.lib.constant import PROTOBUF_PYTHON_OUT_PATH
from data.lib.constant import PROTOBUF_SCHEMA_PATH
from data.lib.log import info
from data.lib.log import warning
from data.lib.utils import execute_command
from data.lib.utils import get_command
from data.lib.workspace.config import WorkspaceConfig


init(autoreset=True)

if __name__ != "__main__":
    print(
        styled([Style.BRIGHT, Fore.RED], "Invalid Usage: ")
        + "`x.py` must be used as a script, not a module!"
    )
    exit(0)

ProjectConfiguration.load_from_global()
WorkspaceCache.load_from_global()


DRY_RUN = False


def __execute_command(cmd: list, title: str, capture_stdout: bool = False) -> str:
    global DRY_RUN

    return execute_command(cmd, title, DRY_RUN, capture_stdout)


@click.group(
    context_settings={
        "help_option_names": ["-h", "--help"],
    },
    cls=ClickAliasedGroup,
)
@click.option("--dry-run", is_flag=True, default=False, help="Show the command without executing.")
@click.option("--workspace", "--ws", "ws_name", default=None, help="Set current workspace.")
def cli(dry_run, ws_name):
    """EFA Workspace Manager."""
    global DRY_RUN
    DRY_RUN = dry_run

    if ws_name:
        WorkspaceCache.select_workspace(ws_name)


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
        __execute_command([uv, "run", "ruff", "check", "--fix"], "RUFF CHECK OUTPUT")

    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Executing command: ") + "uv run ruff format")
    __execute_command([uv, "run", "ruff", "format"], "RUFF FORMAT OUTPUT")
    dart = get_command("dart")

    if not no_check:
        click.echo(styled([Style.BRIGHT, Fore.GREEN], "Executing command: ") + "dart fix --apply")
        __execute_command([dart, "fix", "--apply"], "DART FIX OUTPUT")
        click.echo(styled([Style.BRIGHT, Fore.GREEN], "Executing command: ") + "dart analyze")
        __execute_command([dart, "analyze"], "DART ANALYZE OUTPUT")

    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Executing command: ") + "dart format lib/")
    __execute_command([dart, "format", "lib/"], "DART FORMAT OUTPUT")

    cargo = get_command("cargo")
    click.echo(
        styled([Style.BRIGHT, Fore.GREEN], "Executing command: ")
        + "cargo fmt --package rust_lib_eve_fit_assistant"
    )
    __execute_command([cargo, "fmt", "--package", "rust_lib_eve_fit_assistant"], "CARGO FMT OUTPUT")

    if not no_check:
        click.echo(
            styled([Style.BRIGHT, Fore.GREEN], "Executing command: ")
            + "cargo clippy --fix --allow-dirty --package rust_lib_eve_fit_assistant"
        )
        __execute_command(
            [cargo, "clippy", "--fix", "--allow-dirty", "--package", "rust_lib_eve_fit_assistant"],
            "CARGO CLIPPY OUTPUT",
        )

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

            if not descriptor.resources.fsd.exists() or not descriptor.resources.fsd.is_dir():
                click.echo(
                    styled([Style.BRIGHT, Fore.RED], "  [!] Error: ")
                    + f"FSD path '{descriptor.resources.fsd}' does not exist or is not a directory.",
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
@click.option("--pretty", is_flag=True, default=False, help="Pretty print the JSON output.")
def inspect_json(pretty: bool):
    """Resolve the workspace configurations and print in JSON format."""
    name = data.lib.config.WORKSPACE_CACHE.current_workspace
    if not name:
        click.echo(styled([Style.BRIGHT, Fore.RED], "No workspace selected."))
        click.echo("Please select a workspace using `x workspace list` and `x workspace default`.")
        exit(1)

    ws = __get_workspace(name)
    info(f"Resolving workspace: {name} ({ws})")
    descriptor = WorkspaceConfig.load_from_descriptor(ws)
    click.echo(descriptor.model_dump_json(indent=4 if pretty else None))


@workspace.command()
@click.option("--pretty", is_flag=True, default=False, help="Pretty print the JSON output.")
def cache(pretty: bool):
    """Print current workspace cache in JSON format."""
    click.echo(data.lib.config.WORKSPACE_CACHE.model_dump_json(indent=4 if pretty else None))


@cli.group()
def config():
    """Configuration related commands."""


@config.command()
def display():
    """Print loaded configuration in JSON format."""
    click.echo(data.lib.config.CONFIGURATION.model_dump_json(indent=4))


@cli.group(aliases=["gen"], cls=ClickAliasedGroup)
@click.option(
    "--format",
    "-f",
    "format_source",
    is_flag=True,
    default=False,
    help="Run formatter after generation.",
)
@click.pass_context
def generate(ctx: click.Context, format_source: bool):
    """Code generation related commands."""
    ctx.ensure_object(dict)
    ctx.obj["format_source"] = format_source


@generate.command("all")
@click.pass_context
def all_cmd(ctx: click.Context):
    """Generate all code."""
    ctx.invoke(protobuf)
    ctx.invoke(rust_cmd)
    ctx.invoke(dart_build_runner)
    ctx.invoke(gen_l10n)

    if ctx.obj.get("format_source", False):
        ctx.invoke(format_cmd)


@generate.command(aliases=["proto", "pb"])
@click.pass_context
def protobuf(ctx: click.Context):
    """Generate protobuf code for all supported languages."""
    protoc = get_command("protoc")

    total = 0
    failed = set()

    if not PROTOBUF_PYTHON_OUT_PATH.exists():
        warning("Python protobuf output path not found, creating it.")
        PROTOBUF_PYTHON_OUT_PATH.mkdir(parents=True, exist_ok=True)
    if not PROTOBUF_DART_OUT_PATH.exists():
        warning("Dart protobuf output path not found, creating it.")
        PROTOBUF_DART_OUT_PATH.mkdir(parents=True, exist_ok=True)

    for file in PROTOBUF_SCHEMA_PATH.glob("*.proto"):
        click.echo(styled([Style.BRIGHT, Fore.GREEN], "Generating protobuf code for: ") + f"{file}")
        __execute_command(
            [
                protoc,
                f"--proto_path={PROTOBUF_SCHEMA_PATH}",
                f"--python_out={PROTOBUF_PYTHON_OUT_PATH}",
                f"--dart_out={PROTOBUF_DART_OUT_PATH}",
                file.name,
            ],
            "PROTOBUF CODEGEN OUTPUT",
        )
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

    if ctx.obj.get("format_source", False):
        ctx.invoke(format_cmd)


@generate.command("rust", aliases=["rs"])
@click.pass_context
def rust_cmd(ctx: click.Context):
    """Generate flutter-rust-bridge glue code."""
    native_output_dir = PROJECT_ROOT / "lib" / "native"
    if native_output_dir.exists():
        info(f"Removing existing native output directory: {native_output_dir}")
        shutil.rmtree(native_output_dir)
    flutter_rust_bridge_codegen = get_command("flutter_rust_bridge_codegen")
    click.echo(
        styled([Style.BRIGHT, Fore.GREEN], "Executing command: ")
        + "flutter_rust_bridge_codegen generate"
    )
    __execute_command([flutter_rust_bridge_codegen, "generate"], "FRB CODEGEN OUTPUT")
    click.echo(
        styled([Style.BRIGHT, Fore.GREEN], "Rust bridge code generation completed successfully.")
    )

    if ctx.obj.get("format_source", False):
        ctx.invoke(format_cmd)


@generate.command("dart")
@click.option("--watch", "-w", is_flag=True, default=False, help="Run in watch mode.")
@click.pass_context
def dart_build_runner(ctx: click.Context, watch: bool):
    """Run `dart run build_runner build`."""
    click.echo(
        styled([Style.BRIGHT, Fore.GREEN], "Executing codegen: "),
    )
    for codegen in CODEGEN_DART:
        for file in codegen():
            click.echo(f"  Modified {file}")

    dart = get_command("dart")
    click.echo(
        styled([Style.BRIGHT, Fore.GREEN], "Executing command: ")
        + f"dart run build_runner {'watch' if watch else 'build'} --delete-conflicting-outputs"
    )
    __execute_command(
        [
            dart,
            "run",
            "build_runner",
            "watch" if watch else "build",
            "--delete-conflicting-outputs",
        ],
        "DART BUILDRUNNER OUTPUT",
    )
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Dart build runner completed successfully."))

    if ctx.obj.get("format_source", False):
        ctx.invoke(format_cmd)


@generate.command("l10n")
@click.option("--watch", "-w", is_flag=True, default=False, help="Run in watch mode.")
@click.pass_context
def gen_l10n(ctx: click.Context, watch: bool):
    """Generate localization files."""
    if watch:

        async def watch_l10n():
            flutter = get_command("flutter")

            click.echo(
                styled([Style.BRIGHT, Fore.GREEN], "Executing command: ") + "flutter gen-l10n"
            )
            __execute_command(
                [flutter, "gen-l10n"],
                "FLUTTER GEN-L10N OUTPUT",
            )
            async for _ in awatch(str(I18N_ROOT)):
                click.echo(
                    styled([Style.BRIGHT, Fore.GREEN], "Executing command: ") + "flutter gen-l10n"
                )
                __execute_command(
                    [flutter, "gen-l10n"],
                    "FLUTTER GEN-L10N OUTPUT",
                )

        try:
            asyncio.run(watch_l10n())
        except KeyboardInterrupt:
            click.echo(styled([Style.BRIGHT, Fore.YELLOW], "\nWatch mode interrupted by user."))
            return

    flutter = get_command("flutter")
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Executing command: ") + "flutter gen-l10n")
    __execute_command(
        [flutter, "gen-l10n"],
        "FLUTTER GEN-L10N OUTPUT",
    )
    click.echo(
        styled([Style.BRIGHT, Fore.GREEN], "Localization generation completed successfully.")
    )

    if ctx.obj.get("format_source", False):
        ctx.invoke(format_cmd)


@cli.group(aliases=["env"], cls=ClickAliasedGroup)
def environment():
    """Environment related commands."""


@environment.command(
    context_settings={
        "ignore_unknown_options": True,
        "allow_extra_args": True,
    }
)
@click.option(
    "--python",
    "--py",
    is_flag=True,
    default=False,
    help="Treat all arguments as python packages.\nThis will forward the command to `uv add`.",
)
@click.option(
    "--rust",
    "--rs",
    is_flag=True,
    default=False,
    help="Treat all arguments as python packages.\nThis will forward the command to `uv add`.",
)
@click.option(
    "--dart",
    "--flutter",
    "--fl",
    is_flag=True,
    default=False,
    help="Treat all arguments as python packages.\nThis will forward the command to `uv add`.",
)
@click.option("--dry-run", is_flag=True, default=False, help="Show the command without executing.")
@click.pass_context
def add(ctx: click.Context, python, rust, dart, dry_run):
    """Add new tool to the current environment.

    This command accept the following syntax:

    \b
    If `--python`, `-p` is specified, then all arguments after it are treated as python packages to install.
        The command will be directly passed to `uv add`.
    If `--dart`, `-d`, `--flutter`, `-f` is specified, then all arguments after it are treated as dart packages to install.
        The command will be directly passed to `flutter pub add`.
    If `--rust`, `-r` is specified, then all arguments after it are treated as rust packages to install.
        The command will be directly passed to `cargo add`.
    If none of the above is specified, then:
        If the package starts with `py:` or `python:`, it is treated as a python package to install.
            If the package starts with `dev:`, it is treated as a development dependency.
        If the package starts with `dart:`, `flutter:` or `fl:`, it is treated as a dart package to install.
            all package literals will be forwarded to `flutter pub add`.
        If the package starts with `rs:` or `rust:` it is treated as a rust package to install.
            If the package starts with `dev:`, it is treated as a development dependency.
            If the package starts with `build:`, it is treated as a build dependency.
        If not specified, the package won't be installed.
    """

    if len(list(filter(None, [python, rust, dart]))) > 1:
        click.echo(
            styled([Style.BRIGHT, Fore.RED], "Invalid usage: ")
            + "Only one of --python, --dart/--flutter, --rust can be specified."
        )
        exit(1)

    argv = list(ctx.args)
    if python:
        if len(argv) == 0:
            click.echo(
                styled([Style.BRIGHT, Fore.RED], "Invalid usage: ") + "No package specified to add."
            )
            exit(1)
        uv = get_command("uv")
        click.echo(
            styled([Style.BRIGHT, Fore.GREEN], "Executing command: ") + f"uv add {' '.join(argv)}"
        )
        __execute_command([uv, "add", *argv], "UV ADD OUTPUT")
        click.echo(styled([Style.BRIGHT, Fore.GREEN], "Python package(s) added successfully."))
        return
    elif dart:
        if len(argv) == 0:
            click.echo(
                styled([Style.BRIGHT, Fore.RED], "Invalid usage: ") + "No package specified to add."
            )
            exit(1)
        flutter = get_command("flutter")
        click.echo(
            styled([Style.BRIGHT, Fore.GREEN], "Executing command: ")
            + f"flutter pub add {' '.join(argv)}"
        )
        __execute_command([flutter, "pub", "add", *argv], "FLUTTER PUB ADD OUTPUT")
        click.echo(styled([Style.BRIGHT, Fore.GREEN], "Dart package(s) added successfully."))
        return
    elif rust:
        if len(argv) == 0:
            click.echo(
                styled([Style.BRIGHT, Fore.RED], "Invalid usage: ") + "No package specified to add."
            )
            exit(1)
        cargo = get_command("cargo")
        click.echo(
            styled([Style.BRIGHT, Fore.GREEN], "Executing command: ")
            + f"cargo add {' '.join(argv)}"
        )
        __execute_command([cargo, "add", *argv], "CARGO ADD OUTPUT")
        click.echo(styled([Style.BRIGHT, Fore.GREEN], "Rust package(s) added successfully."))
        return

    # parse arguments
    pkgs = {
        "python": {
            "norm": [],
            "dev": [],
        },
        "dart": [],
        "rust": {
            "norm": [],
            "dev": [],
            "build": [],
        },
        "unknown": [],
    }
    for arg in argv:
        if arg.startswith(("py:", "python:")):
            inner = arg.split(":", 1)[1].strip()
            if len(inner) == 0:
                pkgs["unknown"].append(arg)
            elif inner.startswith("dev:"):
                pkg = inner.split(":", 1)[1].strip()
                if len(pkg) == 0:
                    pkgs["unknown"].append(arg)
                else:
                    pkgs["python"]["dev"].append(pkg)
            else:
                pkgs["python"]["norm"].append(inner)
        elif arg.startswith(("dart:", "flutter:", "fl:")):
            inner = arg.split(":", 1)[1].strip()
            if len(inner) == 0:
                pkgs["unknown"].append(arg)
            else:
                pkgs["dart"].append(inner)
        elif arg.startswith(("rs:", "rust:")):
            inner = arg.split(":", 1)[1].strip()
            if len(inner) == 0:
                pkgs["unknown"].append(arg)
            elif inner.startswith("dev:"):
                pkg = inner.split(":", 1)[1].strip()
                if len(pkg) == 0:
                    pkgs["unknown"].append(arg)
                else:
                    pkgs["rust"]["dev"].append(pkg)
            elif inner.startswith("build:"):
                pkg = inner.split(":", 1)[1].strip()
                if len(pkg) == 0:
                    pkgs["unknown"].append(arg)
                else:
                    pkgs["rust"]["build"].append(pkg)
            else:
                pkgs["rust"]["norm"].append(inner)
        else:
            pkgs["unknown"].append(arg)

    if (x := sum(map(len, pkgs["python"].values()))) > 0:
        click.echo(
            styled(Fore.GREEN, "Adding ")
            + styled([Style.BRIGHT, Fore.GREEN], f"{x}")
            + styled(Fore.GREEN, f" python package{'s' if x > 1 else ''}.")
        )
        uv = get_command("uv")
        norm = pkgs["python"]["norm"]
        if len(norm) > 0:
            click.echo(
                f"  · Adding normal package{'s' if len(norm) > 1 else ''}: " + ", ".join(norm)
            )
            __execute_command(
                [uv, "add", *norm],
                "UV ADD OUTPUT (NORMAL)",
            )

        dev = pkgs["python"]["dev"]
        if len(dev) > 0:
            click.echo(f"  · Adding dev package{'s' if len(dev) > 1 else ''}: " + ", ".join(dev))
            __execute_command(
                [uv, "add", "--dev", *dev],
                "UV ADD OUTPUT (DEV)",
            )

    if (x := len(pkgs["dart"])) > 0:
        click.echo(
            styled(Fore.GREEN, "Adding ")
            + styled([Style.BRIGHT, Fore.GREEN], f"{x}")
            + styled(Fore.GREEN, f" dart package{'s' if x > 1 else ''}.")
        )
        flutter = get_command("flutter")
        click.echo(f"  · Adding package{'s' if x > 1 else ''}: " + ", ".join(pkgs["dart"]))
        __execute_command(
            [flutter, "pub", "add", *pkgs["dart"]],
            "FLUTTER PUB ADD OUTPUT",
        )

    if (x := sum(map(len, pkgs["rust"].values()))) > 0:
        click.echo(
            styled(Fore.GREEN, "Adding ")
            + styled([Style.BRIGHT, Fore.GREEN], f"{x}")
            + styled(Fore.GREEN, f" rust package{'s' if x > 1 else ''}.")
        )
        cargo = get_command("cargo")
        norm = pkgs["rust"]["norm"]
        if len(norm) > 0:
            click.echo(
                f"  · Adding normal package{'s' if len(norm) > 1 else ''}: " + ", ".join(norm)
            )
            __execute_command(
                [cargo, "add", *norm],
                "CARGO ADD OUTPUT (NORMAL)",
            )

        dev = pkgs["rust"]["dev"]
        if len(dev) > 0:
            click.echo(f"  · Adding dev package{'s' if len(dev) > 1 else ''}: " + ", ".join(dev))
            __execute_command(
                [cargo, "add", "--dev", *dev],
                "CARGO ADD OUTPUT (DEV)",
            )

        build = pkgs["rust"]["build"]
        if len(build) > 0:
            click.echo(
                f"  · Adding build package{'s' if len(build) > 1 else ''}: " + ", ".join(build)
            )
            __execute_command(
                [cargo, "add", "--build", *build],
                "CARGO ADD OUTPUT (BUILD)",
            )

    if (x := len(pkgs["unknown"])) > 0:
        click.echo(
            styled([Style.BRIGHT, Fore.YELLOW], "Warning: ")
            + f"{x} unknown argument{'s' if x > 1 else ''} ignored: "
            + ", ".join(pkgs["unknown"])
        )


@environment.command()
def install():
    """Install all tools in the current environment."""

    protoc_gen_dart = get_command("protoc-gen-dart")
    if protoc_gen_dart is None:
        click.echo(
            styled([Style.BRIGHT, Fore.RED], "Warning: ") + "protoc-gen-dart not found, installing"
        )
        dart = get_command("dart")
        __execute_command(
            [dart, "pub", "global", "activate", "protoc_plugin"], "DART ACTIVATE OUTPUT"
        )

    uv = get_command("uv")
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Executing command: ") + "uv sync")
    __execute_command([uv, "sync"], "UV SYNC OUTPUT")

    flutter = get_command("flutter")
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Executing command: ") + "flutter pub get")
    __execute_command([flutter, "pub", "get"], "FLUTTER PUB GET OUTPUT")

    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Environment setup completed successfully."))


@environment.command(aliases=["update"])
def upgrade():
    """Upgrade all tools in the current environment."""

    uv = get_command("uv")
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Executing command: ") + "uv sync --upgrade")
    __execute_command([uv, "sync", "--upgrade"], "UV UPGRADE OUTPUT")

    flutter = get_command("flutter")
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Executing command: ") + "flutter pub upgrade")
    __execute_command([flutter, "pub", "upgrade"], "FLUTTER PUB UPGRADE OUTPUT")

    cargo = get_command("cargo")
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Executing command: ") + "cargo update")
    __execute_command([cargo, "update"], "CARGO UPDATE OUTPUT")

    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Environment upgrade completed successfully."))


@cli.group(cls=ClickAliasedGroup)
def build():
    """Build related commands."""


_GENERATOR_TYPES = {"static", "native", "localization", "images"}


@build.command("data")
@click.option(
    "--skip",
    "-s",
    multiple=True,
    help=f"Skip specified data generators. Values: {', '.join(_GENERATOR_TYPES)}",
)
@click.option(
    "--no-hash",
    envvar=SKIP_FULL_HASHLIST_UPDATE_ENV_VAR,
    is_flag=True,
    default=False,
    help="Do not generate hash files for the data bundle.",
)
def data_cmd(skip: list[str], no_hash: bool):
    """Build data files."""
    from data.lib.workspace.generate import run_generator

    to_skip = set()
    for it in skip:
        for i in it.split(","):
            to_skip.add(i.strip().lower())

    if len(x := to_skip.difference(_GENERATOR_TYPES)) > 0:
        click.echo(
            styled([Style.BRIGHT, Fore.RED], "Invalid generator type to skip: ") + ", ".join(x)
        )
        click.echo("Valid types are: " + ", ".join(_GENERATOR_TYPES))
        exit(1)

    name = data.lib.config.WORKSPACE_CACHE.current_workspace
    if not name:
        click.echo(styled([Style.BRIGHT, Fore.RED], "No workspace selected."))
        click.echo("Please select a workspace using `x workspace list` and `x workspace default`.")
        exit(1)

    ws = __get_workspace(name)
    info(f"Resolving workspace: {name} ({ws})")
    descriptor = WorkspaceConfig.load_from_descriptor(ws)

    asyncio.run(run_generator(descriptor, to_skip, not no_hash))


@build.command("increment", aliases=["inc", "incremental"])
@click.argument("hash_list", envvar=DEFAULT_WORKSPACE_HASHLIST_ENV_VAR)
def build_increment_cmd(hash_list: str):
    """Build increment data bundle."""
    from data.lib.workspace.build_increment import build_increment_bundle

    name = data.lib.config.WORKSPACE_CACHE.current_workspace
    if not name:
        click.echo(styled([Style.BRIGHT, Fore.RED], "No workspace selected."))
        click.echo("Please select a workspace using `x workspace list` and `x workspace default`.")
        exit(1)

    ws = __get_workspace(name)
    info(f"Resolving workspace: {name} ({ws})")
    descriptor = WorkspaceConfig.load_from_descriptor(ws)

    hash_list = Path(hash_list)
    build_increment_bundle(descriptor, hash_list)


@cli.group(cls=ClickAliasedGroup)
def etc():
    """Extra toolsets."""


@etc.command("codeart")
def etc_codeart_cmd():
    """Generate the codeart image."""
    warning("Generate codeart requires tokei with json output installed and exported via path.")
    tokei = get_command("tokei")
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Executing command: ") + "tokei . -o json")
    stdout = __execute_command([tokei, ".", "-o", "json"], "TOKEI OUTPUT")

    output_file = PROJECT_ROOT / "codeart.png"
    generate_codeart(stdout, output_file)
    click.echo(
        styled([Style.BRIGHT, Fore.GREEN], "Codeart image generated successfully: ")
        + str(output_file)
    )


cli()
