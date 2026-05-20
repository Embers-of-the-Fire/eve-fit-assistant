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
import os
import shutil
import subprocess
import sys
import time

from pathlib import Path
from urllib.request import urlopen

import click

from click_aliases import ClickAliasedGroup
from colorama import Fore
from colorama import Style
from colorama import init
from dotenv import load_dotenv
from watchfiles import awatch

from data.lib.codegen import CODEGEN_DART
from data.lib.constant import DEFAULT_WORKSPACE_MANIFEST_ENV_VAR
from data.lib.constant import DEV_CONFIG_PATH
from data.lib.constant import I18N_ROOT
from data.lib.constant import NATIVE_LIB_ROOT
from data.lib.constant import PROJECT_ROOT
from data.lib.constant import SKIP_FULL_MANIFEST_UPDATE_ENV_VAR
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


def __resolve_dev_path(path: Path) -> Path:
    data.lib.config.DeveloperConfiguration.ensure_loaded()
    if path.is_absolute():
        return path
    return data.lib.config.DEV_CONFIGURATION.paths.root / path


def __resource_root(value: str) -> str:
    return value.strip("/")


def __remote_channel_index_url(*, origin_url: str, resource_root: str, channel: str) -> str:
    return (
        f"{origin_url.rstrip('/')}/{__resource_root(resource_root)}/channels/{channel}/index.json"
    )


def __wait_for_http(url: str, timeout_seconds: float = 20.0) -> None:
    deadline = time.monotonic() + timeout_seconds
    last_error: Exception | None = None
    while time.monotonic() < deadline:
        try:
            with urlopen(url, timeout=1.0):
                return
        except Exception as exception:
            last_error = exception
            time.sleep(0.25)

    message = f"Timed out waiting for {url}"
    if last_error is not None:
        message += f": {last_error}"
    raise click.ClickException(message)


def __run_foreground(process: subprocess.Popen[str], interrupted_message: str) -> None:
    try:
        return_code = process.wait()
    except KeyboardInterrupt:
        process.terminate()
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
        click.echo(styled([Style.BRIGHT, Fore.YELLOW], interrupted_message))
        return

    if return_code != 0:
        raise click.ClickException(f"Remote mock process exited with status {return_code}.")


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


