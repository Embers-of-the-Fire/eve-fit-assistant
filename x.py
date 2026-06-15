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
import datetime
import hashlib
import json
import os
import shutil
import subprocess
import sys
import time
import zipfile

from pathlib import Path
from urllib.parse import unquote
from urllib.request import urlopen

import click

from click_aliases import ClickAliasedGroup
from colorama import Fore
from colorama import Style
from colorama import init
from dotenv import load_dotenv
from watchfiles import awatch

from data.lib.codegen import CODEGEN_DART
from data.lib.constant import DEV_CONFIG_PATH
from data.lib.constant import I18N_ROOT
from data.lib.constant import NATIVE_LIB_ROOT
from data.lib.constant import PROJECT_ROOT
from data.lib.etc.codeart import generate_codeart
from data.lib.remote.channel import Channel


def __fix_env():
    sys.path.insert(0, str((PROJECT_ROOT / "data" / "lib" / "schema").resolve()))
    load_dotenv()


__fix_env()

import data.lib.config

from ci.commands import register_ci_commands
from ci.lint import run_lint as _ci_lint
from data.lib.color import styled
from data.lib.config import ProjectConfiguration
from data.lib.config import WorkspaceCache
from data.lib.constant import PROTOBUF_DART_OUT_PATH
from data.lib.constant import PROTOBUF_PYTHON_OUT_PATH
from data.lib.constant import PROTOBUF_SCHEMA_PATH
from data.lib.log import info
from data.lib.log import warning
from data.lib.remote import SessionManager
from data.lib.utils import execute_command
from data.lib.utils import get_bin_size
from data.lib.utils import get_command
from data.lib.utils import get_file_sha1
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


def __execute_command(
    cmd: list, title: str, capture_stdout: bool = False, live_stdout: bool = False
) -> str:
    global DRY_RUN

    return execute_command(cmd, title, DRY_RUN, capture_stdout, live_stdout)


def __resolve_dev_path(path: Path) -> Path:
    data.lib.config.DeveloperConfiguration.ensure_loaded()
    if path.is_absolute():
        return path
    return data.lib.config.DEV_CONFIGURATION.paths.root / path


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


def __validate_remote_resource_root(resource_root: str) -> str:
    normalized = resource_root.strip().strip("/")
    parts = normalized.split("/")
    if (
        not normalized
        or resource_root.strip().startswith("/")
        or ".." in parts
        or any(part == "" for part in parts)
        or "://" in normalized
    ):
        raise click.ClickException(f"Invalid remote resource root: {resource_root!r}")
    return normalized


def __validate_remote_channel(channel: str) -> Channel:
    normalized = channel.strip()
    if not normalized or "/" in normalized or ".." in normalized or "%2e" in normalized.lower():
        raise click.ClickException(f"Invalid remote channel: {channel!r}")
    try:
        return Channel(normalized)
    except ValueError:
        raise click.ClickException(
            f"Unknown remote channel: {channel!r}. "
            f"Expected one of: {', '.join(c.value for c in Channel)}"
        ) from None


def __validate_remote_document_id(document_id: str) -> str:
    normalized = document_id.strip()
    if not normalized or "/" in normalized or ".." in normalized or ".." in unquote(normalized):
        raise click.ClickException(f"Invalid remote document id: {document_id!r}")
    return normalized


def __validate_remote_artifact_id(artifact_id: str) -> str:
    normalized = artifact_id.strip()
    if (
        not normalized
        or normalized.startswith("-")
        or "/" in normalized
        or ".." in normalized
        or ".." in unquote(normalized)
        or any(character.isspace() for character in normalized)
    ):
        raise click.ClickException(f"Invalid remote bundle artifact id: {artifact_id!r}")
    return normalized


def __utc_timestamp() -> str:
    return (
        datetime.datetime.now(datetime.UTC)
        .replace(microsecond=0)
        .isoformat()
        .replace("+00:00", "Z")
    )


def __read_current_app_version() -> str:
    pubspec_path = PROJECT_ROOT / "pubspec.yaml"
    for line in pubspec_path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if stripped.startswith("version:"):
            return stripped.removeprefix("version:").strip()
    raise click.ClickException(f"Unable to read app version from {pubspec_path}")


def __read_json_object(path: Path, default: dict[str, object]) -> dict[str, object]:
    if not path.exists():
        return dict(default)
    if not path.is_file():
        raise click.ClickException(f"JSON path is not a file: {path}")
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exception:
        raise click.ClickException(f"Invalid JSON in {path}: {exception.msg}") from exception
    if not isinstance(payload, dict):
        raise click.ClickException(f"JSON payload must be an object: {path}")
    return payload


def __write_json_object(path: Path, payload: dict[str, object]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=4, ensure_ascii=False) + "\n", encoding="utf-8")


def __file_sha256(path: Path) -> str:
    hasher = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            hasher.update(chunk)
    return hasher.hexdigest()


def __read_zip_json(zip_path: Path, member_name: str) -> dict[str, object]:
    if not zip_path.is_file():
        raise click.ClickException(f"Bundle archive does not exist: {zip_path}")
    try:
        with zipfile.ZipFile(zip_path) as archive, archive.open(member_name) as f:
            payload = json.loads(f.read().decode("utf-8"))
    except KeyError as exception:
        raise click.ClickException(
            f"Bundle archive is missing {member_name}: {zip_path}"
        ) from exception
    except UnicodeDecodeError as exception:
        raise click.ClickException(
            f"Bundle archive {member_name} is not valid UTF-8: {zip_path}"
        ) from exception
    except json.JSONDecodeError as exception:
        raise click.ClickException(
            f"Invalid JSON in bundle archive {member_name}: {zip_path}: {exception.msg}"
        ) from exception
    except zipfile.BadZipFile as exception:
        raise click.ClickException(f"Invalid bundle archive: {zip_path}") from exception
    if not isinstance(payload, dict):
        raise click.ClickException(
            f"Bundle archive {member_name} must be a JSON object: {zip_path}"
        )
    return payload


def __validate_mc_target_segment(value: str, label: str) -> str:
    normalized = value.strip()
    if (
        not normalized
        or normalized.startswith("-")
        or "/" in normalized
        or ".." in normalized
        or any(character.isspace() for character in normalized)
    ):
        raise click.ClickException(f"Invalid remote publish {label}: {value!r}")
    return normalized


