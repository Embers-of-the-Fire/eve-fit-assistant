from __future__ import annotations

from typing import TYPE_CHECKING
from unittest.mock import patch

import click
import pytest
import yaml

from bootstrap.config import ProjectVersion
from bootstrap.release import relnote


if TYPE_CHECKING:
    from pathlib import Path


@pytest.fixture
def version() -> ProjectVersion:
    return ProjectVersion(major=0, minor=2, patch=0, pre_label="beta", pre_num=1)


@pytest.fixture
def isolated_changelog_root(tmp_path: Path) -> Path:
    root = tmp_path / "changelog"
    root.mkdir(parents=True)
    return root


def _write_cliff_stub(tmp_path: Path) -> Path:
    stub = tmp_path / "git-cliff"
    stub.write_text(
        '#!/bin/sh\necho "## [v0.2.0-beta.1] - 2026-07-04\\n\\n### Added\\n\\n- stub"\n',
        encoding="utf-8",
    )
    stub.chmod(0o755)
    return stub


def test_create_raw_release_note_writes_spec_and_changelog(
    tmp_path: Path,
    version: ProjectVersion,
    isolated_changelog_root: Path,
) -> None:
    stub = _write_cliff_stub(tmp_path)

    with (
        patch.object(relnote, "CHANGELOG_ROOT", isolated_changelog_root),
        patch("bootstrap.release.relnote.get_command", return_value=str(stub)),
    ):
        directory, entry_id = relnote.create_raw_release_note(version)

    assert directory == isolated_changelog_root / "0-2-0-beta-1"
    assert entry_id == "version-0-2-0-beta-1"
    assert directory.is_dir()

    spec_path = directory / "spec.yaml"
    changelog_path = directory / "changelog.md"
    assert spec_path.exists()
    assert changelog_path.exists()
    assert not (directory / "content.zh.md").exists()
    assert not (directory / "content.en.md").exists()

    spec = yaml.safe_load(spec_path.read_text(encoding="utf-8"))
    assert spec["id"] == "version-0-2-0-beta-1"
    assert spec["appVersion"] == "0.2.0-beta.1"
    assert spec["tags"] == ["release-note"]
    assert spec["channels"] == ["testing"]
    assert "platforms" not in spec
    assert "publishedAt" in spec

    changelog = changelog_path.read_text(encoding="utf-8")
    assert "## [v0.2.0-beta.1]" in changelog


def test_create_raw_release_note_custom_channels_and_platforms(
    tmp_path: Path,
    version: ProjectVersion,
    isolated_changelog_root: Path,
) -> None:
    stub = _write_cliff_stub(tmp_path)

    with (
        patch.object(relnote, "CHANGELOG_ROOT", isolated_changelog_root),
        patch("bootstrap.release.relnote.get_command", return_value=str(stub)),
    ):
        relnote.create_raw_release_note(
            version,
            channels=["stable"],
            platforms=["ios"],
        )

    spec = yaml.safe_load((isolated_changelog_root / "0-2-0-beta-1" / "spec.yaml").read_text())
    assert spec["channels"] == ["stable"]
    assert spec["platforms"] == ["ios"]


def test_create_raw_release_note_rejects_invalid_platforms(
    tmp_path: Path,
    version: ProjectVersion,
    isolated_changelog_root: Path,
) -> None:
    stub = _write_cliff_stub(tmp_path)

    with (
        pytest.raises(click.ClickException, match="Invalid platform"),
        patch.object(relnote, "CHANGELOG_ROOT", isolated_changelog_root),
        patch("bootstrap.release.relnote.get_command", return_value=str(stub)),
    ):
        relnote.create_raw_release_note(version, platforms=["ios", "fuchsiaos"])

    assert not (isolated_changelog_root / "0-2-0-beta-1").exists()


def test_create_raw_release_note_refuses_overwrite(
    tmp_path: Path,
    version: ProjectVersion,
    isolated_changelog_root: Path,
) -> None:
    directory = isolated_changelog_root / "0-2-0-beta-1"
    directory.mkdir()
    (directory / "existing.txt").write_text("keep", encoding="utf-8")

    with (
        pytest.raises(click.ClickException),
        patch.object(relnote, "CHANGELOG_ROOT", isolated_changelog_root),
    ):
        relnote.create_raw_release_note(version)


