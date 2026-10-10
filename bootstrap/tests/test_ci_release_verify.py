"""Tests for the `x ci release verify` command."""

from __future__ import annotations

import tempfile

from pathlib import Path

import click
import click.testing
import pytest

from bootstrap.ci.release import _check_note_content
from bootstrap.ci.release import _check_notes
from bootstrap.ci.release import _check_submodules
from bootstrap.ci.release import _check_tag_does_not_exist
from bootstrap.ci.release import _load_version_from_config
from bootstrap.ci.release import _normalize_version_for_notes
from bootstrap.ci.release import _read_pubspec_version
from bootstrap.ci.release import _read_toml_version
from bootstrap.ci.release import classify_release_intent
from bootstrap.cli import register_all_commands
from bootstrap.config import ProjectVersion
from bootstrap.config import StableTrackVersion
from bootstrap.config import TestingTrackVersion
from bootstrap.config import semver_precedence_key
from bootstrap.remote.channel import Channel


def _make_version(
    testing: tuple[int, int, int, int] = (0, 1, 0, 2),
    stable: tuple[int, int, int] = (0, 0, 0),
    build: int = 0,
) -> ProjectVersion:
    return ProjectVersion(
        build=build,
        testing=TestingTrackVersion(
            major=testing[0], minor=testing[1], patch=testing[2], num=testing[3]
        ),
        stable=StableTrackVersion(major=stable[0], minor=stable[1], patch=stable[2]),
    )


def _write_config(root: Path, version: dict[str, object]) -> None:
    lines = ["[version]"]
    groups: dict[str, dict[str, object]] = {}
    for key, value in version.items():
        if isinstance(value, dict):
            groups[key] = value
        elif isinstance(value, str):
            lines.append(f'{key} = "{value}"')
        else:
            lines.append(f"{key} = {value}")
    for group, fields in groups.items():
        lines.append(f"[version.{group}]")
        for key, value in fields.items():
            if isinstance(value, str):
                lines.append(f'{key} = "{value}"')
            else:
                lines.append(f"{key} = {value}")
    (root / "efa.config.toml").write_text("\n".join(lines) + "\n", encoding="utf-8")


APP_DIR = Path("apps") / "eve-fit-assistant"


def _write_pubspec(root: Path, version: str) -> None:
    (root / APP_DIR).mkdir(parents=True, exist_ok=True)
    (root / APP_DIR / "pubspec.yaml").write_text(f"version: {version}\n", encoding="utf-8")


def _write_cargo(root: Path, version: str) -> None:
    (root / APP_DIR / "rust").mkdir(parents=True, exist_ok=True)
    (root / APP_DIR / "rust" / "Cargo.toml").write_text(
        f'[package]\nname = "rust_lib_eve_fit_assistant"\nversion = "{version}"\n',
        encoding="utf-8",
    )


def _write_pyproject(root: Path, version: str) -> None:
    (root / "pyproject.toml").write_text(
        f'[project]\nname = "eve-fit-assistant"\nversion = "{version}"\n',
        encoding="utf-8",
    )


def _write_manifests(root: Path, version: ProjectVersion, track: Channel) -> None:
    _write_pubspec(root, version.render_full(track))
    _write_cargo(root, version.render_triplet(track))
    _write_pyproject(root, version.render_triplet(track))


def _make_notes(root: Path, version: ProjectVersion, track: Channel) -> None:
    normalized = _normalize_version_for_notes(version, track)
    notes_dir = root / "docs" / "changelog" / normalized
    notes_dir.mkdir(parents=True, exist_ok=True)
    (notes_dir / "spec.yaml").write_text("---\n", encoding="utf-8")
    (notes_dir / "changelog.md").write_text("# Changelog\n", encoding="utf-8")


def _make_release_note(root: Path, version: ProjectVersion, track: Channel) -> None:
    """Create a fully valid release note directory."""
    normalized = _normalize_version_for_notes(version, track)
    notes_dir = root / "docs" / "changelog" / normalized
    notes_dir.mkdir(parents=True, exist_ok=True)
    (notes_dir / "spec.yaml").write_text(
        f"publishedAt: '2026-06-06T08:44:24Z'\n"
        f"tags:\n- release-note\n"
        f"channels:\n- {track.value}\n"
        f"platforms:\n- android\n- ios\n"
        f"appVersion: {version.render_semver(track)}\n",
        encoding="utf-8",
    )
    (notes_dir / "changelog.md").write_text("## Changelog\n", encoding="utf-8")
    for locale in ("zh", "en"):
        (notes_dir / f"content.{locale}.md").write_text(
            f"# Release Note {locale.upper()}\n\n"
            f"This is the {locale} summary paragraph.\n\n"
            f"Additional body content.\n",
            encoding="utf-8",
        )