def __execute_command_redacted(cmd: list[str], redacted_cmd: list[str], title: str) -> None:
    if DRY_RUN:
        info(f"[Dry-Run] {title}: " + " ".join(redacted_cmd))
        return

    out = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if out.returncode != 0:
        message = f"Failed to execute command [{out.returncode}]: " + " ".join(redacted_cmd)
        stderr = (out.stderr or "").strip()
        if stderr:
            message += f"\n{stderr}"
        raise click.ClickException(message)


def __publish_optional_tree(
    mc: str, source: Path, target: str, *, attrs: dict[str, str] | None = None
) -> None:
    if not source.exists():
        warning(f"Remote publish source tree does not exist, skipping: {source}")
        return
    if not source.is_dir():
        raise click.ClickException(f"Remote publish source tree is not a directory: {source}")
    target_base = target.rstrip("/")
    for f in sorted(source.rglob("*")):
        if not f.is_file():
            continue
        rel = f.relative_to(source)
        remote = f"{target_base}/{rel}"
        __publish_optional_file(mc, f, remote, attrs=attrs)


def __publish_optional_file(
    mc: str, source: Path, target: str, *, attrs: dict[str, str] | None = None
) -> None:
    if not source.exists():
        warning(f"Remote publish source file does not exist, skipping: {source}")
        return
    if not source.is_file():
        raise click.ClickException(f"Remote publish source path is not a file: {source}")
    cmd = [mc, "cp"]
    if attrs:
        for k, v in attrs.items():
            cmd.extend(["--attr", f"{k}={v}"])
    cmd.extend([str(source), target])
    __execute_command(cmd, "REMOTE PUBLISH")


def __publish_remote_origin_to_s3(
    *,
    source_dir: Path,
    endpoint: str,
    bucket: str,
    access_key: str,
    secret_key: str,
    alias_name: str,
    resource_root: str,
    channel: Channel,
    generation: str,
    public_download: bool,
    target: str = "minio",
) -> None:
    if not source_dir.exists():
        raise click.ClickException(f"Remote publish source directory does not exist: {source_dir}")
    if not source_dir.is_dir():
        raise click.ClickException(f"Remote publish source path is not a directory: {source_dir}")
    if not endpoint.strip():
        raise click.ClickException("Remote publish endpoint must not be empty.")
    if not access_key:
        raise click.ClickException("Remote publish access key must not be empty.")
    if not secret_key:
        raise click.ClickException("Remote publish secret key must not be empty.")
    if not generation or not generation.strip():
        raise click.ClickException("Remote publish generation must not be empty.")

    resolved_bucket = __validate_mc_target_segment(bucket, "bucket")
    resolved_alias = __validate_mc_target_segment(alias_name, "alias")
    resolved_resource_root = __validate_remote_resource_root(resource_root)
    root_dir = source_dir / resolved_resource_root
    channel_dir = root_dir / "channels" / channel.value
    gen_dir = channel_dir / ".generations" / generation
    index_path = gen_dir / "index.json"

    if not index_path.exists() or not index_path.is_file():
        raise click.ClickException(f"Remote publish generation index does not exist: {index_path}")

    mc = get_command("mc")
    bucket_target = f"{resolved_alias}/{resolved_bucket}"
    redacted = "<redacted>"
    __execute_command_redacted(
        [mc, "alias", "set", resolved_alias, endpoint, access_key, secret_key, "--api", "s3v4"],
        [mc, "alias", "set", resolved_alias, endpoint, redacted, redacted, "--api", "s3v4"],
        "REMOTE PUBLISH ALIAS",
    )
    if target == "minio":
        __execute_command([mc, "mb", "--ignore-existing", bucket_target], "REMOTE PUBLISH")
    if target == "minio":
        if public_download:
            __execute_command([mc, "anonymous", "set", "download", bucket_target], "REMOTE PUBLISH")
        else:
            __execute_command([mc, "anonymous", "set", "none", bucket_target], "REMOTE PUBLISH")

    target_root = f"{bucket_target}/{resolved_resource_root}"
    # Step 1: mirror shared content (idempotent, safe to interrupt)
    __publish_optional_tree(
        mc,
        root_dir / "documents" / "body",
        f"{target_root}/documents/body",
        attrs={
            "Cache-Control": "immutable, max-age=31536000",
            "Content-Type": "text/markdown; charset=utf-8",
        },
    )
    __publish_optional_tree(
        mc,
        root_dir / "bundles",
        f"{target_root}/bundles",
        attrs={"Cache-Control": "immutable, max-age=31536000"},
    )

    # Step 2: mirror generation catalog tree (tiny JSONs, NEW paths)
    channel_attrs = {"Cache-Control": "max-age=300", "Content-Type": "application/json"}
    __publish_optional_tree(
        mc,
        gen_dir / "documents",
        f"{target_root}/channels/{channel}/.generations/{generation}/documents",
        attrs=channel_attrs,
    )
    __publish_optional_tree(
        mc,
        gen_dir / "bundles",
        f"{target_root}/channels/{channel}/.generations/{generation}/bundles",
        attrs=channel_attrs,
    )
    __publish_optional_file(
        mc,
        gen_dir / "app" / "releases.json",
        f"{target_root}/channels/{channel}/.generations/{generation}/app/releases.json",
        attrs=channel_attrs,
    )

    # Step 3: atomic commit — copy generation's index.json to live path
    __publish_optional_file(
        mc,
        index_path,
        f"{target_root}/channels/{channel}/index.json",
        attrs={"Cache-Control": "no-cache", "Content-Type": "application/json"},
    )

    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Uploaded remote origin: ") + str(source_dir))
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Target bucket: ") + bucket_target)
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Generation: ") + generation)
    click.echo(
        styled([Style.BRIGHT, Fore.GREEN], "Remote index URL: ")
        + (
            f"{endpoint.rstrip('/')}/{resolved_bucket}"
            f"/{resolved_resource_root.strip('/')}"
            f"/channels/{channel.value}/index.json"
        )
    )


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
@click.option(
    "--check",
    "check_only",
    is_flag=True,
    default=False,
    help="Check-only mode: verify without modifying files.",
)
@click.option(
    "--lang",
    type=click.Choice(["all", "python", "dart", "rust", "site"]),
    default="all",
    help="Limit linting to a specific language (default: all).",
)
def lint(no_check: bool, check_only: bool, lang: str):
    """Lint, fix and format code"""
    _ci_lint(lang, no_check=no_check, check_only=check_only, dry_run=DRY_RUN)


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
    ctx.obj["_in_generate_all"] = True
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

    if ctx.obj.get("format_source", False) and not ctx.obj.get("_in_generate_all", False):
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

    if ctx.obj.get("format_source", False) and not ctx.obj.get("_in_generate_all", False):
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

    if ctx.obj.get("format_source", False) and not ctx.obj.get("_in_generate_all", False):
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

    if ctx.obj.get("format_source", False) and not ctx.obj.get("_in_generate_all", False):
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


