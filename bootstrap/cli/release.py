from __future__ import annotations

import click

from colorama import Fore
from colorama import Style

from bootstrap.color import styled
from bootstrap.config import CONFIGURATION
from bootstrap.config import ProjectVersion
from bootstrap.release.relnote import CHANGELOG_ROOT
from bootstrap.release.relnote import create_raw_release_note


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
            version = ProjectVersion.model_validate(_parse_version(version_override))
        else:
            version = CONFIGURATION.version

        channels_list = _split(channels)
        platforms_list = _split(platforms)

        if dry_run:
            app_version = version.render_semver()
            dir_name = app_version.replace(".", "-")
            entry_id = f"version-{dir_name}"
            directory = CHANGELOG_ROOT / dir_name
            click.echo(
                styled([Style.BRIGHT, Fore.CYAN], "[DRY-RUN] ")
                + f"Would create release note for {app_version}"
            )
            click.echo(f"  directory: {directory}")
            click.echo(f"  entry id:  {entry_id}")
            click.echo("  files:     spec.yaml, changelog.md")
            return

        directory, entry_id = create_raw_release_note(
            version,
            dry_run=dry_run,
            force=force,
            published_at=published_at,
            channels=channels_list,
            platforms=platforms_list,
        )

        click.echo(
            styled([Style.BRIGHT, Fore.GREEN], "Created raw release note: ") + str(directory)
        )
        click.echo(f"  entry id: {entry_id}")


def _split(value: str | None) -> list[str] | None:
    if value is None:
        return None
    return [part.strip() for part in value.split(",") if part.strip()]


def _parse_version(value: str) -> dict[str, object]:
    parts = value.split(".")
    if len(parts) < 3:
        raise click.ClickException(f"Invalid version override: {value!r}")
    try:
        major = int(parts[0])
        minor = int(parts[1])
    except ValueError as e:
        raise click.ClickException(f"Invalid version override: {value!r}") from e

    patch_part = parts[2]
    pre_label = ""
    pre_num = 0
    if "-" in patch_part:
        patch_part, pre = patch_part.split("-", 1)
        if "." in pre:
            pre_label, pre_num_str = pre.split(".", 1)
            try:
                pre_num = int(pre_num_str)
            except ValueError as e:
                raise click.ClickException(f"Invalid version override: {value!r}") from e
        else:
            pre_label = pre
            pre_num = 1

    try:
        patch = int(patch_part)
    except ValueError as e:
        raise click.ClickException(f"Invalid version override: {value!r}") from e

    return {
        "major": major,
        "minor": minor,
        "patch": patch,
        "pre_label": pre_label,
        "pre_num": pre_num,
    }
