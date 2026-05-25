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
    """Remote mock and publishing helper commands."""


@remote.group("config", cls=ClickAliasedGroup)
def remote_config():
    """Remote mock configuration commands."""


def __redact_remote_config(config: dict[str, object]) -> dict[str, object]:
    redacted = dict(config)
    for key in ("minio_access_key", "minio_secret_key"):
        if key in redacted:
            redacted[key] = "<redacted>"
    return redacted


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
        "remote": __redact_remote_config(remote_cfg.model_dump(mode="json")),
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
    click.echo(json.dumps(payload, indent=4 if pretty else None))


@remote.group(cls=ClickAliasedGroup)
def prepare():
    """Prepare local remote content payloads before publishing."""


@prepare.command("announcement")
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
    "--replace",
    is_flag=True,
    default=False,
    help="Allow replacing an existing announcement entry and body files.",
)
@click.option("--origin-dir", type=click.Path(path_type=Path), default=None)
@click.option("--resource-root", default=None, help="Override remote resource root.")
@click.option("--channel", default=None, help="Override remote channel.")
def remote_prepare_announcement(
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
    replace: bool,
    origin_dir: Path | None,
    resource_root: str | None,
    channel: str | None,
):
    """Prepare a localized remote startup announcement."""
    data.lib.config.DeveloperConfiguration.ensure_loaded()
    if all_app_ver and min_app_ver is not None:
        raise click.ClickException("--all-app-ver cannot be used together with --min-app-ver.")
    if not zh_path.is_file():
        raise click.ClickException(f"Chinese Markdown file does not exist: {zh_path}")
    if not en_path.is_file():
        raise click.ClickException(f"English Markdown file does not exist: {en_path}")

    remote_cfg = data.lib.config.DEV_CONFIGURATION.remote
    resolved_origin_dir = __resolve_dev_path(origin_dir or remote_cfg.mock_origin_dir)
    resolved_resource_root = __validate_remote_resource_root(
        resource_root or remote_cfg.resource_root
    )
    resolved_channel = __validate_remote_channel(channel or remote_cfg.channel)
    resolved_document_id = __validate_remote_document_id(document_id)
    resolved_published_at = published_at or __utc_timestamp()
    resolved_min_app_ver = None if all_app_ver else (min_app_ver or __read_current_app_version())
    resolved_tags = list(tags or ("announcement",))

    root_dir = resolved_origin_dir / resolved_resource_root
    channel_dir = root_dir / "channels" / resolved_channel
    catalog_path = channel_dir / "documents" / "catalog.json"
    index_path = channel_dir / "index.json"
    zh_body_path = root_dir / "documents" / "body" / "zh" / f"{resolved_document_id}.md"
    en_body_path = root_dir / "documents" / "body" / "en" / f"{resolved_document_id}.md"

    catalog = __read_json_object(
        catalog_path,
        {
            "schemaVersion": 1,
            "version": 1,
            "entries": [],
        },
    )
    entries = catalog.get("entries")
    if not isinstance(entries, list):
        raise click.ClickException(
            f"Remote document catalog entries must be a list: {catalog_path}"
        )

    existing_indexes = [
        index
        for index, entry in enumerate(entries)
        if isinstance(entry, dict) and entry.get("id") == resolved_document_id
    ]
    if existing_indexes and not replace:
        raise click.ClickException(
            "Remote announcement already exists; pass --replace to overwrite: "
            f"{resolved_document_id}"
        )
    for path in (zh_body_path, en_body_path):
        if path.exists() and not replace:
            raise click.ClickException(
                f"Remote announcement body already exists; pass --replace to overwrite: {path}"
            )

    zh_body_path.parent.mkdir(parents=True, exist_ok=True)
    en_body_path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(zh_path, zh_body_path)
    shutil.copyfile(en_path, en_body_path)

    entry = {
        "id": resolved_document_id,
        "kind": "announcement",
        "source": "remote",
        "publishedAt": resolved_published_at,
        "tags": resolved_tags,
        "startup": startup,
        "minAppVer": resolved_min_app_ver,
        "appVer": None,
        "localizations": {
            "en": {
                "title": title_en,
                "summary": summary_en,
                "bodyPath": f"documents/body/en/{resolved_document_id}.md",
            },
            "zh": {
                "title": title_zh,
                "summary": summary_zh,
                "bodyPath": f"documents/body/zh/{resolved_document_id}.md",
            },
        },
    }
    if existing_indexes:
        entries[existing_indexes[0]] = entry
    else:
        entries.append(entry)
    __write_json_object(catalog_path, catalog)

    index = __read_json_object(
        index_path,
        {
            "schemaVersion": 1,
            "minClientApi": 1,
            "channel": resolved_channel,
            "region": "global",
        },
    )
    generated_at = __utc_timestamp()
    index["generatedAt"] = generated_at
    index["schemaVersion"] = index.get("schemaVersion", 1)
    index["minClientApi"] = index.get("minClientApi", 1)
    index["channel"] = resolved_channel
    documents = index.get("documents")
    if not isinstance(documents, dict):
        documents = {}
    documents["catalogPath"] = f"channels/{resolved_channel}/documents/catalog.json"
    documents["revision"] = (
        f"docs-{generated_at.replace('-', '').replace(':', '')}-{resolved_document_id}"
    )
    index["documents"] = documents
    __write_json_object(index_path, index)

    click.echo(
        styled([Style.BRIGHT, Fore.GREEN], "Prepared remote announcement: ") + resolved_document_id
    )
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Catalog: ") + str(catalog_path))
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Index: ") + str(index_path))