@generate.command("schema")
@click.option(
    "--dir",
    "build_dir",
    type=click.Path(path_type=Path),
    required=True,
    help="Build directory containing workspace output.",
)
@click.option(
    "--server",
    "server_id",
    required=True,
    help="Server ID for the checkout catalog (e.g., 'serenity').",
)
@click.option(
    "--schema-root",
    type=click.Path(path_type=Path),
    default=None,
    help="Unified schema root directory (default from dev config).",
)
def generate_schema_cmd(build_dir: Path, server_id: str, schema_root: Path | None):
    """Generate a V2 schema checkout from workspace build output."""
    from data.lib.workspace.generate.schema import generate_schema_checkout

    if schema_root is None:
        data.lib.config.DeveloperConfiguration.ensure_loaded()
        schema_root = data.lib.config.DEV_CONFIGURATION.paths.schema_dir

    hash_ = generate_schema_checkout(
        config=None,
        build_dir=build_dir,
        schema_root=schema_root,
        server_id=server_id,
    )
    if hash_:
        click.echo(styled([Style.BRIGHT, Fore.GREEN], f"Checkout hash: {hash_}"))
    else:
        click.echo(styled([Style.BRIGHT, Fore.RED], "No files found — checkout not generated."))


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

    if Path("package.json").exists():
        pnpm = get_command("pnpm")
        click.echo(styled([Style.BRIGHT, Fore.GREEN], "Executing command: ") + "pnpm install")
        __execute_command([pnpm, "install"], "PNPM INSTALL OUTPUT")


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
    """Remote content management — prepare, publish, validate, fetch, mock."""


@remote.group("config", cls=ClickAliasedGroup)
def remote_config():
    """Remote mock configuration commands."""


def __redact_remote_config(config: dict[str, object]) -> dict[str, object]:
    redacted = dict(config)
    for sub in ("minio", "s3"):
        if sub in redacted and isinstance(redacted[sub], dict):
            sub_dict = dict(redacted[sub])  # type: ignore[arg-type]
            for key in ("access_key", "secret_key"):
                if key in sub_dict:
                    sub_dict[key] = "<redacted>"
            redacted[sub] = sub_dict
    return redacted


@remote_config.command("display")
@click.option("--pretty", is_flag=True, default=False, help="Pretty print the JSON output.")
@click.option(
    "--json",
    "as_json",
    is_flag=True,
    default=False,
    help="Output as machine-readable JSON (no session info).",
)
def remote_config_display(pretty: bool, as_json: bool):
    """Print effective remote developer configuration and current session status."""
    data.lib.config.DeveloperConfiguration.ensure_loaded()
    data.lib.config.ProjectConfiguration.ensure_loaded()
    remote_cfg = data.lib.config.DEV_CONFIGURATION.remote
    paths = data.lib.config.DEV_CONFIGURATION.paths
    origin_path = __resolve_dev_path(remote_cfg.mock_origin_dir)

    resolved: dict[str, str] = {
        "developerRoot": str(paths.root),
        "mockOriginPath": str(origin_path),
    }

    if remote_cfg.minio is not None:
        minio_data_path = __resolve_dev_path(remote_cfg.minio.data_dir)
        minio_origin_url = (
            f"http://{remote_cfg.host}:{remote_cfg.minio.port}/{remote_cfg.minio.bucket}"
        )
        resolved["minioDataPath"] = str(minio_data_path)
        resolved["minioIndexUrl"] = (
            f"{minio_origin_url.rstrip('/')}"
            f"/{data.lib.config.CONFIGURATION.data_schema.resource_root.strip('/')}"
            f"/channels/{remote_cfg.channel.value}/index.json"
        )

    payload: dict[str, object] = {
        "remote": __redact_remote_config(remote_cfg.model_dump(mode="json")),
        "resolved": resolved,
    }
    click.echo(json.dumps(payload, indent=4 if pretty else None))


# ---- push -------------------------------------------------------------------


def _resolve_schema_root(schema_root: Path | None) -> Path:
    data.lib.config.DeveloperConfiguration.ensure_loaded()
    if schema_root is not None:
        return __resolve_dev_path(schema_root)
    return __resolve_dev_path(data.lib.config.DEV_CONFIGURATION.paths.schema_dir)


