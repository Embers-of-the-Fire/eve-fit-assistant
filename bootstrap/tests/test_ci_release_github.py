"""Tests for the `x ci release github-release` command."""

from __future__ import annotations

from typing import TYPE_CHECKING

import click
import click.testing

from bootstrap.cli import register_all_commands


if TYPE_CHECKING:
    from pathlib import Path

    import pytest


def _make_notes(root: Path, version_str: str) -> Path:
    semver = version_str.split("+")[0]
    notes_dir = root / "docs" / "changelog" / semver.replace(".", "-")
    notes_dir.mkdir(parents=True, exist_ok=True)
    (notes_dir / "spec.yaml").write_text(
        "publishedAt: '2026-06-06T08:44:24Z'\n"
        "tags:\n- release-note\n"
        "channels:\n- testing\n"
        "platforms:\n- android\n"
        f"appVersion: {semver}\n",
        encoding="utf-8",
    )
    (notes_dir / "changelog.md").write_text(
        "## [v0.3.0-alpha.1] - 2026-07-01\n\n### Added\n\n- **feature:** new stuff\n",
        encoding="utf-8",
    )
    (notes_dir / "content.en.md").write_text(
        "# v0.3.0-alpha.1 Release Notes\n\nThis is a test release.\n\n- Item one\n",
        encoding="utf-8",
    )
    return notes_dir


def _make_apks(root: Path, version_str: str) -> Path:
    apk_dir = root / "cache" / "releases" / "apk" / version_str
    apk_dir.mkdir(parents=True, exist_ok=True)
    (apk_dir / f"{version_str}-android.apk").write_text("fake apk", encoding="utf-8")
    (apk_dir / f"{version_str}-android-arm64.apk").write_text("fake apk", encoding="utf-8")
    (apk_dir / f"{version_str}-android.apk.sha1").write_text("deadbeef", encoding="utf-8")
    (apk_dir / f"{version_str}-android-arm64.apk.sha1").write_text("deadbeef", encoding="utf-8")
    return apk_dir


def _invoke(root: Path, version_str: str, tag: str) -> click.testing.Result:
    @click.group()
    def cli() -> None:
        pass

    register_all_commands(cli)
    runner = click.testing.CliRunner()
    return runner.invoke(
        cli,
        [
            "ci",
            "release",
            "github-release",
            "--version",
            version_str,
            "--tag",
            tag,
            "--apk-dir",
            str(root / "cache" / "releases" / "apk"),
            "--dry-run",
        ],
    )


class TestGithubReleaseCommand:
    def test_dry_run_shows_command_with_assets(
        self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        version = "0.3.0-alpha.1+42"
        tag = "releases/v0.3.0-alpha.1"
        monkeypatch.setattr("bootstrap.ci.release_github.PROJECT_ROOT", tmp_path)
        _make_notes(tmp_path, version)
        _make_apks(tmp_path, version)

        result = _invoke(tmp_path, version, tag)

        assert result.exit_code == 0, result.output
        assert "[DRY-RUN]" in result.output
        assert "gh release create" in result.output
        assert tag in result.output
        assert "--title v0.3.0-alpha.1" in result.output
        assert "--prerelease" in result.output
        assert "0.3.0-alpha.1+42-android.apk" in result.output
        assert "0.3.0-alpha.1+42-android-arm64.apk" in result.output
        assert "0.3.0-alpha.1+42-android.apk.sha1" in result.output

    def test_dry_run_stable_release(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        version = "1.0.0"
        tag = "releases/v1.0.0"
        monkeypatch.setattr("bootstrap.ci.release_github.PROJECT_ROOT", tmp_path)
        semver = version.split("+")[0]
        notes_dir = tmp_path / "docs" / "changelog" / semver.replace(".", "-")
        notes_dir.mkdir(parents=True, exist_ok=True)
        (notes_dir / "spec.yaml").write_text(
            f"publishedAt: '2026-06-06T08:44:24Z'\nappVersion: {semver}\n",
            encoding="utf-8",
        )
        (notes_dir / "changelog.md").write_text(
            "## [v1.0.0]\n\nStable release.\n", encoding="utf-8"
        )
        (notes_dir / "content.en.md").write_text(
            "# v1.0.0\n\nFirst stable release.\n", encoding="utf-8"
        )
        apk_dir = tmp_path / "cache" / "releases" / "apk" / version
        apk_dir.mkdir(parents=True, exist_ok=True)
        (apk_dir / f"{version}-android.apk").write_text("fake", encoding="utf-8")

        result = _invoke(tmp_path, version, tag)

        assert result.exit_code == 0, result.output
        assert "--prerelease" not in result.output

    def test_fails_missing_content_en(
        self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        version = "0.3.0-alpha.1"
        tag = "releases/v0.3.0-alpha.1"
        monkeypatch.setattr("bootstrap.ci.release_github.PROJECT_ROOT", tmp_path)
        semver = version.split("+")[0]
        notes_dir = tmp_path / "docs" / "changelog" / semver.replace(".", "-")
        notes_dir.mkdir(parents=True, exist_ok=True)
        (notes_dir / "spec.yaml").write_text(
            f"publishedAt: '2026-06-06T08:44:24Z'\nappVersion: {semver}\n",
            encoding="utf-8",
        )
        (notes_dir / "changelog.md").write_text("## Changelog\n", encoding="utf-8")

        result = _invoke(tmp_path, version, tag)

        assert result.exit_code != 0
        assert "content.en.md is required" in result.output

    def test_fails_missing_apk_dir(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        version = "0.3.0-alpha.1+42"
        tag = "releases/v0.3.0-alpha.1"
        monkeypatch.setattr("bootstrap.ci.release_github.PROJECT_ROOT", tmp_path)
        _make_notes(tmp_path, version)

        result = _invoke(tmp_path, version, tag)

        assert result.exit_code != 0
        assert "APK directory not found" in result.output

    def test_fails_missing_changelog_dir(
        self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        version = "0.3.0-alpha.1+42"
        tag = "releases/v0.3.0-alpha.1"
        monkeypatch.setattr("bootstrap.ci.release_github.PROJECT_ROOT", tmp_path)

        result = _invoke(tmp_path, version, tag)

        assert result.exit_code != 0
        assert "Changelog directory not found" in result.output
