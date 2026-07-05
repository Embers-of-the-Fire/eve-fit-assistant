from __future__ import annotations

import os
import subprocess

from pathlib import Path

import click

from colorama import Fore
from colorama import Style

import bootstrap.config

from bootstrap.cli import runtime
from bootstrap.cli.remote.helpers import run_foreground
from bootstrap.cli.remote.helpers import wait_for_http
from bootstrap.color import styled
from bootstrap.utils import get_command


_PROTECTED_PATHS: tuple[Path, ...] | None = None


def _get_protected_paths() -> tuple[Path, ...]:
    global _PROTECTED_PATHS
    if _PROTECTED_PATHS is None:
        cfg = bootstrap.config.DEV_CONFIGURATION
        dev_root = cfg.paths.root.resolve()
        _PROTECTED_PATHS = (
            Path("/"),
            Path.home(),
            dev_root,
        )
    return _PROTECTED_PATHS


def _is_safe_rmtree_target(path: Path) -> bool:
    resolved = path.resolve()
    if not resolved.is_dir():
        raise click.ClickException(f"Refusing to remove non-directory path: {resolved}")
    protected = _get_protected_paths()
    for p in protected:
        if resolved == p or p in resolved.parents:
            raise click.ClickException(
                f"Refusing to remove protected path: {resolved} (conflicts with {p})"
            )
    return True


def _start_minio_remote_mock(
    *,
    host: str,
    port: int,
    console_port: int,
    data_dir: Path,
    bucket: str,
    access_key: str,
    secret_key: str,
    alias_name: str,
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
    if runtime.is_dry_run():
        return

    minio = get_command("minio")
    command[0] = minio
    env = os.environ.copy()
    env["MINIO_ROOT_USER"] = access_key
    env["MINIO_ROOT_PASSWORD"] = secret_key
    process = subprocess.Popen(command, env=env, text=True)
    try:
        wait_for_http(f"{endpoint}/minio/health/ready")

        mc = get_command("mc")
        bucket_target = f"{alias_name}/{bucket}"
        redacted = "<redacted>"
        runtime.execute_redacted(
            [mc, "alias", "set", alias_name, endpoint, access_key, secret_key, "--api", "s3v4"],
            [mc, "alias", "set", alias_name, endpoint, redacted, redacted, "--api", "s3v4"],
            "REMOTE MOCK ALIAS",
        )
        runtime.execute(
            [mc, "mb", "--ignore-existing", bucket_target],
            "REMOTE MOCK BUCKET",
        )
        if public_download:
            runtime.execute(
                [mc, "anonymous", "set", "download", bucket_target],
                "REMOTE MOCK ANONYMOUS",
            )
        else:
            runtime.execute(
                [mc, "anonymous", "set", "none", bucket_target],
                "REMOTE MOCK ANONYMOUS",
            )

        click.echo(
            styled(
                Style.DIM,
                "  No pre-existing data published. Use `./x remote session` to build from scratch.",
            )
        )
        click.echo(styled([Style.BRIGHT, Fore.GREEN], "MinIO console: ") + console_endpoint)
        run_foreground(process, "\nMinIO remote mock interrupted by user.")
    except Exception:
        process.terminate()
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
        raise


def _remove_mock_path(path: Path, label: str) -> bool:
    if not path.exists():
        return False
    _is_safe_rmtree_target(path)
    click.echo(styled(Style.DIM, f"  Removing {label}: {path}"))
    import shutil

    shutil.rmtree(path)
    return True


def register_remote_mock(remote: click.Group) -> None:
    @remote.group()
    def mock():
        """Remote mock origin commands."""

    @mock.command("clean")
    @click.option("--origin-dir", type=click.Path(path_type=Path), default=None)
    @click.option("--data-dir", type=click.Path(path_type=Path), default=None)
    def remote_mock_clean(origin_dir: Path | None, data_dir: Path | None):
        """Remove all persisted remote mock data (MinIO storage + origin directory)."""
        bootstrap.config.DeveloperConfiguration.ensure_loaded()
        remote_cfg = bootstrap.config.DEV_CONFIGURATION.remote
        minio = remote_cfg.require_minio("clean")

        resolved_data_dir = runtime.resolve_dev_path(data_dir or minio.data_dir)
        resolved_origin_dir = runtime.resolve_dev_path(origin_dir or remote_cfg.mock_origin_dir)

        any_removed = False
        if _remove_mock_path(resolved_data_dir, "MinIO data directory"):
            any_removed = True
        if _remove_mock_path(resolved_origin_dir, "mock origin directory"):
            any_removed = True

        if any_removed:
            click.echo(styled([Style.BRIGHT, Fore.GREEN], "Remote mock cleaned."))
        else:
            click.echo(styled(Style.DIM, "Nothing to clean."))

    @mock.command("launch")
    @click.option("--host", default=None, help="Override remote mock host.")
    @click.option("--port", type=int, default=None, help="Override MinIO API port.")
    @click.option("--console-port", type=int, default=None, help="Override MinIO console port.")
    @click.option("--bucket", default=None, help="Override MinIO bucket name.")
    @click.option("--access-key", default=None, help="Override MinIO access key.")
    @click.option("--secret-key", default=None, help="Override MinIO secret key.")
    @click.option("--alias", "alias_name", default=None, help="Override mc alias name.")
    @click.option("--data-dir", type=click.Path(path_type=Path), default=None)
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
        data_dir: Path | None,
        public_download: bool | None,
    ):
        """Launch a local MinIO remote mock against persisted storage.

        No pre-existing data is published - use `./x remote session` commands
        to build data from scratch. Run `./x remote mock clean` first to
        start with a completely empty store.
        """
        bootstrap.config.DeveloperConfiguration.ensure_loaded()
        bootstrap.config.ProjectConfiguration.ensure_loaded()
        remote_cfg = bootstrap.config.DEV_CONFIGURATION.remote
        minio = remote_cfg.require_minio("mock")

        resolved_host = host or remote_cfg.host
        resolved_data_dir = runtime.resolve_dev_path(data_dir or minio.data_dir)
        resolved_port = port or minio.port
        resolved_console_port = console_port or minio.console_port
        resolved_bucket = bucket or minio.bucket
        resolved_access_key = (access_key or minio.access_key).get_secret_value()
        resolved_secret_key = (secret_key or minio.secret_key).get_secret_value()
        resolved_alias = alias_name or minio.alias
        resolved_public_download = (
            public_download if public_download is not None else minio.public_download
        )

        click.echo(styled([Style.BRIGHT, Fore.GREEN], "MinIO data path: ") + str(resolved_data_dir))
        click.echo(
            styled(
                Style.DIM,
                "  Using persisted storage. Run `./x remote mock clean` for a fresh start.",
            )
        )
        _start_minio_remote_mock(
            host=resolved_host,
            port=resolved_port,
            console_port=resolved_console_port,
            data_dir=resolved_data_dir,
            bucket=resolved_bucket,
            access_key=resolved_access_key,
            secret_key=resolved_secret_key,
            alias_name=resolved_alias,
            public_download=resolved_public_download,
        )
