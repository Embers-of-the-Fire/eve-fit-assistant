from __future__ import annotations

import time

from typing import TYPE_CHECKING
from urllib.request import urlopen

import click

from colorama import Fore
from colorama import Style

import bootstrap.config

from bootstrap.cli import runtime
from bootstrap.color import styled
from bootstrap.remote.channel import Channel


if TYPE_CHECKING:
    from pathlib import Path


def wait_for_http(url: str, timeout_seconds: float = 20.0) -> None:
    deadline = time.monotonic() + timeout_seconds
    last_error: Exception | None = None
    while time.monotonic() < deadline:
        try:
            with urlopen(url, timeout=1.0):
                return
        except Exception as exception:  # noqa: BLE001
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


def redact_remote_config(config: dict[str, object]) -> dict[str, object]:
    redacted = dict(config)
    for sub in ("mock", "s3"):
        if sub in redacted and isinstance(redacted[sub], dict):
            sub_dict = dict(redacted[sub])  # type: ignore[arg-type]
            for key in ("access_key", "secret_key"):
                if key in sub_dict:
                    sub_dict[key] = "<redacted>"
            redacted[sub] = sub_dict
    return redacted


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
) -> tuple[str, str, str, str]:
    """Resolve remote target credentials from CLI args or config."""
    bootstrap.config.DeveloperConfiguration.ensure_loaded()
    remote_cfg = bootstrap.config.DEV_CONFIGURATION.remote

    if target is None:
        target = "mock"

    if target == "mock":
        mock_cfg = remote_cfg.mock
        if mock_cfg is None:
            raise click.ClickException(
                "[remote.mock] is not configured in efa.dev.toml. "
                "See efa.dev.example.toml for the expected format."
            )
        if access_key:
            resolved_access_key = access_key
        elif mock_cfg.access_key:
            resolved_access_key = mock_cfg.access_key.get_secret_value()
        else:
            resolved_access_key = ""

        if secret_key:
            resolved_secret_key = secret_key
        elif mock_cfg.secret_key:
            resolved_secret_key = mock_cfg.secret_key.get_secret_value()
        else:
            resolved_secret_key = ""

        return (
            endpoint or f"http://{remote_cfg.host}:{mock_cfg.port}",
            bucket or mock_cfg.bucket,
            resolved_access_key,
            resolved_secret_key,
        )
    elif target == "s3":
        s3_cfg = remote_cfg.s3
        if s3_cfg is None:
            raise click.ClickException(
                "[remote.s3] is not configured in efa.dev.toml. "
                "See efa.dev.example.toml for the expected format."
            )
        if access_key:
            resolved_access_key = access_key
        elif s3_cfg.access_key:
            resolved_access_key = s3_cfg.access_key.get_secret_value()
        else:
            resolved_access_key = ""

        if secret_key:
            resolved_secret_key = secret_key
        elif s3_cfg.secret_key:
            resolved_secret_key = s3_cfg.secret_key.get_secret_value()
        else:
            resolved_secret_key = ""

        return (
            endpoint or s3_cfg.endpoint,
            bucket or s3_cfg.bucket,
            resolved_access_key,
            resolved_secret_key,
        )
    else:
        raise click.ClickException(f"Invalid target: {target!r} (expected mock or s3)")
