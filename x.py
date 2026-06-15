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

from concurrent.futures import ThreadPoolExecutor
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
from data.lib.remote.session import SessionManager
from data.lib.remote.session import SessionManagerCommittedError
from data.lib.remote.session import SessionManagerInvalidError
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


def __resource_root(value: str) -> str:
    return value.strip("/")


def __remote_channel_index_url(*, origin_url: str, resource_root: str, channel: Channel) -> str:
    return f"{origin_url.rstrip('/')}/{__resource_root(resource_root)}/channels/{channel.value}/index.json"


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
        + __remote_channel_index_url(
            origin_url=__remote_origin_url(endpoint=endpoint, bucket=resolved_bucket),
            resource_root=resolved_resource_root,
            channel=channel,
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
        resolved["minioIndexUrl"] = __remote_channel_index_url(
            origin_url=minio_origin_url,
            resource_root=data.lib.config.CONFIGURATION.data_schema.resource_root,
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
    promote_current_id = None
    promote_current_path = sessions_root / "current-promote"
    if promote_current_path.is_file():
        promote_current_id = promote_current_path.read_text(encoding="utf-8").strip()

    click.echo()
    click.echo(styled([Style.BRIGHT, Fore.CYAN], "Session status"))

    if sessions_root.is_dir():
        session_dirs = sorted(
            [
                d
                for d in sessions_root.iterdir()
                if d.is_dir() and d.name not in ("current", "current-promote")
            ],
            reverse=True,
        )
    else:
        session_dirs = []

    if not session_dirs and not current_id and not promote_current_id:
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

    if promote_current_id:
        is_active = (sessions_root / promote_current_id / "lockfile.json").is_file()
        state = "active" if is_active else "committed"
        click.echo(
            styled([Style.BRIGHT, Fore.GREEN], f"  Promote:  {promote_current_id}  [{state}]")
        )

        s_path = sessions_root / promote_current_id
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

    click.echo(styled([Style.BRIGHT, Fore.CYAN], f"  Sessions root: {sessions_root}"))


def __get_session_root() -> Path:
    data.lib.config.DeveloperConfiguration.ensure_loaded()
    return __resolve_dev_path(data.lib.config.DEV_CONFIGURATION.paths.session_dir)


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
        mgr = _get_session(session_id)
        if not mgr.status().committed:
            raise click.ClickException(
                f"Session has not been committed."
                f" Run `./x remote prepare publish --session-id {mgr.session_id}` first."
            )
    else:
        try:
            mgr = SessionManager.find_latest_committed(__get_session_root())
        except FileNotFoundError as exc:
            raise click.ClickException(str(exc)) from exc
    merged = mgr.session_dir / "merged"
    if not merged.is_dir():
        raise click.ClickException(
            f"Session has no merged output."
            f" Run `./x remote prepare publish --session-id {mgr.session_id}` first."
        )
    return merged, mgr.session_id


def __resolve_publish_generation(
    *,
    source_dir: Path,
    session_id: str | None,
    channel: Channel,
    resource_root: str,
) -> str:
    from data.lib.remote.session import _generate_publish_id

    resolved_resource_root = __validate_remote_resource_root(resource_root)
    if session_id is not None:
        mgr = _get_session(session_id)
        todo = mgr._load_todo()
        if todo.generation:
            return todo.generation
        return _generate_publish_id()
    # --source-dir mode: extract generation from the source's index.json
    ch_dir = source_dir / resolved_resource_root / "channels" / channel.value
    gen = _read_generation_from_channel_dir(ch_dir)
    if gen is not None:
        return gen
    return _generate_publish_id()


def _read_generation_from_channel_dir(ch_dir: Path) -> str | None:
    legacy = ch_dir / "index.json"
    if legacy.is_file():
        index_data: dict[str, object] = json.loads(legacy.read_text(encoding="utf-8"))
        gen = index_data.get("generation")
        if isinstance(gen, str) and gen:
            return gen
    for gen_dir in sorted(ch_dir.glob(".generations/*"), reverse=True):
        idx = gen_dir / "index.json"
        if idx.is_file():
            index_data = json.loads(idx.read_text(encoding="utf-8"))
            gen = index_data.get("generation")
            if isinstance(gen, str) and gen:
                return gen
    return None


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
    channel: Channel,
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

        # Download index.json first to locate catalog files
        _run_mc(
            [mc, "cp", f"{ch_target}/index.json", str(tmp_path / channel / "index.json")],
            [mc, "cp", f"{ch_target}/index.json", f"<tmp>/{channel}/index.json"],
            "GC FETCH index.json",
        )

        index_path = tmp_path / channel / "index.json"
        docs_cat_remote = f"{ch_target}/documents/catalog.json"
        bundles_cat_remote = f"{ch_target}/bundles/catalog.json"
        if index_path.is_file():
            index_data: dict[str, object] = json.loads(index_path.read_text(encoding="utf-8"))
            docs = index_data.get("documents", {})
            if isinstance(docs, dict):
                cp = docs.get("catalogPath")
                if isinstance(cp, str):
                    docs_cat_remote = f"{alias_name}/{bucket}/{cp}"
            bundles = index_data.get("bundles", {})
            if isinstance(bundles, dict):
                cp = bundles.get("catalogPath")
                if isinstance(cp, str):
                    bundles_cat_remote = f"{alias_name}/{bucket}/{cp}"

        docs_local = tmp_path / channel / "documents" / "catalog.json"
        docs_local.parent.mkdir(parents=True, exist_ok=True)
        with contextlib.suppress(OSError):
            _run_mc(
                [mc, "cp", docs_cat_remote, str(docs_local)],
                [mc, "cp", docs_cat_remote, f"<tmp>/{channel}/documents/catalog.json"],
                "GC FETCH documents/catalog.json",
            )

        bundles_local = tmp_path / channel / "bundles" / "catalog.json"
        bundles_local.parent.mkdir(parents=True, exist_ok=True)
        with contextlib.suppress(OSError):
            _run_mc(
                [mc, "cp", bundles_cat_remote, str(bundles_local)],
                [mc, "cp", bundles_cat_remote, f"<tmp>/{channel}/bundles/catalog.json"],
                "GC FETCH bundles/catalog.json",
            )

        referenced: set[str] = set()

        if docs_local.is_file():
            docs: dict[str, object] = json.loads(docs_local.read_text(encoding="utf-8"))
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

        if bundles_local.is_file():
            bundles: dict[str, object] = json.loads(bundles_local.read_text(encoding="utf-8"))
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
    channel: Channel,
    *,
    dry_run: bool,
    keep_generations: int = 2,
) -> str:
    """Prune unreferenced objects from the remote bucket.

    Collects all referenced paths from current catalogs via exact path
    matching, then deletes anything in ``documents/body/`` and ``bundles/``
    that isn't referenced.  Also prunes old generations beyond *keep_generations*
    and cleans up stale deployment snapshots.
    Returns a human-readable summary.
    """
    bucket_target = f"{alias_name}/{bucket}/{resource_root}"
    gen_prefix = f"channels/{channel}/.generations"

    # Collect active generation and prune old generations
    generations_stale: list[tuple[str, str]] = []
    try:
        out = subprocess.run(
            [mc, "ls", "--json", f"{bucket_target}/{gen_prefix}/"],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
        if out.returncode == 0:
            gen_names: list[str] = []
            for line in out.stdout.strip().splitlines():
                try:
                    obj: dict[str, object] = json.loads(line)
                except ValueError:
                    continue
                key = obj.get("key", "")
                if not isinstance(key, str):
                    continue
                rel = (
                    key.removeprefix(f"{resource_root}/")
                    if key.startswith(f"{resource_root}/")
                    else key
                )
                name = rel.removeprefix(f"{gen_prefix}/").rstrip("/")
                if name and "/" not in name:
                    gen_names.append(name)
            gen_names.sort(reverse=True)
            for stale_gen in gen_names[keep_generations:]:
                stale_key = f"{gen_prefix}/{stale_gen}"
                generations_stale.append((stale_key, "0"))
    except Exception:
        pass

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
        if generations_stale:
            lines.append(
                f"Would delete {len(generations_stale)} stale generation(s)"
                f" (keeping {keep_generations}):"
            )
            for key, _size in sorted(generations_stale):
                lines.append(f"  {resource_root}/{key}/")
        if unreferenced:
            lines.append(f"Would delete {len(unreferenced)} unreferenced object(s):")
            for key, size in sorted(unreferenced):
                lines.append(f"  {key}  ({size} bytes)")
        if stale_deps:
            lines.append(f"Would delete {len(stale_deps)} stale deployment artifact(s):")
            for key, size in sorted(stale_deps):
                lines.append(f"  {key}  ({size} bytes)")
        if not generations_stale and not unreferenced and not stale_deps:
            return "Nothing to prune."
        return "\n".join(lines)

    deleted_gens = 0
    for gen_rel, _size in generations_stale:
        full_key = f"{resource_root}/{gen_rel}"
        with contextlib.suppress(OSError):
            _run_mc(
                [mc, "rm", "--recursive", "--force", f"{alias_name}/{bucket}/{full_key}"],
                [mc, "rm", "--recursive", "--force", f"{alias_name}/{bucket}/{full_key}"],
                "GC DELETE GENERATION",
            )
            deleted_gens += 1

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
    if deleted_gens:
        parts.append(f"{deleted_gens} stale generation(s)")
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


def _resolve_verify_flag(
    *,
    cli_value: bool | None,
    target: str,
) -> bool:
    """Resolve the verify flag from CLI > target config > global override > target default."""
    if cli_value is not None:
        return cli_value
    data.lib.config.DeveloperConfiguration.ensure_loaded()
    remote_cfg = data.lib.config.DEV_CONFIGURATION.remote
    if remote_cfg.verify_upload is not None:
        return remote_cfg.verify_upload
    if target.lower() == "minio":
        return remote_cfg.require_minio().verify_upload
    return remote_cfg.require_s3().verify_upload


def _resolve_verify_workers(
    *,
    cli_value: int | None,
    target: str,
) -> int:
    """Resolve verify_workers from CLI > target config > global override > target default (4)."""
    if cli_value is not None and cli_value > 0:
        return cli_value
    data.lib.config.DeveloperConfiguration.ensure_loaded()
    remote_cfg = data.lib.config.DEV_CONFIGURATION.remote
    if remote_cfg.verify_workers is not None and remote_cfg.verify_workers > 0:
        return remote_cfg.verify_workers
    if target.lower() == "minio":
        return remote_cfg.require_minio().verify_workers
    return remote_cfg.require_s3().verify_workers


def _resolve_local_index(channel_dir: Path, generation: str) -> Path:
    gen_path = channel_dir / ".generations" / generation / "index.json"
    if gen_path.is_file():
        return gen_path
    legacy = channel_dir / "index.json"
    if legacy.is_file():
        return legacy
    for gen_dir in sorted(channel_dir.glob(".generations/*"), reverse=True):
        idx = gen_dir / "index.json"
        if idx.is_file():
            return idx
    return legacy


def _resolve_local_catalog_file(
    channel_dir: Path, index_data: dict[str, object], section: str
) -> Path:
    sec = index_data.get(section, {})
    if isinstance(sec, dict):
        cp = sec.get("catalogPath")
        if isinstance(cp, str):
            parts = cp.split("/")
            try:
                gen_idx = parts.index(".generations")
                rel = "/".join(parts[gen_idx:])
                return channel_dir / rel
            except ValueError:
                pass
    return channel_dir / section / "catalog.json"


def _resolve_local_app_releases(
    channel_dir: Path, index_data: dict[str, object], generation: str | None
) -> Path:
    app = index_data.get("app", {})
    if isinstance(app, dict):
        rp = app.get("releasesPath")
        if isinstance(rp, str):
            parts = rp.split("/")
            try:
                gen_idx = parts.index(".generations")
                rel = "/".join(parts[gen_idx:])
                return channel_dir / rel
            except ValueError:
                pass
    if generation:
        return channel_dir / ".generations" / generation / "app" / "releases.json"
    return channel_dir / "app" / "releases.json"


def __verify_upload_integrity(
    *,
    source_dir: Path,
    mc_bin: str,
    bucket_target: str,
    resource_root: str,
    channel: Channel,
    generation: str,
    session_id: str | None = None,
    verify_workers: int = 4,
) -> list[str]:
    """Verify uploaded files match local source by re-downloading and comparing SHA256.

    For session uploads, only files from staged operations are verified.
    For --source-dir uploads, all catalog entries are verified.

    Returns a list of error strings (empty = all good).
    """

    local_root = source_dir / resource_root
    channel_dir = local_root / "channels" / channel
    remote_root = f"{bucket_target}/{resource_root}"
    remote_channel = f"{remote_root}/channels/{channel}"

    items: list[dict[str, str]] = []

    tracked_artifact_ids: set[str] | None = None
    tracked_document_ids: set[str] | None = None

    if session_id is not None:
        from data.lib.remote.session import SessionManager as SessionMgr

        sessions_root = __get_session_root()
        mgr = SessionMgr.from_session_id(sessions_root, session_id)
        todo = mgr._load_todo()
        tracked_artifact_ids = set()
        tracked_document_ids = set()
        for op in todo.operations:
            if isinstance(op, data.lib.remote.models.AddBundleOp):
                tracked_artifact_ids.add(op.artifact_id)
            elif isinstance(
                op, (data.lib.remote.models.AddAnnouncementOp, data.lib.remote.models.AddVersionOp)
            ):
                tracked_document_ids.add(op.document_id)

    # Resolve index.json — prefer the generation-specific path matching the upload
    index_local_path = _resolve_local_index(channel_dir, generation)
    if not index_local_path.is_file():
        return ["Local index.json not found for verification."]

    index_data: dict[str, object] = json.loads(index_local_path.read_text(encoding="utf-8"))

    remote_channel_url = f"{remote_channel}/.generations/{generation}"

    items.append(
        {
            "remote": f"{remote_channel}/index.json",
            "sha256": __file_sha256(index_local_path),
            "label": "index.json",
            "mc": mc_bin,
        }
    )

    docs_catalog_local = _resolve_local_catalog_file(channel_dir, index_data, "documents")
    bundles_catalog_local = _resolve_local_catalog_file(channel_dir, index_data, "bundles")
    app_releases_local = _resolve_local_app_releases(channel_dir, index_data, generation)

    for label, local_path, remote_suffix in [
        ("documents/catalog.json", docs_catalog_local, "/documents/catalog.json"),
        ("bundles/catalog.json", bundles_catalog_local, "/bundles/catalog.json"),
    ]:
        if local_path and local_path.is_file():
            items.append(
                {
                    "remote": f"{remote_channel_url}{remote_suffix}",
                    "sha256": __file_sha256(local_path),
                    "label": label,
                    "mc": mc_bin,
                }
            )

    if app_releases_local and app_releases_local.is_file():
        items.append(
            {
                "remote": f"{remote_channel_url}/app/releases.json",
                "sha256": __file_sha256(app_releases_local),
                "label": "app/releases.json",
                "mc": mc_bin,
            }
        )

    bundles_catalog_path = bundles_catalog_local
    if bundles_catalog_path and bundles_catalog_path.is_file():
        bundles_catalog = json.loads(bundles_catalog_path.read_text(encoding="utf-8"))
        if isinstance(bundles_catalog, dict):
            artifacts = bundles_catalog.get("artifacts")
            if isinstance(artifacts, list):
                for entry in artifacts:
                    if not isinstance(entry, dict):
                        continue
                    a_id = entry.get("artifactId")
                    if not isinstance(a_id, str):
                        continue
                    if tracked_artifact_ids is not None and a_id not in tracked_artifact_ids:
                        continue
                    artifact_path = entry.get("artifactPath")
                    expected_sha256 = entry.get("artifactSha256")
                    if not isinstance(artifact_path, str) or not isinstance(expected_sha256, str):
                        continue
                    items.append(
                        {
                            "remote": f"{remote_root}/{artifact_path}",
                            "sha256": expected_sha256,
                            "label": f"bundle {a_id}",
                            "mc": mc_bin,
                        }
                    )

    docs_catalog_path = docs_catalog_local
    if docs_catalog_path and docs_catalog_path.is_file():
        docs_catalog = json.loads(docs_catalog_path.read_text(encoding="utf-8"))
        if isinstance(docs_catalog, dict):
            entries = docs_catalog.get("entries")
            if isinstance(entries, list):
                for entry in entries:
                    if not isinstance(entry, dict):
                        continue
                    doc_id = entry.get("id")
                    if not isinstance(doc_id, str):
                        continue
                    if tracked_document_ids is not None and doc_id not in tracked_document_ids:
                        continue
                    localizations = entry.get("localizations")
                    if not isinstance(localizations, dict):
                        continue
                    for lang, loc in localizations.items():
                        if not isinstance(loc, dict):
                            continue
                        body_path = loc.get("bodyPath")
                        expected_sha256 = loc.get("bodySha256")
                        if not isinstance(body_path, str) or not isinstance(expected_sha256, str):
                            continue
                        items.append(
                            {
                                "remote": f"{remote_root}/{body_path}",
                                "sha256": expected_sha256,
                                "label": f"document body {doc_id} ({lang})",
                                "mc": mc_bin,
                            }
                        )

    if not items:
        return []

    worker_count = min(verify_workers, len(items))
    click.echo(
        styled([Style.BRIGHT, Fore.CYAN], f"Verifying {len(items)} file(s) ")
        + f"with {worker_count} worker(s)..."
    )

    errors: list[str] = []
    with ThreadPoolExecutor(max_workers=worker_count) as executor:
        results = list(executor.map(_verify_one_item, items))

    for i, (item, err) in enumerate(zip(items, results, strict=True), 1):
        if err:
            click.echo(
                styled([Style.BRIGHT, Fore.RED], f"  [{i}/{len(items)}] FAIL ") + item["label"]
            )
            errors.append(err)
        else:
            click.echo(
                styled([Style.BRIGHT, Fore.GREEN], f"  [{i}/{len(items)}] OK   ") + item["label"]
            )

    if errors:
        click.echo()
        click.echo(
            styled([Style.BRIGHT, Fore.RED], "Verification summary: ")
            + f"{len(items) - len(errors)}/{len(items)} passed, {len(errors)} failed."
        )
    else:
        click.echo(
            styled([Style.BRIGHT, Fore.GREEN], "Verification summary: ")
            + f"all {len(items)} file(s) passed."
        )

    return errors


def _verify_remote_file(
    *,
    mc_bin: str,
    remote_path: str,
    expected_sha256: str,
    label: str,
) -> str | None:
    """Download a single remote file to a temp location and compare its SHA256.

    Returns an error string on mismatch, or None on success.
    """
    import tempfile

    with tempfile.NamedTemporaryFile(suffix=".verify", delete=False) as tmp:
        tmp_path = Path(tmp.name)
    try:
        cmd = [mc_bin, "cp", remote_path, str(tmp_path)]
        out = subprocess.run(
            cmd, capture_output=True, text=True, encoding="utf-8", errors="replace"
        )
        if out.returncode != 0:
            stderr = (out.stderr or "").strip()
            return f"Failed to download {label} from {remote_path}: [{out.returncode}] {stderr}"
        actual_sha256 = __file_sha256(tmp_path)
        if actual_sha256 != expected_sha256:
            return (
                f"SHA256 mismatch for {label}:\n"
                f"  expected: {expected_sha256}\n"
                f"  actual:   {actual_sha256}"
            )
        return None
    finally:
        tmp_path.unlink(missing_ok=True)


def _verify_one_item(item: dict[str, str]) -> str | None:
    """Adapter for ThreadPoolExecutor.map — unpacks item dict into _verify_remote_file."""
    return _verify_remote_file(
        mc_bin=item["mc"],
        remote_path=item["remote"],
        expected_sha256=item["sha256"],
        label=item["label"],
    )


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
@click.option(
    "--clean",
    is_flag=True,
    default=False,
    help="Run garbage collection after successful publish to prune old generations and unreferenced content.",
)
@click.option(
    "--public-download/--private",
    default=None,
    help="Configure anonymous bucket downloads after upload.",
)
@click.option(
    "--verify/--no-verify",
    default=None,
    help="Verify uploaded file integrity after publish (overrides config).",
)
@click.option(
    "--verify-workers",
    type=int,
    default=None,
    help="Number of concurrent download workers for verification (default: 4).",
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
    verify: bool | None,
    verify_workers: int | None,
):
    """Upload a local remote origin or committed session to S3-compatible object storage."""
    data.lib.config.DeveloperConfiguration.ensure_loaded()
    data.lib.config.ProjectConfiguration.ensure_loaded()
    remote_cfg = data.lib.config.DEV_CONFIGURATION.remote
    resolved_source_dir, resolved_session_id = __resolve_publish_source(
        source_dir=source_dir, session_id=session_id
    )
    resolved_resource_root = __validate_remote_resource_root(
        resource_root or data.lib.config.CONFIGURATION.data_schema.resource_root
    )
    resolved_channel = __validate_remote_channel(channel or remote_cfg.channel.value)

    generation = __resolve_publish_generation(
        source_dir=resolved_source_dir,
        session_id=resolved_session_id,
        channel=resolved_channel,
        resource_root=resolved_resource_root,
    )

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
        generation=generation,
        public_download=resolved_public_download,
        target=target,
    )

    resolved_verify = _resolve_verify_flag(
        cli_value=verify,
        target=target,
    )
    if resolved_verify:
        mc_bin = get_command("mc")
        bucket_target = f"{resolved_alias}/{resolved_bucket}"
        resolved_workers = _resolve_verify_workers(
            cli_value=verify_workers,
            target=target,
        )
        verify_errors = __verify_upload_integrity(
            source_dir=resolved_source_dir,
            mc_bin=mc_bin,
            bucket_target=bucket_target,
            resource_root=resolved_resource_root,
            channel=resolved_channel,
            generation=generation,
            session_id=resolved_session_id if source_dir is None else None,
            verify_workers=resolved_workers,
        )
        if verify_errors:
            for err in verify_errors:
                click.echo(styled([Style.BRIGHT, Fore.RED], "ERROR: ") + err)
            raise click.ClickException(
                f"Upload verification failed with {len(verify_errors)} error(s)."
            )
        click.echo(
            styled([Style.BRIGHT, Fore.GREEN], "Verification passed: ")
            + "all uploaded files match local source."
        )

    if clean:
        click.echo(styled([Style.BRIGHT, Fore.CYAN], "Running post-publish garbage collection..."))
        mc_bin = get_command("mc")
        bucket_target = f"{resolved_alias}/{resolved_bucket}"
        summary = __gc_unreferenced_objects(
            mc=mc_bin,
            alias_name=resolved_alias,
            bucket=resolved_bucket,
            resource_root=resolved_resource_root,
            channel=resolved_channel,
            dry_run=False,
        )
        click.echo(summary)

    if source_dir is None and not keep_session and resolved_session_id:
        mgr = _get_session(resolved_session_id)
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
@click.option(
    "--keep-generations",
    type=int,
    default=2,
    show_default=True,
    help="Number of generations to keep (current + N-1 previous).",
)
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
    keep_generations: int,
):
    """Prune unreferenced objects from the remote bucket."""
    if keep_generations < 1:
        raise click.ClickException(
            "--keep-generations must be >= 1 to preserve at least the current live generation."
        )
    data.lib.config.DeveloperConfiguration.ensure_loaded()
    data.lib.config.ProjectConfiguration.ensure_loaded()
    remote_cfg = data.lib.config.DEV_CONFIGURATION.remote
    resolved_resource_root = __validate_remote_resource_root(
        resource_root or data.lib.config.CONFIGURATION.data_schema.resource_root
    )
    resolved_channel = __validate_remote_channel(channel or remote_cfg.channel.value)

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
            "--api",
            "s3v4",
        ],
        [
            mc,
            "alias",
            "set",
            resolved_alias,
            str(s3["endpoint"]),
            redacted,
            redacted,
            "--api",
            "s3v4",
        ],
        "GC ALIAS",
    )

    summary = __gc_unreferenced_objects(
        mc=mc,
        alias_name=resolved_alias,
        bucket=resolved_bucket,
        resource_root=resolved_resource_root,
        channel=resolved_channel,
        dry_run=dry_run,
        keep_generations=keep_generations,
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
    data.lib.config.ProjectConfiguration.ensure_loaded()
    remote_cfg = data.lib.config.DEV_CONFIGURATION.remote
    resolved_origin_dir = __resolve_dev_path(origin_dir or remote_cfg.mock_origin_dir)
    resolved_resource_root = __validate_remote_resource_root(
        resource_root or data.lib.config.CONFIGURATION.data_schema.resource_root
    )
    resolved_channel = __validate_remote_channel(channel or remote_cfg.channel.value)

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
    data.lib.config.ProjectConfiguration.ensure_loaded()
    remote_cfg = data.lib.config.DEV_CONFIGURATION.remote

    if output_dir is None:
        stamp = __utc_timestamp().replace("-", "").replace(":", "")
        output_dir = __get_session_root() / f"fetch-{stamp}"

    resolved_resource_root = __validate_remote_resource_root(
        resource_root or data.lib.config.CONFIGURATION.data_schema.resource_root
    )
    resolved_channel = __validate_remote_channel(channel or remote_cfg.channel.value)

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


# ---- status ----------------------------------------------------------------


@remote.command("status")
@click.option(
    "--session-id",
    default=None,
    help="Inspect a specific session instead of the active one.",
)
def remote_status(session_id: str | None):
    """Show the current session status and staged changes."""
    data.lib.config.DeveloperConfiguration.ensure_loaded()
    data.lib.config.ProjectConfiguration.ensure_loaded()
    remote_cfg = data.lib.config.DEV_CONFIGURATION.remote
    sessions_root = __get_session_root()

    if session_id:
        try:
            mgr = SessionManager.from_session_id(sessions_root, session_id)
        except FileNotFoundError as exc:
            raise click.ClickException(f"Session not found: {session_id}") from exc
    else:
        try:
            mgr = _get_session()
        except SessionManagerInvalidError:
            click.echo()
            click.echo(styled([Style.BRIGHT, Fore.CYAN], "Remote status"))
            click.echo()
            click.echo("  No active session.")
            _print_session_list(sessions_root)
            return

    _print_session_status(mgr, remote_cfg)


def _print_session_list(sessions_root: Path) -> None:
    if not sessions_root.is_dir():
        click.echo()
        return
    entries = sorted(
        [
            d
            for d in sessions_root.iterdir()
            if d.is_dir() and d.name not in ("current", "current-promote")
        ],
        reverse=True,
    )
    if not entries:
        click.echo()
        return

    click.echo()
    click.echo(styled(Style.DIM, "  Available sessions:"))
    for d in entries:
        todo_path = d / "todo.json"
        committed = False
        op_count = 0
        if todo_path.is_file():
            try:
                from data.lib.remote.models import TodoList
                from data.lib.remote.models import _load_json_model

                todo = _load_json_model(todo_path, TodoList)
                committed = todo.committed
                op_count = len(todo.operations)
            except Exception:
                pass
        state = "committed" if committed else "active"
        marker = " " if committed else "*"
        prefix = styled([Style.BRIGHT, Fore.GREEN], marker)
        click.echo(f"  {prefix} {d.name}  [{state}]  ({op_count} ops)")


def _print_session_status(mgr: SessionManager, remote_cfg) -> None:
    from data.lib.remote.diff import diff_generations
    from data.lib.remote.diff import read_generation_from_remote
    from data.lib.remote.diff import read_generation_from_staged

    todo = mgr._load_todo()
    gen_id = todo.generation or "unknown"
    channel = mgr.channel or remote_cfg.channel.value

    lockfile_active = mgr.lockfile_path.is_file()
    try:
        lock = mgr._load_lockfile()
    except Exception:
        lock = None

    state = "active" if lockfile_active else "committed"
    state_color = Fore.GREEN if lockfile_active else Fore.YELLOW

    click.echo()
    click.echo(styled([Style.BRIGHT, Fore.CYAN], "Remote status"))
    click.echo()

    click.echo(
        f"  {styled(Style.DIM, 'Session:')}   "
        f"{styled([Style.BRIGHT, state_color], mgr.session_id)}  [{state}]"
    )
    click.echo(f"  {styled(Style.DIM, 'Channel:')}   {channel}")
    if lock:
        click.echo(f"  {styled(Style.DIM, 'Backend:')}   {lock.backend}")
        click.echo(
            f"  {styled(Style.DIM, 'Created:')}   {lock.timestamp} by {lock.host} (PID {lock.pid})"
        )
    click.echo(f"  {styled(Style.DIM, 'Generation:')} {gen_id}")

    staged_resources_dir = mgr.staged_dir / "manifest" / ".generations" / gen_id / "resources"
    has_staged = staged_resources_dir.is_dir() and any(staged_resources_dir.rglob("*.json"))

    if not has_staged:
        click.echo()
        click.echo(f"  {styled(Style.DIM, 'Nothing staged.')}")
        click.echo()
        click.echo(styled(Style.DIM, f"  Path: {mgr.session_dir}"))
        click.echo()
        return

    remote_state_channel_dir = mgr.remote_state_dir / channel
    has_baseline = remote_state_channel_dir.is_dir()

    if has_baseline:
        pending = read_generation_from_staged(mgr.staged_dir, gen_id)

        try:
            baseline = read_generation_from_remote(mgr.remote_state_dir, channel)
        except (FileNotFoundError, ValueError):
            has_baseline = False

    if has_baseline:
        diff = diff_generations(pending, baseline)

        server_counts = {"added": 0, "removed": 0, "changed": 0, "unchanged": 0}
        for sd in diff.servers:
            server_counts[sd.status] += 1
        ck_added = sum(len(sd.checkout_changes.added) for sd in diff.servers if sd.checkout_changes)
        ck_removed = sum(
            len(sd.checkout_changes.removed) for sd in diff.servers if sd.checkout_changes
        )

        has_changes = (
            server_counts["added"]
            or server_counts["removed"]
            or server_counts["changed"]
            or ck_added
            or ck_removed
            or len(diff.releases.added)
            or len(diff.releases.removed)
            or len(diff.announcements.added)
            or len(diff.announcements.changed)
        )

        if not has_changes:
            click.echo()
            click.echo(f"  {styled(Style.DIM, 'Nothing staged.')}")
        else:
            click.echo()
            click.echo(f"  {styled(Style.DIM, 'Changes to be published:')}")
            click.echo()

            if server_counts["added"]:
                click.echo(
                    f"    {styled(Fore.GREEN, '+')} {server_counts['added']} server(s) added"
                )
            if server_counts["changed"]:
                click.echo(
                    f"    {styled(Fore.YELLOW, '~')} {server_counts['changed']} server(s) modified"
                )
            if server_counts["removed"]:
                click.echo(
                    f"    {styled(Fore.RED, '-')} {server_counts['removed']} server(s) removed"
                )
            if ck_added:
                click.echo(f"    {styled(Fore.GREEN, '+')} {ck_added} checkout(s) added")
            if ck_removed:
                click.echo(f"    {styled(Fore.RED, '-')} {ck_removed} checkout(s) removed")
            if len(diff.releases.added):
                click.echo(
                    f"    {styled(Fore.GREEN, '+')} {len(diff.releases.added)} release(s) added"
                )
            if len(diff.releases.removed):
                click.echo(
                    f"    {styled(Fore.RED, '-')} {len(diff.releases.removed)} release(s) removed"
                )
            if len(diff.announcements.added):
                click.echo(
                    f"    {styled(Fore.GREEN, '+')} "
                    f"{len(diff.announcements.added)} announcement(s) added"
                )
            if len(diff.announcements.changed):
                click.echo(
                    f"    {styled(Fore.YELLOW, '~')} "
                    f"{len(diff.announcements.changed)} announcement(s) modified"
                )
    else:
        total_servers = 0
        total_checkouts = 0
        servers_dir = staged_resources_dir / "servers"
        if servers_dir.is_dir():
            total_servers = len(list(servers_dir.glob("*.json")))
        checkouts_dir = staged_resources_dir / "checkouts"
        if checkouts_dir.is_dir():
            total_checkouts = len(list(checkouts_dir.glob("*.json")))

        ann_added = 0
        rel_added = 0
        for op in todo.operations:
            from data.lib.remote.models import AddAnnouncementsOp
            from data.lib.remote.models import AddReleaseOp

            if isinstance(op, AddReleaseOp):
                rel_added += 1
            elif isinstance(op, AddAnnouncementsOp):
                ann_added += 1

        click.echo()
        click.echo(
            f"  {
                styled(
                    Style.DIM,
                    'Staged (no baseline for diff — start a session with ./x remote prepare init):',
                )
            }"
        )
        click.echo()
        if total_servers:
            click.echo(f"    {total_servers} server(s)")
        if total_checkouts:
            click.echo(f"    {total_checkouts} checkout(s)")
        if rel_added:
            click.echo(f"    {rel_added} release(s)")
        if ann_added:
            click.echo(f"    {ann_added} announcement(s)")

    click.echo()
    click.echo(styled(Style.DIM, f"  Path: {mgr.session_dir}"))
    click.echo()


