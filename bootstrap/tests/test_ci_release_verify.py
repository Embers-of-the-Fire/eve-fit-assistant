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
from bootstrap.ci.release import _version_greater_than
from bootstrap.ci.release import _version_key
from bootstrap.cli import register_all_commands
from bootstrap.config import ProjectVersion


def _write_config(root: Path, version: dict[str, object]) -> None:
    lines = ["[version]"]
    for key, value in version.items():
        if isinstance(value, str):
            lines.append(f'{key} = "{value}"')
        else:
            lines.append(f"{key} = {value}")
    (root / "efa.config.toml").write_text("\n".join(lines) + "\n", encoding="utf-8")


def _write_pubspec(root: Path, version: str) -> None:
    (root / "pubspec.yaml").write_text(f"version: {version}\n", encoding="utf-8")


def _write_cargo(root: Path, version: str) -> None:
    (root / "rust").mkdir(parents=True, exist_ok=True)
    (root / "rust" / "Cargo.toml").write_text(
        f'[package]\nname = "rust_lib_eve_fit_assistant"\nversion = "{version}"\n',
        encoding="utf-8",
    )


def _write_pyproject(root: Path, version: str) -> None:
    (root / "pyproject.toml").write_text(
        f'[project]\nname = "eve-fit-assistant"\nversion = "{version}"\n',
        encoding="utf-8",
    )


def _make_notes(root: Path, version: ProjectVersion) -> None:
    normalized = _normalize_version_for_notes(version)
    notes_dir = root / "docs" / "changelog" / normalized
    notes_dir.mkdir(parents=True, exist_ok=True)
    (notes_dir / "spec.yaml").write_text("---\n", encoding="utf-8")
    (notes_dir / "changelog.md").write_text("# Changelog\n", encoding="utf-8")


