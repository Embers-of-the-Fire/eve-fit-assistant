"""`remote promote` — admit testing snapshots into stable, manage suppressions.

Promotion is the only write path into the stable channel's data pointers. The
scheduled workflow (`ci release-data promote`) drives it after a 24h soak; this
CLI is the manual override path plus the suppression-list veto hook.
"""

from __future__ import annotations

import os
import subprocess

from typing import TYPE_CHECKING

import click

from colorama import Fore
from colorama import Style

from bootstrap.cli import runtime
from bootstrap.cli.remote.helpers import validate_remote_channel
from bootstrap.cli.remote.lifecycle import _SCHEMA_ROOT_OPTION
from bootstrap.cli.remote.lifecycle import _resolve_remote_target
from bootstrap.color import styled
from bootstrap.remote import SessionManager
from bootstrap.remote.channel import Channel
from bootstrap.remote.generation import utc_timestamp
from bootstrap.remote.models import SuppressionEntry
from bootstrap.remote.promote import PromotionError


if TYPE_CHECKING:
    from pathlib import Path

    from bootstrap.remote.promote import PromoteResult


def _parse_pair(pair: str) -> tuple[str, str]:
    server, sep, checkout = pair.partition(":")
    if not sep or not server.strip() or not checkout.strip():
        raise click.BadParameter(f"Expected <server>:<checkout>, got {pair!r}")
    return server.strip(), checkout.strip()


def _resolve_actor(actor: str | None) -> str:
    if actor:
        return actor
    try:
        name = subprocess.run(
            ["git", "config", "user.name"], capture_output=True, text=True, check=False
        ).stdout.strip()
        email = subprocess.run(
            ["git", "config", "user.email"], capture_output=True, text=True, check=False
        ).stdout.strip()
        if name and email:
            return f"{name} <{email}>"
        if name:
            return name
    except OSError:
        pass
    return os.environ.get("USER", "unknown")


def _print_plan(result: PromoteResult) -> None:
    for server, checkout in sorted(result.admitted.items()):
        click.echo(f"  admit              {server}: {checkout[:16]}...")
    for server, checkout in sorted(result.skipped_idempotent.items()):
        click.echo(f"  skip (idempotent)  {server}: {checkout[:16]}...")
    for server, checkout in sorted(result.skipped_suppressed.items()):
        click.echo(f"  skip (suppressed)  {server}: {checkout[:16]}...")


def _guard_stable_head_fresh(
    mgr: SessionManager,
    target: str,
    endpoint: str | None,
    bucket: str | None,
    access_key: str | None,
    secret_key: str | None,
    alias_name: str | None,
    workers: int,
    op: str,
) -> None:
    """Sync the stable head from the remote; refuse to mutate a stale cache.

    The hourly promote workflow advances the stable head independently of any
    operator's local cache, and publishing uploads local head files. Refresh
    the head first; if the local state had drifted from the remote, refuse so
    the mutation is never built on — or published over — a stale head.
    """
    channel = str(Channel.STABLE)
    resolved = _resolve_remote_target(
        target, endpoint, bucket, access_key, secret_key, alias_name, op
    )
    endpoint_r, bucket_r, access_r, secret_r, alias_r = resolved
    syncer = mgr.make_syncer(
        endpoint=endpoint_r,
        bucket=bucket_r,
        access_key=access_r,
        secret_key=secret_r,
        alias_name=alias_r,
        workers=workers,
    )

    try:
        before_hash = mgr.get_head(channel).generation_hash
    except FileNotFoundError:
        before_hash = ""
    before_suppressions = mgr.get_suppressions(channel)

    result = syncer.sync_head(channel)
    if not result.head_meta:
        return

    after_hash = mgr.get_head(channel).generation_hash
    after_suppressions = mgr.get_suppressions(channel)
    if before_hash != after_hash or before_suppressions != after_suppressions:
        raise click.ClickException(
            f"Local {channel} head was stale "
            f"(local {before_hash[:16] or '<none>'}, remote {after_hash[:16]}). "
            "Refreshed from remote; re-run the command against the updated state."
        )


