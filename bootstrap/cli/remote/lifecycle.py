from __future__ import annotations

from pathlib import Path
from typing import TYPE_CHECKING

import click

from colorama import Fore
from colorama import Style

import bootstrap.config

from bootstrap.cli import runtime
from bootstrap.cli.remote.helpers import validate_remote_channel
from bootstrap.color import styled
from bootstrap.remote import SessionManager


if TYPE_CHECKING:
    from bootstrap.remote.sync import SyncResult


_SCHEMA_ROOT_OPTION = click.option(
    "--schema-root",
    type=click.Path(path_type=Path),
    default=None,
    help="Schema V2 storage root (default from dev config).",
)


def _print_sync_result(result: SyncResult) -> None:
    """Print a human-readable sync result summary."""
    parts: list[str] = [f"  Channel: {result.channel}"]
    if result.registry:
        parts.append("registry ✓")
    if result.head_meta:
        parts.append("head ✓")
    if result.reflog:
        parts.append("reflog ✓")
    parts.append(f"generations: {result.generations}")
    parts.append(f"resource snapshots: {result.resource_snapshots}")
    parts.append(f"release snapshots: {result.release_snapshots}")
    click.echo("  " + "  ".join(parts))


def _resolve_remote_target(target: str, endpoint, bucket, access_key, secret_key, alias_name, op):
    bootstrap.config.DeveloperConfiguration.ensure_loaded()
    remote_cfg = bootstrap.config.DEV_CONFIGURATION.remote

    if target == "minio":
        minio_cfg = remote_cfg.require_minio(op)
        return (
            endpoint or f"http://{remote_cfg.host}:{minio_cfg.port}",
            bucket or minio_cfg.bucket,
            access_key or minio_cfg.access_key,
            secret_key or minio_cfg.secret_key,
            alias_name or minio_cfg.alias,
        )
    s3_cfg = remote_cfg.require_s3(op)
    return (
        endpoint or s3_cfg.endpoint,
        bucket or s3_cfg.bucket,
        access_key or s3_cfg.access_key,
        secret_key or s3_cfg.secret_key,
        alias_name or s3_cfg.alias,
    )