# ---- prepare (V2) sub-group -------------------------------------------------


def _get_session(session_id: str | None = None) -> SessionManager:
    root = __get_session_root()
    if session_id:
        return SessionManager.from_session_id(root, session_id)
    return SessionManager.from_current(root)


@remote.group(cls=ClickAliasedGroup)
def prepare():
    """V2 schema remote content management (efa/v2/ layout)."""


@prepare.command("init")
@click.option(
    "--backend",
    type=click.Choice(["minio", "s3"]),
    default=None,
    help="Which backend to fetch remote state from (required for --fresh).",
)
@click.option("--resource-root", default=None, help="Override remote resource root.")
@click.option("--channel", default=None, help="Override remote channel.")
@click.option("--description", required=True, help="Description for this generation.")
@click.option(
    "--fresh",
    is_flag=True,
    default=False,
    help="Fetch remote state from S3 instead of auto-chaining from a committed session.",
)
@click.option(
    "--base-session",
    "base_session_id",
    default=None,
    help="Explicitly chain from this committed session ID (overrides auto-chain).",
)
def schema_init(
    backend: str | None,
    resource_root: str | None,
    channel: str | None,
    description: str,
    fresh: bool,
    base_session_id: str | None,
):
    """Start a new V2 schema content session.

    By default auto-chains from the latest committed session (local-only,
    no remote fetch).  Use --fresh to fetch from S3.  Use --base-session to
    chain from a specific committed session.
    """
    data.lib.config.DeveloperConfiguration.ensure_loaded()
    data.lib.config.ProjectConfiguration.ensure_loaded()
    remote_cfg = data.lib.config.DEV_CONFIGURATION.remote
    sessions_root = __get_session_root()

    resolved_resource_root = __validate_remote_resource_root(
        resource_root or data.lib.config.CONFIGURATION.data_schema.resource_root
    )
    resolved_channel = Channel(channel or remote_cfg.channel.value)

    kwargs: dict[str, object] = {
        "description": description,
        "channel": resolved_channel,
        "resource_root": resolved_resource_root,
    }

    # Decide origin base
    if base_session_id:
        base_mgr = SessionManager.from_session_id(sessions_root, base_session_id)
        base_todo_path = base_mgr.session_dir / "todo.json"
        if not base_todo_path.is_file():
            raise click.ClickException(
                f"Base session {base_session_id} has no todo.json (not a valid session)."
            )
        base_todo = data.lib.remote.models._load_json_model(
            base_todo_path, data.lib.remote.models.TodoList
        )
        if not base_todo.committed:
            raise click.ClickException(
                f"Base session {base_session_id} is not committed. Commit it first."
            )
        kwargs["backend"] = "local"
        kwargs["origin_dir"] = base_mgr.merged_dir
        kwargs["parent_session_id"] = base_session_id
        click.echo(
            styled(
                Style.DIM,
                f"Chaining from committed session: {base_session_id}",
            )
        )
    elif not fresh:
        # Auto-chain: find latest committed session
        try:
            base_mgr = SessionManager.find_latest_committed(sessions_root)
            kwargs["backend"] = "local"
            kwargs["origin_dir"] = base_mgr.merged_dir
            kwargs["parent_session_id"] = base_mgr.session_id
            click.echo(
                styled(
                    Style.DIM,
                    f"Auto-chaining from latest committed session: {base_mgr.session_id}",
                )
            )
        except FileNotFoundError:
            # No committed sessions exist — fall through to fresh fetch
            click.echo(
                styled(
                    Style.DIM,
                    "No committed sessions found; fetching from remote.",
                )
            )
            fresh = True

    if fresh:
        if backend is None:
            raise click.UsageError("--backend (minio|s3) is required with --fresh.")
        kwargs["backend"] = backend
        if backend == "minio":
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

    mgr = SessionManager.prepare(sessions_root, **kwargs)  # type: ignore[arg-type]

    click.echo(styled([Style.BRIGHT, Fore.GREEN], f"Session started: {mgr.session_id}"))


