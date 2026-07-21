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
from bootstrap.utils import normalize_version_dir
from bootstrap.utils import version_dir_to_entry_id


if TYPE_CHECKING:
    from pathlib import Path

    from bootstrap.config import ProjectVersion


CHANGELOG_ROOT = PROJECT_ROOT / "docs" / "changelog"
CLIFF_CONFIG = PROJECT_ROOT / "cliff.toml"

_DEFAULT_CHANNELS = ["testing"]
_DEFAULT_PLATFORMS = ["android", "ios"]
_DEFAULT_TAGS = ["release-note"]


def parse_version_override(value: str) -> dict[str, object]:
    if "-" in value:
        core, pre = value.split("-", 1)
    else:
        core = value
        pre = ""

    parts = core.split(".")
    if len(parts) != 3:
        raise click.ClickException(f"Invalid version override: {value!r}")
    try:
        major = int(parts[0])
        minor = int(parts[1])
        patch = int(parts[2])
    except ValueError as e:
        raise click.ClickException(f"Invalid version override: {value!r}") from e

    pre_label = ""
    pre_num = 0
    if pre:
        if "." in pre:
            pre_label, pre_num_str = pre.split(".", 1)
            try:
                pre_num = int(pre_num_str)
            except ValueError as e:
                raise click.ClickException(f"Invalid version override: {value!r}") from e
        else:
            pre_label = pre
            pre_num = 1

    return {
        "major": major,
        "minor": minor,
        "patch": patch,
        "pre_label": pre_label,
        "pre_num": pre_num,
    }


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
    # shell=True, and tag originates from a Pydantic-validated ProjectVersion,
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
        )
    except subprocess.TimeoutExpired as e:
        raise click.ClickException(f"git-cliff timed out after {e.timeout} seconds") from e
    if result.returncode != 0:
        raise click.ClickException(f"git-cliff failed: {result.stderr.strip()}")
    return result.stdout.strip() + "\n"


def _build_spec(
    *,
    version: ProjectVersion,
    published_at: str | None,
    channels: list[str] | None,
    platforms: list[str] | None,
    from_ref: str | None = None,
) -> dict[str, object]:
    app_version = version.render_semver()
    entry_id = version_dir_to_entry_id(app_version)
    when = published_at or dt.datetime.now(dt.UTC).strftime("%Y-%m-%dT%H:%M:%SZ")
    spec: dict[str, object] = {
        "id": entry_id,
        "publishedAt": when,
        "tags": _DEFAULT_TAGS,
        "channels": channels if channels is not None else _DEFAULT_CHANNELS,
        "platforms": platforms if platforms is not None else _DEFAULT_PLATFORMS,
        "appVersion": app_version,
    }
    if from_ref is not None:
        spec["fromRef"] = from_ref
    return spec


def create_raw_release_note(
    version: ProjectVersion,
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
    app_version = version.render_semver()
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
        shutil.rmtree(directory)

    if dry_run:
        return directory, entry_id

    directory.mkdir(parents=True, exist_ok=True)

    spec = _build_spec(
        version=version,
        published_at=published_at,
        channels=channels,
        platforms=platforms,
        from_ref=from_ref,
    )
    spec_path = directory / "spec.yaml"
    changelog_path = directory / "changelog.md"

    tag = version.render_tag()
    changelog_body = _run_cliff(tag, from_ref=from_ref)

    spec_path.write_text(
        yaml.safe_dump(spec, allow_unicode=True, sort_keys=False),
        encoding="utf-8",
    )
    changelog_path.write_text(changelog_body, encoding="utf-8")

    return directory, entry_id