def _publish_and_verify(
    mgr: SessionManager,
    channel: str,
    committed_hash: str | None,
    target: str,
    endpoint: str | None,
    bucket: str | None,
    access_key: str | None,
    secret_key: str | None,
    alias_name: str | None,
    workers: int,
    *,
    suppressions_only: bool = False,
) -> None:
    """Publish the head (or only its suppression list), sync back, assert match."""
    resolved = _resolve_remote_target(
        target, endpoint, bucket, access_key, secret_key, alias_name, "promote"
    )
    endpoint_r, bucket_r, access_r, secret_r, alias_r = resolved

    pub = mgr.make_publisher(
        endpoint=endpoint_r,
        bucket=bucket_r,
        access_key=access_r,
        secret_key=secret_r,
        alias_name=alias_r,
        workers=workers,
    )
    expected_suppressions = mgr.get_suppressions(channel) if suppressions_only else None
    if suppressions_only:
        pub.publish_suppressions(channel)
    else:
        if committed_hash:
            pub.publish_generation(channel, committed_hash)
        pub.publish_head(channel)

    syncer = mgr.make_syncer(
        endpoint=endpoint_r,
        bucket=bucket_r,
        access_key=access_r,
        secret_key=secret_r,
        alias_name=alias_r,
        workers=workers,
    )
    if suppressions_only:
        sync_result = syncer.sync_head(channel)
    else:
        sync_result = syncer.sync_channel(channel, max_depth=1)
    if not sync_result.head_meta:
        raise click.ClickException(
            f"Channel head not found on remote for {channel!r} after publish."
        )

    synced_hash = mgr.get_head(channel).generation_hash
    if committed_hash and synced_hash != committed_hash:
        raise click.ClickException(
            f"Remote head verification failed: committed={committed_hash[:16]}..., "
            f"synced={synced_hash[:16]}..."
        )
    if expected_suppressions is not None:
        synced_suppressions = mgr.get_suppressions(channel)
        if synced_suppressions != expected_suppressions:
            raise click.ClickException(
                f"Remote suppressions verification failed for {channel!r}: "
                "synced list does not match the published list."
            )
    click.echo(styled([Style.BRIGHT, Fore.GREEN], f"Remote head verified: {synced_hash[:16]}..."))


_TARGET_OPTIONS = [
    click.option(
        "--target",
        type=click.Choice(["minio", "s3"]),
        default="s3",
        help="Remote target type (default: s3).",
    ),
    click.option("--endpoint", default=None, help="Override remote endpoint URL."),
    click.option("--bucket", default=None, help="Override remote bucket name."),
    click.option("--access-key", default=None, help="Override remote access key."),
    click.option("--secret-key", default=None, help="Override remote secret key."),
    click.option("--alias", "alias_name", default=None, help="Override mc alias name."),
    click.option(
        "--workers",
        type=click.IntRange(min=1),
        default=8,
        help="Number of parallel upload/download workers.",
    ),
]


def _with_target_options(func):
    for option in _TARGET_OPTIONS:
        func = option(func)
    return func