@pytest.fixture
def tmp_project() -> Path:
    d = Path(tempfile.mkdtemp(prefix="efa-release-verify-"))
    yield d
    import shutil

    shutil.rmtree(d, ignore_errors=True)


class TestSemverPrecedenceKey:
    def test_release_greater_than_prerelease(self) -> None:
        assert semver_precedence_key("1.0.0") > semver_precedence_key("1.0.0-beta.1")

    def test_prerelease_numeric_comparison(self) -> None:
        assert semver_precedence_key("1.0.0-beta.2") > semver_precedence_key("1.0.0-beta.1")

    def test_core_version_comparison(self) -> None:
        assert semver_precedence_key("1.0.0") > semver_precedence_key("0.9.9")

    def test_testing_rollover_outranks_stable(self) -> None:
        assert semver_precedence_key("1.7.0-beta.0") > semver_precedence_key("1.6.5")

    def test_build_metadata_ignored(self) -> None:
        assert semver_precedence_key("1.0.0+1") == semver_precedence_key("1.0.0+2")
        assert semver_precedence_key("1.0.0-beta.1+9") == semver_precedence_key("1.0.0-beta.1")

    def test_equal_versions_not_greater(self) -> None:
        assert not semver_precedence_key("1.0.0-beta.2") > semver_precedence_key("1.0.0-beta.2")

    def test_invalid_core_raises(self) -> None:
        with pytest.raises(ValueError, match="Invalid semver core"):
            semver_precedence_key("1.0")


class TestClassifyReleaseIntent:
    def test_r6_unchanged_is_none(self) -> None:
        base = _make_version()
        head = _make_version()
        intent = classify_release_intent(base, head)
        assert intent.action == "none"
        assert intent.track is None
        assert intent.version is None
        assert "R6" in intent.reason

    def test_r1_testing_bump(self) -> None:
        base = _make_version(testing=(1, 0, 0, 1), build=4)
        head = _make_version(testing=(1, 0, 0, 2), build=5)
        intent = classify_release_intent(base, head)
        assert intent.action == "testing"
        assert intent.track == Channel.TESTING
        assert intent.version is not None
        assert intent.version.semver == "1.0.0-beta.2"
        assert "R1" in intent.reason

    def test_r1_testing_decrease_rejected(self) -> None:
        base = _make_version(testing=(1, 0, 0, 2))
        head = _make_version(testing=(1, 0, 0, 1))
        with pytest.raises(click.ClickException, match="did not increase"):
            classify_release_intent(base, head)

    def test_r2_testing_rebase_without_num_is_none(self) -> None:
        base = _make_version(testing=(1, 0, 0, 2))
        head = _make_version(testing=(1, 1, 0, 0))
        intent = classify_release_intent(base, head)
        assert intent.action == "none"
        assert "R2" in intent.reason

    def test_r3_ship_commit(self) -> None:
        base = _make_version(testing=(1, 2, 3, 4), stable=(1, 2, 2), build=7)
        head = _make_version(testing=(1, 3, 0, 0), stable=(1, 2, 3), build=8)
        intent = classify_release_intent(base, head)
        assert intent.action == "stable"
        assert intent.track == Channel.STABLE
        assert intent.version is not None
        assert intent.version.semver == "1.2.3"
        assert "R3" in intent.reason

    def test_r3_ship_commit_triplet_mismatch_rejected(self) -> None:
        base = _make_version(testing=(1, 2, 3, 4), stable=(1, 2, 2))
        head = _make_version(testing=(1, 3, 0, 0), stable=(1, 2, 4))
        with pytest.raises(click.ClickException, match="ship commit"):
            classify_release_intent(base, head)

    def test_r4_mainline_stable_change_rejected(self) -> None:
        base = _make_version(testing=(1, 2, 3, 4), stable=(1, 2, 2))
        head = _make_version(testing=(1, 2, 3, 4), stable=(1, 2, 3))
        with pytest.raises(click.ClickException, match="R4"):
            classify_release_intent(base, head)

    def test_r4_backport_patch_increment_accepted(self) -> None:
        base = _make_version(testing=(1, 2, 3, 4), stable=(1, 2, 2), build=7)
        head = _make_version(testing=(1, 2, 3, 4), stable=(1, 2, 3), build=8)
        intent = classify_release_intent(base, head, backport_branch=True)
        assert intent.action == "stable"
        assert intent.track == Channel.STABLE
        assert intent.version is not None
        assert intent.version.semver == "1.2.3"

    def test_r4_backport_touching_testing_rejected(self) -> None:
        base = _make_version(testing=(1, 2, 3, 4), stable=(1, 2, 2))
        head = _make_version(testing=(1, 2, 3, 5), stable=(1, 2, 3))
        with pytest.raises(click.ClickException, match="R4"):
            classify_release_intent(base, head, backport_branch=True)

    def test_r4_backport_major_minor_change_rejected(self) -> None:
        base = _make_version(testing=(1, 2, 3, 4), stable=(1, 2, 2))
        head = _make_version(testing=(1, 2, 3, 4), stable=(1, 3, 0))
        with pytest.raises(click.ClickException, match="major/minor"):
            classify_release_intent(base, head, backport_branch=True)

    def test_r4_backport_patch_not_increasing_rejected(self) -> None:
        base = _make_version(testing=(1, 2, 3, 4), stable=(1, 2, 2))
        head = _make_version(testing=(1, 2, 3, 4), stable=(1, 2, 2))
        # Same stable triplet means nothing changed; force a regression instead.
        head = _make_version(testing=(1, 2, 3, 4), stable=(1, 2, 1))
        with pytest.raises(click.ClickException, match="patch must increase"):
            classify_release_intent(base, head, backport_branch=True)

    def test_r5_both_changed_with_testing_num_rejected(self) -> None:
        base = _make_version(testing=(1, 2, 3, 4), stable=(1, 2, 2))
        head = _make_version(testing=(1, 2, 4, 1), stable=(1, 2, 3))
        with pytest.raises(click.ClickException, match="R5"):
            classify_release_intent(base, head)


