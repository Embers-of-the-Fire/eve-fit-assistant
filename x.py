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
import contextlib
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
from data.lib.remote.session import SessionCommittedError
from data.lib.remote.session import SessionManager
from data.lib.remote.session import SessionNotActiveError
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


def __remote_origin_url(*, endpoint: str, bucket: str) -> str:
    return f"{endpoint.rstrip('/')}/{bucket}"


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


def __validate_remote_channel(channel: str) -> str:
    normalized = channel.strip()
    if not normalized or "/" in normalized or ".." in normalized or "%2e" in normalized.lower():
        raise click.ClickException(f"Invalid remote channel: {channel!r}")
    return normalized


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
    cmd = [mc, "mirror", "--overwrite"]
    if attrs:
        for k, v in attrs.items():
            cmd.extend(["--attr", f"{k}={v}"])
    cmd.extend([str(source), target])
    __execute_command(cmd, "REMOTE PUBLISH")


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
    channel: str,
    clean_bucket: bool,
    public_download: bool,
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

    resolved_bucket = __validate_mc_target_segment(bucket, "bucket")
    resolved_alias = __validate_mc_target_segment(alias_name, "alias")
    resolved_resource_root = __validate_remote_resource_root(resource_root)
    resolved_channel = __validate_remote_channel(channel)
    root_dir = source_dir / resolved_resource_root
    channel_dir = root_dir / "channels" / resolved_channel
    index_path = channel_dir / "index.json"
    if not index_path.exists() or not index_path.is_file():
        raise click.ClickException(f"Remote publish channel index does not exist: {index_path}")

    mc = get_command("mc")
    bucket_target = f"{resolved_alias}/{resolved_bucket}"
    redacted = "<redacted>"
    __execute_command_redacted(
        [mc, "alias", "set", resolved_alias, endpoint, access_key, secret_key],
        [mc, "alias", "set", resolved_alias, endpoint, redacted, redacted],
        "REMOTE PUBLISH ALIAS",
    )
    __execute_command([mc, "mb", "--ignore-existing", bucket_target], "REMOTE PUBLISH")
    if clean_bucket:
        __execute_command([mc, "rm", "--recursive", "--force", bucket_target], "REMOTE PUBLISH")
    if public_download:
        __execute_command([mc, "anonymous", "set", "download", bucket_target], "REMOTE PUBLISH")
    else:
        __execute_command([mc, "anonymous", "set", "none", bucket_target], "REMOTE PUBLISH")

    target_root = f"{bucket_target}/{resolved_resource_root}"
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

    target_channel = f"{target_root}/channels/{resolved_channel}"
    channel_attrs = {"Cache-Control": "max-age=300", "Content-Type": "application/json"}
    __publish_optional_file(
        mc,
        channel_dir / "documents" / "catalog.json",
        f"{target_channel}/documents/catalog.json",
        attrs=channel_attrs,
    )
    __publish_optional_file(
        mc,
        channel_dir / "app" / "releases.json",
        f"{target_channel}/app/releases.json",
        attrs=channel_attrs,
    )
    __publish_optional_file(
        mc,
        channel_dir / "bundles" / "catalog.json",
        f"{target_channel}/bundles/catalog.json",
        attrs=channel_attrs,
    )
    __publish_optional_file(
        mc,
        index_path,
        f"{target_channel}/index.json",
        attrs={"Cache-Control": "no-cache", "Content-Type": "application/json"},
    )

    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Uploaded remote origin: ") + str(source_dir))
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Target bucket: ") + bucket_target)
    click.echo(
        styled([Style.BRIGHT, Fore.GREEN], "Remote index URL: ")
        + __remote_channel_index_url(
            origin_url=__remote_origin_url(endpoint=endpoint, bucket=resolved_bucket),
            resource_root=resolved_resource_root,
            channel=resolved_channel,
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
        resolved["minioIndexUrl"] = __remote_channel_index_url(
            origin_url=minio_origin_url,
            resource_root=remote_cfg.resource_root,
            channel=remote_cfg.channel,
        )

    payload: dict[str, object] = {
        "remote": __redact_remote_config(remote_cfg.model_dump(mode="json")),
        "resolved": resolved,
    }
    click.echo(json.dumps(payload, indent=4 if pretty else None))

    if as_json:
        return

    sessions_root = __resolve_dev_path(paths.session_dir)
    current_id = None
    current_path = sessions_root / "current"
    if current_path.is_file():
        current_id = current_path.read_text(encoding="utf-8").strip()

    click.echo()
    click.echo(styled([Style.BRIGHT, Fore.CYAN], "Session status"))

    if sessions_root.is_dir():
        session_dirs = sorted(
            [d for d in sessions_root.iterdir() if d.is_dir() and d.name != "current"],
            reverse=True,
        )
    else:
        session_dirs = []

    if not session_dirs and not current_id:
        click.echo("  No sessions found.")
        return

    if current_id:
        is_active = (sessions_root / current_id / "lockfile.json").is_file()
        state = "active" if is_active else "committed"
        click.echo(styled([Style.BRIGHT, Fore.GREEN], f"  Current:  {current_id}  [{state}]"))

        s_path = sessions_root / current_id
        todo_path = s_path / "todo.json"
        if todo_path.is_file():
            try:
                from data.lib.remote.models import TodoList
                from data.lib.remote.models import _load_json_model

                todo = _load_json_model(todo_path, TodoList)
                click.echo(f"  Operations: {len(todo.operations)}")
                click.echo(styled(Style.DIM, f"  Committed:  {todo.committed}"))
                click.echo(styled(Style.DIM, f"  Path:       {s_path}"))
            except Exception:
                click.echo(styled(Style.DIM, f"  Path:       {s_path}"))
    else:
        recent_committed = None
        for d in session_dirs:
            todo_p = d / "todo.json"
            if todo_p.is_file():
                try:
                    from data.lib.remote.models import TodoList
                    from data.lib.remote.models import _load_json_model

                    todo = _load_json_model(todo_p, TodoList)
                    if todo.committed:
                        recent_committed = (d.name, todo)
                        break
                except Exception:
                    continue
        if recent_committed:
            name, todo = recent_committed
            click.echo(styled([Style.BRIGHT, Fore.GREEN], f"  Latest committed:  {name}"))
            click.echo(f"  Operations: {len(todo.operations)}")
            click.echo(styled(Style.DIM, f"  Path:       {sessions_root / name}"))
        else:
            click.echo("  No current or committed sessions.")
            if session_dirs:
                click.echo(f"  {len(session_dirs)} uncommitted session(s) found.")

    click.echo(styled([Style.BRIGHT, Fore.CYAN], f"  Sessions root: {sessions_root}"))


@remote.group(cls=ClickAliasedGroup)
def prepare():
    """Session-based remote content preparation."""


def __get_session_root() -> Path:
    data.lib.config.DeveloperConfiguration.ensure_loaded()
    return __resolve_dev_path(data.lib.config.DEV_CONFIGURATION.paths.session_dir)


def __get_session(session_id: str | None = None) -> SessionManager:
    root = __get_session_root()
    if session_id:
        return SessionManager.from_session_id(root, session_id)
    return SessionManager.from_current(root)


@prepare.command("start")
@click.option(
    "--backend",
    type=click.Choice(["minio", "s3"]),
    default=None,
    help="Which backend to fetch remote state from. Required unless --origin-dir is used.",
)
@click.option(
    "--origin-dir",
    type=click.Path(path_type=Path),
    default=None,
    help="Local origin directory to copy state from instead of fetching.",
)
@click.option("--resource-root", default=None, help="Override remote resource root.")
@click.option("--channel", default=None, help="Override remote channel.")
def remote_prepare_start(
    backend: str | None,
    origin_dir: Path | None,
    resource_root: str | None,
    channel: str | None,
):
    """Start a new session (fetch remote state, write lockfile, emit session id)."""
    data.lib.config.DeveloperConfiguration.ensure_loaded()
    remote_cfg = data.lib.config.DEV_CONFIGURATION.remote
    sessions_root = __get_session_root()

    resolved_resource_root = __validate_remote_resource_root(
        resource_root or remote_cfg.resource_root
    )
    resolved_channel = __validate_remote_channel(channel or remote_cfg.channel)

    if origin_dir is not None:
        resolved_backend = "local"
    elif backend is None:
        raise click.UsageError("--backend (minio|s3) is required when --origin-dir is not used.")
    else:
        resolved_backend = backend

    kwargs: dict[str, object] = {
        "backend": resolved_backend,
        "origin_dir": origin_dir,
        "resource_root": resolved_resource_root,
        "channel": resolved_channel,
    }

    if origin_dir is None:
        if resolved_backend == "minio":
            sub = remote_cfg.require_minio()
            kwargs["mc_bin"] = get_command("mc")
            kwargs["endpoint"] = f"http://{remote_cfg.host}:{sub.port}"
            kwargs["bucket"] = sub.bucket
            kwargs["access_key"] = sub.access_key
            kwargs["secret_key"] = sub.secret_key
            kwargs["alias_name"] = sub.alias
        else:
            sub = remote_cfg.require_s3()
            kwargs["mc_bin"] = get_command("mc")
            kwargs["endpoint"] = sub.endpoint
            kwargs["bucket"] = sub.bucket
            kwargs["access_key"] = sub.access_key
            kwargs["secret_key"] = sub.secret_key
            kwargs["alias_name"] = sub.alias

    mgr = SessionManager.start(sessions_root, **kwargs)  # type: ignore[arg-type]
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Session started: ") + mgr.session_id)
    click.echo(styled(Style.DIM, f"  backend: {resolved_backend}"))
    click.echo(styled(Style.DIM, f"  channel: {resolved_channel}"))
    click.echo(styled(Style.DIM, f"  session dir: {mgr.session_dir}"))


@prepare.command("status")
@click.option("--session", "session_id", default=None, help="Session ID. Defaults to current.")
def remote_prepare_status(session_id: str | None):
    """Show session summary."""
    try:
        mgr = __get_session(session_id)
    except SessionNotActiveError as exc:
        raise click.ClickException(str(exc)) from exc
    except FileNotFoundError as exc:
        raise click.ClickException(str(exc)) from exc

    st = mgr.status()
    click.echo(styled([Style.BRIGHT, Fore.CYAN], "Session: ") + st.session_id)
    click.echo(f"  backend:    {st.backend}")
    click.echo(f"  timestamp:  {st.timestamp}")
    click.echo(f"  host:       {st.host}")
    click.echo(f"  pid:        {st.pid}")
    click.echo(f"  operations: {st.operation_count}")
    click.echo(f"  committed:  {st.committed}")


# ---- add sub-group ---------------------------------------------------------


@prepare.group(cls=ClickAliasedGroup)
def add():
    """Add content to the pending session."""


@add.command("announcement")
@click.option("--zh", "zh_path", type=click.Path(path_type=Path), required=True)
@click.option("--en", "en_path", type=click.Path(path_type=Path), required=True)
@click.option("--id", "document_id", required=True, help="Remote document id to create.")
@click.option("--title-zh", required=True, help="Chinese announcement title.")
@click.option("--title-en", required=True, help="English announcement title.")
@click.option("--summary-zh", required=True, help="Chinese announcement summary.")
@click.option("--summary-en", required=True, help="English announcement summary.")
@click.option("--published-at", default=None, help="UTC ISO timestamp. Defaults to now.")
@click.option("--min-app-ver", default=None, help="Minimum app version. Defaults to current app.")
@click.option(
    "--all-app-ver",
    is_flag=True,
    default=False,
    help="Publish for all app versions by writing minAppVer as null.",
)
@click.option("--startup/--no-startup", default=True, show_default=True)
@click.option(
    "--tag", "tags", multiple=True, help="Announcement tag. Can be passed multiple times."
)
@click.option(
    "--session", "session_id", default=None, help="Session ID. Defaults to current session."
)
def remote_prepare_add_announcement(
    zh_path: Path,
    en_path: Path,
    document_id: str,
    title_zh: str,
    title_en: str,
    summary_zh: str,
    summary_en: str,
    published_at: str | None,
    min_app_ver: str | None,
    all_app_ver: bool,
    startup: bool,
    tags: tuple[str, ...],
    session_id: str | None,
):
    """Stage an announcement in the pending session."""
    data.lib.config.DeveloperConfiguration.ensure_loaded()
    if all_app_ver and min_app_ver is not None:
        raise click.ClickException("--all-app-ver cannot be used together with --min-app-ver.")
    if not zh_path.is_file():
        raise click.ClickException(f"Chinese Markdown file does not exist: {zh_path}")
    if not en_path.is_file():
        raise click.ClickException(f"English Markdown file does not exist: {en_path}")

    remote_cfg = data.lib.config.DEV_CONFIGURATION.remote
    resolved_document_id = __validate_remote_document_id(document_id)
    resolved_published_at = published_at or __utc_timestamp()
    resolved_min_app_ver = None if all_app_ver else (min_app_ver or __read_current_app_version())
    resolved_tags = list(tags or ("announcement",))
    resolved_resource_root = remote_cfg.resource_root
    resolved_channel = remote_cfg.channel

    try:
        mgr = __get_session(session_id)
        mgr.add_announcement(
            zh_path=zh_path,
            en_path=en_path,
            document_id=resolved_document_id,
            title_zh=title_zh,
            title_en=title_en,
            summary_zh=summary_zh,
            summary_en=summary_en,
            published_at=resolved_published_at,
            min_app_ver=resolved_min_app_ver,
            startup=startup,
            tags=resolved_tags,
            resource_root=resolved_resource_root,
            channel=resolved_channel,
        )
    except (SessionNotActiveError, SessionCommittedError, FileNotFoundError) as exc:
        raise click.ClickException(str(exc)) from exc

    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Staged announcement: ") + resolved_document_id)


@add.command("bundle")
@click.option("--full", "full_path", type=click.Path(path_type=Path), required=True)
@click.option("--manifest", "manifest_path", type=click.Path(path_type=Path), required=True)
@click.option("--artifact-id", required=True, help="Artifact id for the full bundle.")
@click.option("--increment", "increment_path", type=click.Path(path_type=Path), default=None)
@click.option(
    "--increment-artifact-id",
    default=None,
    help="Artifact id for the incremental bundle. Required with --increment.",
)
@click.option(
    "--session", "session_id", default=None, help="Session ID. Defaults to current session."
)
def remote_prepare_add_bundle(
    full_path: Path,
    manifest_path: Path,
    artifact_id: str,
    increment_path: Path | None,
    increment_artifact_id: str | None,
    session_id: str | None,
):
    """Stage a bundle in the pending session."""
    data.lib.config.DeveloperConfiguration.ensure_loaded()
    if increment_path is not None and increment_artifact_id is None:
        raise click.ClickException("--increment-artifact-id is required when --increment is used.")
    if increment_path is None and increment_artifact_id is not None:
        raise click.ClickException("--increment-artifact-id requires --increment.")
    if not manifest_path.is_file():
        raise click.ClickException(f"Bundle manifest file does not exist: {manifest_path}")

    remote_cfg = data.lib.config.DEV_CONFIGURATION.remote
    resolved_artifact_id = __validate_remote_artifact_id(artifact_id)
    resolved_resource_root = remote_cfg.resource_root
    resolved_channel = remote_cfg.channel

    try:
        mgr = __get_session(session_id)
        mgr.add_bundle(
            full_path=full_path,
            manifest_path=manifest_path,
            artifact_id=resolved_artifact_id,
            resource_root=resolved_resource_root,
            channel=resolved_channel,
            increment_path=increment_path,
            increment_artifact_id=increment_artifact_id,
        )
    except (SessionNotActiveError, SessionCommittedError, FileNotFoundError) as exc:
        raise click.ClickException(str(exc)) from exc

    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Staged bundle: ") + resolved_artifact_id)


# ---- remove ----------------------------------------------------------------


@prepare.command("remove")
@click.option("--artifact-id", default=None, help="Bundle artifact id to remove.")
@click.option("--document-id", default=None, help="Document id to remove.")
@click.option(
    "--session", "session_id", default=None, help="Session ID. Defaults to current session."
)
def remote_prepare_remove(
    artifact_id: str | None,
    document_id: str | None,
    session_id: str | None,
):
    """Stage a removal in the pending session."""
    if artifact_id is not None and document_id is not None:
        raise click.ClickException("Pass either --artifact-id or --document-id, not both.")
    if artifact_id is None and document_id is None:
        raise click.ClickException("Pass either --artifact-id or --document-id.")

    try:
        mgr = __get_session(session_id)
        if artifact_id is not None:
            resolved = __validate_remote_artifact_id(artifact_id)
            mgr.remove(target_type="artifact", target_id=resolved)
            click.echo(
                styled([Style.BRIGHT, Fore.GREEN], "Staged removal of artifact: ") + resolved
            )
        else:
            assert document_id is not None
            resolved = __validate_remote_document_id(document_id)
            mgr.remove(target_type="document", target_id=resolved)
            click.echo(
                styled([Style.BRIGHT, Fore.GREEN], "Staged removal of document: ") + resolved
            )
    except (SessionNotActiveError, SessionCommittedError, FileNotFoundError) as exc:
        raise click.ClickException(str(exc)) from exc


# ---- diff ------------------------------------------------------------------


def _print_diff(diff: dict[str, object]) -> None:
    """Recursively print a human-readable diff tree produced by diff_catalogs."""

    def _walk(d: dict[str, object], depth: int) -> int:
        """Recurse into nested diff dicts. Returns count of leaf entries printed."""
        count = 0
        for key, val in sorted(d.items()):
            if not isinstance(val, dict):
                continue
            if "type" in val:
                ctype = val.get("type", "?")
                indent = "  " * depth
                if ctype == "added":
                    click.echo(styled(Fore.GREEN, f"{indent}+ {key}"))
                elif ctype == "removed":
                    click.echo(styled(Fore.RED, f"{indent}- {key}"))
                elif ctype == "changed":
                    click.echo(styled(Fore.YELLOW, f"{indent}~ {key}"))
                else:
                    click.echo(f"{indent}? {key}")
                count += 1
            else:
                sub = _walk(val, depth + 1)
                if sub > 0:
                    count += sub
        return count

    top_total = 0
    for section, section_val in sorted(diff.items()):
        if not isinstance(section_val, dict) or not section_val:
            continue
        if "type" in section_val:
            ctype = section_val.get("type", "?")
            if ctype == "added":
                click.echo(styled(Fore.GREEN, f"  + {section}"))
            elif ctype == "removed":
                click.echo(styled(Fore.RED, f"  - {section}"))
            elif ctype == "changed":
                click.echo(styled(Fore.YELLOW, f"  ~ {section}"))
            else:
                click.echo(f"  ? {section}")
            top_total += 1
        else:
            n = _walk(section_val, 2)
            if n > 0:
                top_total += n

    if top_total > 0:
        click.echo(
            styled([Style.BRIGHT, Fore.CYAN], "Catalog diffs:") + f"  ({top_total} change(s))"
        )
    else:
        click.echo(styled([Style.BRIGHT, Fore.GREEN], "No differences detected."))


@prepare.command("diff")
@click.option(
    "--session", "session_id", default=None, help="Session ID. Defaults to current session."
)
@click.option("--resource-root", default=None, help="Override remote resource root.")
@click.option("--channel", default=None, help="Override remote channel.")
@click.option(
    "--json", "as_json", is_flag=True, default=False, help="Output as machine-readable JSON."
)
def remote_prepare_diff(
    session_id: str | None,
    resource_root: str | None,
    channel: str | None,
    as_json: bool,
):
    """Show catalog/index diffs between remote-state and merged output."""
    data.lib.config.DeveloperConfiguration.ensure_loaded()
    remote_cfg = data.lib.config.DEV_CONFIGURATION.remote
    resolved_channel = __validate_remote_channel(channel or remote_cfg.channel)
    resolved_resource_root = __validate_remote_resource_root(
        resource_root or remote_cfg.resource_root
    )

    try:
        mgr = __get_session(session_id)
    except (SessionNotActiveError, SessionCommittedError, FileNotFoundError) as exc:
        raise click.ClickException(str(exc)) from exc

    diff = mgr.diff(channel=resolved_channel, resource_root=resolved_resource_root)
    if as_json:
        click.echo(json.dumps(diff, indent=4, sort_keys=True))
    else:
        _print_diff(diff)


# ---- verify ----------------------------------------------------------------


@prepare.command("verify")
@click.option(
    "--session", "session_id", default=None, help="Session ID. Defaults to current session."
)
@click.option("--resource-root", default=None, help="Override remote resource root.")
@click.option("--channel", default=None, help="Override remote channel.")
def remote_prepare_verify(
    session_id: str | None,
    resource_root: str | None,
    channel: str | None,
):
    """Validate merged output is internally consistent."""
    data.lib.config.DeveloperConfiguration.ensure_loaded()
    remote_cfg = data.lib.config.DEV_CONFIGURATION.remote
    resolved_channel = __validate_remote_channel(channel or remote_cfg.channel)
    resolved_resource_root = __validate_remote_resource_root(
        resource_root or remote_cfg.resource_root
    )

    try:
        mgr = __get_session(session_id)
    except (SessionNotActiveError, SessionCommittedError, FileNotFoundError) as exc:
        raise click.ClickException(str(exc)) from exc

    lock = mgr._load_lockfile()
    backend = lock.backend if lock.backend != "local" else None

    kwargs: dict[str, object] = {"resource_root": resolved_resource_root}
    if backend == "minio":
        sub = remote_cfg.require_minio()
        kwargs["endpoint"] = f"http://{remote_cfg.host}:{sub.port}"
        kwargs["bucket"] = sub.bucket
        kwargs["access_key"] = sub.access_key
        kwargs["secret_key"] = sub.secret_key
        kwargs["alias_name"] = sub.alias
    elif backend == "s3":
        sub = remote_cfg.require_s3()
        kwargs["endpoint"] = sub.endpoint
        kwargs["bucket"] = sub.bucket
        kwargs["access_key"] = sub.access_key
        kwargs["secret_key"] = sub.secret_key
        kwargs["alias_name"] = sub.alias

    errors = mgr.verify(
        channel=resolved_channel,
        backend=backend,
        **kwargs,  # type: ignore[arg-type]
    )
    if errors:
        for err in errors:
            click.echo(styled([Style.BRIGHT, Fore.RED], "ERROR: ") + err)
        raise click.ClickException(f"Verification failed with {len(errors)} error(s).")
    else:
        click.echo(styled([Style.BRIGHT, Fore.GREEN], "Verification passed."))


# ---- commit ----------------------------------------------------------------


@prepare.command("commit")
@click.option(
    "--session", "session_id", default=None, help="Session ID. Defaults to current session."
)
def remote_prepare_commit(session_id: str | None):
    """Finalize session (immutable todo, remove lockfile). Emits summary."""
    try:
        mgr = __get_session(session_id)
        st = mgr.commit()
    except (SessionNotActiveError, SessionCommittedError, FileNotFoundError) as exc:
        raise click.ClickException(str(exc)) from exc

    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Session committed: ") + st.session_id)
    click.echo(f"  operations: {st.operation_count}")
    click.echo("  committed:  true")


# ---- abort -----------------------------------------------------------------


@prepare.command("abort")
@click.option(
    "--session", "session_id", default=None, help="Session ID. Defaults to current session."
)
@click.option("--force", is_flag=True, default=False, help="Skip confirmation prompt.")
def remote_prepare_abort(session_id: str | None, force: bool):
    """Discard session, remove session dir."""
    try:
        mgr = __get_session(session_id)
    except (SessionNotActiveError, FileNotFoundError) as exc:
        raise click.ClickException(str(exc)) from exc

    if not force:
        click.confirm(
            f"Discard session {mgr.session_id} and all staged content?",
            abort=True,
        )

    session_dir = mgr.session_dir
    mgr.abort()
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Session aborted: ") + str(session_dir))


@remote.group(cls=ClickAliasedGroup)
def publish():
    """Remote content publishing commands."""


def __resolve_publish_source(
    *,
    source_dir: Path | None,
    session_id: str | None,
) -> tuple[Path, str | None]:
    if source_dir is not None and session_id is not None:
        raise click.ClickException("Pass either --source-dir or --session, not both.")
    if source_dir is not None:
        resolved = __resolve_dev_path(source_dir)
        if not resolved.is_dir():
            raise click.ClickException(f"Source directory does not exist: {resolved}")
        return resolved, None
    if session_id:
        mgr = __get_session(session_id)
        if not mgr.status().committed:
            raise click.ClickException(
                f"Session has not been committed."
                f" Run `./x remote prepare commit --session {mgr.session_id}` first."
            )
    else:
        try:
            mgr = SessionManager.find_latest_committed(__get_session_root())
        except FileNotFoundError as exc:
            raise click.ClickException(str(exc)) from exc
    merged = mgr.session_dir / "merged"
    if not merged.is_dir():
        raise click.ClickException(
            f"Session has no merged output. Run `./x remote prepare diff` first: {mgr.session_id}"
        )
    return merged, mgr.session_id


# ---- shared S3 upload helpers -----------------------------------------------


def __get_publish_s3_params(
    target: str,
    endpoint: str | None,
    bucket: str | None,
    access_key: str | None,
    secret_key: str | None,
    alias_name: str | None,
    public_download: bool | None,
) -> dict[str, object]:
    data.lib.config.DeveloperConfiguration.ensure_loaded()
    remote_cfg = data.lib.config.DEV_CONFIGURATION.remote

    if target.lower() == "minio":
        sub = remote_cfg.require_minio()
        return {
            "endpoint": endpoint or f"http://{remote_cfg.host}:{sub.port}",
            "bucket": bucket or sub.bucket,
            "access_key": access_key or sub.access_key,
            "secret_key": secret_key or sub.secret_key,
            "alias_name": alias_name or sub.alias,
            "public_download": (
                public_download if public_download is not None else sub.public_download
            ),
        }
    else:
        sub = remote_cfg.require_s3()
        return {
            "endpoint": endpoint or sub.endpoint,
            "bucket": bucket or sub.bucket,
            "access_key": access_key or sub.access_key,
            "secret_key": secret_key or sub.secret_key,
            "alias_name": alias_name or sub.alias,
            "public_download": (
                public_download if public_download is not None else sub.public_download
            ),
        }


def _collect_referenced_paths_from_catalogs(
    mc: str,
    alias_name: str,
    bucket: str,
    resource_root: str,
    channel: str,
) -> set[str]:
    """Download current catalogs and collect all referenced content paths.

    Returns the set of full relative paths (e.g. ``bundles/{bundleId}/{artifactId}.zip``)
    from ``artifactPath``, ``manifestPath``, and ``bodyPath`` fields.
    """
    import tempfile

    bucket_target = f"{alias_name}/{bucket}/{resource_root}"
    ch_target = f"{bucket_target}/channels/{channel}"

    with tempfile.TemporaryDirectory() as tmp:
        tmp_path = Path(tmp)
        (tmp_path / channel).mkdir(parents=True, exist_ok=True)

        for catalog_name in ("index.json", "documents/catalog.json", "bundles/catalog.json"):
            _run_mc(
                [
                    mc,
                    "cp",
                    f"{ch_target}/{catalog_name}",
                    str(tmp_path / channel / catalog_name),
                ],
                [
                    mc,
                    "cp",
                    f"{ch_target}/{catalog_name}",
                    f"<tmp>/{channel}/{catalog_name}",
                ],
                f"GC FETCH {catalog_name}",
            )

        referenced: set[str] = set()

        docs_path = tmp_path / channel / "documents" / "catalog.json"
        if docs_path.is_file():
            docs: dict[str, object] = json.loads(docs_path.read_text(encoding="utf-8"))
            entries: object = docs.get("entries", [])
            if isinstance(entries, list):
                for entry in entries:
                    if not isinstance(entry, dict):
                        continue
                    localizations = entry.get("localizations")
                    if isinstance(localizations, dict):
                        for _lang, loc in localizations.items():
                            if isinstance(loc, dict):
                                body = loc.get("bodyPath")
                                if isinstance(body, str):
                                    referenced.add(body)

        bundles_path = tmp_path / channel / "bundles" / "catalog.json"
        if bundles_path.is_file():
            bundles: dict[str, object] = json.loads(bundles_path.read_text(encoding="utf-8"))
            artifacts: object = bundles.get("artifacts", [])
            if isinstance(artifacts, list):
                for artifact in artifacts:
                    if not isinstance(artifact, dict):
                        continue
                    ap = artifact.get("artifactPath")
                    if isinstance(ap, str):
                        referenced.add(ap)
                    mp = artifact.get("manifestPath")
                    if isinstance(mp, str):
                        referenced.add(mp)

    return referenced


def __gc_unreferenced_objects(
    mc: str,
    alias_name: str,
    bucket: str,
    resource_root: str,
    channel: str,
    *,
    dry_run: bool,
) -> str:
    """Prune unreferenced objects from the remote bucket.

    Collects all referenced paths from current catalogs via exact path
    matching, then deletes anything in ``documents/body/`` and ``bundles/``
    that isn't referenced.  Also cleans up stale deployment snapshots.
    Returns a human-readable summary.
    """
    bucket_target = f"{alias_name}/{bucket}/{resource_root}"

    referenced = _collect_referenced_paths_from_catalogs(
        mc=mc,
        alias_name=alias_name,
        bucket=bucket,
        resource_root=resource_root,
        channel=channel,
    )

    # List all objects in mutable prefixes
    results: list[str] = []
    for prefix in (f"{bucket_target}/documents/body", f"{bucket_target}/bundles"):
        try:
            out = subprocess.run(
                [mc, "ls", "--recursive", "--json", prefix],
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
            )
            if out.returncode == 0:
                results.extend(out.stdout.strip().splitlines())
        except Exception:
            continue

    unreferenced: list[tuple[str, str]] = []
    for line in results:
        if not line.strip():
            continue
        try:
            obj: dict[str, object] = json.loads(line)
        except ValueError:
            continue
        key = obj.get("key", "")
        if not isinstance(key, str):
            continue
        rel = key.removeprefix(f"{resource_root}/") if key.startswith(f"{resource_root}/") else key
        if rel not in referenced:
            size = obj.get("size")
            size_str = f"{size}" if isinstance(size, (int, float)) else "?"
            unreferenced.append((key, size_str))

    # Collect stale deployment snapshots
    stale_deps: list[tuple[str, str]] = []
    dep_prefix = f"{bucket_target}/deployments"
    try:
        out = subprocess.run(
            [mc, "ls", "--recursive", "--json", dep_prefix],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
        if out.returncode == 0:
            dep_objects: list[dict[str, object]] = []
            for line in out.stdout.strip().splitlines():
                try:
                    dep_objects.append(json.loads(line))
                except ValueError:
                    continue
            # Keep only the 10 most recent deployments
            timestamps: set[str] = set()
            for obj in dep_objects:
                key: object = obj.get("key", "")
                if not isinstance(key, str):
                    continue
                rel = (
                    key.removeprefix(f"{resource_root}/")
                    if key.startswith(f"{resource_root}/")
                    else key
                )
                parts = rel.split("/")
                if len(parts) > 1 and parts[0] == "deployments":
                    for part in parts[1:]:
                        if len(part) >= 14 and part[0].isdigit():
                            timestamps.add(part)
            keep = set(sorted(timestamps, reverse=True)[:10])
            for obj in dep_objects:
                key: object = obj.get("key", "")
                if not isinstance(key, str):
                    continue
                rel = (
                    key.removeprefix(f"{resource_root}/")
                    if key.startswith(f"{resource_root}/")
                    else key
                )
                parts = rel.split("/")
                ts = None
                if len(parts) > 1 and parts[0] == "deployments":
                    for part in parts[1:]:
                        if len(part) >= 14 and part[0].isdigit():
                            ts = part
                            break
                if ts and ts not in keep:
                    size = obj.get("size")
                    size_str = f"{size}" if isinstance(size, (int, float)) else "?"
                    stale_deps.append((key, size_str))
    except Exception:
        pass

    if dry_run:
        lines = []
        if unreferenced:
            lines.append(f"Would delete {len(unreferenced)} unreferenced object(s):")
            for key, size in sorted(unreferenced):
                lines.append(f"  {key}  ({size} bytes)")
        if stale_deps:
            lines.append(f"Would delete {len(stale_deps)} stale deployment artifact(s):")
            for key, size in sorted(stale_deps):
                lines.append(f"  {key}  ({size} bytes)")
        if not unreferenced and not stale_deps:
            return "Nothing to prune."
        return "\n".join(lines)

    deleted_content = 0
    for key, _size in unreferenced:
        with contextlib.suppress(OSError):
            _run_mc(
                [mc, "rm", f"{alias_name}/{bucket}/{key}"],
                [mc, "rm", f"{alias_name}/{bucket}/{key}"],
                "GC DELETE",
            )
            deleted_content += 1

    deleted_deps = 0
    for key, _size in stale_deps:
        with contextlib.suppress(OSError):
            _run_mc(
                [mc, "rm", f"{alias_name}/{bucket}/{key}"],
                [mc, "rm", f"{alias_name}/{bucket}/{key}"],
                "GC DELETE DEPLOYMENT",
            )
            deleted_deps += 1

    parts = []
    if deleted_content:
        parts.append(f"{deleted_content} unreferenced object(s)")
    if deleted_deps:
        parts.append(f"{deleted_deps} stale deployment artifact(s)")
    if not parts:
        return "Nothing to prune."
    return f"Deleted {', '.join(parts)}."


def __write_temp_json(payload: dict[str, object]) -> Path:
    import tempfile

    fd, path_str = tempfile.mkstemp(suffix=".json", text=True)
    os.close(fd)
    p = Path(path_str)
    p.write_text(json.dumps(payload, indent=4, ensure_ascii=False) + "\n", encoding="utf-8")
    return p


def _run_mc(cmd: list[str], redacted_cmd: list[str], title: str) -> None:
    if DRY_RUN:
        info(f"[Dry-Run] {title}: {' '.join(redacted_cmd)}")
        return
    out = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if out.returncode != 0:
        msg = f"Failed to execute [{out.returncode}]: {' '.join(redacted_cmd)}"
        stderr = (out.stderr or "").strip()
        if stderr:
            msg += f"\n{stderr}"
        raise OSError(msg)


# ---- upload ----------------------------------------------------------------


@publish.command("upload")
@click.option(
    "--target",
    type=click.Choice(["minio", "s3"], case_sensitive=False),
    default="minio",
    show_default=True,
    help="S3-compatible upload target preset.",
)
@click.option("--source-dir", type=click.Path(path_type=Path), default=None)
@click.option(
    "--session",
    "session_id",
    default=None,
    help="Session ID. Defaults to latest committed session.",
)
@click.option(
    "--keep-session",
    is_flag=True,
    default=False,
    help="Keep the session directory after successful publish.",
)
@click.option("--endpoint", default=None, help="Override S3-compatible endpoint URL.")
@click.option("--bucket", default=None, help="Override bucket name.")
@click.option("--access-key", default=None, help="Override access key.")
@click.option("--secret-key", default=None, help="Override secret key.")
@click.option("--alias", "alias_name", default=None, help="Override mc alias name.")
@click.option("--resource-root", default=None, help="Override remote resource root.")
@click.option("--channel", default=None, help="Override remote channel.")
@click.option("--clean", is_flag=True, default=False, help="Clean bucket before publishing.")
@click.option(
    "--public-download/--private",
    default=None,
    help="Configure anonymous bucket downloads after upload.",
)
def remote_publish_upload(
    target: str,
    source_dir: Path | None,
    session_id: str | None,
    keep_session: bool,
    endpoint: str | None,
    bucket: str | None,
    access_key: str | None,
    secret_key: str | None,
    alias_name: str | None,
    resource_root: str | None,
    channel: str | None,
    clean: bool,
    public_download: bool | None,
):
    """Upload a local remote origin or committed session to S3-compatible object storage."""
    data.lib.config.DeveloperConfiguration.ensure_loaded()
    remote_cfg = data.lib.config.DEV_CONFIGURATION.remote
    resolved_source_dir, resolved_session_id = __resolve_publish_source(
        source_dir=source_dir, session_id=session_id
    )
    resolved_resource_root = __validate_remote_resource_root(
        resource_root or remote_cfg.resource_root
    )
    resolved_channel = __validate_remote_channel(channel or remote_cfg.channel)

    s3 = __get_publish_s3_params(
        target, endpoint, bucket, access_key, secret_key, alias_name, public_download
    )
    resolved_endpoint = str(s3["endpoint"])
    resolved_bucket = str(s3["bucket"])
    resolved_access_key = str(s3["access_key"])
    resolved_secret_key = str(s3["secret_key"])
    resolved_alias = str(s3["alias_name"])
    resolved_public_download = bool(s3["public_download"])

    __publish_remote_origin_to_s3(
        source_dir=resolved_source_dir,
        endpoint=resolved_endpoint,
        bucket=resolved_bucket,
        access_key=resolved_access_key,
        secret_key=resolved_secret_key,
        alias_name=resolved_alias,
        resource_root=resolved_resource_root,
        channel=resolved_channel,
        clean_bucket=clean,
        public_download=resolved_public_download,
    )

    if source_dir is None and not keep_session and resolved_session_id:
        mgr = __get_session(resolved_session_id)
        mgr.abort()
        click.echo(
            styled([Style.BRIGHT, Fore.GREEN], "Session cleaned up: ") + str(mgr.session_dir)
        )


# ---- gc --------------------------------------------------------------------


@publish.command("gc")
@click.option(
    "--target",
    type=click.Choice(["minio", "s3"], case_sensitive=False),
    default="minio",
    show_default=True,
)
@click.option(
    "--dry-run",
    is_flag=True,
    default=False,
    help="List what would be deleted without actually deleting.",
)
@click.option("--endpoint", default=None)
@click.option("--bucket", default=None)
@click.option("--access-key", default=None)
@click.option("--secret-key", default=None)
@click.option("--alias", "alias_name", default=None)
@click.option("--resource-root", default=None)
@click.option("--channel", default=None)
def remote_publish_gc(
    target: str,
    dry_run: bool,
    endpoint: str | None,
    bucket: str | None,
    access_key: str | None,
    secret_key: str | None,
    alias_name: str | None,
    resource_root: str | None,
    channel: str | None,
):
    """Prune unreferenced objects from the remote bucket."""
    data.lib.config.DeveloperConfiguration.ensure_loaded()
    remote_cfg = data.lib.config.DEV_CONFIGURATION.remote
    resolved_resource_root = __validate_remote_resource_root(
        resource_root or remote_cfg.resource_root
    )
    resolved_channel = __validate_remote_channel(channel or remote_cfg.channel)

    s3 = __get_publish_s3_params(target, endpoint, bucket, access_key, secret_key, alias_name, None)
    mc = get_command("mc")

    resolved_alias = str(s3["alias_name"])
    resolved_bucket = str(s3["bucket"])

    redacted = "<redacted>"
    _run_mc(
        [
            mc,
            "alias",
            "set",
            resolved_alias,
            str(s3["endpoint"]),
            str(s3["access_key"]),
            str(s3["secret_key"]),
        ],
        [mc, "alias", "set", resolved_alias, str(s3["endpoint"]), redacted, redacted],
        "GC ALIAS",
    )

    summary = __gc_unreferenced_objects(
        mc=mc,
        alias_name=resolved_alias,
        bucket=resolved_bucket,
        resource_root=resolved_resource_root,
        channel=resolved_channel,
        dry_run=dry_run,
    )
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "GC: ") + summary)


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
    channel: str,
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
        __publish_remote_origin_to_s3(
            source_dir=origin_dir,
            endpoint=endpoint,
            bucket=bucket,
            access_key=access_key,
            secret_key=secret_key,
            alias_name=alias_name,
            resource_root=resource_root,
            channel=channel,
            clean_bucket=clean_bucket,
            public_download=public_download,
        )

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
    remote_cfg = data.lib.config.DEV_CONFIGURATION.remote
    minio = remote_cfg.require_minio()

    resolved_host = host or remote_cfg.host
    resolved_resource_root = resource_root or remote_cfg.resource_root
    resolved_channel = channel or remote_cfg.channel
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
        alias_name=resolved_alias,
        resource_root=resolved_resource_root,
        channel=resolved_channel,
        clean_bucket=clean_bucket,
        public_download=resolved_public_download,
    )


