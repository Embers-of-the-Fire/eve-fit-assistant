from __future__ import annotations

import asyncio
import json
import os
import tarfile

from pathlib import Path

import click

from colorama import Fore
from colorama import Style

import bootstrap.ci.resolve as resolver

from bootstrap.ci.codegen import all_step_names
from bootstrap.ci.codegen import run_steps
from bootstrap.ci.codegen import steps_for_packages
from bootstrap.ci.diagnostics import register_ci_diagnostics_commands
from bootstrap.ci.release import register_ci_release_commands
from bootstrap.ci.release_github import register_github_release_command
from bootstrap.cli import runtime
from bootstrap.cli.remote.helpers import validate_remote_channel
from bootstrap.color import styled
from bootstrap.constant import PROJECT_ROOT
from bootstrap.data.updater.server import SERVER_IDS
from bootstrap.data.workspace.config import WorkspaceConfig
from bootstrap.utils import get_command


def register_ci_commands(cli_group: click.Group) -> None:
    @cli_group.group()
    def ci():
        """CI/CD helper commands."""

    register_ci_release_commands(ci)
    register_github_release_command(ci)
    register_ci_diagnostics_commands(ci)

    def _resolve_change_set(target, head, from_file, full):
        """Resolve CLI options into a Resolution via the single resolver."""
        if full:
            return resolver.escalated_resolution()
        if from_file:
            with open(from_file) as f:
                return resolver.resolve(line.strip() for line in f if line.strip())
        if target:
            try:
                files = resolver.changed_files(target, head or "HEAD")
            except RuntimeError as exception:
                raise click.ClickException(str(exception)) from exception
            return resolver.resolve(files)
        return resolver.resolve([])

    change_set_options = [
        click.option(
            "--target",
            default=None,
            help="Target branch/ref; the change set is the merge-base diff to the head.",
        ),
        click.option("--head", default=None, help="Head ref (default: HEAD)."),
        click.option(
            "--from-file", type=click.Path(exists=True), default=None, help="Changed-file list."
        ),
        click.option(
            "--full",
            is_flag=True,
            default=False,
            help="Escalate: instantiate the entire catalog (no diff).",
        ),
    ]

    def _with_change_set_options(func):
        for option in change_set_options:
            func = option(func)
        return func

    @ci.command("matrix")
    @_with_change_set_options
    def ci_matrix(target, head, from_file, full):
        """Resolve the change set into the CI job matrix. Outputs JSON to stdout."""
        resolution = _resolve_change_set(target, head, from_file, full)
        print(json.dumps(resolver.job_matrix(resolution)))

    @ci.command("affected")
    @_with_change_set_options
    def ci_affected(target, head, from_file, full):
        """Report the resolved packages and tasks for a change set (JSON)."""
        resolution = _resolve_change_set(target, head, from_file, full)
        print(json.dumps(resolver.affected_report(resolution)))

    @ci.command("web-gate")
    @_with_change_set_options
    def ci_web_gate(target, head, from_file, full):
        """Whether the Flutter web bundle must be rebuilt. Prints true/false."""
        resolution = _resolve_change_set(target, head, from_file, full)
        print("true" if resolver.web_bundle_gate(resolution) else "false")

    @ci.command("codegen")
    @click.option(
        "--packages",
        default=None,
        help="Comma-separated package ids; generates what their dependency closure requires.",
    )
    @click.option("--steps", default=None, help="Comma-separated codegen step names.")
    @click.option("--all", "all_steps", is_flag=True, default=False, help="Run every step.")
    @click.option(
        "--format/--no-format",
        default=True,
        help="Format each step's outputs right after it runs (default: on).",
    )
    def ci_codegen(packages: str | None, steps: str | None, all_steps: bool, format: bool):
        """Generate code through the step graph (CI-aware)."""
        selected = [name for name in (packages, steps) if name] + ([True] if all_steps else [])
        if len(selected) != 1:
            raise click.ClickException("Pass exactly one of --packages, --steps, or --all.")
        if all_steps:
            names = all_step_names()
        elif packages:
            ids = [p.strip() for p in packages.split(",") if p.strip()]
            try:
                names = steps_for_packages(ids)
            except ValueError as exception:
                raise click.ClickException(str(exception)) from exception
        else:
            assert steps is not None
            names = [s.strip() for s in steps.split(",") if s.strip()]
        try:
            run_steps(names, format_outputs=format)
        except ValueError as exception:
            raise click.ClickException(str(exception)) from exception

    @ci.command("zizmor")
    def ci_zizmor():
        """Scan GitHub workflow files with zizmor."""
        zizmor = get_command("zizmor")
        cmd = [zizmor]
        if os.environ.get("GITHUB_ACTIONS") == "true":
            cmd += ["--format", "github"]
        cmd += [".github/workflows", ".github/actions"]
        runtime.execute(cmd, "ZIZMOR SCAN", live_stdout=True)

    @ci.command("pack-data")
    @click.option(
        "--output", "-o", default="cache/ci/ci-native-data.tar.gz", help="Output tarball path"
    )
    @click.option(
        "--upload", is_flag=True, default=False, help="Upload to CI storage after packing"
    )
    def ci_pack_data(output, upload):
        """Pack native CI data into a tarball for upload to CI storage."""
        import bootstrap.config

        bootstrap.config.DeveloperConfiguration.ensure_loaded()
        storage = bootstrap.config.DEV_CONFIGURATION.ci.require_storage()
        native = bootstrap.config.DEV_CONFIGURATION.native
        if native.output_dir is None:
            raise click.ClickException("Missing [native].output_dir in efa.dev.toml")

        output_dir = native.output_dir
        json_dir = output_dir / "json"
        pb2_dir = output_dir / "pb2"

        required_json = ["dogmaAttributes.json", "dogmaEffects.json"]
        required_pb2 = [
            "types.pb2",
            "dogmaAttributes.pb2",
            "dogmaEffects.pb2",
            "typeDogma.pb2",
            "dbuffcollections.pb2",
        ]

        missing = []
        for f in required_json:
            if not (json_dir / f).exists():
                missing.append(f"json/{f}")
        for f in required_pb2:
            if not (pb2_dir / f).exists():
                missing.append(f"pb2/{f}")

        if missing:
            raise click.ClickException(
                "Missing files (run `./x build data` first):\n  " + "\n  ".join(missing)
            )

        out_path = Path(output).resolve()
        out_path.parent.mkdir(parents=True, exist_ok=True)
        with tarfile.open(out_path, "w:gz") as tar:
            for f in required_json:
                tar.add(json_dir / f, arcname=f"json/{f}")
            for f in required_pb2:
                tar.add(pb2_dir / f, arcname=f"pb2/{f}")

        total = len(required_json) + len(required_pb2)
        size_mb = out_path.stat().st_size / (1024 * 1024)
        click.echo(
            styled(
                [Style.BRIGHT, Fore.GREEN],
                f"Packed {total} files ({size_mb:.1f} MiB) -> {out_path}",
            )
        )

        remote_path = f"{storage.alias}/{storage.bucket}/build-dependencies/ci-native-data.tar.gz"

        if upload:
            mc = get_command("mc")
            redacted = "<redacted>"
            runtime.execute_redacted(
                [
                    mc,
                    "alias",
                    "set",
                    storage.alias,
                    storage.endpoint,
                    storage.access_key.get_secret_value(),
                    storage.secret_key.get_secret_value(),
                ],
                [
                    mc,
                    "alias",
                    "set",
                    storage.alias,
                    storage.endpoint,
                    redacted,
                    redacted,
                ],
                "CI STORAGE ALIAS",
            )
            runtime.execute([mc, "cp", str(out_path), remote_path], "CI STORAGE UPLOAD")
        else:
            click.echo(f"Upload with: mc cp {out_path} {remote_path}")

    def _lookup_command(ctx: click.Context, *path: str) -> click.Command:
        """Walk from the root CLI group to a nested command by name."""
        root_ctx = ctx
        while root_ctx.parent is not None:
            root_ctx = root_ctx.parent
        cmd = root_ctx.command
        for name in path:
            cmd = cmd.commands[name]
        return cmd

    @ci.group("release-data")
    def release_data():
        """Manage CI release data snapshots."""

    @release_data.command("build")
    @click.option(
        "--output",
        "-o",
        type=click.Path(file_okay=False, path_type=Path),
        default="cache/remote",
        help="Schema V2 root for the generated snapshots (default: cache/remote).",
    )
    @click.option(
        "--hashes",
        type=click.Path(file_okay=True, path_type=Path),
        default="snapshot-hashes.json",
        help="Output path for the snapshot hashes JSON file.",
    )
    @click.option(
        "--server",
        multiple=True,
        default=None,
        help="Server to build (default: all configured servers).",
    )
    @click.option(
        "--servers",
        default=None,
        help="JSON array of server IDs to build (default: all configured servers).",
    )
    @click.option(
        "--download",
        is_flag=True,
        help="Download raw artifacts from CI storage before building.",
    )
    @click.option(
        "--resources-dir",
        type=click.Path(file_okay=False, path_type=Path),
        default="data/resources",
        help="Directory to download raw artifacts into (default: data/resources).",
    )
    def release_data_build(
        output: Path,
        hashes: Path,
        server: tuple[str, ...],
        servers: str | None,
        download: bool,
        resources_dir: Path,
    ):
        """Build resource snapshots for all servers and emit snapshot-hashes.json."""
        from bootstrap.data.workspace.generate import run_generator

        if servers is not None:
            if servers.strip() == "":
                servers_to_build = sorted(SERVER_IDS)
            else:
                try:
                    parsed_servers = json.loads(servers)
                except json.JSONDecodeError as exc:
                    raise click.BadParameter(f"Invalid JSON in --servers: {exc}") from exc
                if not isinstance(parsed_servers, list):
                    raise click.BadParameter("--servers must be a JSON array")
                servers_to_build = parsed_servers
        elif server:
            servers_to_build = list(server)
        else:
            servers_to_build = sorted(SERVER_IDS)

        if not servers_to_build:
            servers_to_build = sorted(SERVER_IDS)
        if not servers_to_build:
            raise click.ClickException("No servers configured.")

        for server_id in servers_to_build:
            if server_id not in SERVER_IDS:
                raise click.ClickException(f"Unknown server: {server_id}")

        schema_root = (PROJECT_ROOT / output).resolve()
        resolved_resources_dir = (PROJECT_ROOT / resources_dir).resolve()

        raw_artifacts = None
        storage = None
        if download:
            import bootstrap.config

            from bootstrap.data.updater.uploader import download_artifacts

            bootstrap.config.DeveloperConfiguration.ensure_loaded()
            ci = bootstrap.config.DEV_CONFIGURATION.ci
            raw_artifacts, storage = ci.require_raw_artifacts()

        async def run_pipeline():
            if download:
                assert raw_artifacts is not None
                assert storage is not None
                for server_id in servers_to_build:
                    await download_artifacts(
                        server_id, resolved_resources_dir, raw_artifacts, storage
                    )
                    click.echo(
                        f"Downloaded {server_id} artifacts to {resolved_resources_dir / server_id}"
                    )

            hashes_data: dict[str, str] = {}
            for server_id in servers_to_build:
                ws_descriptor = runtime.get_workspace(server_id)
                ws_config = WorkspaceConfig.load_from_descriptor(ws_descriptor)
                snapshot_hash = await run_generator(ws_config, set(), schema_root=schema_root)
                if snapshot_hash is None:
                    raise click.ClickException(f"No snapshot produced for {server_id}")
                hashes_data[server_id] = snapshot_hash
                click.echo(f"Built {server_id} snapshot: {snapshot_hash[:16]}...")

            hashes_path = (PROJECT_ROOT / hashes).resolve()
            hashes_path.parent.mkdir(parents=True, exist_ok=True)
            hashes_path.write_text(
                json.dumps(hashes_data, indent=2, sort_keys=True) + "\n",
                encoding="utf-8",
            )
            click.echo(
                styled([Style.BRIGHT, Fore.GREEN], f"Wrote snapshot hashes to {hashes_path}")
            )

        asyncio.run(run_pipeline())

    @release_data.command("publish")
    @click.argument("channel")
    @click.option(
        "--hashes",
        type=click.Path(exists=True, file_okay=True, path_type=Path),
        default="snapshot-hashes.json",
        help="Path to the snapshot hashes JSON file.",
    )
    @click.option(
        "--schema-root",
        type=click.Path(file_okay=False, path_type=Path),
        default="cache/remote",
        help="Schema V2 root containing the snapshots (default: cache/remote).",
    )
    @click.option(
        "--test-mode",
        is_flag=True,
        help="Commit with --no-push and skip publish/sync/verify.",
    )
    @click.option(
        "--target",
        type=click.Choice(["minio", "s3"]),
        default="s3",
        help="Remote target type (default: s3).",
    )
    @click.option("--endpoint", default=None, help="Override remote endpoint URL.")
    @click.option("--bucket", default=None, help="Override remote bucket name.")
    @click.option("--access-key", default=None, help="Override remote access key.")
    @click.option("--secret-key", default=None, help="Override remote secret key.")
    @click.option("--alias", "alias_name", default=None, help="Override mc alias name.")
    @click.option(
        "--workers",
        type=click.IntRange(min=1),
        default=8,
        help="Number of parallel upload/download workers.",
    )
    @click.option(
        "--sync-depth",
        type=click.IntRange(min=-1),
        default=1,
        help="Max generations to sync after publish (default: 1).",
    )
    @click.option(
        "--merge/--no-merge",
        is_flag=True,
        default=True,
        help="Include unchanged server snapshots from the current channel head (default: true).",
    )
    @click.option(
        "--allow-missing-head",
        is_flag=True,
        default=False,
        help="Allow publishing without a local channel head (first publish to a channel).",
    )
    @click.pass_context
    def release_data_publish(
        ctx: click.Context,
        channel: str,
        hashes: Path,
        schema_root: Path,
        test_mode: bool,
        target: str,
        endpoint: str | None,
        bucket: str | None,
        access_key: str | None,
        secret_key: str | None,
        alias_name: str | None,
        workers: int,
        sync_depth: int,
        merge: bool,
        allow_missing_head: bool,
    ):
        """Publish resource snapshots to a remote channel."""
        from bootstrap.remote import SessionManager

        resolved_root = (PROJECT_ROOT / schema_root).resolve()

        hashes_path = (PROJECT_ROOT / hashes).resolve()
        hashes_data = json.loads(hashes_path.read_text(encoding="utf-8"))
        if not isinstance(hashes_data, dict):
            raise click.ClickException(f"Invalid hashes file: {hashes_path}")

        resolved_channel = validate_remote_channel(channel).value

        mgr = SessionManager(resolved_root)
        if merge:
            from bootstrap.remote.generation import GenerationStore

            try:
                head = mgr.get_head(resolved_channel)
            except FileNotFoundError:
                head = None
            if head and head.generation_hash:
                prev_gen = GenerationStore(resolved_root).load(head.generation_hash)
                for entry in prev_gen.resources.entries:
                    if entry.server_id not in hashes_data:
                        hashes_data[entry.server_id] = entry.snapshot_hash
                        click.echo(
                            f"Carried forward {entry.server_id} snapshot: "
                            f"{entry.snapshot_hash[:16]}..."
                        )
            elif not allow_missing_head:
                raise click.ClickException(
                    f"No local channel head found for '{resolved_channel}' under "
                    f"{resolved_root}; refusing to publish a partial generation. "
                    "Run `remote sync` for this channel into the same schema root first, "
                    "or pass --allow-missing-head if this is the first publish "
                    "to the channel."
                )

        init_cmd = _lookup_command(ctx, "remote", "session", "init")
        add_cmd = _lookup_command(ctx, "remote", "session", "add")
        diff_cmd = _lookup_command(ctx, "remote", "session", "diff")
        verify_cmd = _lookup_command(ctx, "remote", "session", "verify")
        commit_cmd = _lookup_command(ctx, "remote", "session", "commit")

        ctx.invoke(
            init_cmd,
            channel=resolved_channel,
            schema_root=resolved_root,
            force_overwrite=False,
        )

        for server_id, hash_value in hashes_data.items():
            ctx.invoke(
                add_cmd,
                resource_flag=True,
                release_flag=False,
                source_hash=hash_value,
                source_file=None,
                force=False,
                replace_hash=None,
                schema_root=resolved_root,
            )
            click.echo(f"Staged {server_id} snapshot: {hash_value[:16]}...")

        ctx.invoke(diff_cmd, as_json=True, schema_root=resolved_root)
        ctx.invoke(verify_cmd, repair=False, schema_root=resolved_root)
        ctx.invoke(
            commit_cmd,
            no_push=test_mode,
            force=False,
            allow_empty_release_pointer=allow_missing_head,
            schema_root=resolved_root,
        )

        committed_hash = mgr.get_head(resolved_channel).generation_hash
        click.echo(
            styled(
                [Style.BRIGHT, Fore.GREEN],
                f"Committed generation: {committed_hash[:16]}...",
            )
        )

        if test_mode:
            click.echo(
                styled([Style.BRIGHT, Fore.YELLOW], "Test mode: skipped publish/sync/verify.")
            )
            return

        publish_cmd = _lookup_command(ctx, "remote", "publish")
        sync_cmd = _lookup_command(ctx, "remote", "sync")

        ctx.invoke(
            publish_cmd,
            channel=resolved_channel,
            target=target,
            endpoint=endpoint,
            bucket=bucket,
            access_key=access_key,
            secret_key=secret_key,
            alias_name=alias_name,
            workers=workers,
            schema_root=resolved_root,
        )

        ctx.invoke(
            sync_cmd,
            target=target,
            endpoint=endpoint,
            bucket=bucket,
            access_key=access_key,
            secret_key=secret_key,
            alias_name=alias_name,
            depth=sync_depth,
            workers=workers,
            schema_root=resolved_root,
            channel=resolved_channel,
        )

        synced_hash = mgr.get_head(resolved_channel).generation_hash
        if committed_hash != synced_hash:
            raise click.ClickException(
                f"Remote head verification failed: "
                f"committed={committed_hash[:16]}..., synced={synced_hash[:16]}..."
            )
        click.echo(
            styled(
                [Style.BRIGHT, Fore.GREEN],
                f"Remote head verified: {synced_hash[:16]}...",
            )
        )

    @release_data.command("d1-sync")
    @click.option(
        "--hashes",
        type=click.Path(exists=True, file_okay=True, path_type=Path),
        default="snapshot-hashes.json",
        help="Path to the snapshot hashes JSON file.",
    )
    @click.option(
        "--schema-root",
        type=click.Path(file_okay=False, path_type=Path),
        default="cache/remote",
        help="Schema V2 root containing the snapshots (default: cache/remote).",
    )
    @click.option("--url", default=None, help="Override the data-sync worker URL.")
    @click.option("--token", default=None, help="Override the data-sync bearer token.")
    @click.option(
        "--batch-size",
        type=click.IntRange(min=1, max=2000),
        default=500,
        help="Rows per upload frame (default: 500).",
    )
    @click.option(
        "--dry-run",
        is_flag=True,
        help="Decode and count entries without uploading.",
    )
    def release_data_d1_sync(
        hashes: Path,
        schema_root: Path,
        url: str | None,
        token: str | None,
        batch_size: int,
        dry_run: bool,
    ):
        """Sync snapshot engine data into the platform D1 database."""
        import bootstrap.config

        from bootstrap.data.d1.sync import WebSocketTransport
        from bootstrap.data.d1.sync import run_sync

        resolved_root = (PROJECT_ROOT / schema_root).resolve()
        hashes_path = (PROJECT_ROOT / hashes).resolve()
        hashes_data = json.loads(hashes_path.read_text(encoding="utf-8"))
        if not isinstance(hashes_data, dict):
            raise click.ClickException(f"Invalid hashes file: {hashes_path}")

        bootstrap.config.DeveloperConfiguration.ensure_loaded()
        d1 = bootstrap.config.DEV_CONFIGURATION.d1

        resolved_url = url or d1.url
        resolved_token = token or (d1.token.get_secret_value() if d1.token else None)

        transport = None
        if not dry_run:
            if not resolved_token:
                raise click.ClickException(
                    "No D1 sync token configured. Set [d1].token in efa.dev.toml, "
                    "pass --token, or use --dev-env d1.token=... (or --dry-run)."
                )
            transport = WebSocketTransport(resolved_url, resolved_token)

        run_sync(
            hashes_data,
            resolved_root,
            transport,
            batch_size=batch_size,
            dry_run=dry_run,
        )
        click.echo(styled([Style.BRIGHT, Fore.GREEN], "D1 sync completed."))