class TestReadVersions:
    def test_read_pubspec_quoted(self, tmp_project: Path) -> None:
        (tmp_project / "pubspec.yaml").write_text('version: "1.2.3+4"\n', encoding="utf-8")
        assert _read_pubspec_version(tmp_project / "pubspec.yaml") == "1.2.3+4"

    def test_read_pubspec_unquoted(self, tmp_project: Path) -> None:
        (tmp_project / "pubspec.yaml").write_text("version: 1.2.3+4\n", encoding="utf-8")
        assert _read_pubspec_version(tmp_project / "pubspec.yaml") == "1.2.3+4"

    def test_read_pubspec_missing(self, tmp_project: Path) -> None:
        (tmp_project / "pubspec.yaml").write_text("name: foo\n", encoding="utf-8")
        with pytest.raises(click.ClickException, match="Missing 'version:'"):
            _read_pubspec_version(tmp_project / "pubspec.yaml")

    def test_read_toml_pyproject(self, tmp_project: Path) -> None:
        _write_pyproject(tmp_project, "1.2.3")
        assert _read_toml_version(tmp_project / "pyproject.toml") == "1.2.3"

    def test_read_toml_cargo(self, tmp_project: Path) -> None:
        _write_cargo(tmp_project, "1.2.3")
        assert _read_toml_version(tmp_project / APP_DIR / "rust" / "Cargo.toml") == "1.2.3"

    def test_read_toml_missing(self, tmp_project: Path) -> None:
        (tmp_project / "pyproject.toml").write_text('[project]\nname = "foo"\n', encoding="utf-8")
        with pytest.raises(click.ClickException, match="Missing 'version' key"):
            _read_toml_version(tmp_project / "pyproject.toml")