@prepare.command("add-resources")
@click.option(
    "--checkout",
    "checkout_path",
    type=click.Path(path_type=Path, exists=True),
    required=True,
    multiple=True,
    help="Path to checkout catalog JSON (can repeat).",
)
@click.option("--server", "server_id", required=True, help="Server ID.")
@click.option("--name-en", required=True, help="Server display name (English).")
@click.option("--name-zh", required=True, help="Server display name (Chinese).")
@click.option("--session-id", default=None, help="Override active session.")
def schema_add_resources(
    checkout_path: list[Path],
    server_id: str,
    name_en: str,
    name_zh: str,
    session_id: str | None,
):
    """Register server and checkout catalogs in the active session."""
    import datetime as _dt

    checkout_catalogs = []
    for p in checkout_path:
        with p.open("r", encoding="utf-8") as f:
            checkout_catalogs.append(json.load(f))

    server_catalog = {
        "id": server_id,
        "lastUpdatedAt": _dt.datetime.now(_dt.UTC).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "name": {"en": name_en, "zh": name_zh},
        "metadata": checkout_catalogs[0]["metadata"] if checkout_catalogs else {},
        "checkouts": [
            {"id": cc["id"], "createdAt": cc["createdAt"], "metadata": cc["metadata"]}
            for cc in checkout_catalogs
        ],
    }

    try:
        mgr = _get_session(session_id)
        mgr.add_resources(
            server_catalogs=[server_catalog],
            checkout_catalogs=checkout_catalogs,
        )
    except SessionManagerCommittedError as exc:
        raise click.ClickException("Session is already committed.") from exc
    except SessionManagerInvalidError as exc:
        raise click.ClickException("No active session.") from exc

    click.echo(
        styled(
            [Style.BRIGHT, Fore.GREEN],
            f"Resources added: server={server_id}, checkouts={len(checkout_catalogs)}",
        )
    )