# ---- validate --------------------------------------------------------------


@remote.command("validate")
@click.option("--origin-dir", type=click.Path(path_type=Path), default=None)
@click.option("--resource-root", default=None, help="Override remote resource root.")
@click.option("--channel", default=None, help="Override remote channel.")
def remote_validate(
    origin_dir: Path | None,
    resource_root: str | None,
    channel: str | None,
):
    """Validate a local origin tree for internal consistency."""
    data.lib.config.DeveloperConfiguration.ensure_loaded()
    remote_cfg = data.lib.config.DEV_CONFIGURATION.remote
    resolved_origin_dir = __resolve_dev_path(origin_dir or remote_cfg.mock_origin_dir)
    resolved_resource_root = __validate_remote_resource_root(
        resource_root or remote_cfg.resource_root
    )
    resolved_channel = __validate_remote_channel(channel or remote_cfg.channel)

    from data.lib.remote import fetch as remote_fetch

    channel_dir = resolved_origin_dir / resolved_resource_root / "channels" / resolved_channel
    index_path = channel_dir / "index.json"
    docs_path = channel_dir / "documents" / "catalog.json"
    bundles_path = channel_dir / "bundles" / "catalog.json"

    missing = []
    for p in (index_path, docs_path, bundles_path):
        if not p.is_file():
            missing.append(str(p))
    if missing:
        raise click.ClickException("Missing required files:\n  " + "\n  ".join(missing))

    index, docs, bundles = remote_fetch.read_local_remote_state(
        resolved_origin_dir / resolved_resource_root, resolved_channel
    )

    from data.lib.remote.catalog import verify_merged_state

    staged_sha256s: dict[str, str] = {}
    body_dir = resolved_origin_dir / resolved_resource_root / "documents" / "body"
    if body_dir.is_dir():
        for f in body_dir.rglob("*.md"):
            if f.is_file():
                staged_sha256s[str(f.relative_to(body_dir))] = __file_sha256(f)

    merged_state: dict[str, object] = {
        "index": index,
        "documents_catalog": docs,
        "bundles_catalog": bundles,
    }
    errors = verify_merged_state(merged_state, staged_sha256s)
    if errors:
        for err in errors:
            click.echo(styled([Style.BRIGHT, Fore.RED], "ERROR: ") + err)
        raise click.ClickException(f"Validation failed with {len(errors)} error(s).")
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Origin tree passed validation."))


