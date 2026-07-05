from __future__ import annotations

import shutil
import time

from typing import TYPE_CHECKING
from urllib.request import urlopen

import click

from colorama import Fore
from colorama import Style

import bootstrap.config

from bootstrap.cli import runtime
from bootstrap.color import styled
from bootstrap.log import warning
from bootstrap.remote.channel import Channel
from bootstrap.utils import get_command


if TYPE_CHECKING:
    from pathlib import Path


def wait_for_http(url: str, timeout_seconds: float = 20.0) -> None:
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


def run_foreground(process, interrupted_message: str) -> None:
    import subprocess

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


def validate_remote_resource_root(resource_root: str) -> str:
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


def validate_remote_channel(channel: str) -> Channel:
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


def validate_mc_target_segment(value: str, label: str) -> str:
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


def redact_remote_config(config: dict[str, object]) -> dict[str, object]:
    redacted = dict(config)
    for sub in ("minio", "s3"):
        if sub in redacted and isinstance(redacted[sub], dict):
            sub_dict = dict(redacted[sub])  # type: ignore[arg-type]
            for key in ("access_key", "secret_key"):
                if key in sub_dict:
                    sub_dict[key] = "<redacted>"
            redacted[sub] = sub_dict
    return redacted


def publish_optional_tree(
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
        publish_optional_file(mc, f, remote, attrs=attrs)


def publish_optional_file(
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
    runtime.execute(cmd, "REMOTE PUBLISH")


def publish_remote_origin_to_s3(
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

    resolved_bucket = validate_mc_target_segment(bucket, "bucket")
    resolved_alias = validate_mc_target_segment(alias_name, "alias")
    resolved_resource_root = validate_remote_resource_root(resource_root)
    root_dir = source_dir / resolved_resource_root
    channel_dir = root_dir / "channels" / channel.value
    gen_dir = channel_dir / ".generations" / generation
    index_path = gen_dir / "index.json"

    if not index_path.exists() or not index_path.is_file():
        if not channel_dir.is_dir():
            raise click.ClickException(
                f"Remote publish channel directory does not exist: {channel_dir}"
            )
        gen_dir.mkdir(parents=True, exist_ok=True)
        for item in channel_dir.iterdir():
            if item.name == ".generations":
                continue
            dst = gen_dir / item.name
            if item.is_dir():
                if not dst.exists():
                    shutil.copytree(item, dst)
            elif not dst.exists():
                shutil.copy2(item, dst)

    mc = get_command("mc")
    bucket_target = f"{resolved_alias}/{resolved_bucket}"
    redacted = "<redacted>"
    runtime.execute_redacted(
        [mc, "alias", "set", resolved_alias, endpoint, access_key, secret_key, "--api", "s3v4"],
        [mc, "alias", "set", resolved_alias, endpoint, redacted, redacted, "--api", "s3v4"],
        "REMOTE PUBLISH ALIAS",
    )
    if target == "minio":
        runtime.execute([mc, "mb", "--ignore-existing", bucket_target], "REMOTE PUBLISH")
    if target == "minio":
        if public_download:
            runtime.execute([mc, "anonymous", "set", "download", bucket_target], "REMOTE PUBLISH")
        else:
            runtime.execute([mc, "anonymous", "set", "none", bucket_target], "REMOTE PUBLISH")

    target_root = f"{bucket_target}/{resolved_resource_root}"
    # Step 1: mirror shared content (idempotent, safe to interrupt)
    publish_optional_tree(
        mc,
        root_dir / "documents" / "body",
        f"{target_root}/documents/body",
        attrs={
            "Cache-Control": "immutable, max-age=31536000",
            "Content-Type": "text/markdown; charset=utf-8",
        },
    )
    publish_optional_tree(
        mc,
        root_dir / "bundles",
        f"{target_root}/bundles",
        attrs={"Cache-Control": "immutable, max-age=31536000"},
    )

    # Step 2: mirror generation catalog tree (tiny JSONs, NEW paths)
    channel_attrs = {"Cache-Control": "max-age=300", "Content-Type": "application/json"}
    publish_optional_tree(
        mc,
        gen_dir / "documents",
        f"{target_root}/channels/{channel}/.generations/{generation}/documents",
        attrs=channel_attrs,
    )
    publish_optional_tree(
        mc,
        gen_dir / "bundles",
        f"{target_root}/channels/{channel}/.generations/{generation}/bundles",
        attrs=channel_attrs,
    )
    publish_optional_file(
        mc,
        gen_dir / "app" / "releases.json",
        f"{target_root}/channels/{channel}/.generations/{generation}/app/releases.json",
        attrs=channel_attrs,
    )

    # Step 3: atomic commit — copy generation's index.json to live path
    publish_optional_file(
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


def get_announce_workspace() -> Path:
    """Get the announcement workspace root path."""
    bootstrap.config.DeveloperConfiguration.ensure_loaded()
    root = bootstrap.config.DEV_CONFIGURATION.paths.root / "announce"
    return runtime.resolve_dev_path(root)


def resolve_announce_remote_target(
    target: str | None,
    endpoint: str | None,
    bucket: str | None,
    access_key: str | None,
    secret_key: str | None,
    alias: str | None,
) -> tuple[str, str, str, str, str]:
    """Resolve remote target credentials from CLI args or config."""
    bootstrap.config.DeveloperConfiguration.ensure_loaded()
    remote_cfg = bootstrap.config.DEV_CONFIGURATION.remote

    if target is None:
        target = "minio"

    if target == "minio":
        minio_cfg = remote_cfg.minio
        if minio_cfg is None:
            raise click.ClickException(
                "[remote.minio] is not configured in efa.dev.toml. "
                "See efa.dev.example.toml for the expected format."
            )
        return (
            endpoint or f"http://{remote_cfg.host}:{minio_cfg.port}",
            bucket or minio_cfg.bucket,
            (access_key or minio_cfg.access_key).get_secret_value()
            if access_key or minio_cfg.access_key
            else "",
            (secret_key or minio_cfg.secret_key).get_secret_value()
            if secret_key or minio_cfg.secret_key
            else "",
            alias or minio_cfg.alias,
        )
    elif target == "s3":
        s3_cfg = remote_cfg.s3
        if s3_cfg is None:
            raise click.ClickException(
                "[remote.s3] is not configured in efa.dev.toml. "
                "See efa.dev.example.toml for the expected format."
            )
        return (
            endpoint or s3_cfg.endpoint,
            bucket or s3_cfg.bucket,
            (access_key or s3_cfg.access_key).get_secret_value()
            if access_key or s3_cfg.access_key
            else "",
            (secret_key or s3_cfg.secret_key).get_secret_value()
            if secret_key or s3_cfg.secret_key
            else "",
            alias or s3_cfg.alias,
        )
    else:
        raise click.ClickException(f"Invalid target: {target!r} (expected minio or s3)")
