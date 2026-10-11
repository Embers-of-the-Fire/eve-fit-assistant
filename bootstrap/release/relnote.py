"""Raw release note generation — emits spec.yaml and changelog.md only."""

from __future__ import annotations

import datetime as dt
import shutil
import subprocess

from typing import TYPE_CHECKING

import click
import yaml

from bootstrap.constant import PROJECT_ROOT
from bootstrap.docs.announcements_remote import AnnouncementPlatform
from bootstrap.utils import get_command
from bootstrap.utils import normalize_version_dir
from bootstrap.utils import version_dir_to_entry_id


if TYPE_CHECKING:
    from pathlib import Path

    from bootstrap.config import ReleaseVersion


CHANGELOG_ROOT = PROJECT_ROOT / "docs" / "changelog"
CLIFF_CONFIG = PROJECT_ROOT / "cliff.toml"

_DEFAULT_TAGS = ["release-note"]


def parse_release_version(value: str) -> ReleaseVersion:
    from bootstrap.config import ReleaseVersion

    try:
        return ReleaseVersion.parse(value)
    except ValueError as e:
        raise click.ClickException(f"Invalid version override: {value!r}") from e


def split_csv(value: str | None) -> list[str] | None:
    if value is None:
        return None
    return [part.strip() for part in value.split(",") if part.strip()]


def _run_cliff(tag: str, from_ref: str | None = None) -> str:
    cmd = [
        get_command("git-cliff"),
        "--config",
        str(CLIFF_CONFIG),
        "--tag",
        tag,
        "--strip",
        "header",
    ]
    if from_ref is not None:
        cmd.append(f"{from_ref}..HEAD")
    else:
        cmd.append("--unreleased")
    # CWE-78 / S603 are false positives here: cmd is a list passed without
    # shell=True, and tag originates from a validated ReleaseVersion,
    # so there is no shell-interpretation vector.
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            cwd=PROJECT_ROOT,
            timeout=60,
            check=False,
        )
    except subprocess.TimeoutExpired as e:
        raise click.ClickException(f"git-cliff timed out after {e.timeout} seconds") from e
    if result.returncode != 0:
        raise click.ClickException(f"git-cliff failed: {result.stderr.strip()}")
    return result.stdout.strip() + "\n"


def _normalize_platforms(platforms: list[str]) -> list[str]:
    allowed = {platform.value for platform in AnnouncementPlatform}
    unknown = [platform for platform in platforms if platform not in allowed]
    if unknown:
        raise click.ClickException(
            "Invalid platform value(s): "
            + ", ".join(repr(platform) for platform in unknown)
            + f" (allowed: {', '.join(sorted(allowed))})"
        )
    return platforms


def _build_spec(
    *,
    version: ReleaseVersion,
    published_at: str | None,
    channels: list[str] | None,
    platforms: list[str] | None,
    from_ref: str | None = None,
) -> dict[str, object]:
    app_version = version.semver
    entry_id = version_dir_to_entry_id(app_version)
    when = published_at or dt.datetime.now(dt.UTC).strftime("%Y-%m-%dT%H:%M:%SZ")
    spec: dict[str, object] = {
        "id": entry_id,
        "publishedAt": when,
        "tags": _DEFAULT_TAGS,
        "channels": channels if channels is not None else version.default_channels,
        "appVersion": app_version,
        "platforms": _normalize_platforms(platforms) if platforms is not None else [],
    }
    if from_ref is not None:
        spec["fromRef"] = from_ref
    return spec


def create_raw_release_note(
    version: ReleaseVersion,
    *,
    dry_run: bool = False,
    force: bool = False,
    published_at: str | None = None,
    channels: list[str] | None = None,
    platforms: list[str] | None = None,
    from_ref: str | None = None,
) -> tuple[Path, str]:
    """Create a raw release note directory under docs/changelog.

    Emits only spec.yaml and changelog.md; no localized content.*.md files.
    """
    app_version = version.semver
    dir_name = normalize_version_dir(app_version)
    entry_id = version_dir_to_entry_id(app_version)
    directory = CHANGELOG_ROOT / dir_name

    if directory.exists() and any(directory.iterdir()):
        if not force:
            raise click.ClickException(
                f"Release note directory already exists: {directory}. Use --force to overwrite."
            )
        if dry_run:
            return directory, entry_id

    if dry_run:
        return directory, entry_id

    spec = _build_spec(
        version=version,
        published_at=published_at,
        channels=channels,
        platforms=platforms,
        from_ref=from_ref,
    )
    tag = version.tag
    changelog_body = _run_cliff(tag, from_ref=from_ref)

    if directory.exists():
        shutil.rmtree(directory)
    directory.mkdir(parents=True, exist_ok=True)
    spec_path = directory / "spec.yaml"
    changelog_path = directory / "changelog.md"

    spec_path.write_text(
        yaml.safe_dump(spec, allow_unicode=True, sort_keys=False),
        encoding="utf-8",
    )
    changelog_path.write_text(changelog_body, encoding="utf-8")

    return directory, entry_id
