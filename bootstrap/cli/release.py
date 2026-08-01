from __future__ import annotations

import click

from colorama import Fore
from colorama import Style

import bootstrap.config

from bootstrap.cli import runtime
from bootstrap.color import styled
from bootstrap.config import ProjectVersion
from bootstrap.release.relnote import create_raw_release_note
from bootstrap.release.relnote import parse_version_override
from bootstrap.release.relnote import split_csv
from bootstrap.release.version_sync import sync_versions


def register_release_commands(cli_group: click.Group) -> None:
    @cli_group.group("release")
    def release():
        """Release workflow commands."""

    @release.command("relnote")
    @click.option(
        "--version",
        "version_override",
        default=None,
        help="Override the app version (semver, e.g. 0.1.0-beta.7).",
    )
    @click.option(
        "--published-at",
        default=None,
        help="Override publishedAt timestamp (ISO-8601, default: now).",
    )
    @click.option(
        "--channels",
        default=None,
        help="Comma-separated channel list (default: testing).",
    )
    @click.option(
        "--platforms",
        default=None,
        help="Comma-separated platform list (default: all platforms).",
    )
    @click.option(
        "--force",
        is_flag=True,
        default=False,
        help="Overwrite an existing release note directory.",
    )
    @click.option(
        "--dry-run",
        is_flag=True,
        default=False,
        help="Show the target directory without writing files.",
    )
    @click.option(
        "--from-ref",
        default=None,
        help="Base git ref (tag or commit hash) to compare against. "
        "If omitted, uses the last tag matching version pattern.",
    )
    def release_relnote(
        version_override: str | None,
        published_at: str | None,
        channels: str | None,
        platforms: str | None,
        force: bool,
        dry_run: bool,
        from_ref: str | None,
    ):
        """Create a raw release note in docs/changelog.

        Emits only spec.yaml and changelog.md (no localized content files).
        The changelog body is generated with git-cliff using cliff.toml.
        """
        if version_override is not None:
            version = ProjectVersion.model_validate(parse_version_override(version_override))
        else:
            bootstrap.config.ProjectConfiguration.ensure_loaded()
            version = bootstrap.config.CONFIGURATION.version

        channels_list = split_csv(channels)
        platforms_list = split_csv(platforms)

        directory, entry_id = create_raw_release_note(
            version,
            dry_run=dry_run,
            force=force,
            published_at=published_at,
            channels=channels_list,
            platforms=platforms_list,
            from_ref=from_ref,
        )

        if dry_run:
            click.echo(
                styled([Style.BRIGHT, Fore.CYAN], "[DRY-RUN] ")
                + f"Would create release note for {version.render_semver()}"
            )
            click.echo(f"  directory: {directory}")
            click.echo(f"  entry id:  {entry_id}")
            click.echo("  files:     spec.yaml, changelog.md")
            return

        click.echo(
            styled([Style.BRIGHT, Fore.GREEN], "Created raw release note: ") + str(directory)
        )
        click.echo(f"  entry id: {entry_id}")

    @release.group("version")
    def release_version():
        """Version management commands."""

    @release_version.command("sync")
    @click.option(
        "--dry-run",
        is_flag=True,
        default=False,
        help="Show the changes without writing files.",
    )
    def release_version_sync(dry_run: bool):
        """Sync the canonical version from efa.config.toml to package manifests."""
        dry_run = dry_run or runtime.is_dry_run()
        bootstrap.config.ProjectConfiguration.ensure_loaded()
        version = bootstrap.config.CONFIGURATION.version

        if dry_run:
            click.echo(
                styled([Style.BRIGHT, Fore.CYAN], "[DRY-RUN] ")
                + "Syncing version to package manifests..."
            )
        else:
            click.echo("Syncing version to package manifests...")

        changed = sync_versions(version, dry_run=dry_run)

        if dry_run:
            click.echo(
                styled([Style.BRIGHT, Fore.CYAN], "[DRY-RUN] ")
                + f"Done. {changed} file(s) would be updated."
            )
        else:
            click.echo(f"Done. {changed} file(s) updated.")
