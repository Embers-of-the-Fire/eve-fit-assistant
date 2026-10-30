"""Build-state (generator memoization) subcommands.

The per-server models build-state map lives in CI storage
(``build-state/models/<server>.json``); output blob hashes reference the
production remote store. See ``bootstrap.data.buildstate.models`` for the
map semantics and invalidation rules.
"""

from __future__ import annotations

import asyncio

from configparser import ConfigParser
from pathlib import Path

import click

from colorama import Fore
from colorama import Style

import bootstrap.config

from bootstrap.cli import runtime
from bootstrap.cli.remote.helpers import validate_remote_channel
from bootstrap.color import styled
from bootstrap.constant import PROJECT_ROOT
from bootstrap.data.buildstate.models import MAP_SCHEMA_VERSION
from bootstrap.data.buildstate.models import ModelArtifactEntry
from bootstrap.data.buildstate.models import ModelsBuildStateMap
from bootstrap.data.buildstate.models import map_remote_key
from bootstrap.data.buildstate.models import ship_resource_id
from bootstrap.data.updater.server import SERVER_ALIASES
from bootstrap.data.updater.server import SERVER_IDS
from bootstrap.data.workspace.config import WorkspaceConfig
from bootstrap.remote.s3client import S3Client


_MODELS_RESOURCE_PREFIX = "resource://static/models/"


def _resolve_server(server: str) -> str:
    normalized = SERVER_ALIASES.get(server.lower(), server.lower())
    if normalized not in SERVER_IDS:
        raise click.UsageError(f"Unknown server: {server}")
    return normalized


def _workspace_game_build(ws_config: WorkspaceConfig) -> str:
    """Game build of the workspace, derived like snapshot metadata (start.cfg)."""
    start_config = ConfigParser()
    start_config.read(ws_config.metadata.start_cfg)
    return start_config.get("main", "build", fallback="")


def _ci_client() -> S3Client:
    """CI storage client (write-scoped credentials required for mutations)."""
    bootstrap.config.DeveloperConfiguration.ensure_loaded()
    storage = bootstrap.config.DEV_CONFIGURATION.ci.require_storage()
    return S3Client(
        endpoint=storage.endpoint,
        bucket=storage.bucket,
        access_key=storage.access_key.get_secret_value(),
        secret_key=storage.secret_key.get_secret_value(),
    )


def _prod_client() -> S3Client:
    """Production remote client from [remote.s3] in efa.dev.toml."""
    bootstrap.config.DeveloperConfiguration.ensure_loaded()
    s3_cfg = bootstrap.config.DEV_CONFIGURATION.remote.require_s3("build-state")
    return S3Client(
        endpoint=s3_cfg.endpoint,
        bucket=s3_cfg.bucket,
        access_key=s3_cfg.access_key.get_secret_value(),
        secret_key=s3_cfg.secret_key.get_secret_value(),
    )


