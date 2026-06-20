from __future__ import annotations

import json

import click

from click_aliases import ClickAliasedGroup

import bootstrap.config

from bootstrap.cli import runtime
from bootstrap.cli.remote.helpers import redact_remote_config


def register_remote_config(remote: click.Group) -> None:
    @remote.group("config", cls=ClickAliasedGroup)
    def remote_config():
        """Remote mock configuration commands."""

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
        bootstrap.config.DeveloperConfiguration.ensure_loaded()
        bootstrap.config.ProjectConfiguration.ensure_loaded()
        remote_cfg = bootstrap.config.DEV_CONFIGURATION.remote
        paths = bootstrap.config.DEV_CONFIGURATION.paths
        origin_path = runtime.resolve_dev_path(remote_cfg.mock_origin_dir)

        resolved: dict[str, str] = {
            "developerRoot": str(paths.root),
            "mockOriginPath": str(origin_path),
        }

        if remote_cfg.minio is not None:
            minio_data_path = runtime.resolve_dev_path(remote_cfg.minio.data_dir)
            minio_origin_url = (
                f"http://{remote_cfg.host}:{remote_cfg.minio.port}/{remote_cfg.minio.bucket}"
            )
            resolved["minioDataPath"] = str(minio_data_path)
            resolved["minioIndexUrl"] = (
                f"{minio_origin_url.rstrip('/')}"
                f"/{bootstrap.config.CONFIGURATION.data_schema.resource_root.strip('/')}"
                f"/channels/{remote_cfg.channel.value}/index.json"
            )

        payload: dict[str, object] = {
            "remote": redact_remote_config(remote_cfg.model_dump(mode="json")),
            "resolved": resolved,
        }
        indent = None if as_json else (4 if pretty else None)
        click.echo(json.dumps(payload, indent=indent))
