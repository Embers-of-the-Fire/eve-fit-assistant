from __future__ import annotations

import re

from dataclasses import dataclass
from typing import TYPE_CHECKING

import click

from colorama import Fore
from colorama import Style

from bootstrap.color import styled
from bootstrap.constant import EFA_APP_ROOT
from bootstrap.constant import PROJECT_ROOT


if TYPE_CHECKING:
    from collections.abc import Callable
    from pathlib import Path

    from bootstrap.config import ProjectVersion
    from bootstrap.remote.channel import Channel


@dataclass(frozen=True)
class VersionTarget:
    path: Path
    description: str
    render: Callable[[ProjectVersion, Channel], str]
    pattern: re.Pattern[str]
    replacement: Callable[[re.Match[str], str], str]


class VersionTargetMissingError(click.ClickException):
    """Raised when a version sync target has no matching version line."""

    def __init__(self, target: VersionTarget) -> None:
        self.target = target
        super().__init__(f"{target.description}: no version line found in {target.path}")


def _render_pubspec(version: ProjectVersion, track: Channel) -> str:
    return version.render_full(track)


def _render_triplet(version: ProjectVersion, track: Channel) -> str:
    return version.render_triplet(track)


def _pubspec_replacement(match: re.Match[str], new_value: str) -> str:
    return f"{match.group(1)}{new_value}"


def _toml_replacement(match: re.Match[str], new_value: str) -> str:
    return f"{match.group(1)}{new_value}{match.group(2)}"


TARGETS = [
    VersionTarget(
        path=EFA_APP_ROOT / "pubspec.yaml",
        description="apps/eve-fit-assistant/pubspec.yaml",
        render=_render_pubspec,
        pattern=re.compile(r"^(version:\s*).+$", re.MULTILINE),
        replacement=_pubspec_replacement,
    ),
    VersionTarget(
        path=EFA_APP_ROOT / "rust" / "Cargo.toml",
        description="apps/eve-fit-assistant/rust/Cargo.toml",
        render=_render_triplet,
        pattern=re.compile(r'^(version\s*=\s*")[^"]+(")', re.MULTILINE),
        replacement=_toml_replacement,
    ),
    VersionTarget(
        path=PROJECT_ROOT / "pyproject.toml",
        description="pyproject.toml",
        render=_render_triplet,
        pattern=re.compile(r'^(version\s*=\s*")[^"]+(")', re.MULTILINE),
        replacement=_toml_replacement,
    ),
]


def _validate_target(target: VersionTarget) -> None:
    content = target.path.read_text(encoding="utf-8")
    if not target.pattern.search(content):
        raise VersionTargetMissingError(target)


def _sync_target(
    target: VersionTarget, version: ProjectVersion, track: Channel, dry_run: bool
) -> bool:
    content = target.path.read_text(encoding="utf-8")
    match = target.pattern.search(content)
    if not match:
        raise VersionTargetMissingError(target)

    new_value = target.render(version, track)
    new_content = target.pattern.sub(lambda m: target.replacement(m, new_value), content, count=1)

    if new_content == content:
        click.echo(
            f"  {styled([Style.BRIGHT, Fore.GREEN], 'OK')} {target.description}: {new_value}"
        )
        return False

    if dry_run:
        click.echo(
            f"  {styled([Style.BRIGHT, Fore.CYAN], '[DRY-RUN]')} {target.description}: {new_value}"
        )
        return True

    target.path.write_text(new_content, encoding="utf-8")
    click.echo(
        f"  {styled([Style.BRIGHT, Fore.GREEN], 'UPDATED')} {target.description}: {new_value}"
    )
    return True


def sync_versions(version: ProjectVersion, track: Channel, *, dry_run: bool = False) -> int:
    for target in TARGETS:
        _validate_target(target)

    changed = 0
    for target in TARGETS:
        if _sync_target(target, version, track, dry_run):
            changed += 1
    return changed


def sync_target(
    path: Path, version: ProjectVersion, track: Channel, *, dry_run: bool = False
) -> bool:
    for target in TARGETS:
        if target.path == path:
            return _sync_target(target, version, track, dry_run)
    raise ValueError(f"No version sync target registered for {path}")