@prepare.command("diff")
@click.option(
    "--session-id",
    default=None,
    help="Use a specific committed session instead of the active one.",
)
@click.option(
    "--generation",
    "generation_id",
    default=None,
    help="Diff against a specific remote generation instead of the activated one.",
)
def schema_diff(session_id: str | None, generation_id: str | None):
    """Compare the session's staged generation against remote state."""
    from data.lib.remote.diff import diff_generations
    from data.lib.remote.diff import read_generation_from_remote
    from data.lib.remote.diff import read_generation_from_staged

    data.lib.config.DeveloperConfiguration.ensure_loaded()
    remote_cfg = data.lib.config.DEV_CONFIGURATION.remote

    try:
        mgr = _get_session(session_id)
    except SessionManagerInvalidError as exc:
        raise click.ClickException("No active session.") from exc

    todo = mgr._load_todo()
    gen_id = todo.generation or "unknown"
    channel = mgr.channel or remote_cfg.channel.value

    pending = read_generation_from_staged(mgr.staged_dir, gen_id)

    try:
        baseline = read_generation_from_remote(mgr.remote_state_dir, channel, generation_id)
    except FileNotFoundError as exc:
        raise click.ClickException(str(exc)) from exc
    except ValueError as exc:
        raise click.ClickException(
            f"{exc}\n"
            "  Hint: The remote server has no published content.\n"
            "  Run './x remote prepare publish' to publish, or\n"
            "  specify a generation ID with '--generation <id>'."
        ) from exc

    diff = diff_generations(pending, baseline)

    pending_id_short = pending.gen_id[:16] if len(pending.gen_id) > 16 else pending.gen_id
    baseline_id_short = baseline.gen_id[:16] if len(baseline.gen_id) > 16 else baseline.gen_id
    click.echo(
        f"\nGeneration diff: {styled([Style.BRIGHT, Fore.CYAN], gen_id)} ({pending_id_short}..., pending)"
    )
    click.echo(
        f"              vs {styled([Style.BRIGHT, Fore.CYAN], baseline.gen_id)} ({baseline_id_short}..., baseline)\n"
    )

    if diff.servers:
        click.echo(styled([Style.BOLD], "  Servers:"))
        for sd in diff.servers:
            marker = {"added": "+", "removed": "-", "unchanged": "=", "changed": "~"}[sd.status]
            color = {
                "added": Fore.GREEN,
                "removed": Fore.RED,
                "unchanged": Fore.RESET,
                "changed": Fore.YELLOW,
            }[sd.status]
            click.echo(f"    {styled([Style.BRIGHT, color], marker)} {sd.server_id}")
            if sd.checkout_changes:
                click.echo("      Checkouts:")
                for cid in sd.checkout_changes.added:
                    ck = pending.checkouts.get(cid, {})
                    fc = ck.get("fileCount", "?")
                    ts = ck.get("totalSize", 0)
                    size_str = f"{ts / 1_000_000:.1f} MB" if ts else "?"
                    label = f"        {styled([Style.BRIGHT, Fore.GREEN], '+')} {cid}"
                    click.echo(f"{label} ({fc} files, {size_str})")
                for cid in sd.checkout_changes.removed:
                    ck = baseline.checkouts.get(cid, {})
                    fc = ck.get("fileCount", "?")
                    ts = ck.get("totalSize", 0)
                    size_str = f"{ts / 1_000_000:.1f} MB" if ts else "?"
                    line = f"        {styled([Style.BRIGHT, Fore.RED], '-')} {cid}"
                    click.echo(f"{line} ({fc} files, {size_str}) [removed]")
                for cid in sd.checkout_changes.unchanged:
                    click.echo(f"        {styled([Style.BRIGHT, Fore.RESET], '=')} {cid}")

    if diff.releases.added or diff.releases.removed or diff.releases.changed:
        click.echo("\n  Releases:")
        for rid in diff.releases.added:
            rel = pending.releases.get(rid, {})
            version = rel.get("version", rid)
            apk_hash = rel.get("apk_hash", "?")
            click.echo(
                f"    {styled([Style.BRIGHT, Fore.GREEN], '+')} {version}  (apk: {apk_hash})"
            )
        for rid in diff.releases.removed:
            rel = baseline.releases.get(rid, {})
            version = rel.get("version", rid)
            click.echo(f"    {styled([Style.BRIGHT, Fore.RED], '-')} {version}")

    if diff.announcements.added or diff.announcements.removed or diff.announcements.changed:
        click.echo("\n  Announcements:")
        for aid in diff.announcements.added:
            click.echo(f"    {styled([Style.BRIGHT, Fore.GREEN], '+')} {aid}")
        for aid in diff.announcements.removed:
            click.echo(f"    {styled([Style.BRIGHT, Fore.RED], '-')} {aid}")
        for aid in diff.announcements.changed:
            click.echo(
                f"    {styled([Style.BRIGHT, Fore.YELLOW], '~')} {aid}      content hash changed"
            )

    server_counts = {"added": 0, "removed": 0, "changed": 0, "unchanged": 0}
    for sd in diff.servers:
        server_counts[sd.status] += 1

    ck_added = sum(len(sd.checkout_changes.added) for sd in diff.servers if sd.checkout_changes)
    ck_removed = sum(len(sd.checkout_changes.removed) for sd in diff.servers if sd.checkout_changes)

    click.echo("\n  Summary:")
    if server_counts["added"]:
        click.echo(f"    {server_counts['added']} server(s) added")
    if server_counts["changed"]:
        click.echo(f"    {server_counts['changed']} server(s) changed")
    if server_counts["removed"]:
        click.echo(f"    {server_counts['removed']} server(s) removed")
    if ck_added:
        click.echo(f"    {ck_added} checkout(s) added")
    if ck_removed:
        click.echo(f"    {ck_removed} checkout(s) removed")
    if len(diff.releases.added):
        click.echo(f"    {len(diff.releases.added)} release(s) added")
    if len(diff.releases.removed):
        click.echo(f"    {len(diff.releases.removed)} release(s) removed")
    if len(diff.announcements.added):
        click.echo(f"    {len(diff.announcements.added)} announcement(s) added")
    if len(diff.announcements.changed):
        click.echo(f"    {len(diff.announcements.changed)} announcement(s) changed")