class TestCheckNotes:
    def test_notes_present(self, tmp_project: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        version = _make_version()
        _make_notes(tmp_project, version, Channel.TESTING)
        monkeypatch.setattr("bootstrap.ci.release.PROJECT_ROOT", tmp_project)
        _check_notes(version, Channel.TESTING)  # should not raise

    def test_notes_missing_directory(
        self, tmp_project: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        version = _make_version(testing=(0, 1, 0, 99))
        monkeypatch.setattr("bootstrap.ci.release.PROJECT_ROOT", tmp_project)
        with pytest.raises(click.ClickException, match="Changelog directory not found"):
            _check_notes(version, Channel.TESTING)

    def test_notes_missing_file(self, tmp_project: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        version = _make_version(testing=(0, 1, 0, 3))
        normalized = _normalize_version_for_notes(version, Channel.TESTING)
        notes_dir = tmp_project / "docs" / "changelog" / normalized
        notes_dir.mkdir(parents=True, exist_ok=True)
        (notes_dir / "spec.yaml").write_text("---\n", encoding="utf-8")
        monkeypatch.setattr("bootstrap.ci.release.PROJECT_ROOT", tmp_project)
        with pytest.raises(click.ClickException, match="Missing changelog files"):
            _check_notes(version, Channel.TESTING)


class TestLoadVersionFromConfig:
    def test_valid(self, tmp_project: Path) -> None:
        _write_config(
            tmp_project,
            {
                "build": 5,
                "testing": {"major": 1, "minor": 2, "patch": 3, "num": 4},
                "stable": {"major": 1, "minor": 2, "patch": 2},
            },
        )
        version = _load_version_from_config(tmp_project / "efa.config.toml")
        assert version.build == 5
        assert version.testing.major == 1
        assert version.testing.minor == 2
        assert version.testing.patch == 3
        assert version.testing.num == 4
        assert version.stable.major == 1
        assert version.stable.patch == 2

    def test_legacy_schema_migrates(self, tmp_project: Path) -> None:
        _write_config(
            tmp_project,
            {
                "major": 1,
                "minor": 2,
                "patch": 3,
                "pre_label": "beta",
                "pre_num": 4,
                "build": 5,
            },
        )
        version = _load_version_from_config(tmp_project / "efa.config.toml")
        assert version.build == 5
        assert version.testing.major == 1
        assert version.testing.minor == 2
        assert version.testing.patch == 3
        assert version.testing.num == 4
        assert (version.stable.major, version.stable.minor, version.stable.patch) == (0, 0, 0)

    def test_missing_file(self, tmp_project: Path) -> None:
        with pytest.raises(click.ClickException, match="Config file not found"):
            _load_version_from_config(tmp_project / "efa.config.toml")

    def test_invalid_version(self, tmp_project: Path) -> None:
        _write_config(
            tmp_project,
            {
                "testing": {"major": -1, "minor": 0, "patch": 0, "num": 1},
                "stable": {"major": 0, "minor": 0, "patch": 0},
            },
        )
        with pytest.raises(click.ClickException, match="Invalid version"):
            _load_version_from_config(tmp_project / "efa.config.toml")


class TestReleaseVerifyIntegration:
    def test_success(self, tmp_project: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        _write_config(
            tmp_project,
            {
                "testing": {"major": 0, "minor": 1, "patch": 0, "num": 2},
                "stable": {"major": 0, "minor": 0, "patch": 0},
            },
        )
        ver = _make_version()
        _write_manifests(tmp_project, ver, Channel.TESTING)
        _make_notes(tmp_project, ver, Channel.TESTING)

        monkeypatch.setattr("bootstrap.ci.release.PROJECT_ROOT", tmp_project)
        monkeypatch.setattr("bootstrap.ci.release.EFA_APP_ROOT", tmp_project / APP_DIR)

        @click.group()
        def cli():
            pass

        register_all_commands(cli)
        runner = click.testing.CliRunner()
        result = runner.invoke(
            cli, ["ci", "release", "verify", "--track", "testing", "--check-notes"]
        )
        assert result.exit_code == 0, result.output
        assert "Canonical version: 0.1.0-beta.2" in result.output
        assert "Semver version:    0.1.0-beta.2" in result.output
        assert "Expected tag: releases/v0.1.0-beta.2" in result.output

    def test_success_stable_track(self, tmp_project: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        _write_config(
            tmp_project,
            {
                "testing": {"major": 1, "minor": 1, "patch": 0, "num": 0},
                "stable": {"major": 1, "minor": 0, "patch": 0},
            },
        )
        ver = _make_version(testing=(1, 1, 0, 0), stable=(1, 0, 0))
        _write_manifests(tmp_project, ver, Channel.STABLE)
        _make_notes(tmp_project, ver, Channel.STABLE)

        monkeypatch.setattr("bootstrap.ci.release.PROJECT_ROOT", tmp_project)
        monkeypatch.setattr("bootstrap.ci.release.EFA_APP_ROOT", tmp_project / APP_DIR)

        @click.group()
        def cli():
            pass

        register_all_commands(cli)
        runner = click.testing.CliRunner()
        result = runner.invoke(
            cli, ["ci", "release", "verify", "--track", "stable", "--check-notes"]
        )
        assert result.exit_code == 0, result.output
        assert "Expected tag: releases/v1.0.0" in result.output

    def test_testing_track_with_num_zero_fails(
        self, tmp_project: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        _write_config(
            tmp_project,
            {
                "testing": {"major": 1, "minor": 1, "patch": 0, "num": 0},
                "stable": {"major": 1, "minor": 0, "patch": 0},
            },
        )
        ver = _make_version(testing=(1, 1, 0, 0), stable=(1, 0, 0))
        _write_manifests(tmp_project, ver, Channel.TESTING)

        monkeypatch.setattr("bootstrap.ci.release.PROJECT_ROOT", tmp_project)
        monkeypatch.setattr("bootstrap.ci.release.EFA_APP_ROOT", tmp_project / APP_DIR)

        @click.group()
        def cli():
            pass

        register_all_commands(cli)
        runner = click.testing.CliRunner()
        result = runner.invoke(cli, ["ci", "release", "verify", "--track", "testing"])
        assert result.exit_code != 0
        assert "I3 violated" in result.output

    def test_i1_track_order_violation_fails(
        self, tmp_project: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        _write_config(
            tmp_project,
            {
                "testing": {"major": 1, "minor": 0, "patch": 0, "num": 1},
                "stable": {"major": 1, "minor": 0, "patch": 0},
            },
        )
        ver = _make_version(testing=(1, 0, 0, 1), stable=(1, 0, 0))
        _write_manifests(tmp_project, ver, Channel.TESTING)

        monkeypatch.setattr("bootstrap.ci.release.PROJECT_ROOT", tmp_project)
        monkeypatch.setattr("bootstrap.ci.release.EFA_APP_ROOT", tmp_project / APP_DIR)

        @click.group()
        def cli():
            pass

        register_all_commands(cli)
        runner = click.testing.CliRunner()
        result = runner.invoke(cli, ["ci", "release", "verify", "--track", "testing"])
        assert result.exit_code != 0
        assert "I1 violated" in result.output

    def test_pubspec_mismatch(self, tmp_project: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        _write_config(
            tmp_project,
            {
                "testing": {"major": 0, "minor": 1, "patch": 0, "num": 2},
                "stable": {"major": 0, "minor": 0, "patch": 0},
            },
        )
        ver = _make_version()
        _write_pubspec(tmp_project, "0.0.0")
        _write_cargo(tmp_project, ver.render_triplet(Channel.TESTING))
        _write_pyproject(tmp_project, ver.render_triplet(Channel.TESTING))

        monkeypatch.setattr("bootstrap.ci.release.PROJECT_ROOT", tmp_project)
        monkeypatch.setattr("bootstrap.ci.release.EFA_APP_ROOT", tmp_project / APP_DIR)

        @click.group()
        def cli2():
            pass

        register_all_commands(cli2)
        runner = click.testing.CliRunner()
        result = runner.invoke(cli2, ["ci", "release", "verify", "--track", "testing"])
        assert result.exit_code != 0
        assert "Version mismatch" in result.output
        assert "pubspec.yaml" in result.output

    def test_base_ref_build_not_increased_fails(
        self, tmp_project: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        _write_config(
            tmp_project,
            {
                "build": 5,
                "testing": {"major": 0, "minor": 1, "patch": 0, "num": 3},
                "stable": {"major": 0, "minor": 0, "patch": 0},
            },
        )
        head = _make_version(testing=(0, 1, 0, 3), build=5)
        base = _make_version(testing=(0, 1, 0, 2), build=5)
        _write_manifests(tmp_project, head, Channel.TESTING)

        monkeypatch.setattr("bootstrap.ci.release.PROJECT_ROOT", tmp_project)
        monkeypatch.setattr("bootstrap.ci.release.EFA_APP_ROOT", tmp_project / APP_DIR)
        monkeypatch.setattr("bootstrap.ci.release._load_version_from_git_ref", lambda _ref: base)

        @click.group()
        def cli():
            pass

        register_all_commands(cli)
        runner = click.testing.CliRunner()
        result = runner.invoke(
            cli, ["ci", "release", "verify", "--track", "testing", "--base-ref", "HEAD~1"]
        )
        assert result.exit_code != 0
        assert "I2 violated" in result.output

    def test_base_ref_success(self, tmp_project: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        _write_config(
            tmp_project,
            {
                "build": 6,
                "testing": {"major": 0, "minor": 1, "patch": 0, "num": 3},
                "stable": {"major": 0, "minor": 0, "patch": 0},
            },
        )
        head = _make_version(testing=(0, 1, 0, 3), build=6)
        base = _make_version(testing=(0, 1, 0, 2), build=5)
        _write_manifests(tmp_project, head, Channel.TESTING)

        monkeypatch.setattr("bootstrap.ci.release.PROJECT_ROOT", tmp_project)
        monkeypatch.setattr("bootstrap.ci.release.EFA_APP_ROOT", tmp_project / APP_DIR)
        monkeypatch.setattr("bootstrap.ci.release._load_version_from_git_ref", lambda _ref: base)

        @click.group()
        def cli():
            pass

        register_all_commands(cli)
        runner = click.testing.CliRunner()
        result = runner.invoke(
            cli, ["ci", "release", "verify", "--track", "testing", "--base-ref", "HEAD~1"]
        )
        assert result.exit_code == 0, result.output
        assert "Release intent: testing" in result.output
        assert "Version check OK" in result.output

    def test_base_ref_track_mismatch_fails(
        self, tmp_project: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        _write_config(
            tmp_project,
            {
                "build": 6,
                "testing": {"major": 0, "minor": 1, "patch": 0, "num": 3},
                "stable": {"major": 0, "minor": 0, "patch": 0},
            },
        )
        head = _make_version(testing=(0, 1, 0, 3), build=6)
        base = _make_version(testing=(0, 1, 0, 2), build=5)
        _write_manifests(tmp_project, head, Channel.STABLE)

        monkeypatch.setattr("bootstrap.ci.release.PROJECT_ROOT", tmp_project)
        monkeypatch.setattr("bootstrap.ci.release.EFA_APP_ROOT", tmp_project / APP_DIR)
        monkeypatch.setattr("bootstrap.ci.release._load_version_from_git_ref", lambda _ref: base)

        @click.group()
        def cli():
            pass

        register_all_commands(cli)
        runner = click.testing.CliRunner()
        result = runner.invoke(
            cli, ["ci", "release", "verify", "--track", "stable", "--base-ref", "HEAD~1"]
        )
        assert result.exit_code != 0
        assert "Track mismatch" in result.output


class TestCheckTagDoesNotExist:
    def _mock_run_tag_missing(self, cmd, **kwargs):
        class Result:
            returncode = 1
            stdout = ""
            stderr = ""

        return Result()

    def _mock_run_tag_exists(self, cmd, **kwargs):
        class Result:
            returncode = 0
            stdout = "abc123\n"
            stderr = ""

        return Result()

    def test_tag_missing(self, tmp_project: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setattr("bootstrap.ci.release.subprocess.run", self._mock_run_tag_missing)
        monkeypatch.setattr("bootstrap.ci.release.PROJECT_ROOT", tmp_project)
        version = _make_version()
        _check_tag_does_not_exist(version, Channel.TESTING)  # should not raise

    def test_tag_exists(self, tmp_project: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setattr("bootstrap.ci.release.subprocess.run", self._mock_run_tag_exists)
        monkeypatch.setattr("bootstrap.ci.release.PROJECT_ROOT", tmp_project)
        version = _make_version()
        with pytest.raises(click.ClickException, match="already exists"):
            _check_tag_does_not_exist(version, Channel.TESTING)


class TestCheckNoteContent:
    def test_valid(self, tmp_project: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        version = _make_version()
        _make_release_note(tmp_project, version, Channel.TESTING)
        monkeypatch.setattr("bootstrap.ci.release.PROJECT_ROOT", tmp_project)
        _check_note_content(version, Channel.TESTING)  # should not raise

    def test_missing_content_file(self, tmp_project: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        version = _make_version()
        _make_release_note(tmp_project, version, Channel.TESTING)
        notes_dir = (
            tmp_project
            / "docs"
            / "changelog"
            / _normalize_version_for_notes(version, Channel.TESTING)
        )
        (notes_dir / "content.zh.md").unlink()
        monkeypatch.setattr("bootstrap.ci.release.PROJECT_ROOT", tmp_project)
        with pytest.raises(click.ClickException, match="Missing required locale file"):
            _check_note_content(version, Channel.TESTING)

    def test_invalid_spec(self, tmp_project: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        version = _make_version()
        _make_release_note(tmp_project, version, Channel.TESTING)
        notes_dir = (
            tmp_project
            / "docs"
            / "changelog"
            / _normalize_version_for_notes(version, Channel.TESTING)
        )
        (notes_dir / "spec.yaml").write_text("publishedAt: invalid\n", encoding="utf-8")
        monkeypatch.setattr("bootstrap.ci.release.PROJECT_ROOT", tmp_project)
        with pytest.raises(click.ClickException, match="invalid"):
            _check_note_content(version, Channel.TESTING)


class TestCheckSubmodules:
    def _mock_subprocess_run(
        self, expected_commit: str = "abc123def456", actual_commit: str | None = None
    ):
        if actual_commit is None:
            actual_commit = expected_commit

        def _fake_run(cmd, **kwargs):
            class Result:
                returncode = 0
                stdout = ""
                stderr = ""

            if "ls-tree" in cmd:
                Result.stdout = f"160000 commit {expected_commit}\n"
            elif "rev-parse" in cmd and "HEAD" in cmd:
                Result.stdout = f"{actual_commit}\n"
            return Result()

        return _fake_run

    def test_clean(self, tmp_project: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        for path in ("packages/eve-fit-os", "tools/eve-fsd-dumper"):
            (tmp_project / path).mkdir(parents=True, exist_ok=True)
            (tmp_project / path / ".git").mkdir()
        monkeypatch.setattr("bootstrap.ci.release.subprocess.run", self._mock_subprocess_run())
        monkeypatch.setattr("bootstrap.ci.release.PROJECT_ROOT", tmp_project)
        _check_submodules()  # should not raise

    def test_uninitialized(self, tmp_project: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setattr("bootstrap.ci.release.PROJECT_ROOT", tmp_project)
        with pytest.raises(click.ClickException, match="not initialized"):
            _check_submodules()

    def test_wrong_commit(self, tmp_project: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        for path in ("packages/eve-fit-os", "tools/eve-fsd-dumper"):
            (tmp_project / path).mkdir(parents=True, exist_ok=True)
            (tmp_project / path / ".git").mkdir()
        monkeypatch.setattr(
            "bootstrap.ci.release.subprocess.run",
            self._mock_subprocess_run("abc123def456", "000000000000"),
        )
        monkeypatch.setattr("bootstrap.ci.release.PROJECT_ROOT", tmp_project)
        with pytest.raises(click.ClickException, match="expected"):
            _check_submodules()

    def test_dirty(self, tmp_project: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        for path in ("packages/eve-fit-os", "tools/eve-fsd-dumper"):
            (tmp_project / path).mkdir(parents=True, exist_ok=True)
            (tmp_project / path / ".git").mkdir()

        def _fake_run(cmd, **kwargs):
            class Result:
                returncode = 0
                stdout = ""
                stderr = ""

            if "ls-tree" in cmd:
                Result.stdout = "160000 commit abc123def456\n"
            elif "rev-parse" in cmd and "HEAD" in cmd:
                Result.stdout = "abc123def456\n"
            elif "diff" in cmd and "--cached" in cmd:
                Result.returncode = 1  # staged changes
            return Result()

        monkeypatch.setattr("bootstrap.ci.release.subprocess.run", _fake_run)
        monkeypatch.setattr("bootstrap.ci.release.PROJECT_ROOT", tmp_project)
        with pytest.raises(click.ClickException, match="uncommitted"):
            _check_submodules()


class TestReleaseVerifyPreflightFlags:
    def _fake_execute(
        self,
        cmd: list,
        title: str,
        capture_stdout: bool = False,
        live_stdout: bool = False,
        cwd: Path | None = None,
    ) -> str:
        if not hasattr(self, "_execute_calls"):
            self._execute_calls = []
        self._execute_calls.append((cmd, title))
        return ""

    def _fake_get_command(self, cmd: str) -> Path:
        return Path(cmd)

    def _mock_subprocess_run(self, expected_commit: str = "abc123def456"):
        def _fake_run(cmd, **kwargs):
            class Result:
                returncode = 0
                stdout = ""
                stderr = ""

            cmd_str = " ".join(cmd)
            if "rev-parse" in cmd and "--verify" in cmd_str:
                # Tag does not exist
                Result.returncode = 1
            elif "ls-tree" in cmd:
                Result.stdout = f"160000 commit {expected_commit}\n"
            elif "rev-parse" in cmd and "HEAD" in cmd:
                Result.stdout = f"{expected_commit}\n"
            elif "git" in cmd and "diff" in cmd:
                Result.returncode = 0
            return Result()

        return _fake_run

    def _write_testing_project(self, tmp_project: Path) -> ProjectVersion:
        _write_config(
            tmp_project,
            {
                "testing": {"major": 0, "minor": 1, "patch": 0, "num": 2},
                "stable": {"major": 0, "minor": 0, "patch": 0},
            },
        )
        ver = _make_version()
        _write_manifests(tmp_project, ver, Channel.TESTING)
        return ver

    def test_check_tag_success(self, tmp_project: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        ver = self._write_testing_project(tmp_project)
        _make_notes(tmp_project, ver, Channel.TESTING)

        monkeypatch.setattr("bootstrap.ci.release.PROJECT_ROOT", tmp_project)
        monkeypatch.setattr("bootstrap.ci.release.EFA_APP_ROOT", tmp_project / APP_DIR)
        monkeypatch.setattr("bootstrap.ci.release.subprocess.run", self._mock_subprocess_run())

        @click.group()
        def cli():
            pass

        register_all_commands(cli)
        runner = click.testing.CliRunner()
        result = runner.invoke(
            cli, ["ci", "release", "verify", "--track", "testing", "--check-tag"]
        )
        assert result.exit_code == 0, result.output
        assert "Tag check OK" in result.output

    def test_check_note_content_success(
        self, tmp_project: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        ver = self._write_testing_project(tmp_project)
        _make_release_note(tmp_project, ver, Channel.TESTING)

        monkeypatch.setattr("bootstrap.ci.release.PROJECT_ROOT", tmp_project)
        monkeypatch.setattr("bootstrap.ci.release.EFA_APP_ROOT", tmp_project / APP_DIR)

        @click.group()
        def cli():
            pass

        register_all_commands(cli)
        runner = click.testing.CliRunner()
        result = runner.invoke(
            cli, ["ci", "release", "verify", "--track", "testing", "--check-note-content"]
        )
        assert result.exit_code == 0, result.output
        assert "Release note content OK" in result.output

    def test_check_all_success(self, tmp_project: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        ver = self._write_testing_project(tmp_project)
        _make_release_note(tmp_project, ver, Channel.TESTING)

        for path in ("packages/eve-fit-os", "tools/eve-fsd-dumper"):
            (tmp_project / path).mkdir(parents=True, exist_ok=True)
            (tmp_project / path / ".git").mkdir()

        # Create tracked generated files so _check_generated passes existence check.
        (tmp_project / "packages" / "efa_constant" / "lib").mkdir(parents=True, exist_ok=True)
        (
            tmp_project / "packages" / "efa_constant" / "lib" / "eve_dogma_unit_generated.dart"
        ).write_text("// generated\n", encoding="utf-8")
        (tmp_project / APP_DIR / "lib" / "storage" / "repo").mkdir(parents=True, exist_ok=True)
        (tmp_project / APP_DIR / "lib" / "storage" / "repo" / "repo_version.dart").write_text(
            "// generated\n", encoding="utf-8"
        )

        monkeypatch.setattr("bootstrap.ci.release.PROJECT_ROOT", tmp_project)
        monkeypatch.setattr("bootstrap.ci.release.EFA_APP_ROOT", tmp_project / APP_DIR)
        monkeypatch.setattr("bootstrap.ci.release.runtime.execute", self._fake_execute)
        monkeypatch.setattr("bootstrap.ci.release.subprocess.run", self._mock_subprocess_run())
        monkeypatch.setattr("bootstrap.utils.get_command", self._fake_get_command)

        @click.group()
        def cli():
            pass

        register_all_commands(cli)
        runner = click.testing.CliRunner()
        result = runner.invoke(
            cli, ["ci", "release", "verify", "--track", "testing", "--check-all"]
        )
        assert result.exit_code == 0, result.output
        assert "Tag check OK" in result.output
        assert "Release note content OK" in result.output
        assert "Submodule check OK" in result.output
        assert "Generated code OK" in result.output
        assert "Build check OK" in result.output
        assert "Tests OK" in result.output

        pub_get_calls = [call for call in self._execute_calls if call[1] == "FLUTTER PUB GET"]
        assert len(pub_get_calls) == 1, (
            "flutter pub get should run exactly once when both checks are enabled"
        )