def _make_release_note(root: Path, version: ProjectVersion) -> None:
    """Create a fully valid release note directory."""
    normalized = _normalize_version_for_notes(version)
    notes_dir = root / "docs" / "changelog" / normalized
    notes_dir.mkdir(parents=True, exist_ok=True)
    (notes_dir / "spec.yaml").write_text(
        f"publishedAt: '2026-06-06T08:44:24Z'\n"
        f"tags:\n- release-note\n"
        f"channels:\n- testing\n"
        f"platforms:\n- android\n- ios\n"
        f"appVersion: {version.render_semver()}\n",
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


class TestVersionKey:
    def test_release_greater_than_prerelease(self) -> None:
        release = ProjectVersion(major=1, minor=0, patch=0)
        prerelease = ProjectVersion(major=1, minor=0, patch=0, pre_label="beta", pre_num=1)
        assert _version_key(release) > _version_key(prerelease)

    def test_prerelease_numeric_comparison(self) -> None:
        a = ProjectVersion(major=1, minor=0, patch=0, pre_label="beta", pre_num=2)
        b = ProjectVersion(major=1, minor=0, patch=0, pre_label="beta", pre_num=1)
        assert _version_key(a) > _version_key(b)

    def test_prerelease_label_comparison(self) -> None:
        alpha = ProjectVersion(major=1, minor=0, patch=0, pre_label="alpha", pre_num=1)
        beta = ProjectVersion(major=1, minor=0, patch=0, pre_label="beta", pre_num=1)
        assert _version_key(beta) > _version_key(alpha)

    def test_core_version_comparison(self) -> None:
        a = ProjectVersion(major=1, minor=0, patch=0)
        b = ProjectVersion(major=0, minor=9, patch=9)
        assert _version_key(a) > _version_key(b)


class TestVersionGreaterThan:
    def test_same_version_is_not_greater(self) -> None:
        v = ProjectVersion(major=0, minor=1, patch=0, pre_label="beta", pre_num=6)
        assert not _version_greater_than(v, v)

    def test_greater(self) -> None:
        current = ProjectVersion(major=0, minor=1, patch=0, pre_label="beta", pre_num=7)
        base = ProjectVersion(major=0, minor=1, patch=0, pre_label="beta", pre_num=6)
        assert _version_greater_than(current, base)

    def test_release_after_prerelease(self) -> None:
        current = ProjectVersion(major=0, minor=1, patch=0)
        base = ProjectVersion(major=0, minor=1, patch=0, pre_label="beta", pre_num=6)
        assert _version_greater_than(current, base)

    def test_lower(self) -> None:
        current = ProjectVersion(major=0, minor=1, patch=0, pre_label="beta", pre_num=5)
        base = ProjectVersion(major=0, minor=1, patch=0, pre_label="beta", pre_num=6)
        assert not _version_greater_than(current, base)


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
        assert _read_toml_version(tmp_project / "rust" / "Cargo.toml") == "1.2.3"

    def test_read_toml_missing(self, tmp_project: Path) -> None:
        (tmp_project / "pyproject.toml").write_text('[project]\nname = "foo"\n', encoding="utf-8")
        with pytest.raises(click.ClickException, match="Missing 'version' key"):
            _read_toml_version(tmp_project / "pyproject.toml")


class TestCheckNotes:
    def test_notes_present(self, tmp_project: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        version = ProjectVersion(major=0, minor=1, patch=0, pre_label="beta", pre_num=2)
        _make_notes(tmp_project, version)
        monkeypatch.setattr("bootstrap.ci.release.PROJECT_ROOT", tmp_project)
        _check_notes(version)  # should not raise

    def test_notes_missing_directory(
        self, tmp_project: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        version = ProjectVersion(major=0, minor=1, patch=0, pre_label="beta", pre_num=99)
        monkeypatch.setattr("bootstrap.ci.release.PROJECT_ROOT", tmp_project)
        with pytest.raises(click.ClickException, match="Changelog directory not found"):
            _check_notes(version)

    def test_notes_missing_file(self, tmp_project: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        version = ProjectVersion(major=0, minor=1, patch=0, pre_label="beta", pre_num=3)
        normalized = _normalize_version_for_notes(version)
        notes_dir = tmp_project / "docs" / "changelog" / normalized
        notes_dir.mkdir(parents=True, exist_ok=True)
        (notes_dir / "spec.yaml").write_text("---\n", encoding="utf-8")
        monkeypatch.setattr("bootstrap.ci.release.PROJECT_ROOT", tmp_project)
        with pytest.raises(click.ClickException, match="Missing changelog files"):
            _check_notes(version)


class TestLoadVersionFromConfig:
    def test_valid(self, tmp_project: Path) -> None:
        _write_config(tmp_project, {"major": 1, "minor": 2, "patch": 3})
        version = _load_version_from_config(tmp_project / "efa.config.toml")
        assert version.major == 1
        assert version.minor == 2
        assert version.patch == 3

    def test_missing_file(self, tmp_project: Path) -> None:
        with pytest.raises(click.ClickException, match="Config file not found"):
            _load_version_from_config(tmp_project / "efa.config.toml")

    def test_invalid_version(self, tmp_project: Path) -> None:
        _write_config(tmp_project, {"major": -1, "minor": 0, "patch": 0})
        with pytest.raises(click.ClickException, match="Invalid version"):
            _load_version_from_config(tmp_project / "efa.config.toml")


class TestReleaseVerifyIntegration:
    def test_success(self, tmp_project: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        version = {"major": 0, "minor": 1, "patch": 0, "pre_label": "beta", "pre_num": 2}
        _write_config(tmp_project, version)
        ver = ProjectVersion.model_validate(version)
        _write_pubspec(tmp_project, ver.render_full())
        _write_cargo(tmp_project, ver.render_semver())
        _write_pyproject(tmp_project, ver.render_semver())
        _make_notes(tmp_project, ver)

        monkeypatch.setattr("bootstrap.ci.release.PROJECT_ROOT", tmp_project)

        @click.group()
        def cli():
            pass

        register_all_commands(cli)
        runner = click.testing.CliRunner()
        result = runner.invoke(cli, ["ci", "release", "verify", "--check-notes"])
        assert result.exit_code == 0, result.output
        assert "Expected tag: v0.1.0-beta.2" in result.output

    def test_pubspec_mismatch(self, tmp_project: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        version = {"major": 0, "minor": 1, "patch": 0, "pre_label": "beta", "pre_num": 2}
        _write_config(tmp_project, version)
        ver = ProjectVersion.model_validate(version)
        _write_pubspec(tmp_project, "0.0.0")
        _write_cargo(tmp_project, ver.render_semver())
        _write_pyproject(tmp_project, ver.render_semver())

        monkeypatch.setattr("bootstrap.ci.release.PROJECT_ROOT", tmp_project)

        @click.group()
        def cli2():
            pass

        register_all_commands(cli2)
        runner = click.testing.CliRunner()
        result = runner.invoke(cli2, ["ci", "release", "verify"])
        assert result.exit_code != 0
        assert "Version mismatch" in result.output
        assert "pubspec.yaml" in result.output


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
        version = ProjectVersion(major=0, minor=1, patch=0, pre_label="beta", pre_num=2)
        _check_tag_does_not_exist(version)  # should not raise

    def test_tag_exists(self, tmp_project: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setattr("bootstrap.ci.release.subprocess.run", self._mock_run_tag_exists)
        monkeypatch.setattr("bootstrap.ci.release.PROJECT_ROOT", tmp_project)
        version = ProjectVersion(major=0, minor=1, patch=0, pre_label="beta", pre_num=2)
        with pytest.raises(click.ClickException, match="already exists"):
            _check_tag_does_not_exist(version)


class TestCheckNoteContent:
    def test_valid(self, tmp_project: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        version = ProjectVersion(major=0, minor=1, patch=0, pre_label="beta", pre_num=2)
        _make_release_note(tmp_project, version)
        monkeypatch.setattr("bootstrap.ci.release.PROJECT_ROOT", tmp_project)
        _check_note_content(version)  # should not raise

    def test_missing_content_file(self, tmp_project: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        version = ProjectVersion(major=0, minor=1, patch=0, pre_label="beta", pre_num=2)
        _make_release_note(tmp_project, version)
        notes_dir = tmp_project / "docs" / "changelog" / _normalize_version_for_notes(version)
        (notes_dir / "content.zh.md").unlink()
        monkeypatch.setattr("bootstrap.ci.release.PROJECT_ROOT", tmp_project)
        with pytest.raises(click.ClickException, match="Missing required locale file"):
            _check_note_content(version)

    def test_invalid_spec(self, tmp_project: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        version = ProjectVersion(major=0, minor=1, patch=0, pre_label="beta", pre_num=2)
        _make_release_note(tmp_project, version)
        notes_dir = tmp_project / "docs" / "changelog" / _normalize_version_for_notes(version)
        (notes_dir / "spec.yaml").write_text("publishedAt: invalid\n", encoding="utf-8")
        monkeypatch.setattr("bootstrap.ci.release.PROJECT_ROOT", tmp_project)
        with pytest.raises(click.ClickException, match="invalid"):
            _check_note_content(version)


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
        for path in ("rust/lib/eve-fit-os", "tools/eve-fsd-dumper"):
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
        for path in ("rust/lib/eve-fit-os", "tools/eve-fsd-dumper"):
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
        for path in ("rust/lib/eve-fit-os", "tools/eve-fsd-dumper"):
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
        self, cmd: list, title: str, capture_stdout: bool = False, live_stdout: bool = False
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

    def test_check_tag_success(self, tmp_project: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        version = {"major": 0, "minor": 1, "patch": 0, "pre_label": "beta", "pre_num": 2}
        _write_config(tmp_project, version)
        ver = ProjectVersion.model_validate(version)
        _write_pubspec(tmp_project, ver.render_full())
        _write_cargo(tmp_project, ver.render_semver())
        _write_pyproject(tmp_project, ver.render_semver())
        _make_notes(tmp_project, ver)

        monkeypatch.setattr("bootstrap.ci.release.PROJECT_ROOT", tmp_project)
        monkeypatch.setattr("bootstrap.ci.release.subprocess.run", self._mock_subprocess_run())

        @click.group()
        def cli():
            pass

        register_all_commands(cli)
        runner = click.testing.CliRunner()
        result = runner.invoke(cli, ["ci", "release", "verify", "--check-tag"])
        assert result.exit_code == 0, result.output
        assert "Tag check OK" in result.output

    def test_check_note_content_success(
        self, tmp_project: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        version = {"major": 0, "minor": 1, "patch": 0, "pre_label": "beta", "pre_num": 2}
        _write_config(tmp_project, version)
        ver = ProjectVersion.model_validate(version)
        _write_pubspec(tmp_project, ver.render_full())
        _write_cargo(tmp_project, ver.render_semver())
        _write_pyproject(tmp_project, ver.render_semver())
        _make_release_note(tmp_project, ver)

        monkeypatch.setattr("bootstrap.ci.release.PROJECT_ROOT", tmp_project)

        @click.group()
        def cli():
            pass

        register_all_commands(cli)
        runner = click.testing.CliRunner()
        result = runner.invoke(cli, ["ci", "release", "verify", "--check-note-content"])
        assert result.exit_code == 0, result.output
        assert "Release note content OK" in result.output

    def test_check_all_success(self, tmp_project: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        version = {"major": 0, "minor": 1, "patch": 0, "pre_label": "beta", "pre_num": 2}
        _write_config(tmp_project, version)
        ver = ProjectVersion.model_validate(version)
        _write_pubspec(tmp_project, ver.render_full())
        _write_cargo(tmp_project, ver.render_semver())
        _write_pyproject(tmp_project, ver.render_semver())
        _make_release_note(tmp_project, ver)

        for path in ("rust/lib/eve-fit-os", "tools/eve-fsd-dumper"):
            (tmp_project / path).mkdir(parents=True, exist_ok=True)
            (tmp_project / path / ".git").mkdir()

        # Create tracked generated files so _check_generated passes existence check.
        (tmp_project / "lib" / "constant").mkdir(parents=True, exist_ok=True)
        (tmp_project / "lib" / "constant" / "eve_dogma_unit_generated.dart").write_text(
            "// generated\n", encoding="utf-8"
        )
        (tmp_project / "lib" / "storage" / "repo").mkdir(parents=True, exist_ok=True)
        (tmp_project / "lib" / "storage" / "repo" / "repo_version.dart").write_text(
            "// generated\n", encoding="utf-8"
        )

        monkeypatch.setattr("bootstrap.ci.release.PROJECT_ROOT", tmp_project)
        monkeypatch.setattr("bootstrap.ci.release.runtime.execute", self._fake_execute)
        monkeypatch.setattr("bootstrap.ci.release.subprocess.run", self._mock_subprocess_run())
        monkeypatch.setattr("bootstrap.utils.get_command", self._fake_get_command)

        @click.group()
        def cli():
            pass

        register_all_commands(cli)
        runner = click.testing.CliRunner()
        result = runner.invoke(cli, ["ci", "release", "verify", "--check-all"])
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