@prepare.command("verify")
@click.option(
    "--session-id",
    default=None,
    help="Which session to verify (uses active session if omitted).",
)
@click.option(
    "--schema-root",
    type=click.Path(path_type=Path),
    default=None,
    help="Unified schema root directory (default from dev config).",
)
@click.option(
    "--verbose",
    is_flag=True,
    default=False,
    help="Show per-file results (default: summary only).",
)
def schema_verify(
    session_id: str | None,
    schema_root: Path | None,
    verbose: bool,
):
    """Verify checkout assets in the session's staged area (local only)."""
    import json as _json

    from data.lib.workspace.generate.schema import verify_checkout_assets

    data.lib.config.DeveloperConfiguration.ensure_loaded()
    if schema_root is None:
        schema_root = data.lib.config.DEV_CONFIGURATION.paths.schema_dir

    try:
        mgr = _get_session(session_id)
    except SessionManagerInvalidError as exc:
        raise click.ClickException("No active session.") from exc

    gen_id = mgr._load_todo().generation
    ck_dir = mgr.staged_dir / "manifest" / ".generations" / gen_id / "resources" / "checkouts"
    if not ck_dir.exists():
        raise click.ClickException(
            f"No checkout catalogs found in session staged area for generation {gen_id}."
        )

    catalogs_to_verify: list[dict] = []
    for ck_file in sorted(ck_dir.glob("*.json")):
        with ck_file.open("r", encoding="utf-8") as f:
            catalogs_to_verify.append(_json.load(f))

    total_ok = 0
    total_fail = 0
    total_missing = 0

    for catalog in catalogs_to_verify:
        catalog_id = catalog.get("id", "unknown")
        if verbose:
            click.echo(f"\nVerifying checkout: {catalog_id}")

        results = verify_checkout_assets(catalog, schema_root)
        for r in results:
            if verbose:
                status_color = {
                    "OK": Fore.GREEN,
                    "FAIL": Fore.RED,
                    "MISSING": Fore.YELLOW,
                }[r.status]
                size_str = f" ({r.size:,} bytes)" if r.size is not None else ""
                label = f"  {r.path} "
                dots = "." * max(1, 70 - len(label) - len(str(r.status)) - len(size_str))
                line = f"{label}{dots} {styled([Style.BRIGHT, status_color], r.status)}{size_str}"
                click.echo(line)
                if r.details:
                    click.echo(f"    {r.details}")

            if r.status == "OK":
                total_ok += 1
            elif r.status == "FAIL":
                total_fail += 1
            else:
                total_missing += 1

    click.echo(
        f"\n  Summary: "
        f"{styled([Style.BRIGHT, Fore.GREEN], str(total_ok))} OK, "
        f"{styled([Style.BRIGHT, Fore.RED], str(total_fail))} FAIL, "
        f"{styled([Style.BRIGHT, Fore.YELLOW], str(total_missing))} MISSING"
    )


