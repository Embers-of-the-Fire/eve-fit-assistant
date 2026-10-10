from __future__ import annotations

from typing import TYPE_CHECKING
from unittest.mock import patch

import pytest

from bootstrap.config import ProjectVersion
from bootstrap.config import StableTrackVersion
from bootstrap.config import TestingTrackVersion
from bootstrap.release import version_sync
from bootstrap.remote.channel import Channel


if TYPE_CHECKING:
    from pathlib import Path


@pytest.fixture
def version() -> ProjectVersion:
    return ProjectVersion(
        build=5,
        testing=TestingTrackVersion(major=1, minor=2, patch=3, num=4),
        stable=StableTrackVersion(major=1, minor=2, patch=2),
    )


@pytest.fixture
def track() -> Channel:
    return Channel.TESTING


@pytest.fixture
def isolated_targets(tmp_path: Path) -> tuple[list[version_sync.VersionTarget], Path, Path, Path]:
    pubspec = tmp_path / "pubspec.yaml"
    cargo = tmp_path / "Cargo.toml"
    pyproject = tmp_path / "pyproject.toml"

    pubspec.write_text("version: 0.0.0+0\n", encoding="utf-8")
    cargo.write_text('[package]\nversion = "0.0.0"\n', encoding="utf-8")
    pyproject.write_text('[project]\nversion = "0.0.0"\n', encoding="utf-8")

    targets = [
        version_sync.VersionTarget(
            path=pubspec,
            description="pubspec.yaml",
            render=version_sync._render_pubspec,
            pattern=version_sync.TARGETS[0].pattern,
            replacement=version_sync._pubspec_replacement,
        ),
        version_sync.VersionTarget(
            path=cargo,
            description="rust/Cargo.toml",
            render=version_sync._render_triplet,
            pattern=version_sync.TARGETS[1].pattern,
            replacement=version_sync._toml_replacement,
        ),
        version_sync.VersionTarget(
            path=pyproject,
            description="pyproject.toml",
            render=version_sync._render_triplet,
            pattern=version_sync.TARGETS[2].pattern,
            replacement=version_sync._toml_replacement,
        ),
    ]
    return targets, pubspec, cargo, pyproject


def test_sync_versions_updates_files(
    version: ProjectVersion,
    track: Channel,
    isolated_targets: tuple[list[version_sync.VersionTarget], Path, Path, Path],
) -> None:
    targets, pubspec, cargo, pyproject = isolated_targets

    with patch.object(version_sync, "TARGETS", targets):
        changed = version_sync.sync_versions(version, track, dry_run=False)

    assert changed == 3
    assert pubspec.read_text(encoding="utf-8") == "version: 1.2.3-beta.4+5\n"
    assert cargo.read_text(encoding="utf-8") == '[package]\nversion = "1.2.3"\n'
    assert pyproject.read_text(encoding="utf-8") == '[project]\nversion = "1.2.3"\n'


def test_sync_versions_stable_track(
    version: ProjectVersion,
    isolated_targets: tuple[list[version_sync.VersionTarget], Path, Path, Path],
) -> None:
    targets, pubspec, cargo, pyproject = isolated_targets

    with patch.object(version_sync, "TARGETS", targets):
        changed = version_sync.sync_versions(version, Channel.STABLE, dry_run=False)

    assert changed == 3
    assert pubspec.read_text(encoding="utf-8") == "version: 1.2.2+5\n"
    assert cargo.read_text(encoding="utf-8") == '[package]\nversion = "1.2.2"\n'
    assert pyproject.read_text(encoding="utf-8") == '[project]\nversion = "1.2.2"\n'


def test_sync_versions_dry_run_does_not_write(
    version: ProjectVersion,
    track: Channel,
    isolated_targets: tuple[list[version_sync.VersionTarget], Path, Path, Path],
) -> None:
    targets, pubspec, cargo, pyproject = isolated_targets

    with patch.object(version_sync, "TARGETS", targets):
        changed = version_sync.sync_versions(version, track, dry_run=True)

    assert changed == 3
    assert pubspec.read_text(encoding="utf-8") == "version: 0.0.0+0\n"
    assert cargo.read_text(encoding="utf-8") == '[package]\nversion = "0.0.0"\n'
    assert pyproject.read_text(encoding="utf-8") == '[project]\nversion = "0.0.0"\n'


def test_sync_versions_no_change_when_up_to_date(
    version: ProjectVersion,
    track: Channel,
    isolated_targets: tuple[list[version_sync.VersionTarget], Path, Path, Path],
) -> None:
    targets, pubspec, cargo, pyproject = isolated_targets

    pubspec.write_text("version: 1.2.3-beta.4+5\n", encoding="utf-8")
    cargo.write_text('[package]\nversion = "1.2.3"\n', encoding="utf-8")
    pyproject.write_text('[project]\nversion = "1.2.3"\n', encoding="utf-8")

    with patch.object(version_sync, "TARGETS", targets):
        changed = version_sync.sync_versions(version, track, dry_run=False)

    assert changed == 0


def test_sync_versions_raises_when_version_line_missing(
    version: ProjectVersion,
    track: Channel,
    isolated_targets: tuple[list[version_sync.VersionTarget], Path, Path, Path],
) -> None:
    targets, pubspec, _, _ = isolated_targets

    pubspec.write_text("description: no version field here\n", encoding="utf-8")

    with (
        patch.object(version_sync, "TARGETS", targets),
        pytest.raises(version_sync.VersionTargetMissingError) as exc_info,
    ):
        version_sync.sync_versions(version, track, dry_run=False)

    assert "pubspec.yaml" in str(exc_info.value)


def test_sync_target_raises_when_version_line_missing(
    version: ProjectVersion,
    track: Channel,
    isolated_targets: tuple[list[version_sync.VersionTarget], Path, Path, Path],
) -> None:
    targets, pubspec, _, _ = isolated_targets

    pubspec.write_text("description: no version field here\n", encoding="utf-8")

    with (
        patch.object(version_sync, "TARGETS", targets),
        pytest.raises(version_sync.VersionTargetMissingError) as exc_info,
    ):
        version_sync.sync_target(pubspec, version, track, dry_run=False)

    assert "pubspec.yaml" in str(exc_info.value)


def test_sync_versions_earlier_files_unchanged_when_later_target_missing(
    version: ProjectVersion,
    track: Channel,
    isolated_targets: tuple[list[version_sync.VersionTarget], Path, Path, Path],
) -> None:
    targets, pubspec, cargo, pyproject = isolated_targets

    pyproject.write_text("[project]\nname = 'no-version-here'\n", encoding="utf-8")

    with (
        patch.object(version_sync, "TARGETS", targets),
        pytest.raises(version_sync.VersionTargetMissingError),
    ):
        version_sync.sync_versions(version, track, dry_run=False)

    assert pubspec.read_text(encoding="utf-8") == "version: 0.0.0+0\n"
    assert cargo.read_text(encoding="utf-8") == '[package]\nversion = "0.0.0"\n'
    assert pyproject.read_text(encoding="utf-8") == "[project]\nname = 'no-version-here'\n"