# ---- fetch -----------------------------------------------------------------


@remote.command("fetch")
@click.option(
    "--backend",
    type=click.Choice(["minio", "s3"]),
    required=True,
    help="Which backend to fetch remote state from.",
)
@click.option(
    "--output-dir",
    type=click.Path(path_type=Path),
    default=None,
    help="Output directory. Defaults to a timestamped dir under the session root.",
)
@click.option("--endpoint", default=None)
@click.option("--bucket", default=None)
@click.option("--access-key", default=None)
@click.option("--secret-key", default=None)
@click.option("--alias", "alias_name", default=None)
@click.option("--resource-root", default=None)
@click.option("--channel", default=None)
def remote_fetch(
    backend: str,
    output_dir: Path | None,
    endpoint: str | None,
    bucket: str | None,
    access_key: str | None,
    secret_key: str | None,
    alias_name: str | None,
    resource_root: str | None,
    channel: str | None,
):
    """Download remote state into a local directory (for debugging/backup)."""
    data.lib.config.DeveloperConfiguration.ensure_loaded()
    remote_cfg = data.lib.config.DEV_CONFIGURATION.remote

    if output_dir is None:
        stamp = __utc_timestamp().replace("-", "").replace(":", "")
        output_dir = __get_session_root() / f"fetch-{stamp}"

    resolved_resource_root = __validate_remote_resource_root(
        resource_root or remote_cfg.resource_root
    )
    resolved_channel = __validate_remote_channel(channel or remote_cfg.channel)

    from data.lib.remote import fetch as remote_fetch

    mc = get_command("mc")

    if backend == "minio":
        sub = remote_cfg.require_minio()
        resolved_endpoint = endpoint or f"http://{remote_cfg.host}:{sub.port}"
        resolved_bucket = bucket or sub.bucket
        resolved_access_key = access_key or sub.access_key
        resolved_secret_key = secret_key or sub.secret_key
        resolved_alias = alias_name or sub.alias
    else:
        sub = remote_cfg.require_s3()
        resolved_endpoint = endpoint or sub.endpoint
        resolved_bucket = bucket or sub.bucket
        resolved_access_key = access_key or sub.access_key
        resolved_secret_key = secret_key or sub.secret_key
        resolved_alias = alias_name or sub.alias

    remote_fetch.fetch_remote_state_s3(
        mc_bin=mc,
        endpoint=resolved_endpoint,
        bucket=resolved_bucket,
        access_key=resolved_access_key,
        secret_key=resolved_secret_key,
        alias_name=resolved_alias,
        resource_root=resolved_resource_root,
        channel=resolved_channel,
        output_dir=output_dir,
    )
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Fetched remote state to: ") + str(output_dir))


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