@prepare.command("add-release")
@click.option("--version", required=True, help="Semantic version (e.g., 0.2.0).")
@click.option(
    "--apk",
    "apk_path",
    type=click.Path(path_type=Path, exists=True),
    required=True,
    help="Path to the APK file.",
)
@click.option(
    "--announcement",
    "announcement_id",
    default=None,
    help="Announcement ID link.",
)
@click.option("--session-id", default=None, help="Override active session.")
def schema_add_release(
    version: str,
    apk_path: Path,
    announcement_id: str | None,
    session_id: str | None,
):
    """Register an APK release artifact."""
    try:
        mgr = _get_session(session_id)
        mgr.add_release(
            version=version,
            apk_path=apk_path,
            announcement_id=announcement_id,
        )
    except SessionManagerCommittedError as exc:
        raise click.ClickException("Session is already committed.") from exc
    except SessionManagerInvalidError as exc:
        raise click.ClickException("No active session.") from exc

    click.echo(styled([Style.BRIGHT, Fore.GREEN], f"Release added: version={version}"))


@prepare.command("commit")
@click.option("--session-id", default=None, help="Override active session.")
def schema_commit(session_id: str | None):
    """Regenerate merged tree and freeze the session locally.

    After commit the session is immutable and can be published.
    Commit does not upload to S3/R2 — use `publish` for that.
    """
    data.lib.config.DeveloperConfiguration.ensure_loaded()
    data.lib.config.ProjectConfiguration.ensure_loaded()

    try:
        mgr = _get_session(session_id)
    except SessionManagerInvalidError as exc:
        raise click.ClickException("No active session.") from exc

    try:
        merged_root = mgr.commit(channel=Channel(mgr.channel))
    except SessionManagerCommittedError as exc:
        raise click.ClickException(
            "Session is already committed.  Start a new session with `prepare init`."
        ) from exc

    click.echo(styled([Style.BRIGHT, Fore.GREEN], f"Committed: {mgr.session_id}"))
    click.echo(styled(Style.DIM, f"  Merged tree: {merged_root}"))


