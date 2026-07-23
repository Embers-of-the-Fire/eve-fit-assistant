from __future__ import annotations

import asyncio
import json
import os
import tarfile

from pathlib import Path

import click

from colorama import Fore
from colorama import Style

from bootstrap.ci.codegen import run_codegen
from bootstrap.ci.diagnostics import register_ci_diagnostics_commands
from bootstrap.ci.lint import run_lint
from bootstrap.ci.release import register_ci_release_commands
from bootstrap.ci.release_github import register_github_release_command
from bootstrap.ci.suites import SUITE_DEFINITIONS
from bootstrap.ci.suites import calculate_ci_matrix
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

    @ci.command("matrix")
    @click.option("--from-file", type=click.Path(exists=True), default=None)
    @click.option("--full", is_flag=True, default=False)
    def ci_matrix(from_file, full):
        """Calculate CI job matrix from changed files. Outputs JSON to stdout."""
        if full:
            suites = [
                {
                    "suite": s["suite"],
                    "shell": s["shell"],
                    "lint_command": s["lint_command"],
                    "command": s["command"],
                    "codegen_command": s["codegen_command"],
                }
                for s in SUITE_DEFINITIONS
            ]
        elif from_file:
            with open(from_file) as f:
                files = [line.strip() for line in f if line.strip()]
            suites = calculate_ci_matrix(files)
        else:
            suites = []

        print(json.dumps(suites))

    @ci.command("lint")
    @click.option(
        "--lang",
        type=click.Choice(["all", "python", "dart", "rust", "site", "l10n"]),
        default="all",
        help="Limit linting to a specific language (default: all).",
    )
    def ci_lint(lang: str):
        """Check formatting and linting without modifying files."""
        run_lint(lang, no_check=False, check_only=True, dry_run=False)

    @ci.command("codegen")
    @click.option(
        "--lang",
        type=click.Choice(["all", "python", "dart", "site"]),
        default="all",
        help="Generate code for specific language (default: all).",
    )
    def ci_codegen(lang: str):
        """Generate code and auto-format (CI-aware)."""
        run_codegen(lang)
        run_lint(lang, no_check=True, dry_run=False)

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
