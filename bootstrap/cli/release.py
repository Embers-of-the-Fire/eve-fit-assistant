from __future__ import annotations

import click

from colorama import Fore
from colorama import Style

from bootstrap.color import styled
from bootstrap.config import CONFIGURATION
from bootstrap.config import ProjectVersion
from bootstrap.release.relnote import create_raw_release_note
from bootstrap.release.relnote import parse_version_override
from bootstrap.release.relnote import split_csv


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
        help="Comma-separated platform list (default: android,ios).",
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
    def release_relnote(
        version_override: str | None,
        published_at: str | None,
        channels: str | None,
        platforms: str | None,
        force: bool,
        dry_run: bool,
    ):
        """Create a raw release note in docs/changelog.

        Emits only spec.yaml and changelog.md (no localized content files).
        The changelog body is generated with git-cliff using cliff.toml.
        """
        if version_override is not None:
            version = ProjectVersion.model_validate(parse_version_override(version_override))
        else:
            version = CONFIGURATION.version

        channels_list = split_csv(channels)
        platforms_list = split_csv(platforms)

        directory, entry_id = create_raw_release_note(
            version,
            dry_run=dry_run,
            force=force,
            published_at=published_at,
            channels=channels_list,
            platforms=platforms_list,
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