def register_remote_promotion(remote: click.Group) -> None:
    @remote.group("promote", invoke_without_command=True)
    @click.option(
        "--server",
        multiple=True,
        help="Server to promote (repeatable); defaults to its source head snapshot.",
    )
    @click.option(
        "--all",
        "all_servers",
        is_flag=True,
        default=False,
        help="Promote every server in the source head.",
    )
    @click.option(
        "--checkout",
        multiple=True,
        help="Pin an explicit snapshot as <server>:<hash> (repeatable).",
    )
    @click.option("--force", is_flag=True, help="Promote suppressed checkouts.")
    @click.option("--dry-run", is_flag=True, help="Print the admission plan; write nothing.")
    @click.option(
        "--allow-missing-head",
        is_flag=True,
        default=False,
        help="Allow promoting into a channel without a head (bootstrap promotion).",
    )
    @click.option(
        "--test-mode",
        is_flag=True,
        help="Exercise the full local flow only; no remote upload.",
    )
    @click.option("--actor", default=None, help="Recorded actor (default: git identity).")
    @_with_target_options
    @_SCHEMA_ROOT_OPTION
    @click.pass_context
    def promote_group(
        ctx: click.Context,
        server: tuple[str, ...],
        all_servers: bool,
        checkout: tuple[str, ...],
        force: bool,
        dry_run: bool,
        allow_missing_head: bool,
        test_mode: bool,
        actor: str | None,
        target: str,
        endpoint: str | None,
        bucket: str | None,
        access_key: str | None,
        secret_key: str | None,
        alias_name: str | None,
        workers: int,
        schema_root: Path | None,
    ):
        """Promote testing snapshots into the stable channel."""
        if ctx.invoked_subcommand is not None:
            return

        root = runtime.resolve_schema_root(schema_root)
        mgr = SessionManager(root)

        source, target_channel = Channel.TESTING, Channel.STABLE
        try:
            source_gen = mgr.load_generation(mgr.get_head(source).generation_hash)
        except (FileNotFoundError, PromotionError) as exc:
            raise click.ClickException(str(exc)) from exc
        head_snapshots = {
            entry.server_id: entry.snapshot_hash for entry in source_gen.resources.entries
        }

        candidates: dict[str, str] = {}
        for pair in checkout:
            server_id, checkout_hash = _parse_pair(pair)
            candidates[server_id] = checkout_hash
        servers = sorted(head_snapshots) if all_servers else list(server)
        if not servers and not candidates:
            raise click.ClickException("Pass --server/--all or --checkout.")
        for server_id in servers:
            if server_id in candidates:
                continue
            if server_id not in head_snapshots:
                raise click.ClickException(
                    f"Unknown server {server_id!r} in the {source} channel head."
                )
            candidates[server_id] = head_snapshots[server_id]

        if dry_run:
            result = _plan_only(
                mgr,
                source=source,
                target=target_channel,
                candidates=candidates,
                force=force,
            )
            _print_plan(result)
            click.echo("Dry run: nothing written.")
            return

        if not test_mode:
            _guard_stable_head_fresh(
                mgr,
                target,
                endpoint,
                bucket,
                access_key,
                secret_key,
                alias_name,
                workers,
                "promote",
            )

        try:
            result = mgr.promote(
                source=source,
                target=target_channel,
                candidates=candidates,
                actor=_resolve_actor(actor),
                respect_suppressions=not force,
                allow_missing_head=allow_missing_head,
            )
        except PromotionError as exc:
            raise click.ClickException(str(exc)) from exc

        _print_plan(result)
        if result.noop:
            click.echo("Nothing to promote: no generation created, head unchanged.")
            return

        click.echo(
            styled(
                [Style.BRIGHT, Fore.GREEN],
                f"Promoted generation: {result.generation_hash[:16]}...",
            )
        )

        if test_mode:
            click.echo(
                styled([Style.BRIGHT, Fore.YELLOW], "Test mode: skipped publish/sync/verify.")
            )
            return

        _publish_and_verify(
            mgr,
            str(target_channel),
            result.generation_hash,
            target,
            endpoint,
            bucket,
            access_key,
            secret_key,
            alias_name,
            workers,
        )

    @promote_group.command("suppress")
    @click.argument("pair")
    @click.option("--reason", default="", help="Why this checkout is suppressed.")
    @click.option("--actor", default=None, help="Recorded actor (default: git identity).")
    @click.option(
        "--test-mode",
        is_flag=True,
        help="Mutate the local store only; no remote upload.",
    )
    @_with_target_options
    @_SCHEMA_ROOT_OPTION
    def promote_suppress(
        pair: str,
        reason: str,
        actor: str | None,
        test_mode: bool,
        target: str,
        endpoint: str | None,
        bucket: str | None,
        access_key: str | None,
        secret_key: str | None,
        alias_name: str | None,
        workers: int,
        schema_root: Path | None,
    ):
        """Veto a <server>:<checkout> pair from automatic promotion."""
        server_id, checkout_hash = _parse_pair(pair)
        root = runtime.resolve_schema_root(schema_root)
        mgr = SessionManager(root)
        channel = str(Channel.STABLE)

        if not test_mode:
            _guard_stable_head_fresh(
                mgr,
                target,
                endpoint,
                bucket,
                access_key,
                secret_key,
                alias_name,
                workers,
                "promote suppress",
            )

        suppressions = mgr.get_suppressions(channel)
        if any(
            entry.server == server_id and entry.checkout == checkout_hash
            for entry in suppressions.suppressions
        ):
            click.echo(f"Already suppressed: {server_id}:{checkout_hash[:16]}...")
            return

        suppressions.suppressions.append(
            SuppressionEntry(
                server=server_id,
                checkout=checkout_hash,
                reason=reason,
                suppressedAt=utc_timestamp(),
                actor=_resolve_actor(actor),
            )
        )
        mgr.save_suppressions(channel, suppressions)
        click.echo(f"Suppressed {server_id}: {checkout_hash[:16]}...")

        _warn_if_already_promoted(mgr, channel, server_id, checkout_hash)

        if test_mode:
            click.echo(styled([Style.BRIGHT, Fore.YELLOW], "Test mode: skipped publish."))
            return
        _publish_and_verify(
            mgr,
            channel,
            None,
            target,
            endpoint,
            bucket,
            access_key,
            secret_key,
            alias_name,
            workers,
            suppressions_only=True,
        )

    @promote_group.command("unsuppress")
    @click.argument("pair")
    @click.option(
        "--test-mode",
        is_flag=True,
        help="Mutate the local store only; no remote upload.",
    )
    @_with_target_options
    @_SCHEMA_ROOT_OPTION
    def promote_unsuppress(
        pair: str,
        test_mode: bool,
        target: str,
        endpoint: str | None,
        bucket: str | None,
        access_key: str | None,
        secret_key: str | None,
        alias_name: str | None,
        workers: int,
        schema_root: Path | None,
    ):
        """Remove a <server>:<checkout> pair from the suppression list."""
        server_id, checkout_hash = _parse_pair(pair)
        root = runtime.resolve_schema_root(schema_root)
        mgr = SessionManager(root)
        channel = str(Channel.STABLE)

        if not test_mode:
            _guard_stable_head_fresh(
                mgr,
                target,
                endpoint,
                bucket,
                access_key,
                secret_key,
                alias_name,
                workers,
                "promote unsuppress",
            )

        suppressions = mgr.get_suppressions(channel)
        kept = [
            entry
            for entry in suppressions.suppressions
            if not (entry.server == server_id and entry.checkout == checkout_hash)
        ]
        if len(kept) == len(suppressions.suppressions):
            raise click.ClickException(f"Not suppressed: {server_id}:{checkout_hash[:16]}...")
        suppressions.suppressions = kept
        mgr.save_suppressions(channel, suppressions)
        click.echo(f"Unsuppressed {server_id}: {checkout_hash[:16]}...")

        if test_mode:
            click.echo(styled([Style.BRIGHT, Fore.YELLOW], "Test mode: skipped publish."))
            return
        _publish_and_verify(
            mgr,
            channel,
            None,
            target,
            endpoint,
            bucket,
            access_key,
            secret_key,
            alias_name,
            workers,
            suppressions_only=True,
        )

    @promote_group.command("suppressions")
    @_SCHEMA_ROOT_OPTION
    def promote_suppressions(schema_root: Path | None):
        """List active promotion suppressions for the stable channel."""
        root = runtime.resolve_schema_root(schema_root)
        mgr = SessionManager(root)
        suppressions = mgr.get_suppressions(str(Channel.STABLE))
        if not suppressions.suppressions:
            click.echo("No active suppressions.")
            return
        for entry in suppressions.suppressions:
            suffix = f" — {entry.reason}" if entry.reason else ""
            actor = f" (by {entry.actor})" if entry.actor else ""
            click.echo(
                f"  {entry.server}: {entry.checkout[:16]}... "
                f"at {entry.suppressed_at}{actor}{suffix}"
            )

    @remote.command("set-default-channel")
    @click.argument("channel")
    @click.option(
        "--test-mode",
        is_flag=True,
        help="Mutate the local store only; no remote upload.",
    )
    @_with_target_options
    @_SCHEMA_ROOT_OPTION
    def set_default_channel(
        channel: str,
        test_mode: bool,
        target: str,
        endpoint: str | None,
        bucket: str | None,
        access_key: str | None,
        secret_key: str | None,
        alias_name: str | None,
        workers: int,
        schema_root: Path | None,
    ):
        """Set the registry's defaultChannel and publish channels.json."""
        resolved_channel = validate_remote_channel(channel)
        root = runtime.resolve_schema_root(schema_root)
        mgr = SessionManager(root)

        try:
            mgr.set_default_channel(str(resolved_channel))
        except ValueError as exc:
            raise click.ClickException(str(exc)) from exc
        click.echo(
            styled(
                [Style.BRIGHT, Fore.GREEN],
                f"defaultChannel set to {resolved_channel}.",
            )
        )

        if test_mode:
            click.echo(styled([Style.BRIGHT, Fore.YELLOW], "Test mode: skipped publish."))
            return

        resolved = _resolve_remote_target(
            target, endpoint, bucket, access_key, secret_key, alias_name, "set-default-channel"
        )
        endpoint_r, bucket_r, access_r, secret_r, alias_r = resolved
        pub = mgr.make_publisher(
            endpoint=endpoint_r,
            bucket=bucket_r,
            access_key=access_r,
            secret_key=secret_r,
            alias_name=alias_r,
            workers=workers,
        )
        pub.publish_registry()
        click.echo(styled([Style.BRIGHT, Fore.GREEN], "Registry published."))