@remote.command("push")
@click.argument("channel")
@click.option("--author", default="pipeline", help="Author identifier for the generation.")
@click.option("--description", required=True, help="Description for this generation.")
@click.option(
    "--schema-root",
    type=click.Path(path_type=Path),
    default=None,
    help="Schema V2 storage root (default from dev config).",
)
@click.option(
    "--release-snapshot",
    default=None,
    help="Release snapshot hash to include in the generation.",
)
@click.option(
    "--announcement-snapshot",
    default=None,
    help="Announcement snapshot hash to include in the generation.",
)
def remote_push(
    channel: str,
    author: str,
    description: str,
    schema_root: Path | None,
    release_snapshot: str | None,
    announcement_snapshot: str | None,
):
    """Create a new generation from current resource snapshots and advance the channel head."""

    from data.lib.remote.models import GenerationMetadata
    from data.lib.remote.models import GenerationPointer
    from data.lib.remote.models import GenerationResources
    from data.lib.remote.models import ServerIndex

    root = _resolve_schema_root(schema_root)
    mgr = SessionManager(root)

    resolved_channel = __validate_remote_channel(channel)
    mgr.ensure_channel(resolved_channel)

    resources_dir = root / "assets" / "resources"
    snap_store = mgr.snap_store

    servers: list[tuple[str, dict[str, str], str, str]] = []
    mappings: list[tuple[str, str]] = []

    if resources_dir.is_dir():
        for snap_dir in sorted(resources_dir.iterdir()):
            if not snap_dir.is_dir():
                continue
            if snap_dir.name.startswith("tmp"):
                continue
            try:
                meta, _index = snap_store.load_resource_snapshot(snap_dir.name)
            except Exception:
                continue
            server_id = meta.server_id
            if not server_id:
                continue

            name_map = {"en": server_id}
            servers.append((server_id, name_map, meta.game_build, meta.game_version))
            mappings.append((server_id, snap_dir.name))

    if not servers:
        raise click.ClickException(
            "No resource snapshots found. Run './x build data' first to generate snapshots."
        )

    server_index = ServerIndex()
    server_index.schema_version = 1
    for sid, name_map, build, version in servers:
        entry = server_index.servers.add()
        entry.server_id = sid
        for loc, dn in name_map.items():
            entry.name[loc] = dn
        entry.game_build = build
        entry.game_version = version

    gen_resources = GenerationResources()
    gen_resources.schema_version = 1
    for sid, snap_hash in mappings:
        entry = gen_resources.entries.add()
        entry.server_id = sid
        entry.snapshot_hash = snap_hash

    release_ptr = GenerationPointer()
    release_ptr.schema_version = 1
    if release_snapshot:
        release_ptr.snapshot_hash = release_snapshot

    announcement_ptr = GenerationPointer()
    announcement_ptr.schema_version = 1
    if announcement_snapshot:
        announcement_ptr.snapshot_hash = announcement_snapshot

    current_head = mgr.head_store._safe_get_head(resolved_channel)
    parent = current_head.generation_hash if current_head and current_head.generation_hash else None

    ts = __utc_timestamp()
    meta = GenerationMetadata(
        channel=resolved_channel,
        author=author,
        timestamp=ts,
        description=description,
        subject="",
        parent=parent,
    )

    gen_hash = mgr.create_generation(
        metadata=meta,
        server_index=server_index,
        resources=gen_resources,
        release_pointer=release_ptr,
        announcement_pointer=announcement_ptr,
    )

    mgr.push(resolved_channel, gen_hash, author=author)

    click.echo(styled([Style.BRIGHT, Fore.GREEN], f"Generation created: {gen_hash[:16]}..."))
    click.echo(styled([Style.BRIGHT, Fore.GREEN], f"Head advanced on channel {resolved_channel}"))
    click.echo(styled(Style.DIM, f"  Servers: {', '.join(s[0] for s in servers)}"))
    click.echo(styled(Style.DIM, f"  Parent:  {parent or 'none (root)'}"))


# ---- revert -----------------------------------------------------------------


@remote.command("revert")
@click.argument("channel")
@click.argument("gen_hash")
@click.option("--author", default="pipeline", help="Author identifier for the revert.")
@click.option(
    "--schema-root",
    type=click.Path(path_type=Path),
    default=None,
    help="Schema V2 storage root (default from dev config).",
)
def remote_revert(
    channel: str,
    gen_hash: str,
    author: str,
    schema_root: Path | None,
):
    """Revert the channel head to a previous generation (pointer move only)."""
    root = _resolve_schema_root(schema_root)
    mgr = SessionManager(root)

    resolved_channel = __validate_remote_channel(channel)
    mgr.revert(resolved_channel, gen_hash, author=author)

    click.echo(
        styled([Style.BRIGHT, Fore.GREEN], f"Channel {resolved_channel} reverted to")
        + f" {gen_hash[:16]}..."
    )


# ---- gc ---------------------------------------------------------------------


@remote.command("gc")
@click.option(
    "--dry-run",
    is_flag=True,
    default=False,
    help="List what would be deleted without actually deleting.",
)
@click.option(
    "--schema-root",
    type=click.Path(path_type=Path),
    default=None,
    help="Schema V2 storage root (default from dev config).",
)
def remote_gc(dry_run: bool, schema_root: Path | None):
    """Garbage collect unreferenced entities from local V2 storage."""
    root = _resolve_schema_root(schema_root)
    mgr = SessionManager(root)

    deleted = mgr.gc(dry_run=dry_run)

    if dry_run:
        if not deleted:
            click.echo("Nothing to prune.")
            return
        click.echo(f"Would delete {len(deleted)} unreferenced entity(ies):")
        for path in sorted(deleted):
            click.echo(f"  {path}")
    else:
        if not deleted:
            click.echo("Nothing to prune.")
            return
        click.echo(
            styled([Style.BRIGHT, Fore.GREEN], f"Pruned {len(deleted)} unreferenced entity(ies):")
        )
        for path in sorted(deleted):
            click.echo(styled(Style.DIM, f"  {path}"))


# ---- verify -----------------------------------------------------------------


@remote.command("verify")
@click.option(
    "--repair",
    is_flag=True,
    default=False,
    help="Attempt to repair issues from workspace origin.",
)
@click.option(
    "--schema-root",
    type=click.Path(path_type=Path),
    default=None,
    help="Schema V2 storage root (default from dev config).",
)
def remote_verify(repair: bool, schema_root: Path | None):
    """Verify integrity of heads, generations, snapshots, and blobs."""
    root = _resolve_schema_root(schema_root)
    mgr = SessionManager(root)

    if repair:
        fixed = mgr.repair()
        if fixed > 0:
            click.echo(styled([Style.BRIGHT, Fore.GREEN], f"Repaired {fixed} entity(ies)."))
        else:
            click.echo("No entities needed repair.")
        return

    all_issues = mgr.verify()
    total = sum(len(v) for v in all_issues.values())
    if total == 0:
        click.echo(styled([Style.BRIGHT, Fore.GREEN], "All entities passed verification."))
        return

    for category, issues in all_issues.items():
        if not issues:
            continue
        click.echo(f"\n  {styled([Style.BRIGHT, Fore.CYAN], category.capitalize())}:")
        for issue in issues:
            color = Fore.RED if issue.severity == "error" else Fore.YELLOW
            click.echo(
                f"    {styled([Style.BRIGHT, color], issue.severity.upper())} "
                f"[{issue.entity_type}] {issue.entity}: {issue.message}"
            )

    error_count = sum(sum(1 for i in v if i.severity == "error") for v in all_issues.values())
    warn_count = total - error_count
    summary = f"{total} issue(s): {error_count} error(s), {warn_count} warning(s)"
    if error_count:
        click.echo(styled([Style.BRIGHT, Fore.RED], f"\nVerification failed — {summary}"))
    else:
        click.echo(styled([Style.BRIGHT, Fore.YELLOW], f"\nVerification complete — {summary}"))