def test_create_raw_release_note_force_overwrites(
    tmp_path: Path,
    version: ProjectVersion,
    isolated_changelog_root: Path,
) -> None:
    directory = isolated_changelog_root / "0-2-0-beta-1"
    directory.mkdir()
    (directory / "existing.txt").write_text("keep", encoding="utf-8")

    stub = _write_cliff_stub(tmp_path)
    with (
        patch.object(relnote, "CHANGELOG_ROOT", isolated_changelog_root),
        patch("bootstrap.release.relnote.get_command", return_value=str(stub)),
    ):
        relnote.create_raw_release_note(version, force=True)

    assert not (directory / "existing.txt").exists()
    assert (directory / "spec.yaml").exists()


def test_create_raw_release_note_dry_run_does_not_write(
    tmp_path: Path,
    version: ProjectVersion,
    isolated_changelog_root: Path,
) -> None:
    stub = _write_cliff_stub(tmp_path)

    with (
        patch.object(relnote, "CHANGELOG_ROOT", isolated_changelog_root),
        patch("bootstrap.release.relnote.get_command", return_value=str(stub)),
    ):
        directory, entry_id = relnote.create_raw_release_note(version, dry_run=True)

    assert directory == isolated_changelog_root / "0-2-0-beta-1"
    assert entry_id == "version-0-2-0-beta-1"
    assert not directory.exists()


def test_create_raw_release_note_dry_run_force_preserves_existing(
    version: ProjectVersion,
    isolated_changelog_root: Path,
) -> None:
    directory = isolated_changelog_root / "0-2-0-beta-1"
    directory.mkdir()
    existing = directory / "existing.txt"
    existing.write_text("keep", encoding="utf-8")

    with patch.object(relnote, "CHANGELOG_ROOT", isolated_changelog_root):
        returned_directory, entry_id = relnote.create_raw_release_note(
            version, dry_run=True, force=True
        )

    assert returned_directory == directory
    assert entry_id == "version-0-2-0-beta-1"
    assert directory.is_dir()
    assert existing.read_text(encoding="utf-8") == "keep"
    assert not (directory / "spec.yaml").exists()
    assert not (directory / "changelog.md").exists()


def test_version_dir_to_entry_id() -> None:
    assert relnote.version_dir_to_entry_id("0.2.0") == "version-0-2-0"
    assert relnote.version_dir_to_entry_id("0.2.0-beta.1") == "version-0-2-0-beta-1"


def test_run_cliff_passes_from_ref_as_range() -> None:
    captured_cmd: list[str] = []

    def _mock_run(cmd, **_kw):
        captured_cmd.extend(cmd)
        import subprocess

        result = subprocess.CompletedProcess(cmd, 0, "## [v0.3.0]\n", "")
        return result

    with (
        patch("bootstrap.release.relnote.get_command", return_value="/usr/bin/git-cliff"),
        patch("bootstrap.release.relnote.subprocess.run", side_effect=_mock_run),
    ):
        result = relnote._run_cliff("v0.3.0", from_ref="v0.2.0")

    assert captured_cmd[-1] == "v0.2.0..HEAD"
    assert "--unreleased" not in captured_cmd
    assert result == "## [v0.3.0]\n"


def test_create_raw_release_note_with_from_ref(
    tmp_path: Path,
    version: ProjectVersion,
    isolated_changelog_root: Path,
) -> None:
    stub = _write_cliff_stub(tmp_path)

    with (
        patch.object(relnote, "CHANGELOG_ROOT", isolated_changelog_root),
        patch("bootstrap.release.relnote.get_command", return_value=str(stub)),
    ):
        directory, _ = relnote.create_raw_release_note(
            version,
            from_ref="v0.1.0",
        )

    spec = yaml.safe_load(
        (directory / "spec.yaml").read_text(encoding="utf-8"),
    )
    assert spec["fromRef"] == "v0.1.0"
    assert spec["appVersion"] == "0.2.0-beta.1"
    assert directory.is_dir()


def test_create_raw_release_note_with_from_ref_dry_run(
    version: ProjectVersion,
    isolated_changelog_root: Path,
) -> None:
    directory = isolated_changelog_root / "0-2-0-beta-1"

    with patch.object(relnote, "CHANGELOG_ROOT", isolated_changelog_root):
        returned_directory, entry_id = relnote.create_raw_release_note(
            version,
            dry_run=True,
            from_ref="v0.1.0",
        )

    assert returned_directory == directory
    assert entry_id == "version-0-2-0-beta-1"
    assert not directory.exists()