def _plan_only(
    mgr: SessionManager,
    *,
    source: Channel,
    target: Channel,
    candidates: dict[str, str],
    force: bool,
) -> PromoteResult:
    """Compute the admission plan without writing (mirrors promote's filters)."""
    from bootstrap.remote.promote import PromoteResult
    from bootstrap.remote.promote import _valid_source_checkouts

    result = PromoteResult(source=str(source), target=str(target))
    source_gen = mgr.load_generation(mgr.get_head(source).generation_hash)
    valid = _valid_source_checkouts(mgr.root, source_gen)
    unknown = [
        f"{server}:{checkout}"
        for server, checkout in candidates.items()
        if checkout not in valid.get(server, set())
    ]
    if unknown:
        raise click.ClickException("Unknown candidate checkout(s): " + ", ".join(sorted(unknown)))

    try:
        target_head = mgr.get_head(target)
        target_gen = (
            mgr.load_generation(target_head.generation_hash)
            if target_head.generation_hash
            else None
        )
    except FileNotFoundError:
        target_gen = None
    target_current = (
        {entry.server_id: entry.snapshot_hash for entry in target_gen.resources.entries}
        if target_gen is not None
        else {}
    )
    suppressed = {
        (entry.server, entry.checkout) for entry in mgr.get_suppressions(str(target)).suppressions
    }
    for server, checkout_hash in candidates.items():
        if target_current.get(server) == checkout_hash:
            result.skipped_idempotent[server] = checkout_hash
        elif not force and (server, checkout_hash) in suppressed:
            result.skipped_suppressed[server] = checkout_hash
        else:
            result.admitted[server] = checkout_hash
    return result


def _warn_if_already_promoted(
    mgr: SessionManager, channel: str, server_id: str, checkout_hash: str
) -> None:
    """Suppression has no retroactive effect on already-admitted checkouts."""
    from bootstrap.remote.models import ServerHistory
    from bootstrap.remote.models import read_pb2
    from bootstrap.remote.paths import generation_dir

    try:
        head = mgr.get_head(channel)
    except FileNotFoundError:
        return
    if not head.generation_hash:
        return
    history_path = generation_dir(mgr.root, head.generation_hash) / "history.pb2"
    if not history_path.is_file():
        return
    history = read_pb2(history_path, ServerHistory)
    promoted = any(
        snap.snapshot_hash == checkout_hash
        for entry in history.servers
        if entry.server_id == server_id
        for snap in entry.snapshots
    )
    if promoted:
        click.echo(
            styled(
                [Style.BRIGHT, Fore.YELLOW],
                f"Warning: {server_id}:{checkout_hash[:16]}... is already promoted; "
                "suppression has no retroactive effect. "
                "Use `./x remote revert` to roll back.",
            )
        )
