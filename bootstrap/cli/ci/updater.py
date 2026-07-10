"""CI raw-data updater subcommands."""

from __future__ import annotations

import asyncio
import json
import shutil
import urllib.request

from pathlib import Path

import click

import bootstrap.config

from bootstrap.constant import PROJECT_ROOT
from bootstrap.data.updater.pipeline import check_server
from bootstrap.data.updater.pipeline import update_server
from bootstrap.data.updater.server import SERVER_ALIASES
from bootstrap.data.updater.server import SERVER_IDS
from bootstrap.data.updater.uploader import download_artifacts
from bootstrap.data.updater.uploader import upload_artifacts


def _resolve_server_input(server: str | None, all_flag: bool) -> list[str]:
    """Return the list of server identifiers to operate on."""
    if all_flag:
        return sorted(SERVER_IDS)
    if server is None:
        raise click.UsageError("Provide --server or --all.")
    normalized = SERVER_ALIASES.get(server.lower(), server.lower())
    if normalized not in SERVER_IDS:
        raise click.UsageError(f"Unknown server: {server}")
    return [normalized]


def register_raw_data_commands(ci: click.Group) -> None:
    @ci.group("raw-data")
    def raw_data():
        """Manage CI raw EVE client artifact updates."""

    @raw_data.command("check")
    @click.option("--server", default=None, help=f"Server id ({', '.join(sorted(SERVER_IDS))}).")
    @click.option("--all", "all_flag", is_flag=True, help="Check all servers.")
    @click.option(
        "--format",
        "output_format",
        type=click.Choice(["text", "json"]),
        default="text",
        help="Output format (default: text).",
    )
    def raw_data_check(server: str | None, all_flag: bool, output_format: str):
        """Compare remote EVE builds with the CI bucket."""
        server_ids = _resolve_server_input(server, all_flag)

        async def run():
            results: list[str] = []
            for server_id in server_ids:
                result = await check_server(server_id)
                if output_format == "json":
                    pass
                else:
                    click.echo(
                        f"{server_id}: remote={result.remote_build}, "
                        f"bucket={result.bucket_build}, "
                        f"needs_update={result.needs_update}"
                    )
                if result.needs_update:
                    results.append(server_id)
            if output_format == "json":
                click.echo(json.dumps(results))

        asyncio.run(run())

    @raw_data.command("update")
    @click.option("--server", default=None, help=f"Server id ({', '.join(sorted(SERVER_IDS))}).")
    @click.option("--all", "all_flag", is_flag=True, help="Update all servers.")
    @click.option("--no-upload", is_flag=True, help="Skip uploading to CI storage.")
    @click.option("--keep-temp", is_flag=True, help="Keep temporary working directories.")
    def raw_data_update(server: str | None, all_flag: bool, no_upload: bool, keep_temp: bool):
        """Download, convert, and optionally upload raw data."""
        server_ids = _resolve_server_input(server, all_flag)

        async def run():
            for server_id in server_ids:
                result = await update_server(
                    server_id,
                    upload=not no_upload,
                    keep_temp=keep_temp,
                )
                click.echo(
                    f"Updated {result.server_id} to build {result.build}: {result.artifacts_dir}"
                )

        asyncio.run(run())

    @raw_data.command("upload")
    @click.option("--server", required=True, help=f"Server id ({', '.join(sorted(SERVER_IDS))}).")
    @click.option(
        "--from-dir",
        type=click.Path(exists=True, file_okay=False, path_type=Path),
        required=True,
        help="Local directory containing the artifacts/ tree.",
    )
    def raw_data_upload(server: str, from_dir: Path):
        """Upload a pre-built local artifact tree to CI storage."""
        normalized = _resolve_server_input(server, False)[0]
        artifacts_dir = from_dir / "artifacts"
        if not artifacts_dir.is_dir():
            raise click.ClickException(f"Artifacts directory not found: {artifacts_dir}")

        build_file = from_dir / "build.txt"
        if not build_file.is_file():
            raise click.ClickException(f"Build file not found: {build_file}")
        try:
            build = int(build_file.read_text(encoding="utf-8").strip())
        except ValueError as exc:
            raise click.ClickException(
                f"Build file does not contain a valid integer: {build_file}"
            ) from exc

        bootstrap.config.DeveloperConfiguration.ensure_loaded()
        ci = bootstrap.config.DEV_CONFIGURATION.ci
        raw_artifacts, storage = ci.require_raw_artifacts()

        async def run():
            await upload_artifacts(normalized, artifacts_dir, build, raw_artifacts, storage)

        asyncio.run(run())
        click.echo(f"Uploaded {normalized} build {build} from {from_dir}")

    @raw_data.command("download")
    @click.option("--server", default=None, help=f"Server id ({', '.join(sorted(SERVER_IDS))}).")
    @click.option("--all", "all_flag", is_flag=True, help="Download all servers.")
    @click.option(
        "--output-dir",
        type=click.Path(file_okay=False, path_type=Path),
        default=None,
        help="Output directory (default: data/resources).",
    )
    def raw_data_download(server: str | None, all_flag: bool, output_dir: Path | None):
        """Download raw artifacts from CI storage to the local data/resources tree."""
        server_ids = _resolve_server_input(server, all_flag)
        if output_dir is None:
            output_dir = PROJECT_ROOT / "data" / "resources"

        bootstrap.config.DeveloperConfiguration.ensure_loaded()
        ci = bootstrap.config.DEV_CONFIGURATION.ci
        raw_artifacts, storage = ci.require_raw_artifacts()

        async def run():
            for server_id in server_ids:
                await download_artifacts(server_id, output_dir, raw_artifacts, storage)
                click.echo(f"Downloaded {server_id} artifacts to {output_dir / server_id}")

        asyncio.run(run())

    @raw_data.command("setup-py27")
    @click.option(
        "--output",
        "-o",
        type=click.Path(file_okay=True, path_type=Path),
        default="tools/eve-fsd-dumper/py27.zip",
        help="Output path for py27.zip.",
    )
    @click.option(
        "--url",
        default="https://ci.storage.efa-tech.dev/build-dependencies/py27.zip",
        help="Download URL for portable Python 2.7.",
    )
    def raw_data_setup_py27(output: Path, url: str):
        """Download portable Python 2.7 for the FSD dumper."""
        bootstrap.config.DeveloperConfiguration.ensure_loaded()
        ci = bootstrap.config.DEV_CONFIGURATION.ci
        public_url: str | None = None
        if ci.raw_artifacts is not None:
            public_url = ci.raw_artifacts.public_url
        if public_url is None and ci.storage is not None:
            public_url = ci.storage.public_url
        if public_url:
            url = f"{public_url}/build-dependencies/py27.zip"
        output.parent.mkdir(parents=True, exist_ok=True)
        request = urllib.request.Request(
            url,
            headers={"User-Agent": "Mozilla/5.0 (compatible; EFA-CI/1.0)"},
        )
        with (
            urllib.request.urlopen(request) as response,
            open(output, "wb") as f,
        ):
            shutil.copyfileobj(response, f)
        click.echo(f"Downloaded Python 2.7 to {output}")

    @raw_data.command("sync-local")
    @click.option("--server", required=True, help=f"Server id ({', '.join(sorted(SERVER_IDS))}).")
    def raw_data_sync_local(server: str):
        """Upload the local ``data/resources/<server>/`` tree to CI storage as-is."""
        normalized = _resolve_server_input(server, False)[0]
        local_dir = PROJECT_ROOT / "data" / "resources" / normalized
        if not local_dir.is_dir():
            raise click.ClickException(f"Local resource directory not found: {local_dir}")

        bootstrap.config.DeveloperConfiguration.ensure_loaded()
        ci = bootstrap.config.DEV_CONFIGURATION.ci
        raw_artifacts, storage = ci.require_raw_artifacts()

        base_dir = PROJECT_ROOT / "cache" / "raw-artifacts" / normalized
        if base_dir.exists():
            shutil.rmtree(base_dir)
        artifacts_dir = base_dir / "artifacts"
        artifacts_dir.mkdir(parents=True, exist_ok=True)
        shutil.copytree(local_dir, artifacts_dir, dirs_exist_ok=True)

        build_file = base_dir / "build.txt"
        build_file.write_text("0", encoding="utf-8")

        async def run():
            await upload_artifacts(normalized, artifacts_dir, 0, raw_artifacts, storage)

        asyncio.run(run())
        click.echo(f"Synced local {normalized} resources to CI storage")
