"""Raw release note generation — emits spec.yaml and changelog.md only."""

from __future__ import annotations

import datetime as dt
import shutil
import subprocess

from typing import TYPE_CHECKING

import click
import yaml

from bootstrap.constant import PROJECT_ROOT
from bootstrap.utils import get_command


if TYPE_CHECKING:
    from pathlib import Path

    from bootstrap.config import ProjectVersion


CHANGELOG_ROOT = PROJECT_ROOT / "docs" / "changelog"
CLIFF_CONFIG = PROJECT_ROOT / "cliff.toml"

_DEFAULT_CHANNELS = ["testing"]
_DEFAULT_PLATFORMS = ["android", "ios"]
_DEFAULT_TAGS = ["release-note"]


def _normalize_version_dir(version: str) -> str:
    return version.replace(".", "-")


def _version_dir_to_entry_id(name: str) -> str:
    return f"version-{_normalize_version_dir(name)}"


def _run_cliff(tag: str) -> str:
    cmd = [
        get_command("git-cliff"),
        "--config",
        str(CLIFF_CONFIG),
        "--unreleased",
        "--tag",
        tag,
        "--strip",
        "header",
    ]
    result = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        cwd=PROJECT_ROOT,
    )
    if result.returncode != 0:
        raise RuntimeError(f"git-cliff failed: {result.stderr.strip()}")
    return result.stdout.strip() + "\n"


def _build_spec(
    *,
    version: ProjectVersion,
    published_at: str | None,
    channels: list[str] | None,
    platforms: list[str] | None,
) -> dict[str, object]:
    app_version = version.render_semver()
    entry_id = _version_dir_to_entry_id(app_version)
    when = published_at or dt.datetime.now(dt.UTC).strftime("%Y-%m-%dT%H:%M:%SZ")
    return {
        "id": entry_id,
        "publishedAt": when,
        "tags": _DEFAULT_TAGS,
        "channels": channels if channels is not None else _DEFAULT_CHANNELS,
        "platforms": platforms if platforms is not None else _DEFAULT_PLATFORMS,
        "appVersion": app_version,
    }


def create_raw_release_note(
    version: ProjectVersion,
    *,
    dry_run: bool = False,
    force: bool = False,
    published_at: str | None = None,
    channels: list[str] | None = None,
    platforms: list[str] | None = None,
) -> tuple[Path, str]:
    """Create a raw release note directory under docs/changelog.

    Emits only spec.yaml and changelog.md; no localized content.*.md files.
    """
    app_version = version.render_semver()
    dir_name = _normalize_version_dir(app_version)
    entry_id = _version_dir_to_entry_id(app_version)
    directory = CHANGELOG_ROOT / dir_name

    if directory.exists() and any(directory.iterdir()):
        if not force:
            raise click.ClickException(
                f"Release note directory already exists: {directory}. Use --force to overwrite."
            )
        shutil.rmtree(directory)

    if dry_run:
        return directory, entry_id

    directory.mkdir(parents=True, exist_ok=True)

    spec = _build_spec(
        version=version,
        published_at=published_at,
        channels=channels,
        platforms=platforms,
    )
    spec_path = directory / "spec.yaml"
    changelog_path = directory / "changelog.md"

    tag = version.render_tag()
    if not dry_run:
        changelog_body = _run_cliff(tag)

    if dry_run:
        return directory, entry_id

    spec_path.write_text(
        yaml.safe_dump(spec, allow_unicode=True, sort_keys=False),
        encoding="utf-8",
    )
    changelog_path.write_text(changelog_body, encoding="utf-8")

    return directory, entry_id