def __require_bundle_descriptor_string(
    descriptor: dict[str, object],
    key: str,
    bundle_path: Path,
) -> str:
    value = descriptor.get(key)
    if not isinstance(value, str) or not value:
        raise click.ClickException(
            f"Bundle descriptor is missing string field {key}: {bundle_path}"
        )
    return value


def __bundle_artifact_entry(
    *,
    archive_path: Path,
    manifest_path: Path,
    artifact_id: str,
    variant: str,
    descriptor: dict[str, object],
    artifact_relative_path: str,
    manifest_relative_path: str,
) -> dict[str, object]:
    manifest_hash = descriptor.get("manifestHash")
    if not isinstance(manifest_hash, str) or not manifest_hash:
        manifest_hash = __file_sha256(manifest_path)

    entry: dict[str, object] = {
        "artifactId": artifact_id,
        "bundleId": __require_bundle_descriptor_string(descriptor, "bundleId", archive_path),
        "variant": variant,
        "appVersion": __require_bundle_descriptor_string(descriptor, "appVersion", archive_path),
        "gameVersion": __require_bundle_descriptor_string(descriptor, "gameVersion", archive_path),
        "gameBuild": __require_bundle_descriptor_string(descriptor, "gameBuild", archive_path),
        "gameRegion": __require_bundle_descriptor_string(descriptor, "gameRegion", archive_path),
        "gameBranch": __require_bundle_descriptor_string(descriptor, "gameBranch", archive_path),
        "gameServer": __require_bundle_descriptor_string(descriptor, "gameServer", archive_path),
        "generatedAt": __utc_timestamp(),
        "artifactPath": artifact_relative_path,
        "artifactSize": archive_path.stat().st_size,
        "artifactSha256": __file_sha256(archive_path),
        "manifestPath": manifest_relative_path,
        "manifestHash": manifest_hash,
    }
    if variant == "incremental":
        entry["baseBundleId"] = __require_bundle_descriptor_string(
            descriptor, "baseBundleId", archive_path
        )
        entry["baseManifestHash"] = __require_bundle_descriptor_string(
            descriptor, "baseManifestHash", archive_path
        )
    return entry


def __stage_remote_bundle_file(source: Path, target: Path, replace: bool) -> None:
    if not source.is_file():
        raise click.ClickException(f"Bundle preparation source file does not exist: {source}")
    if target.exists() and not replace:
        raise click.ClickException(
            f"Remote bundle artifact already exists; pass --replace to overwrite: {target}"
        )
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, target)


def __upsert_remote_bundle_entry(
    entries: list[object],
    entry: dict[str, object],
    replace: bool,
) -> None:
    artifact_id = entry["artifactId"]
    existing_indexes = [
        index
        for index, existing in enumerate(entries)
        if isinstance(existing, dict) and existing.get("artifactId") == artifact_id
    ]
    if existing_indexes and not replace:
        raise click.ClickException(
            f"Remote bundle artifact already exists; pass --replace to overwrite: {artifact_id}"
        )
    if existing_indexes:
        entries[existing_indexes[0]] = entry
    else:
        entries.append(entry)


