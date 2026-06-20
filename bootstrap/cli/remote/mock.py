from __future__ import annotations

import os
import subprocess

from pathlib import Path
from typing import TYPE_CHECKING

import click

from click_aliases import ClickAliasedGroup
from colorama import Fore
from colorama import Style

import bootstrap.config

from bootstrap.cli import runtime
from bootstrap.cli.remote.helpers import materialize_remote_mock
from bootstrap.cli.remote.helpers import publish_remote_origin_to_s3
from bootstrap.cli.remote.helpers import run_foreground
from bootstrap.cli.remote.helpers import validate_remote_channel
from bootstrap.cli.remote.helpers import wait_for_http
from bootstrap.color import styled
from bootstrap.utils import get_command


if TYPE_CHECKING:
    from bootstrap.remote.channel import Channel


def _start_minio_remote_mock(
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
        if clean_bucket:
            mc = get_command("mc")
            bucket_target = f"{alias_name}/{bucket}"
            redacted = "<redacted>"
            runtime.execute_redacted(
                [mc, "alias", "set", alias_name, endpoint, access_key, secret_key, "--api", "s3v4"],
                [mc, "alias", "set", alias_name, endpoint, redacted, redacted, "--api", "s3v4"],
                "REMOTE PUBLISH ALIAS",
            )
            runtime.execute_redacted(
                [mc, "mb", "--ignore-existing", bucket_target],
                [mc, "mb", "--ignore-existing", bucket_target],
                "REMOTE CLEAN BUCKET (CREATE)",
            )
            runtime.execute_redacted(
                [mc, "rm", "--recursive", "--force", bucket_target],
                [mc, "rm", "--recursive", "--force", bucket_target],
                "REMOTE CLEAN BUCKET",
            )
        from bootstrap.remote.generation import utc_timestamp

        mock_generation = utc_timestamp().replace("-", "").replace(":", "") + "Z"
        publish_remote_origin_to_s3(
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

        v2_heads_dir = origin_dir / resource_root / "channels" / "heads"
        if v2_heads_dir.is_dir():
            from bootstrap.remote import Publisher as V2Publisher

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
        run_foreground(process, "\nMinIO remote mock interrupted by user.")
    except Exception:
        process.terminate()
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
        raise


def register_remote_mock(remote: click.Group) -> None:
    @remote.group(cls=ClickAliasedGroup)
    def mock():
        """Remote mock origin commands."""

    @mock.command("materialize")
    @click.option("--origin-dir", type=click.Path(path_type=Path), default=None)
    @click.option("--clean", is_flag=True, default=False, help="Remove the origin directory first.")
    def remote_mock_materialize(origin_dir: Path | None, clean: bool):
        """Copy committed remote mock fixtures into the configured origin directory."""
        bootstrap.config.DeveloperConfiguration.ensure_loaded()
        remote_cfg = bootstrap.config.DEV_CONFIGURATION.remote
        resolved_origin_dir = runtime.resolve_dev_path(origin_dir or remote_cfg.mock_origin_dir)
        materialize_remote_mock(resolved_origin_dir, clean)

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
        bootstrap.config.DeveloperConfiguration.ensure_loaded()
        bootstrap.config.ProjectConfiguration.ensure_loaded()
        remote_cfg = bootstrap.config.DEV_CONFIGURATION.remote
        minio = remote_cfg.require_minio("mock")

        resolved_host = host or remote_cfg.host
        resolved_resource_root = (
            resource_root or bootstrap.config.CONFIGURATION.data_schema.resource_root
        )
        resolved_channel = validate_remote_channel(channel or remote_cfg.channel.value)
        resolved_origin_dir = runtime.resolve_dev_path(origin_dir or remote_cfg.mock_origin_dir)

        if not no_materialize:
            materialize_remote_mock(resolved_origin_dir, clean_origin)
        elif not resolved_origin_dir.exists():
            raise click.ClickException(f"Remote mock origin does not exist: {resolved_origin_dir}")

        resolved_port = port or minio.port
        resolved_console_port = console_port or minio.console_port
        resolved_bucket = bucket or minio.bucket
        resolved_access_key = access_key or minio.access_key
        resolved_secret_key = secret_key or minio.secret_key
        resolved_data_dir = runtime.resolve_dev_path(data_dir or minio.data_dir)
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
        _start_minio_remote_mock(
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