def register_remote_lifecycle(remote: click.Group) -> None:
    @remote.command("revert")
    @click.argument("channel")
    @click.argument("gen_hash")
    @_SCHEMA_ROOT_OPTION
    def remote_revert(channel: str, gen_hash: str, schema_root: Path | None):
        """Revert the channel head to a previous generation (pointer move only)."""
        root = runtime.resolve_schema_root(schema_root)
        mgr = SessionManager(root)

        resolved_channel = validate_remote_channel(channel)
        mgr.revert(resolved_channel, gen_hash)

        click.echo(
            styled([Style.BRIGHT, Fore.GREEN], f"Channel {resolved_channel} reverted to")
            + f" {gen_hash[:16]}..."
        )

    @remote.command("gc")
    @click.option(
        "--dry-run",
        is_flag=True,
        default=False,
        help="List what would be deleted without actually deleting.",
    )
    @click.option(
        "--retention-depth",
        type=click.IntRange(min=0),
        default=0,
        show_default=True,
        help="Ancestor generations kept per head (head-only = 0; head + last N = N).",
    )
    @_SCHEMA_ROOT_OPTION
    def remote_gc(dry_run: bool, retention_depth: int, schema_root: Path | None):
        """Garbage collect unreferenced entities from local V2 storage."""
        root = runtime.resolve_schema_root(schema_root)
        mgr = SessionManager(root)

        deleted = mgr.gc(dry_run=dry_run, retention_depth=retention_depth)

        if dry_run:
            if not deleted:
                click.echo("Nothing to prune.")
                return
            click.echo(f"Would delete {len(deleted)} unreferenced entity(ies):")
            for path in sorted(deleted):
                click.echo(f"  {path}")
        else:
            if not deleted:
                click.echo("Nothing to prune.")
                return
            click.echo(
                styled(
                    [Style.BRIGHT, Fore.GREEN], f"Pruned {len(deleted)} unreferenced entity(ies):"
                )
            )
            for path in sorted(deleted):
                click.echo(styled(Style.DIM, f"  {path}"))

    @remote.command("verify")
    @click.option(
        "--repair",
        is_flag=True,
        default=False,
        help="Attempt to repair issues from workspace origin.",
    )
    @_SCHEMA_ROOT_OPTION
    def remote_verify(repair: bool, schema_root: Path | None):
        """Verify integrity of heads, generations, snapshots, and blobs."""
        root = runtime.resolve_schema_root(schema_root)
        mgr = SessionManager(root)

        if repair:
            fixed = mgr.repair()
            if fixed > 0:
                click.echo(styled([Style.BRIGHT, Fore.GREEN], f"Repaired {fixed} entity(ies)."))
            else:
                click.echo("No entities needed repair.")
            return

        all_issues = mgr.verify()
        total = sum(len(v) for v in all_issues.values())
        if total == 0:
            click.echo(styled([Style.BRIGHT, Fore.GREEN], "All entities passed verification."))
            return

        for category, issues in all_issues.items():
            if not issues:
                continue
            click.echo(f"\n  {styled([Style.BRIGHT, Fore.CYAN], category.capitalize())}:")
            for issue in issues:
                color = Fore.RED if issue.severity == "error" else Fore.YELLOW
                click.echo(
                    f"    {styled([Style.BRIGHT, color], issue.severity.upper())} "
                    f"[{issue.entity_type}] {issue.entity}: {issue.message}"
                )

        error_count = sum(sum(1 for i in v if i.severity == "error") for v in all_issues.values())
        warn_count = total - error_count
        summary = f"{total} issue(s): {error_count} error(s), {warn_count} warning(s)"
        if error_count:
            click.echo(styled([Style.BRIGHT, Fore.RED], f"\nVerification failed — {summary}"))
        else:
            click.echo(styled([Style.BRIGHT, Fore.YELLOW], f"\nVerification complete — {summary}"))

    @remote.command("publish")
    @click.argument("channel")
    @click.option(
        "--target",
        type=click.Choice(["minio", "s3"], case_sensitive=False),
        required=True,
        help="S3-compatible upload target (reads defaults from efa.dev.toml).",
    )
    @click.option("--endpoint", default=None, help="Override S3-compatible endpoint URL.")
    @click.option("--bucket", default=None, help="Override bucket name.")
    @click.option("--access-key", default=None, help="Override access key.")
    @click.option("--secret-key", default=None, help="Override secret key.")
    @click.option("--alias", "alias_name", default=None, help="Override mc alias name.")
    @click.option(
        "--workers",
        type=click.IntRange(min=1),
        default=8,
        show_default=True,
        help="Number of parallel upload workers.",
    )
    @_SCHEMA_ROOT_OPTION
    def remote_publish(
        channel: str,
        target: str,
        endpoint: str | None,
        bucket: str | None,
        access_key: str | None,
        secret_key: str | None,
        alias_name: str | None,
        workers: int,
        schema_root: Path | None,
    ):
        """Publish the channel's current head to a remote S3/MinIO bucket."""
        (
            resolved_endpoint,
            resolved_bucket,
            resolved_access_key,
            resolved_secret_key,
            resolved_alias,
        ) = _resolve_remote_target(
            target, endpoint, bucket, access_key, secret_key, alias_name, "publish"
        )

        root = runtime.resolve_schema_root(schema_root)
        mgr = SessionManager(root)

        resolved_channel = validate_remote_channel(channel)

        pub = mgr.make_publisher(
            endpoint=resolved_endpoint,
            bucket=resolved_bucket,
            access_key=resolved_access_key,
            secret_key=resolved_secret_key,
            alias_name=resolved_alias,
            workers=workers,
        )

        click.echo(styled([Style.BRIGHT, Fore.GREEN], f"Publishing channel {resolved_channel}..."))
        pub.publish_all_for_head(resolved_channel)
        click.echo(styled([Style.BRIGHT, Fore.GREEN], "Publish complete."))

    @remote.command("sync")
    @click.option(
        "--target",
        type=click.Choice(["minio", "s3"], case_sensitive=False),
        required=True,
        help="S3-compatible sync target (reads defaults from efa.dev.toml).",
    )
    @click.option("--endpoint", default=None, help="Override S3-compatible endpoint URL.")
    @click.option("--bucket", default=None, help="Override bucket name.")
    @click.option("--access-key", default=None, help="Override access key.")
    @click.option("--secret-key", default=None, help="Override secret key.")
    @click.option("--alias", "alias_name", default=None, help="Override mc alias name.")
    @click.option(
        "--depth",
        type=click.IntRange(min=-1),
        default=-1,
        show_default=True,
        help="Max generations to walk (-1 = all).",
    )
    @click.option(
        "--workers",
        type=click.IntRange(min=1),
        default=8,
        show_default=True,
        help="Number of parallel download workers.",
    )
    @_SCHEMA_ROOT_OPTION
    @click.option(
        "--channel",
        default=None,
        help="Sync a specific channel (default: all channels).",
    )
    def remote_sync(
        target: str,
        endpoint: str | None,
        bucket: str | None,
        access_key: str | None,
        secret_key: str | None,
        alias_name: str | None,
        depth: int,
        workers: int,
        schema_root: Path | None,
        channel: str | None,
    ):
        """Sync remote metadata/catalog to local schema root (no blobs).

        By default syncs all channels found in the remote registry.
        Use --channel to limit to a specific channel.
        """
        (
            resolved_endpoint,
            resolved_bucket,
            resolved_access_key,
            resolved_secret_key,
            resolved_alias,
        ) = _resolve_remote_target(
            target, endpoint, bucket, access_key, secret_key, alias_name, "sync"
        )

        root = runtime.resolve_schema_root(schema_root)
        mgr = SessionManager(root)

        syncer = mgr.make_syncer(
            endpoint=resolved_endpoint,
            bucket=resolved_bucket,
            access_key=resolved_access_key,
            secret_key=resolved_secret_key,
            alias_name=resolved_alias,
            workers=workers,
        )

        if channel is not None:
            resolved_channel = validate_remote_channel(channel)
            click.echo(styled([Style.BRIGHT, Fore.GREEN], f"Syncing channel {resolved_channel}..."))
            result = syncer.sync_channel(resolved_channel, max_depth=depth)
            _print_sync_result(result)
        else:
            click.echo(styled([Style.BRIGHT, Fore.GREEN], "Syncing all channels..."))
            results = syncer.sync_all_channels(max_depth=depth)
            if not results:
                click.echo(
                    styled([Style.BRIGHT, Fore.YELLOW], "No channels found in remote registry.")
                )
                return
            for _ch, r in results.items():
                _print_sync_result(r)

        click.echo(styled([Style.BRIGHT, Fore.GREEN], "Sync complete."))