def __get_current_workspace_descriptor() -> WorkspaceConfig:
    name = data.lib.config.WORKSPACE_CACHE.current_workspace
    if not name:
        click.echo(styled([Style.BRIGHT, Fore.RED], "No workspace selected."))
        click.echo("Please select a workspace using `x workspace list` and `x workspace default`.")
        exit(1)

    ws = __get_workspace(name)
    info(f"Resolving workspace: {name} ({ws})")
    return WorkspaceConfig.load_from_descriptor(ws)


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
    descriptor = __get_current_workspace_descriptor()
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
    """Run `flutter pub run build_runner build`."""
    click.echo(
        styled([Style.BRIGHT, Fore.GREEN], "Executing codegen: "),
    )
    for codegen in CODEGEN_DART:
        for file in codegen():
            click.echo(f"  Modified {file}")

    flutter = get_command("flutter")
    click.echo(
        styled([Style.BRIGHT, Fore.GREEN], "Executing command: ")
        + f"flutter pub run build_runner {'watch' if watch else 'build'} --delete-conflicting-outputs"
    )
    __execute_command(
        [
            flutter,
            "pub",
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


@generate.group("values", cls=ClickAliasedGroup)
def generate_values():
    """Generate value-dependent code from the selected workspace."""


@generate_values.command("dogma-units")
@click.pass_context
def dogma_units_cmd(ctx: click.Context):
    """Generate dogma unit ID constants."""
    from data.lib.codegen.dogma_unit_id import codegen_dart

    files = asyncio.run(codegen_dart(__get_current_workspace_descriptor()))
    for file in files:
        click.echo(f"  Modified {file}")

    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Dogma unit ID generation completed."))

    if ctx.obj.get("format_source", False):
        ctx.invoke(format_cmd)


def __env_install():
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


def __env_upgrade():
    uv = get_command("uv")
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Executing command: ") + "uv sync --upgrade")
    __execute_command([uv, "sync", "--upgrade"], "UV UPGRADE OUTPUT")

    flutter = get_command("flutter")
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Executing command: ") + "flutter pub upgrade")
    __execute_command([flutter, "pub", "upgrade"], "FLUTTER PUB UPGRADE OUTPUT")

    cargo = get_command("cargo")
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Executing command: ") + "cargo update")
    __execute_command([cargo, "update"], "CARGO UPDATE OUTPUT")


@cli.group(cls=ClickAliasedGroup)
def dev():
    """Developer environment commands."""


@dev.command("init-cfg")
def dev_init_cfg():
    """Create efa.dev.toml from the example template."""
    if DEV_CONFIG_PATH.exists():
        click.echo(
            styled([Style.BRIGHT, Fore.YELLOW], "Warning: ") + "efa.dev.toml already exists."
        )
        return

    template = PROJECT_ROOT / "efa.dev.example.toml"
    shutil.copyfile(template, DEV_CONFIG_PATH)
    click.echo(
        styled([Style.BRIGHT, Fore.GREEN], "Created developer config: ") + str(DEV_CONFIG_PATH)
    )


@dev.group(cls=ClickAliasedGroup)
def env():
    """Developer environment setup commands."""


@env.command("install")
def dev_env_install():
    """Install all tools in the current environment."""
    __env_install()
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Environment setup completed successfully."))


@env.command("upgrade", aliases=["update"])
def dev_env_upgrade():
    """Upgrade all tools in the current environment."""
    __env_upgrade()
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Environment upgrade completed successfully."))


@env.command("write-backend")
def dev_env_write_backend():
    """Write rust/lib/eve-fit-os/.env from efa.dev.toml."""
    data.lib.config.DeveloperConfiguration.ensure_loaded()
    native = data.lib.config.DEV_CONFIGURATION.native

    values = {
        "FSD_FORMAT": native.fsd_format,
        "FSD_BINARY_DIR": native.fsd_binary_dir,
        "FSD_LOC_EN_DIR": native.fsd_loc_en_dir,
        "OUTPUT_DIR": native.output_dir,
    }
    missing = [key for key, value in values.items() if value is None]
    if len(missing) > 0:
        raise click.ClickException(
            "Missing native developer config value(s): " + ", ".join(sorted(missing))
        )

    env_path = NATIVE_LIB_ROOT / ".env"
    lines = [f"{key}={value}" for key, value in values.items()]
    env_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Wrote backend env: ") + str(env_path))


@cli.group(cls=ClickAliasedGroup)
def remote():
    """Remote mock and publishing helper commands."""


@remote.group("config", cls=ClickAliasedGroup)
def remote_config():
    """Remote mock configuration commands."""


@remote_config.command("display")
@click.option("--pretty", is_flag=True, default=False, help="Pretty print the JSON output.")
def remote_config_display(pretty: bool):
    """Print effective remote developer configuration."""
    data.lib.config.DeveloperConfiguration.ensure_loaded()
    remote_cfg = data.lib.config.DEV_CONFIGURATION.remote
    paths = data.lib.config.DEV_CONFIGURATION.paths
    origin_path = __resolve_dev_path(remote_cfg.mock_origin_dir)
    minio_data_path = __resolve_dev_path(remote_cfg.minio_data_dir)
    static_origin_url = f"http://{remote_cfg.host}:{remote_cfg.static_port}"
    minio_origin_url = f"http://{remote_cfg.host}:{remote_cfg.minio_port}/{remote_cfg.minio_bucket}"
    payload = {
        "remote": remote_cfg.model_dump(mode="json"),
        "resolved": {
            "developerRoot": str(paths.root),
            "mockOriginPath": str(origin_path),
            "minioDataPath": str(minio_data_path),
            "staticIndexUrl": __remote_channel_index_url(
                origin_url=static_origin_url,
                resource_root=remote_cfg.resource_root,
                channel=remote_cfg.channel,
            ),
            "minioIndexUrl": __remote_channel_index_url(
                origin_url=minio_origin_url,
                resource_root=remote_cfg.resource_root,
                channel=remote_cfg.channel,
            ),
        },
    }
    import json

    click.echo(json.dumps(payload, indent=4 if pretty else None))


@remote.group(cls=ClickAliasedGroup)
def mock():
    """Remote mock origin commands."""


def __materialize_remote_mock(origin_dir: Path, clean: bool) -> None:
    source_dir = PROJECT_ROOT / "docs" / "examples" / "remote" / "mock-origin"
    if not source_dir.exists():
        raise click.ClickException(f"Missing remote mock fixture directory: {source_dir}")

    if clean and origin_dir.exists():
        shutil.rmtree(origin_dir)

    origin_dir.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(source_dir, origin_dir, dirs_exist_ok=True)
    click.echo(
        styled([Style.BRIGHT, Fore.GREEN], "Materialized remote mock origin: ") + str(origin_dir)
    )


@mock.command("materialize")
@click.option("--origin-dir", type=click.Path(path_type=Path), default=None)
@click.option("--clean", is_flag=True, default=False, help="Remove the origin directory first.")
def remote_mock_materialize(origin_dir: Path | None, clean: bool):
    """Copy committed remote mock fixtures into the configured origin directory."""
    data.lib.config.DeveloperConfiguration.ensure_loaded()
    remote_cfg = data.lib.config.DEV_CONFIGURATION.remote
    resolved_origin_dir = __resolve_dev_path(origin_dir or remote_cfg.mock_origin_dir)
    __materialize_remote_mock(resolved_origin_dir, clean)


def __start_static_remote_mock(host: str, port: int, origin_dir: Path) -> None:
    python = get_command("python3")
    command = [
        python,
        "-m",
        "http.server",
        str(port),
        "--bind",
        host,
        "--directory",
        str(origin_dir),
    ]
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Executing command: ") + " ".join(command))
    if DRY_RUN:
        return
    process = subprocess.Popen(command, text=True)
    __run_foreground(process, "\nStatic remote mock interrupted by user.")


def __start_minio_remote_mock(
    *,
    host: str,
    port: int,
    console_port: int,
    origin_dir: Path,
    data_dir: Path,
    bucket: str,
    access_key: str,
    secret_key: str,
    clean_bucket: bool,
) -> None:
    data_dir.mkdir(parents=True, exist_ok=True)
    endpoint = f"http://{host}:{port}"
    console_endpoint = f"http://{host}:{console_port}"
    command = [
        "minio",
        "server",
        str(data_dir),
        "--address",
        f"{host}:{port}",
        "--console-address",
        f"{host}:{console_port}",
    ]
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Executing command: ") + " ".join(command))
    if DRY_RUN:
        return

    minio = get_command("minio")
    mc = get_command("mc")
    command[0] = minio
    env = os.environ.copy()
    env["MINIO_ROOT_USER"] = access_key
    env["MINIO_ROOT_PASSWORD"] = secret_key
    process = subprocess.Popen(command, env=env, text=True)
    try:
        __wait_for_http(f"{endpoint}/minio/health/ready")
        alias_name = "efa-remote-mock"
        setup_commands = [
            [mc, "alias", "set", alias_name, endpoint, access_key, secret_key],
            [mc, "mb", "--ignore-existing", "-p", f"{alias_name}/{bucket}"],
        ]
        if clean_bucket:
            setup_commands.append([mc, "rm", "--recursive", "--force", f"{alias_name}/{bucket}"])
        setup_commands.append([mc, "anonymous", "set", "download", f"{alias_name}/{bucket}"])
        setup_commands.append(
            [mc, "mirror", "--overwrite", str(origin_dir), f"{alias_name}/{bucket}"]
        )
        for setup_command in setup_commands:
            __execute_command(setup_command, "MINIO MOCK SETUP")

        click.echo(styled([Style.BRIGHT, Fore.GREEN], "MinIO console: ") + console_endpoint)
        __run_foreground(process, "\nMinIO remote mock interrupted by user.")
    except Exception:
        process.terminate()
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
        raise


@mock.command("launch")
@click.option(
    "--backend",
    type=click.Choice(["static", "minio"], case_sensitive=False),
    default="static",
    show_default=True,
)
@click.option("--host", default=None, help="Override remote mock host.")
@click.option("--port", type=int, default=None, help="Override static or MinIO API port.")
@click.option("--console-port", type=int, default=None, help="Override MinIO console port.")
@click.option("--bucket", default=None, help="Override MinIO bucket name.")
@click.option("--access-key", default=None, help="Override MinIO access key.")
@click.option("--secret-key", default=None, help="Override MinIO secret key.")
@click.option("--origin-dir", type=click.Path(path_type=Path), default=None)
@click.option("--data-dir", type=click.Path(path_type=Path), default=None)
@click.option("--resource-root", default=None, help="Override remote resource root.")
@click.option("--channel", default=None, help="Override remote channel.")
@click.option(
    "--no-materialize", is_flag=True, default=False, help="Do not refresh origin fixtures."
)
@click.option(
    "--clean-origin", is_flag=True, default=False, help="Clean origin before materializing."
)
@click.option(
    "--clean-bucket", is_flag=True, default=False, help="Clean MinIO bucket before mirroring."
)
def remote_mock_launch(
    backend: str,
    host: str | None,
    port: int | None,
    console_port: int | None,
    bucket: str | None,
    access_key: str | None,
    secret_key: str | None,
    origin_dir: Path | None,
    data_dir: Path | None,
    resource_root: str | None,
    channel: str | None,
    no_materialize: bool,
    clean_origin: bool,
    clean_bucket: bool,
):
    """Launch a local remote mock through static HTTP or MinIO."""
    data.lib.config.DeveloperConfiguration.ensure_loaded()
    remote_cfg = data.lib.config.DEV_CONFIGURATION.remote
    resolved_host = host or remote_cfg.host
    resolved_resource_root = resource_root or remote_cfg.resource_root
    resolved_channel = channel or remote_cfg.channel
    resolved_origin_dir = __resolve_dev_path(origin_dir or remote_cfg.mock_origin_dir)

    if not no_materialize:
        __materialize_remote_mock(resolved_origin_dir, clean_origin)
    elif not resolved_origin_dir.exists():
        raise click.ClickException(f"Remote mock origin does not exist: {resolved_origin_dir}")

    if backend.lower() == "static":
        resolved_port = port or remote_cfg.static_port
        origin_url = f"http://{resolved_host}:{resolved_port}"
        click.echo(
            styled([Style.BRIGHT, Fore.GREEN], "Remote index URL: ")
            + __remote_channel_index_url(
                origin_url=origin_url,
                resource_root=resolved_resource_root,
                channel=resolved_channel,
            )
        )
        __start_static_remote_mock(resolved_host, resolved_port, resolved_origin_dir)
        return

    resolved_port = port or remote_cfg.minio_port
    resolved_console_port = console_port or remote_cfg.minio_console_port
    resolved_bucket = bucket or remote_cfg.minio_bucket
    resolved_access_key = access_key or remote_cfg.minio_access_key
    resolved_secret_key = secret_key or remote_cfg.minio_secret_key
    resolved_data_dir = __resolve_dev_path(data_dir or remote_cfg.minio_data_dir)
    origin_url = f"http://{resolved_host}:{resolved_port}/{resolved_bucket}"
    click.echo(
        styled([Style.BRIGHT, Fore.GREEN], "Remote index URL: ")
        + __remote_channel_index_url(
            origin_url=origin_url,
            resource_root=resolved_resource_root,
            channel=resolved_channel,
        )
    )
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "MinIO data path: ") + str(resolved_data_dir))
    __start_minio_remote_mock(
        host=resolved_host,
        port=resolved_port,
        console_port=resolved_console_port,
        origin_dir=resolved_origin_dir,
        data_dir=resolved_data_dir,
        bucket=resolved_bucket,
        access_key=resolved_access_key,
        secret_key=resolved_secret_key,
        clean_bucket=clean_bucket,
    )