def register_build_state_commands(ci: click.Group) -> None:
    @ci.group("build-state")
    def build_state():
        """Manage generator build-state maps (models memoization)."""

    @build_state.command("invalidate")
    @click.option("--server", required=True, help=f"Server id ({', '.join(sorted(SERVER_IDS))}).")
    def invalidate(server: str):
        """Delete a server's models build-state map; the next build reconverts all.

        Use after converter or toolchain changes: the map carries no converter
        identity, so output-affecting tool changes are a manual gate.
        """
        server_id = _resolve_server(server)
        client = _ci_client()
        client.delete_key(map_remote_key(server_id))
        click.echo(
            styled(
                [Style.BRIGHT, Fore.GREEN],
                f"Invalidated models build-state for {server_id}.",
            )
        )

    @build_state.command("commit")
    @click.option(
        "--from",
        "from_dir",
        type=click.Path(exists=True, file_okay=False, path_type=Path),
        required=True,
        help="Directory containing models/<server>.json maps to upload.",
    )
    def commit(from_dir: Path):
        """Upload locally written build-state maps to CI storage."""
        maps_dir = from_dir / "models"
        if not maps_dir.is_dir():
            raise click.ClickException(f"No models maps found under {maps_dir}")
        client = _ci_client()
        maps = sorted(maps_dir.glob("*.json"))
        if not maps:
            raise click.ClickException(f"No models maps found under {maps_dir}")
        for map_file in maps:
            state_map = ModelsBuildStateMap.from_json(map_file.read_bytes())
            if state_map.schema_version != MAP_SCHEMA_VERSION:
                raise click.ClickException(f"Unsupported map schema in {map_file}")
            if state_map.server_id != map_file.stem:
                raise click.ClickException(
                    f"Map {map_file} declares server {state_map.server_id!r}; "
                    "filename must be <server>.json."
                )
            client.write_bytes(map_remote_key(state_map.server_id), map_file.read_bytes())
            click.echo(f"Committed models build-state for {state_map.server_id}.")
        click.echo(styled([Style.BRIGHT, Fore.GREEN], f"Committed {len(maps)} build-state map(s)."))

    @build_state.command("seed")
    @click.option("--server", required=True, help=f"Server id ({', '.join(sorted(SERVER_IDS))}).")
    @click.option(
        "--channel",
        default="testing",
        help="Channel whose head snapshot supplies output hashes (default: testing).",
    )
    @click.option(
        "--schema-root",
        type=click.Path(file_okay=False, path_type=Path),
        default="cache/remote",
        help="Locally synced schema root (run `remote sync` first).",
    )
    @click.option(
        "--force",
        is_flag=True,
        help="Seed even when the snapshot game build differs from the workspace "
        "build, or when either side lacks game-build metadata.",
    )
    def seed(server: str, channel: str, schema_root: Path, force: bool):
        """Rebuild a server's map without converting: inputs from the resource
        index, outputs from the synced channel head snapshot.

        Recovery path when the map is lost but the published blobs exist. The
        snapshot's game build must match the workspace build, so outputs from
        another game build are not marked valid for current inputs. Missing
        game-build metadata on either side also requires --force, since the map
        carries no game-build field to re-check the pairing later.
        """
        from bootstrap.data.workspace.generate import GeneratorDatasource
        from bootstrap.data.workspace.generate.models import gather_dna_inputs
        from bootstrap.data.workspace.generate.models import resolve_ship_jobs
        from bootstrap.data.workspace.generate.paths import ShipModelVariant

        server_id = _resolve_server(server)
        resolved_channel = validate_remote_channel(channel).value
        resolved_root = (PROJECT_ROOT / schema_root).resolve()

        from bootstrap.remote import SessionManager
        from bootstrap.remote.snapshot import SnapshotStore

        mgr = SessionManager(resolved_root)
        try:
            head = mgr.get_head(resolved_channel)
        except FileNotFoundError:
            raise click.ClickException(
                f"No local channel head for {resolved_channel!r} under {resolved_root}; "
                "run `remote sync` for this channel first."
            ) from None
        gen = mgr.load_generation(head.generation_hash)
        snapshot_hash = next(
            (e.snapshot_hash for e in gen.resources.entries if e.server_id == server_id),
            None,
        )
        if snapshot_hash is None:
            raise click.ClickException(
                f"Channel {resolved_channel} head has no snapshot for {server_id}."
            )
        metadata, index = SnapshotStore(resolved_root).load_resource_snapshot(snapshot_hash)
        outputs = {
            entry.resource_id: entry.content_hash
            for entry in index.entries
            if entry.resource_id.startswith(_MODELS_RESOURCE_PREFIX)
        }
        if not outputs:
            raise click.ClickException(
                f"Snapshot {snapshot_hash[:16]}... carries no models resources."
            )

        ws_config = WorkspaceConfig.load_from_descriptor(runtime.get_workspace(server_id))
        workspace_build = _workspace_game_build(ws_config)
        snapshot_build = metadata.game_build
        if workspace_build and snapshot_build:
            if snapshot_build != workspace_build:
                if not force:
                    raise click.ClickException(
                        f"Snapshot game build {snapshot_build!r} does not match workspace "
                        f"build {workspace_build!r}: its outputs may belong to another "
                        "game build. Re-run with --force to seed anyway."
                    )
                click.echo(
                    styled([Style.BRIGHT, Fore.YELLOW], "Warning: ")
                    + f"Seeding from snapshot game build {snapshot_build!r} despite "
                    f"workspace build {workspace_build!r} (--force)."
                )
        elif not force:
            missing = []
            if not snapshot_build:
                missing.append(f"snapshot {snapshot_hash[:16]}...")
            if not workspace_build:
                missing.append("workspace (start.cfg)")
            raise click.ClickException(
                f"Game build metadata missing on {' and '.join(missing)}; the "
                "snapshot's outputs may belong to another game build and would be "
                "marked valid for current inputs without a way to detect it later. "
                "Re-run with --force to seed anyway."
            )
        else:
            click.echo(
                styled([Style.BRIGHT, Fore.YELLOW], "Warning: ")
                + "Seeding despite missing game build metadata on snapshot or "
                "workspace (--force)."
            )

        async def gather_inputs():
            data = GeneratorDatasource(ws_config)
            try:
                _jobs, resolved_jobs = await resolve_ship_jobs(data)
                return gather_dna_inputs(data, resolved_jobs)
            finally:
                await data.aclose()

        dna_aliases, _dna_jobs, dna_inputs = asyncio.run(gather_inputs())

        entries: dict[str, ModelArtifactEntry] = {}
        for dna, aliases in dna_aliases.items():
            inputs = dna_inputs[dna]
            if inputs is None:
                continue
            for alias in aliases:
                for variant in ShipModelVariant:
                    rid = ship_resource_id(alias, variant)
                    output = outputs.get(rid)
                    if output is None:
                        continue
                    variant_inputs = (
                        inputs if variant is ShipModelVariant.FULL else inputs.without_textures()
                    )
                    entries[rid] = ModelArtifactEntry(
                        model=variant_inputs.model,
                        texture=variant_inputs.texture,
                        dna=variant_inputs.dna,
                        sof=variant_inputs.sof,
                        output=output,
                    )

        state_map = ModelsBuildStateMap(server_id=server_id, entries=entries)
        _ci_client().write_bytes(map_remote_key(server_id), state_map.to_json())
        click.echo(
            styled(
                [Style.BRIGHT, Fore.GREEN],
                f"Seeded models build-state for {server_id}: "
                f"{len(entries)} entries ({len(outputs)} outputs in snapshot).",
            )
        )

    @build_state.command("push-models")
    @click.option("--server", required=True, help=f"Server id ({', '.join(sorted(SERVER_IDS))}).")
    def push_models(server: str):
        """Pre-build ship models locally and push outputs to the production store.

        Runs the full models conversion on this machine, uploads every produced
        GLB blob to the production remote store (skipping blobs already
        present), and commits the updated build-state map to CI storage. The
        next CI build then rehydrates instead of converting.
        """
        from bootstrap.data.workspace.generate import GeneratorDatasource

        server_id = _resolve_server(server)

        bootstrap.config.ProjectConfiguration.ensure_loaded()
        resource_root = bootstrap.config.CONFIGURATION.data_schema.resource_root

        from bootstrap.data.buildstate.models import ModelsCacheContext
        from bootstrap.data.workspace.generate import models as models_step

        cache = ModelsCacheContext(
            server_id=server_id,
            resource_root=resource_root,
            ci_client=_ci_client(),
            prod_client=_prod_client(),
            rebuild=True,
            upload_map=True,
            upload_blobs=True,
        )

        async def run():
            ws_config = WorkspaceConfig.load_from_descriptor(runtime.get_workspace(server_id))
            data = GeneratorDatasource(ws_config)
            try:
                await models_step.generate(data, cache=cache)
            finally:
                await data.aclose()

        asyncio.run(run())
        click.echo(
            styled(
                [Style.BRIGHT, Fore.GREEN],
                f"Pushed pre-built models for {server_id}: blobs uploaded, map committed.",
            )
        )