@prepare.command("publish")
@click.option("--session-id", default=None, help="Publish a specific committed session.")
@click.option(
    "--all-generations",
    is_flag=True,
    default=False,
    help="Publish each committed generation separately instead of squashing.",
)
def schema_publish(session_id: str | None, all_generations: bool):
    """Upload committed generations to S3/R2.

    By default squashes all committed generations into one.  Use
    --all-generations to publish each generation separately.  After a
    successful publish all committed session directories are cleaned up.
    """
    data.lib.config.DeveloperConfiguration.ensure_loaded()
    remote_cfg = data.lib.config.DEV_CONFIGURATION.remote
    s3_cfg = remote_cfg.require_s3()
    sessions_root = __get_session_root()

    mc_bin = get_command("mc")
    endpoint = s3_cfg.endpoint
    bucket = s3_cfg.bucket
    access_key = s3_cfg.access_key
    secret_key = s3_cfg.secret_key
    alias_name = s3_cfg.alias

    if session_id:
        mgr = SessionManager.from_session_id(sessions_root, session_id)
        channel = Channel(mgr.channel)
        mgr.publish(
            channel=channel,
            mc_bin=mc_bin,
            endpoint=endpoint,
            bucket=bucket,
            access_key=access_key,
            secret_key=secret_key,
            alias_name=alias_name,
            squash=not all_generations,
        )
        mgr.abort()
        click.echo(styled([Style.BRIGHT, Fore.GREEN], f"Published: {mgr.session_id}"))
        return

    if all_generations:
        chain = SessionManager.find_committed_chain(sessions_root)
        if not chain:
            raise click.ClickException("No committed sessions found.  Run `prepare commit` first.")
        channel = Channel(chain[0].channel)
        click.echo(
            styled(
                Style.DIM,
                f"Publishing {len(chain)} generation(s) separately (--all-generations)...",
            )
        )
        for mgr in chain:
            mgr.publish(
                channel=channel,
                mc_bin=mc_bin,
                endpoint=endpoint,
                bucket=bucket,
                access_key=access_key,
                secret_key=secret_key,
                alias_name=alias_name,
                squash=False,
            )
            click.echo(styled(Style.DIM, f"  Published generation: {mgr.session_id}"))
    else:
        try:
            tip = SessionManager.find_latest_committed(sessions_root)
        except FileNotFoundError:
            raise click.ClickException(
                "No committed sessions found.  Run `prepare commit` first."
            ) from None
        channel = Channel(tip.channel)
        click.echo(styled(Style.DIM, "Publishing squashed generation..."))
        tip.publish(
            channel=channel,
            mc_bin=mc_bin,
            endpoint=endpoint,
            bucket=bucket,
            access_key=access_key,
            secret_key=secret_key,
            alias_name=alias_name,
            squash=True,
        )

    removed = SessionManager.cleanup_committed_sessions(sessions_root)
    click.echo(
        styled([Style.BRIGHT, Fore.GREEN], f"Published. Cleaned up {removed} committed session(s).")
    )


@prepare.command("abort")
@click.option("--session-id", default=None, help="Override active session.")
@click.option("--force", is_flag=True, default=False, help="Skip confirmation prompt.")
def schema_abort(session_id: str | None, force: bool):
    """Discard a session and its directory."""
    try:
        mgr = _get_session(session_id)
    except (SessionManagerInvalidError, FileNotFoundError) as exc:
        raise click.ClickException(str(exc)) from exc

    if not force:
        click.confirm(
            f"Discard session {mgr.session_id} and all staged content?",
            abort=True,
        )

    session_dir = mgr.session_dir
    mgr.abort()
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Session aborted: ") + str(session_dir))


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