@cli.group(aliases=["env"], cls=ClickAliasedGroup)
def environment():
    """Environment related commands. Prefer `x dev env`."""


@env.command(
    "add",
    context_settings={
        "ignore_unknown_options": True,
        "allow_extra_args": True,
    },
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
    help="Treat all arguments as rust packages.\nThis will forward the command to `cargo add`.",
)
@click.option(
    "--dart",
    "--flutter",
    "--fl",
    is_flag=True,
    default=False,
    help="Treat all arguments as dart packages.\nThis will forward the command to `flutter pub add`.",
)
@click.option("--dry-run", is_flag=True, default=False, help="Show the command without executing.")
@click.pass_context
def dev_env_add(ctx: click.Context, python, rust, dart, dry_run):
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

    if dry_run:
        click.echo(
            styled([Style.BRIGHT, Fore.YELLOW], "Warning: ")
            + "--dry-run is not supported for env add; no package manager command was executed."
        )
        return

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
    help="Treat all arguments as rust packages.\nThis will forward the command to `cargo add`.",
)
@click.option(
    "--dart",
    "--flutter",
    "--fl",
    is_flag=True,
    default=False,
    help="Treat all arguments as dart packages.\nThis will forward the command to `flutter pub add`.",
)
@click.option("--dry-run", is_flag=True, default=False, help="Show the command without executing.")
@click.pass_context
def add(ctx: click.Context, python, rust, dart, dry_run):
    """Add new tool to the current environment. Prefer `x dev env add`."""
    dev_env_add.callback(python, rust, dart, dry_run)