@prepare.command("bundle")
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
    "--replace",
    is_flag=True,
    default=False,
    help="Allow replacing existing artifact catalog entries and files.",
)
@click.option("--origin-dir", type=click.Path(path_type=Path), default=None)
@click.option("--resource-root", default=None, help="Override remote resource root.")
@click.option("--channel", default=None, help="Override remote channel.")
def remote_prepare_bundle(
    full_path: Path,
    manifest_path: Path,
    artifact_id: str,
    increment_path: Path | None,
    increment_artifact_id: str | None,
    replace: bool,
    origin_dir: Path | None,
    resource_root: str | None,
    channel: str | None,
):
    """Prepare remote bundle catalog entries and artifact files."""
    data.lib.config.DeveloperConfiguration.ensure_loaded()
    if increment_path is not None and increment_artifact_id is None:
        raise click.ClickException("--increment-artifact-id is required when --increment is used.")
    if increment_path is None and increment_artifact_id is not None:
        raise click.ClickException("--increment-artifact-id requires --increment.")
    if not manifest_path.is_file():
        raise click.ClickException(f"Bundle manifest file does not exist: {manifest_path}")

    remote_cfg = data.lib.config.DEV_CONFIGURATION.remote
    resolved_origin_dir = __resolve_dev_path(origin_dir or remote_cfg.mock_origin_dir)
    resolved_resource_root = __validate_remote_resource_root(
        resource_root or remote_cfg.resource_root
    )
    resolved_channel = __validate_remote_channel(channel or remote_cfg.channel)
    resolved_artifact_id = __validate_remote_artifact_id(artifact_id)

    full_descriptor = __read_zip_json(full_path, "descriptor.json")
    if full_descriptor.get("isIncremental") is True:
        raise click.ClickException(f"Full bundle archive must not be incremental: {full_path}")
    bundle_id = __require_bundle_descriptor_string(full_descriptor, "bundleId", full_path)

    root_dir = resolved_origin_dir / resolved_resource_root
    channel_dir = root_dir / "channels" / resolved_channel
    catalog_path = channel_dir / "bundles" / "catalog.json"
    index_path = channel_dir / "index.json"
    bundle_dir = root_dir / "bundles" / bundle_id

    full_zip_relative_path = f"bundles/{bundle_id}/{resolved_artifact_id}.zip"
    full_manifest_relative_path = f"bundles/{bundle_id}/{resolved_artifact_id}.manifest.json"
    full_zip_target = root_dir / full_zip_relative_path
    full_manifest_target = root_dir / full_manifest_relative_path
    files_to_stage = [
        (full_path, full_zip_target),
        (manifest_path, full_manifest_target),
    ]

    prepared_entries = [
        __bundle_artifact_entry(
            archive_path=full_path,
            manifest_path=manifest_path,
            artifact_id=resolved_artifact_id,
            variant="full",
            descriptor=full_descriptor,
            artifact_relative_path=full_zip_relative_path,
            manifest_relative_path=full_manifest_relative_path,
        )
    ]

    if increment_path is not None and increment_artifact_id is not None:
        resolved_increment_artifact_id = __validate_remote_artifact_id(increment_artifact_id)
        increment_descriptor = __read_zip_json(increment_path, "descriptor.json")
        if increment_descriptor.get("isIncremental") is not True:
            raise click.ClickException(
                f"Incremental bundle archive must declare isIncremental: {increment_path}"
            )
        increment_bundle_id = __require_bundle_descriptor_string(
            increment_descriptor, "bundleId", increment_path
        )
        if increment_bundle_id != bundle_id:
            raise click.ClickException(
                f"Incremental bundle id does not match full bundle: {increment_bundle_id} != {bundle_id}"
            )
        increment_base_bundle_id = __require_bundle_descriptor_string(
            increment_descriptor, "baseBundleId", increment_path
        )
        if increment_base_bundle_id != bundle_id:
            raise click.ClickException(
                "Incremental base bundle id does not match full bundle: "
                f"{increment_base_bundle_id} != {bundle_id}"
            )
        __require_bundle_descriptor_string(increment_descriptor, "baseManifestHash", increment_path)

        increment_relative_path = f"bundles/{bundle_id}/{resolved_increment_artifact_id}.zip"
        increment_target = root_dir / increment_relative_path
        files_to_stage.append((increment_path, increment_target))
        prepared_entries.append(
            __bundle_artifact_entry(
                archive_path=increment_path,
                manifest_path=manifest_path,
                artifact_id=resolved_increment_artifact_id,
                variant="incremental",
                descriptor=increment_descriptor,
                artifact_relative_path=increment_relative_path,
                manifest_relative_path=full_manifest_relative_path,
            )
        )

    catalog = __read_json_object(
        catalog_path,
        {
            "schemaVersion": 1,
            "artifacts": [],
        },
    )
    entries = catalog.get("artifacts")
    if not isinstance(entries, list):
        raise click.ClickException(
            f"Remote bundle catalog artifacts must be a list: {catalog_path}"
        )
    prepared_artifact_ids = [entry["artifactId"] for entry in prepared_entries]
    if len(set(prepared_artifact_ids)) != len(prepared_artifact_ids):
        raise click.ClickException(
            "Remote bundle artifact ids must be unique within one preparation."
        )
    for entry in prepared_entries:
        __upsert_remote_bundle_entry(entries, entry, replace)
    for source, target in files_to_stage:
        __stage_remote_bundle_file(source, target, replace)
    __write_json_object(catalog_path, catalog)

    index = __read_json_object(
        index_path,
        {
            "schemaVersion": 1,
            "minClientApi": 1,
            "channel": resolved_channel,
            "region": "global",
        },
    )
    generated_at = __utc_timestamp()
    index["generatedAt"] = generated_at
    index["schemaVersion"] = index.get("schemaVersion", 1)
    index["minClientApi"] = index.get("minClientApi", 1)
    index["channel"] = resolved_channel
    bundles = index.get("bundles")
    if not isinstance(bundles, dict):
        bundles = {}
    bundles["catalogPath"] = f"channels/{resolved_channel}/bundles/catalog.json"
    bundles["revision"] = f"bundles-{generated_at.replace('-', '').replace(':', '')}-{bundle_id}"
    index["bundles"] = bundles
    __write_json_object(index_path, index)

    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Prepared remote bundle: ") + bundle_id)
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Catalog: ") + str(catalog_path))
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Bundle artifacts: ") + str(bundle_dir))
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Index: ") + str(index_path))