# ---- publish ----------------------------------------------------------------


@remote.command("publish")
@click.argument("channel")
@click.option(
    "--target",
    type=click.Choice(["minio", "s3"], case_sensitive=False),
    required=True,
    help="S3-compatible upload target.",
)
@click.option("--endpoint", required=True, help="S3-compatible endpoint URL.")
@click.option("--bucket", required=True, help="Bucket name.")
@click.option("--access-key", required=True, help="Access key.")
@click.option("--secret-key", required=True, help="Secret key.")
@click.option("--alias", "alias_name", required=True, help="mc alias name.")
@click.option(
    "--schema-root",
    type=click.Path(path_type=Path),
    default=None,
    help="Schema V2 storage root (default from dev config).",
)
def remote_publish(
    channel: str,
    target: str,
    endpoint: str,
    bucket: str,
    access_key: str,
    secret_key: str,
    alias_name: str,
    schema_root: Path | None,
):
    """Publish the channel's current head to a remote S3/MinIO bucket."""
    root = _resolve_schema_root(schema_root)
    mgr = SessionManager(root)

    resolved_channel = __validate_remote_channel(channel)

    pub = mgr.make_publisher(
        endpoint=endpoint,
        bucket=bucket,
        access_key=access_key,
        secret_key=secret_key,
        alias_name=alias_name,
    )

    click.echo(styled([Style.BRIGHT, Fore.GREEN], f"Publishing channel {resolved_channel}..."))
    pub.publish_all_for_head(resolved_channel)
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Publish complete."))


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
    alias_name: str,
    resource_root: str,
    channel: Channel,
    clean_bucket: bool,
    public_download: bool,
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
    command[0] = minio
    env = os.environ.copy()
    env["MINIO_ROOT_USER"] = access_key
    env["MINIO_ROOT_PASSWORD"] = secret_key
    process = subprocess.Popen(command, env=env, text=True)
    try:
        __wait_for_http(f"{endpoint}/minio/health/ready")
        if clean_bucket:
            mc = get_command("mc")
            bucket_target = f"{alias_name}/{bucket}"
            redacted = "<redacted>"
            __execute_command_redacted(
                [mc, "alias", "set", alias_name, endpoint, access_key, secret_key, "--api", "s3v4"],
                [mc, "alias", "set", alias_name, endpoint, redacted, redacted, "--api", "s3v4"],
                "REMOTE PUBLISH ALIAS",
            )
            __execute_command_redacted(
                [mc, "mb", "--ignore-existing", bucket_target],
                [mc, "mb", "--ignore-existing", bucket_target],
                "REMOTE CLEAN BUCKET (CREATE)",
            )
            __execute_command_redacted(
                [mc, "rm", "--recursive", "--force", bucket_target],
                [mc, "rm", "--recursive", "--force", bucket_target],
                "REMOTE CLEAN BUCKET",
            )
        mock_generation = __utc_timestamp().replace("-", "").replace(":", "") + "Z"
        __publish_remote_origin_to_s3(
            source_dir=origin_dir,
            endpoint=endpoint,
            bucket=bucket,
            access_key=access_key,
            secret_key=secret_key,
            alias_name=alias_name,
            resource_root=resource_root,
            channel=channel,
            generation=mock_generation,
            public_download=public_download,
        )

        # Attempt V2 publish if mock origin has V2-structured data
        v2_heads_dir = origin_dir / resource_root / "channels" / "heads"
        if v2_heads_dir.is_dir():
            from data.lib.remote import Publisher as V2Publisher

            pub = V2Publisher(
                local_root=origin_dir / resource_root,
                endpoint=endpoint,
                bucket=bucket,
                access_key=access_key,
                secret_key=secret_key,
                alias_name=alias_name,
            )
            pub.publish_all_for_head(channel.value)
            click.echo(styled(Style.DIM, "  V2 head published."))
        else:
            click.echo(styled(Style.DIM, "  No V2 data in mock origin; skipping V2 publish."))

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
@click.option("--host", default=None, help="Override remote mock host.")
@click.option("--port", type=int, default=None, help="Override MinIO API port.")
@click.option("--console-port", type=int, default=None, help="Override MinIO console port.")
@click.option("--bucket", default=None, help="Override MinIO bucket name.")
@click.option("--access-key", default=None, help="Override MinIO access key.")
@click.option("--secret-key", default=None, help="Override MinIO secret key.")
@click.option("--alias", "alias_name", default=None, help="Override mc alias name.")
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
@click.option(
    "--public-download/--private",
    "public_download",
    default=None,
    help="Configure anonymous bucket downloads.",
)
def remote_mock_launch(
    host: str | None,
    port: int | None,
    console_port: int | None,
    bucket: str | None,
    access_key: str | None,
    secret_key: str | None,
    alias_name: str | None,
    origin_dir: Path | None,
    data_dir: Path | None,
    resource_root: str | None,
    channel: str | None,
    no_materialize: bool,
    clean_origin: bool,
    clean_bucket: bool,
    public_download: bool | None,
):
    """Launch a local MinIO remote mock."""
    data.lib.config.DeveloperConfiguration.ensure_loaded()
    data.lib.config.ProjectConfiguration.ensure_loaded()
    remote_cfg = data.lib.config.DEV_CONFIGURATION.remote
    minio = remote_cfg.require_minio()

    resolved_host = host or remote_cfg.host
    resolved_resource_root = (
        resource_root or data.lib.config.CONFIGURATION.data_schema.resource_root
    )
    resolved_channel = __validate_remote_channel(channel or remote_cfg.channel.value)
    resolved_origin_dir = __resolve_dev_path(origin_dir or remote_cfg.mock_origin_dir)

    if not no_materialize:
        __materialize_remote_mock(resolved_origin_dir, clean_origin)
    elif not resolved_origin_dir.exists():
        raise click.ClickException(f"Remote mock origin does not exist: {resolved_origin_dir}")

    resolved_port = port or minio.port
    resolved_console_port = console_port or minio.console_port
    resolved_bucket = bucket or minio.bucket
    resolved_access_key = access_key or minio.access_key
    resolved_secret_key = secret_key or minio.secret_key
    resolved_data_dir = __resolve_dev_path(data_dir or minio.data_dir)
    resolved_alias = alias_name or minio.alias
    resolved_public_download = (
        public_download if public_download is not None else minio.public_download
    )

    origin_url = f"http://{resolved_host}:{resolved_port}/{resolved_bucket}"
    click.echo(
        styled([Style.BRIGHT, Fore.GREEN], "Remote index URL: ")
        + f"{origin_url.rstrip('/')}/{resolved_resource_root.strip('/')}/channels/{resolved_channel.value}/index.json"
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
        alias_name=resolved_alias,
        resource_root=resolved_resource_root,
        channel=resolved_channel,
        clean_bucket=clean_bucket,
        public_download=resolved_public_download,
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
def data_cmd(skip: list[str]):
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

    asyncio.run(run_generator(__get_current_workspace_descriptor(), to_skip))


@build.command("docs", aliases=["doc"])
def build_docs_cmd():
    """Build bundled document assets."""
    from data.lib.docs import build_documents

    try:
        build_documents()
    except ValueError as exception:
        raise click.ClickException(str(exception)) from exception


_ABI_FLUTTER_TO_APK = {
    "armeabi-v7a": "arm",
    "arm64-v8a": "arm64",
    "x86_64": "x64",
}


def _build_apk_copy_and_verify(src_apk: Path, src_sha1: Path, dst_apk: Path, dst_sha1: Path):
    shutil.copy2(src_apk, dst_apk)
    shutil.copy2(src_sha1, dst_sha1)
    expected = src_sha1.read_text(encoding="utf-8").strip()
    actual = get_file_sha1(dst_apk)
    if expected != actual:
        raise click.ClickException(
            f"SHA1 mismatch for {dst_apk.name}: expected {expected}, got {actual}"
        )


@build.command("apk")
@click.option("--clean", is_flag=True, default=False, help="Run `flutter clean` before building.")
@click.option("--flavor", default=None, help="Flutter flavor to build (e.g. dev, prod).")
@click.option(
    "--debug", is_flag=True, default=False, help="Build debug APK (single ABI only, no split)."
)
def build_apk_cmd(clean: bool, flavor: str | None, debug: bool):
    """Build Android APKs with versioned filenames."""
    ProjectConfiguration.ensure_loaded()
    version = data.lib.config.CONFIGURATION.version
    tag = version.render_tag()
    output_root = data.lib.config.CONFIGURATION.paths.apk
    output_dir = output_root / tag
    output_dir.mkdir(parents=True, exist_ok=True)
    apk_source = PROJECT_ROOT / "build" / "app" / "outputs" / "flutter-apk"

    flutter = get_command("flutter")
    flavor_args = [f"--flavor={flavor}"] if flavor else []

    if clean:
        __execute_command([flutter, "clean"], "CLEANING BUILD ARTIFACTS")

    if debug:
        __execute_command([flutter, "build", "apk", "--debug", *flavor_args], "BUILDING DEBUG APK")
        src_prefix = f"app-{flavor}-" if flavor else "app-"
        src_apk = apk_source / f"{src_prefix}debug.apk"
        src_sha1 = apk_source / f"{src_prefix}debug.apk.sha1"
        if not src_apk.exists():
            raise click.ClickException(f"Expected debug APK not found: {src_apk}")
        dst_apk = output_dir / f"{tag}-debug.apk"
        dst_sha1 = output_dir / f"{tag}-debug.apk.sha1"
        _build_apk_copy_and_verify(src_apk, src_sha1, dst_apk, dst_sha1)
    else:
        __execute_command([flutter, "build", "apk", *flavor_args], "BUILDING GENERAL APK")
        src_apk = apk_source / (f"app-{flavor}-release.apk" if flavor else "app-release.apk")
        src_sha1 = apk_source / (
            f"app-{flavor}-release.apk.sha1" if flavor else "app-release.apk.sha1"
        )
        if not src_apk.exists():
            raise click.ClickException(f"Expected general APK not found: {src_apk}")
        dst_apk = output_dir / f"{tag}-general.apk"
        dst_sha1 = output_dir / f"{tag}-general.apk.sha1"
        _build_apk_copy_and_verify(src_apk, src_sha1, dst_apk, dst_sha1)

        __execute_command(
            [flutter, "build", "apk", "--split-per-abi", *flavor_args],
            "BUILDING SPLIT ABI APKS",
        )
        for flutter_abi, apk_suffix in _ABI_FLUTTER_TO_APK.items():
            src_apk = apk_source / (
                f"app-{flavor}-{flutter_abi}-release.apk"
                if flavor
                else f"app-{flutter_abi}-release.apk"
            )
            src_sha1 = apk_source / (
                f"app-{flavor}-{flutter_abi}-release.apk.sha1"
                if flavor
                else f"app-{flutter_abi}-release.apk.sha1"
            )
            if not src_apk.exists():
                raise click.ClickException(f"Expected ABI APK not found: {src_apk}")
            dst_apk = output_dir / f"{tag}-{apk_suffix}.apk"
            dst_sha1 = output_dir / f"{tag}-{apk_suffix}.apk.sha1"
            _build_apk_copy_and_verify(src_apk, src_sha1, dst_apk, dst_sha1)

    click.echo(styled([Style.BRIGHT, Fore.GREEN], f"Build complete. Output: {output_dir}"))
    for f in sorted(output_dir.iterdir()):
        if f.is_file():
            size = get_bin_size(f.stat().st_size)
            click.echo(f"  {f.name} ({size})")


@cli.group(aliases=["rel"], cls=ClickAliasedGroup)
def release():
    """Pre-release workflow commands."""


# --- release version ---


@release.group("version", cls=ClickAliasedGroup)
def release_version():
    """Version management — show, sync, and bump the canonical version."""


@release_version.command("show")
def release_version_show():
    """Display the current version from efa.config.toml."""
    from data.lib.release.version import load_version

    v = load_version()
    is_pre = v.is_prerelease()

    lines = [
        ("Canonical version", v.render_full()),
        ("  major", str(v.major)),
        ("  minor", str(v.minor)),
        ("  patch", str(v.patch)),
        ("  pre-release", f"{v.pre_label}.{v.pre_num}" if is_pre else "(none)"),
        ("  build", str(v.build)),
        ("", ""),
        ("Full string", v.render_full()),
        ("Semver only", v.render_semver()),
        ("Git tag", v.render_tag()),
    ]
    label_width = max(len(label) for label, _ in lines if label)
    for label, value in lines:
        if not label:
            click.echo("")
        else:
            click.echo(
                styled([Style.BRIGHT, Fore.CYAN], label.ljust(label_width))
                + "  "
                + styled([Style.BRIGHT], value)
            )


@release_version.command("sync")
@click.option("--dry-run", is_flag=True, default=False, help="Show what would be written.")
def release_version_sync(dry_run: bool):
    """Sync version from efa.config.toml to all target files."""
    from data.lib.release.version import load_version
    from data.lib.release.version import sync_all

    v = load_version()
    click.echo(
        styled([Style.BRIGHT, Fore.GREEN], "Syncing version ")
        + styled([Style.BRIGHT], v.render_full())
    )

    report = sync_all(v, dry_run=dry_run)
    for t in report.synced:
        click.echo(styled([Fore.GREEN], f"  {t.label:40s} -> {t.expected}"))
    for err in report.errors:
        click.echo(styled([Fore.RED], f"  ERROR: {err}"))

    if dry_run:
        click.echo(styled([Fore.YELLOW], "  (dry-run — no files were modified)"))


@release_version.command("bump")
@click.argument("level", type=click.Choice(["major", "minor", "patch"]), required=False)
@click.option("--pre-label", default=None, help="Set pre-release label (e.g. 'beta', 'rc').")
@click.option("--pre-num", type=int, default=None, help="Set pre-release number.")
@click.option("--build", "build_num", type=int, default=None, help="Set build number.")
@click.option(
    "--clear-pre", is_flag=True, default=False, help="Remove pre-release (promote to release)."
)
@click.option("--dry-run", is_flag=True, default=False, help="Show what would be done.")
def release_version_bump(
    level: str | None,
    pre_label: str | None,
    pre_num: int | None,
    build_num: int | None,
    clear_pre: bool,
    dry_run: bool,
):
    """Bump the canonical version and sync all target files.

    LEVEL must be one of: major, minor, patch.

    \b
    Bump patch with pre-release:
        ./x release version bump patch --pre-label beta --pre-num 1

    \b
    Bump minor and clear pre-release (final release):
        ./x release version bump minor --clear-pre

    \b
    Only update pre-release number:
        ./x release version bump --pre-label beta --pre-num 5

    \b
    Only update build number:
        ./x release version bump --build 42
    """
    from data.lib.release.version import load_version
    from data.lib.release.version import sync_all
    from data.lib.release.version import write_config_version

    v = load_version()
    old_ver = v.render_full()

    if level is not None:
        if level == "major":
            v.bump_major()
        elif level == "minor":
            v.bump_minor()
        elif level == "patch":
            v.bump_patch()

    if clear_pre:
        v.clear_prerelease()
    else:
        if pre_label is not None:
            v.pre_label = pre_label
            if v.pre_num == 0 and pre_num is None:
                v.pre_num = 1
        if pre_num is not None:
            v.pre_num = pre_num
            if v.pre_num > 0 and not v.pre_label:
                raise click.ClickException("pre_label is required when setting pre_num > 0")

    if build_num is not None:
        v.build = build_num

    new_ver = v.render_full()
    click.echo(
        styled([Style.BRIGHT, Fore.CYAN], "Bumping: ")
        + styled([Style.BRIGHT], f"{old_ver} -> {new_ver}")
    )

    if dry_run:
        click.echo(styled([Fore.YELLOW], "  (dry-run — no files were modified)"))
        return

    write_config_version(v, dry_run=False)
    click.echo(styled([Fore.GREEN], "  Updated efa.config.toml"))

    report = sync_all(v, dry_run=False)
    for t in report.synced:
        click.echo(styled([Fore.GREEN], f"  Synced {t.label} -> {t.expected}"))
    for err in report.errors:
        click.echo(styled([Fore.RED], f"  ERROR: {err}"))


# --- release check ---


@release.command("check")
@click.option(
    "--since", "since_tag", default=None, help="Compare against this tag instead of auto-detecting."
)
@click.option(
    "--force", is_flag=True, default=False, help="Downgrade most fatal checks to warnings."
)
def release_check(since_tag: str | None, force: bool):
    """Run all pre-release checks.

    \b
    Runs 11 verification gates: version-sync, git-clean, git-tag,
    schema-diff, schema-bump, schema-version, persistence-check, submodule,
    generate, lint, and changelog.  Fatal failures block the
    release unless --force is used.
    """
    from data.lib.release.check import CheckSeverity
    from data.lib.release.check import run_all_checks

    report = run_all_checks(force=force, since_tag=since_tag)

    # Print results
    click.echo("")
    click.echo(styled([Style.BRIGHT], "=" * 60))
    click.echo(styled([Style.BRIGHT], "Pre-Release Check Report"))
    click.echo(styled([Style.BRIGHT], "=" * 60))
    click.echo("")

    width = max(len(r.name) for r in report.results) + 2

    for r in report.results:
        name_padded = r.name.ljust(width)
        if r.passed:
            click.echo(
                styled([Fore.GREEN], f"  {r.icon} ")
                + styled([Style.BRIGHT], name_padded)
                + styled([Fore.GREEN], r.message)
            )
        elif r.severity == CheckSeverity.FATAL:
            click.echo(
                styled([Fore.RED], f"  {r.icon} ")
                + styled([Style.BRIGHT], name_padded)
                + styled([Fore.RED], r.message)
            )
        elif r.severity == CheckSeverity.WARN:
            click.echo(
                styled([Fore.YELLOW], f"  {r.icon} ")
                + styled([Style.BRIGHT], name_padded)
                + styled([Fore.YELLOW], r.message)
            )
        else:
            click.echo(
                styled([Fore.CYAN], f"  {r.icon} ")
                + styled([Style.BRIGHT], name_padded)
                + styled([Fore.CYAN], r.message)
            )

        if r.details:
            for line in r.details.split("\n"):
                click.echo(" " * (14 + width) + line)

    click.echo("")
    fatal = report.fatal_failures
    warns = report.warnings
    passed = len(report.results) - len(fatal) - len(warns)

    click.echo(
        styled([Style.BRIGHT], f"  {passed} passed, ")
        + styled([Fore.YELLOW, Style.BRIGHT], f"{len(warns)} warnings, ")
        + styled([Fore.RED, Style.BRIGHT], f"{len(fatal)} failures")
    )
    click.echo("")

    if report.has_fatal_failure:
        click.echo(styled([Fore.RED, Style.BRIGHT], "Release blocked by fatal check failures."))
        if not force:
            click.echo(
                styled([Fore.YELLOW], "Re-run with --force to downgrade to warnings, ")
                + "or fix the issues above."
            )
        exit(1)

    if warns:
        click.echo(
            styled(
                [Fore.YELLOW, Style.BRIGHT], f"Release would proceed with {len(warns)} warning(s)."
            )
        )
    else:
        click.echo(styled([Fore.GREEN, Style.BRIGHT], "All checks passed — ready to release!"))


# --- release commit ---


@release.command("commit")
@click.option(
    "--no-edit",
    is_flag=True,
    default=False,
    help="Use the default message without opening an editor.",
)
@click.option(
    "--dry-run", is_flag=True, default=False, help="Print the commands without executing."
)
def release_commit(no_edit: bool, dry_run: bool):
    """Commit staged changes and create a git tag locally.

    \b
    Reads the version from efa.config.toml and:
      1. Commits staged changes with message "chore: release v{version}"
      2. Creates an annotated tag "v{version}"

    By default, both the commit and tag open $EDITOR for message review.
    Use --no-edit to accept the default messages without review.
    Use --dry-run to preview without executing.

    Does NOT push — you must push manually.
    """
    from data.lib.release.git_util import check_tag_exists
    from data.lib.release.version import load_version

    v = load_version()
    tag = v.render_tag()
    commit_msg = f"chore: release {tag}"

    if check_tag_exists(tag):
        raise click.ClickException(
            f"Tag {tag} already exists. Delete it first with `git tag -d {tag}` if you want to re-tag."
        )

    # Build git commands
    commit_cmd = ["git", "commit", "-m", commit_msg]
    if not no_edit:
        commit_cmd.append("--edit")
    commit_cmd.append("-s")

    tag_cmd = ["git", "tag", "-a", tag, "-m", f"Release {tag}"]
    if not no_edit:
        tag_cmd.append("--edit")

    if dry_run:
        click.echo(styled([Style.BRIGHT, Fore.CYAN], "[DRY-RUN] Would execute:"))
        click.echo(f"  {' '.join(commit_cmd)}")
        click.echo(f"  {' '.join(tag_cmd)}")
        return

    # Commit
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Committing: ") + commit_msg)
    proc = subprocess.run(commit_cmd, cwd=PROJECT_ROOT)
    if proc.returncode != 0:
        raise click.ClickException(f"git commit failed with exit code {proc.returncode}")

    # Tag
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Tagging: ") + tag)
    proc = subprocess.run(tag_cmd, cwd=PROJECT_ROOT)
    if proc.returncode != 0:
        raise click.ClickException(f"git tag failed with exit code {proc.returncode}")

    click.echo(
        styled([Style.BRIGHT, Fore.GREEN], "Committed and tagged locally. ")
        + styled([Fore.YELLOW], "Push manually when ready."),
    )
    click.echo(f"  git push origin dev && git push origin {tag}")


# --- release changelog ---


@release.group("changelog", cls=ClickAliasedGroup)
def release_changelog():
    """Changelog generation — full file and per-version documents."""


@release_changelog.command("generate")
def release_changelog_generate():
    """Regenerate CHANGELOG.md using git-cliff.

    Prepends a new version entry for the current version from efa.config.toml.
    """
    from data.lib.release.changelog_gen import generate_full
    from data.lib.release.version import load_version

    v = load_version()
    tag = v.render_tag()
    click.echo(
        styled([Style.BRIGHT, Fore.GREEN], "Generating changelog for ")
        + styled([Style.BRIGHT], tag)
    )
    generate_full(v)
    click.echo(styled([Fore.GREEN], "  Prepended entry to CHANGELOG.md"))


@release_changelog.command("detail")
@click.option(
    "--no-edit",
    is_flag=True,
    default=False,
    help="Write template as-is without opening editor.",
)
def release_changelog_detail(no_edit: bool):
    """Generate bi-lingual version documents for in-app release notes.

    By default, opens $EDITOR with a template containing en-us/zh-cn summary sections.
    Use --no-edit to write the generated template as-is without manual editing.
    On save (or if --no-edit), writes authored .md files to assets/content/documents/{en,zh}/.
    """
    from data.lib.release.changelog_gen import generate_detail
    from data.lib.release.version import load_version

    v = load_version()
    click.echo(
        styled([Style.BRIGHT, Fore.GREEN], "Preparing version documents for ")
        + styled([Style.BRIGHT], v.render_semver())
    )
    generate_detail(v, no_edit=no_edit)
    click.echo(styled([Fore.GREEN], "  Written to assets/content/documents/"))


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


@etc.group(cls=ClickAliasedGroup)
def site():
    """Landing page site commands."""


@site.command("dev")
def site_dev():
    """Start the SvelteKit dev server."""
    pnpm = get_command("pnpm")
    __execute_command([pnpm, "--filter", "efa-tech", "dev"], "SITE DEV", live_stdout=True)


@site.command("build")
def site_build():
    """Build the static site for Cloudflare Pages."""
    pnpm = get_command("pnpm")
    __execute_command([pnpm, "--filter", "efa-tech", "build"], "SITE BUILD", live_stdout=True)


@cli.group(aliases=["t"], cls=ClickAliasedGroup)
def test():
    """Run project test suites."""


@test.command("python")
def test_python():
    """Run Python tests via pytest."""
    uv = get_command("uv")
    click.echo(
        styled([Style.BRIGHT, Fore.GREEN], "Executing command: ") + "uv run pytest data/tests/"
    )
    __execute_command([uv, "run", "pytest", "data/tests/"], "PYTEST OUTPUT")


@test.command("dart")
def test_dart():
    """Run Flutter/Dart tests."""
    flutter = get_command("flutter")
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Executing command: ") + "flutter test")
    __execute_command([flutter, "test"], "FLUTTER TEST OUTPUT")


@test.command("all")
def test_all():
    """Run all test suites (Python + Dart)."""
    ctx = click.get_current_context()
    ctx.invoke(test_python)
    click.echo()
    ctx.invoke(test_dart)


register_ci_commands(cli)


cli()