@release_changelog.command("stage")
def release_changelog_stage():
    """Stage version release notes in a remote prepare session.

    Reads the generated version documents from assets/content/documents/,
    creates a remote prepare session, and stages the version entry as an
    announcement.  Use ``./x remote prepare publish --session-id <id>``
    afterwards to publish to the remote server.
    """

    from data.lib.constant import PROJECT_ROOT
    from data.lib.release.changelog_gen import _version_to_doc_id
    from data.lib.release.version import load_version
    from data.lib.remote.channel import Channel
    from data.lib.remote.session import SessionManager

    v = load_version()
    doc_id = _version_to_doc_id(v)
    semver = v.render_semver()

    zh_path = PROJECT_ROOT / "assets" / "content" / "documents" / "zh" / f"{doc_id}.md"
    en_path = PROJECT_ROOT / "assets" / "content" / "documents" / "en" / f"{doc_id}.md"

    if not zh_path.is_file():
        raise click.ClickException(
            f"Chinese version document not found: {zh_path}\n"
            f"  Run './x release changelog detail' first."
        )
    if not en_path.is_file():
        raise click.ClickException(
            f"English version document not found: {en_path}\n"
            f"  Run './x release changelog detail' first."
        )

    zh_meta, zh_title, _zh_summary = _parse_version_document(zh_path)
    _en_meta, _en_title, _en_summary = _parse_version_document(en_path)
    app_ver = zh_meta.get("appVer", semver)
    published_at = zh_meta.get("publishedAt", None)
    if published_at is None:
        published_at = __utc_timestamp()

    click.echo(
        styled([Style.BRIGHT, Fore.GREEN], "Staging version document: ")
        + styled([Style.BRIGHT], doc_id)
    )
    click.echo(styled(Style.DIM, f"  zh: {zh_path}"))
    click.echo(styled(Style.DIM, f"  en: {en_path}"))
    click.echo(styled(Style.DIM, f"  appVer: {app_ver}"))
    click.echo("")

    # Build temporary announcement directory ----------------------------------
    import tempfile

    tmp_dir = Path(tempfile.mkdtemp(prefix="efa-stage-"))
    ann_dir = tmp_dir / "announcements"
    files_dir = ann_dir / "files"
    registry_dir = ann_dir / "registry"

    for locale, path in (("en", en_path), ("zh", zh_path)):
        locale_dir = files_dir / locale
        locale_dir.mkdir(parents=True)
        shutil.copy2(str(path), str(locale_dir / doc_id))

    registry_dir.mkdir(parents=True)
    registry: dict[str, object] = {
        "id": doc_id,
        "firstPublishedAt": published_at,
        "updatedAt": published_at,
        "isVersionUpdate": True,
    }
    (registry_dir / f"{doc_id}.json").write_text(
        json.dumps(registry, indent=4, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    # Start session ------------------------------------------------------------
    data.lib.config.DeveloperConfiguration.ensure_loaded()
    data.lib.config.ProjectConfiguration.ensure_loaded()
    remote_cfg = data.lib.config.DEV_CONFIGURATION.remote
    resolved_resource_root = __validate_remote_resource_root(
        data.lib.config.CONFIGURATION.data_schema.resource_root
    )
    resolved_channel = Channel(remote_cfg.channel.value)
    description = f"Version {semver}: {zh_title}" if zh_title else f"Version {semver}"

    resolved_backend, origin_dir, start_kwargs = _resolve_stage_backend(
        remote_cfg=remote_cfg,
        resource_root=resolved_resource_root,
        channel=resolved_channel,
    )

    sessions_root = __get_session_root()
    try:
        mgr = SessionManager.prepare(
            sessions_root=sessions_root,
            backend=resolved_backend,
            description=description,
            resource_root=resolved_resource_root,
            channel=resolved_channel,
            origin_dir=origin_dir,
            **start_kwargs,
        )
    except (OSError, FileNotFoundError) as exc:
        click.echo(styled([Style.BRIGHT, Fore.YELLOW], f"Remote state unavailable: {exc}"))
        click.echo(styled(Style.DIM, "Falling back to local-only session."))
        mgr = SessionManager.prepare(
            sessions_root=sessions_root,
            backend="local",
            description=description,
            channel=resolved_channel,
        )
        resolved_backend = "local"
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Session started: ") + mgr.session_id)
    click.echo(styled(Style.DIM, f"  backend: {resolved_backend}"))
    click.echo(styled(Style.DIM, f"  channel: {resolved_channel}"))

    # Stage announcement -------------------------------------------------------
    try:
        mgr.add_announcements(source_dir=tmp_dir)
    except Exception as exc:
        mgr.abort()
        shutil.rmtree(tmp_dir, ignore_errors=True)
        raise click.ClickException(str(exc)) from exc
    finally:
        shutil.rmtree(tmp_dir, ignore_errors=True)

    click.echo("")
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Staged version announcement:"))
    click.echo(styled(Style.DIM, f"  id:      {doc_id}"))
    click.echo(styled(Style.DIM, f"  title:   {zh_title}"))
    click.echo(styled(Style.DIM, f"  version: {semver}"))
    click.echo(styled(Style.DIM, "  locales: en, zh"))
    click.echo("")
    click.echo(styled([Style.BRIGHT, Fore.YELLOW], "Session staged but not published."))
    click.echo(f"  Publish:  ./x remote prepare publish --session-id {mgr.session_id}")
    click.echo(f"  Upload:   ./x remote publish upload --target s3 --session {mgr.session_id}")


def _parse_version_document(path: Path) -> tuple[dict[str, object], str, str]:
    """Parse a version markdown document into (metadata, title, summary).

    Returns metadata from YAML front matter (may be empty for en files),
    the h1 heading text as title, and the first non-heading paragraph as summary.
    """
    import re as _re

    import yaml as _yaml

    content = path.read_text(encoding="utf-8")
    metadata: dict[str, object] = {}
    body = content

    if content.startswith("---\n"):
        parts = content.split("\n---\n", 1)
        if len(parts) == 2:
            raw_front_matter = parts[0][len("---\n") :]
            body = parts[1]
            data = _yaml.safe_load(raw_front_matter)
            if isinstance(data, dict):
                metadata = data

    body = body.lstrip()
    lines = body.splitlines()

    title = ""
    summary = ""
    title_found = False

    for line in lines:
        stripped = line.strip()
        if not stripped:
            continue
        if stripped.startswith("# "):
            if not title_found:
                title = stripped[2:].strip()
                title_found = True
            continue
        if (
            title_found
            and not summary
            and not stripped.startswith(("#", "```", "- ", "* ", "+ "))
            and not _re.match(r"\d+\.\s", stripped)
        ):
            summary = stripped
            break

    if not title:
        title = path.stem
    if not summary:
        summary = title

    return metadata, title, summary


def _resolve_stage_backend(
    *,
    remote_cfg,
    resource_root: str,
    channel,
) -> tuple[str, Path | None, dict[str, object]]:
    if remote_cfg.s3 is not None:
        sub = remote_cfg.require_s3()
        return (
            "s3",
            None,
            {
                "mc_bin": get_command("mc"),
                "endpoint": sub.endpoint,
                "bucket": sub.bucket,
                "access_key": sub.access_key,
                "secret_key": sub.secret_key,
                "alias_name": sub.alias,
            },
        )
    if remote_cfg.minio is not None:
        sub = remote_cfg.require_minio()
        return (
            "minio",
            None,
            {
                "mc_bin": get_command("mc"),
                "endpoint": f"http://{remote_cfg.host}:{sub.port}",
                "bucket": sub.bucket,
                "access_key": sub.access_key,
                "secret_key": sub.secret_key,
                "alias_name": sub.alias,
            },
        )
    return "local", None, {}


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