@remote.group(cls=ClickAliasedGroup)
def publish():
    """Remote content publishing commands."""


@publish.command("upload")
@click.option(
    "--target",
    type=click.Choice(["minio", "s3"], case_sensitive=False),
    default="minio",
    show_default=True,
    help="S3-compatible upload target preset.",
)
@click.option("--source-dir", type=click.Path(path_type=Path), default=None)
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
    """Upload a local remote origin to S3-compatible object storage."""
    data.lib.config.DeveloperConfiguration.ensure_loaded()
    remote_cfg = data.lib.config.DEV_CONFIGURATION.remote
    resolved_source_dir = __resolve_dev_path(source_dir or remote_cfg.mock_origin_dir)
    resolved_endpoint = endpoint
    if resolved_endpoint is None and target.lower() == "minio":
        resolved_endpoint = f"http://{remote_cfg.host}:{remote_cfg.minio_port}"
    if resolved_endpoint is None:
        raise click.ClickException("Remote publish endpoint is required for non-MinIO targets.")

    __publish_remote_origin_to_s3(
        source_dir=resolved_source_dir,
        endpoint=resolved_endpoint,
        bucket=bucket or remote_cfg.minio_bucket,
        access_key=access_key or remote_cfg.minio_access_key,
        secret_key=secret_key or remote_cfg.minio_secret_key,
        alias_name=alias_name or remote_cfg.publish_alias,
        resource_root=resource_root or remote_cfg.resource_root,
        channel=channel or remote_cfg.channel,
        clean_bucket=clean,
        public_download=(
            remote_cfg.publish_public_download if public_download is None else public_download
        ),
    )


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
def remote_mock_launch(
    backend: str,
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
        alias_name=alias_name or remote_cfg.publish_alias,
        resource_root=resolved_resource_root,
        channel=resolved_channel,
        clean_bucket=clean_bucket,
        public_download=remote_cfg.publish_public_download,
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