@environment.command()
def install():
    """Install all tools in the current environment. Prefer `x dev env install`."""
    __env_install()
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Environment setup completed successfully."))


@environment.command(aliases=["update"])
def upgrade():
    """Upgrade all tools in the current environment. Prefer `x dev env upgrade`."""
    __env_upgrade()
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
    envvar=SKIP_FULL_MANIFEST_UPDATE_ENV_VAR,
    is_flag=True,
    default=False,
    help="Do not generate the snapshot manifest for the data bundle.",
)
def data_cmd(skip: list[str], no_hash: bool):
    """Build data files."""
    from data.lib.workspace.generate import run_generator

    if not no_hash:
        no_hash = data.lib.config.DEV_CONFIGURATION.build.skip_hash

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

    asyncio.run(run_generator(__get_current_workspace_descriptor(), to_skip, not no_hash))


@build.command("docs", aliases=["doc"])
def build_docs_cmd():
    """Build bundled document assets."""
    from data.lib.docs import build_documents

    try:
        build_documents()
    except ValueError as exception:
        raise click.ClickException(str(exception)) from exception


@build.command("increment", aliases=["inc", "incremental"])
@click.argument("baseline_manifest_path", required=False, envvar=DEFAULT_WORKSPACE_MANIFEST_ENV_VAR)
def build_increment_cmd(baseline_manifest_path: str | None):
    """Build incremental patch bundle."""
    from data.lib.workspace.build_increment import build_increment_bundle

    if baseline_manifest_path is None:
        baseline_manifest = data.lib.config.DEV_CONFIGURATION.build.baseline
        if baseline_manifest is None:
            raise click.ClickException(
                "Missing baseline manifest. Pass one as an argument or set build.baseline in efa.dev.toml."
            )
    else:
        baseline_manifest = Path(baseline_manifest_path)

    build_increment_bundle(__get_current_workspace_descriptor(), baseline_manifest)


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
