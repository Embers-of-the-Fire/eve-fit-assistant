"""Tests for ./x remote announce add-release-note."""

from __future__ import annotations

from typing import TYPE_CHECKING

import click
import pytest

from click.testing import CliRunner

from bootstrap.cli.remote.announce import _compose_release_body
from bootstrap.cli.remote.announce import _load_spec_or_defaults
from bootstrap.config import ProjectVersion
from bootstrap.docs.announcements_remote import ACTIVE_KEY
from bootstrap.docs.announcements_remote import AnnouncementWorkspace
from bootstrap.docs.document_parser import parse_locale_document
from bootstrap.release.relnote import parse_version_override
from bootstrap.release.relnote import split_csv
from bootstrap.utils import normalize_version_dir
from bootstrap.utils import version_dir_to_entry_id


if TYPE_CHECKING:
    from pathlib import Path


def _make_release_note_dir(
    tmp_path: Path,
    version_dir_name: str,
    *,
    app_version: str,
    zh_body: str,
    en_body: str,
    changelog: str,
    published_at: str = "2026-07-04T00:00:00Z",
    extra_spec: str = "",
) -> Path:
    directory = tmp_path / "changelog" / version_dir_name
    directory.mkdir(parents=True)
    spec_content = f"publishedAt: {published_at}\nappVersion: {app_version!r}\n{extra_spec}"
    (directory / "spec.yaml").write_text(spec_content, encoding="utf-8")
    (directory / "content.zh.md").write_text(zh_body, encoding="utf-8")
    (directory / "content.en.md").write_text(en_body, encoding="utf-8")
    (directory / "changelog.md").write_text(changelog, encoding="utf-8")
    return directory


def _build_workspace(tmp_path: Path) -> AnnouncementWorkspace:
    workspace_root = tmp_path / "announce-workspace"
    workspace = AnnouncementWorkspace(workspace_root)
    workspace.ensure_remote_directories()
    return workspace


def _write_empty_remote_state(workspace: AnnouncementWorkspace) -> None:
    from datetime import UTC
    from datetime import datetime

    from bootstrap.docs.announcements_remote import AnnouncementCatalog
    from bootstrap.docs.announcements_remote import AnnouncementCatalogPage
    from bootstrap.docs.announcements_remote import AnnouncementPage

    now = datetime.now(UTC).isoformat().replace("+00:00", "Z")
    page_uuid = "00000000-0000-0000-0000-000000000001"
    catalog = AnnouncementCatalog(
        schema_version=1,
        pages=[
            AnnouncementCatalogPage(
                uuid=page_uuid,
                published_at=now,
                min_app_version="0.0.0",
                channels=[],
                count=0,
                active=True,
            )
        ],
    )
    page = AnnouncementPage(
        uuid=page_uuid,
        published_at=now,
        max_entries=50,
        entries=[],
    )
    workspace._write_catalog(workspace.remote_dir, catalog)
    workspace._write_active(workspace.remote_dir, page)


class TestHelpers:
    def test_normalize_version_dir(self) -> None:
        assert normalize_version_dir("0.1.0-beta.7") == "0-1-0-beta-7"
        assert normalize_version_dir("1.0.0") == "1-0-0"

    def test_version_dir_to_entry_id(self) -> None:
        assert version_dir_to_entry_id("0.1.0-beta.7") == "version-0-1-0-beta-7"
        assert version_dir_to_entry_id("1.0.0") == "version-1-0-0"

    def test_parse_version(self) -> None:
        parsed = parse_version_override("0.1.0-beta.7")
        assert parsed == {
            "major": 0,
            "minor": 1,
            "patch": 0,
            "pre_label": "beta",
            "pre_num": 7,
        }

    def test_parse_version_without_pre_num(self) -> None:
        parsed = parse_version_override("0.1.0-beta")
        assert parsed["pre_label"] == "beta"
        assert parsed["pre_num"] == 1

    def test_parse_version_invalid(self) -> None:
        with pytest.raises(click.ClickException):
            parse_version_override("not-a-version")

    def test_split_csv(self) -> None:
        assert split_csv("a, b, c") == ["a", "b", "c"]
        assert split_csv(None) is None
        assert split_csv("  ") == []

    def test_load_spec_or_defaults(self, tmp_path: Path) -> None:
        directory = tmp_path / "rel"
        directory.mkdir()
        (directory / "spec.yaml").write_text(
            "publishedAt: '2026-07-04T00:00:00Z'\nappVersion: 0.1.0\n",
            encoding="utf-8",
        )
        spec = _load_spec_or_defaults(directory)
        assert spec["publishedAt"] == "2026-07-04T00:00:00Z"
        assert spec["appVersion"] == "0.1.0"

    def test_load_spec_missing_returns_empty(self, tmp_path: Path) -> None:
        directory = tmp_path / "rel"
        directory.mkdir()
        assert _load_spec_or_defaults(directory) == {}

    def test_compose_release_body(self) -> None:
        body = _compose_release_body("Human body.\n", "- Fix A\n- Fix B\n")
        assert body.startswith("Human body.")
        assert "\n---\n" in body
        assert "- Fix A" in body
        assert body.endswith("\n")


class TestAddReleaseNote:
    def test_stages_release_note_entry(self, tmp_path: Path) -> None:
        import bootstrap.config

        bootstrap.config.ProjectConfiguration.ensure_loaded()
        from bootstrap.cli.remote.announce import register_remote_announce

        directory = _make_release_note_dir(
            tmp_path,
            "0-1-0-beta-7",
            app_version="0.1.0-beta.7",
            zh_body="# v0.1.0-beta.7 发布说明\n\n本次更新包含以下改动。\n\n- 新增功能 A\n",
            en_body="# v0.1.0-beta.7 Release Notes\n\nThis release includes the changes below.\n\n- Feature A\n",
            changelog="## [v0.1.0-beta.7] - 2026-07-04\n\n### Added\n\n- Feature A\n",
        )
        workspace = _build_workspace(tmp_path)
        _write_empty_remote_state(workspace)

        version = ProjectVersion(major=0, minor=1, patch=0, pre_label="beta", pre_num=7)

        with pytest.MonkeyPatch.context() as mp:
            mp.setattr(
                "bootstrap.cli.remote.announce.get_announce_workspace",
                lambda: tmp_path / "announce-workspace",
            )
            mp.setattr("bootstrap.config.CONFIGURATION.version", version)

            group = click.Group()
            register_remote_announce(group)
            cmd = group.commands["announce"].commands["add-release-note"]
            result = CliRunner().invoke(
                cmd,
                [
                    f"--directory={directory}",
                ],
            )
            assert result.exit_code == 0

        overlay = workspace.read_overlay()
        assert ACTIVE_KEY in overlay.pages
        entry = overlay.pages[ACTIVE_KEY]["version-0-1-0-beta-7"]
        assert entry is not None
        assert entry.id == "version-0-1-0-beta-7"
        assert entry.app_version == "0.1.0-beta.7"
        assert entry.tags == ["release-note"]
        assert entry.channels == ["testing"]
        assert entry.platforms == ["android", "ios"]

        zh = entry.localizations["zh"]
        en = entry.localizations["en"]
        assert zh.title == "v0.1.0-beta.7 发布说明"
        assert en.title == "v0.1.0-beta.7 Release Notes"
        assert "Feature A" in workspace.get_document(en.body_hash)
        assert "---" in workspace.get_document(en.body_hash)

    def test_uses_spec_channels_and_platforms(self, tmp_path: Path) -> None:
        import bootstrap.config

        bootstrap.config.ProjectConfiguration.ensure_loaded()
        from bootstrap.cli.remote.announce import register_remote_announce

        directory = _make_release_note_dir(
            tmp_path,
            "1-0-0",
            app_version="1.0.0",
            zh_body="# 标题\n\n摘要。\n",
            en_body="# Title\n\nSummary.\n",
            changelog="- Fix\n",
            extra_spec="channels:\n- stable\nplatforms:\n- ios\n",
        )
        workspace = _build_workspace(tmp_path)
        _write_empty_remote_state(workspace)

        version = ProjectVersion(major=1, minor=0, patch=0)

        with pytest.MonkeyPatch.context() as mp:
            mp.setattr(
                "bootstrap.cli.remote.announce.get_announce_workspace",
                lambda: tmp_path / "announce-workspace",
            )
            mp.setattr("bootstrap.config.CONFIGURATION.version", version)

            group = click.Group()
            register_remote_announce(group)
            cmd = group.commands["announce"].commands["add-release-note"]
            result = CliRunner().invoke(cmd, [f"--directory={directory}"])
            assert result.exit_code == 0

        overlay = workspace.read_overlay()
        entry = overlay.pages[ACTIVE_KEY]["version-1-0-0"]
        assert entry.channels == ["stable"]
        assert entry.platforms == ["ios"]

    def test_uses_spec_tags(self, tmp_path: Path) -> None:
        import bootstrap.config

        bootstrap.config.ProjectConfiguration.ensure_loaded()
        from bootstrap.cli.remote.announce import register_remote_announce

        directory = _make_release_note_dir(
            tmp_path,
            "1-0-0",
            app_version="1.0.0",
            zh_body="# 标题\n\n摘要。\n",
            en_body="# Title\n\nSummary.\n",
            changelog="- Fix\n",
            extra_spec="tags:\n- custom-tag\n",
        )
        workspace = _build_workspace(tmp_path)
        _write_empty_remote_state(workspace)

        version = ProjectVersion(major=1, minor=0, patch=0)

        with pytest.MonkeyPatch.context() as mp:
            mp.setattr(
                "bootstrap.cli.remote.announce.get_announce_workspace",
                lambda: tmp_path / "announce-workspace",
            )
            mp.setattr("bootstrap.config.CONFIGURATION.version", version)

            group = click.Group()
            register_remote_announce(group)
            cmd = group.commands["announce"].commands["add-release-note"]
            result = CliRunner().invoke(cmd, [f"--directory={directory}"])
            assert result.exit_code == 0

        overlay = workspace.read_overlay()
        entry = overlay.pages[ACTIVE_KEY]["version-1-0-0"]
        assert entry.tags == ["custom-tag"]

    def test_cli_overrides_take_precedence(self, tmp_path: Path) -> None:
        import bootstrap.config

        bootstrap.config.ProjectConfiguration.ensure_loaded()
        from bootstrap.cli.remote.announce import register_remote_announce

        directory = _make_release_note_dir(
            tmp_path,
            "1-0-0",
            app_version="1.0.0",
            zh_body="# 标题\n\n摘要。\n",
            en_body="# Title\n\nSummary.\n",
            changelog="- Fix\n",
            extra_spec="channels:\n- stable\n",
        )
        workspace = _build_workspace(tmp_path)
        _write_empty_remote_state(workspace)

        version = ProjectVersion(major=1, minor=0, patch=0)

        with pytest.MonkeyPatch.context() as mp:
            mp.setattr(
                "bootstrap.cli.remote.announce.get_announce_workspace",
                lambda: tmp_path / "announce-workspace",
            )
            mp.setattr("bootstrap.config.CONFIGURATION.version", version)

            group = click.Group()
            register_remote_announce(group)
            cmd = group.commands["announce"].commands["add-release-note"]
            result = CliRunner().invoke(
                cmd,
                [
                    f"--directory={directory}",
                    "--channels=testing,stable",
                    "--platforms=ios",
                    "--published-at=2026-01-01T00:00:00Z",
                    "--tags=version",
                ],
            )
            assert result.exit_code == 0

        overlay = workspace.read_overlay()
        entry = overlay.pages[ACTIVE_KEY]["version-1-0-0"]
        assert entry.channels == ["testing", "stable"]
        assert entry.platforms == ["ios"]
        assert entry.published_at == "2026-01-01T00:00:00Z"
        assert entry.tags == ["version"]

    def test_missing_changelog_fails(self, tmp_path: Path) -> None:
        import bootstrap.config

        bootstrap.config.ProjectConfiguration.ensure_loaded()
        from bootstrap.cli.remote.announce import register_remote_announce

        directory = _make_release_note_dir(
            tmp_path,
            "1-0-0",
            app_version="1.0.0",
            zh_body="# 标题\n\n摘要。\n",
            en_body="# Title\n\nSummary.\n",
            changelog="- Fix\n",
        )
        (directory / "changelog.md").unlink()
        workspace = _build_workspace(tmp_path)
        _write_empty_remote_state(workspace)

        version = ProjectVersion(major=1, minor=0, patch=0)

        with pytest.MonkeyPatch.context() as mp:
            mp.setattr(
                "bootstrap.cli.remote.announce.get_announce_workspace",
                lambda: tmp_path / "announce-workspace",
            )
            mp.setattr("bootstrap.config.CONFIGURATION.version", version)

            group = click.Group()
            register_remote_announce(group)
            cmd = group.commands["announce"].commands["add-release-note"]
            result = CliRunner().invoke(cmd, [f"--directory={directory}"])
            assert result.exit_code != 0
            assert "release relnote" in result.output

    def test_missing_content_locale_fails(self, tmp_path: Path) -> None:
        import bootstrap.config

        bootstrap.config.ProjectConfiguration.ensure_loaded()
        from bootstrap.cli.remote.announce import register_remote_announce

        directory = _make_release_note_dir(
            tmp_path,
            "1-0-0",
            app_version="1.0.0",
            zh_body="# 标题\n\n摘要。\n",
            en_body="# Title\n\nSummary.\n",
            changelog="- Fix\n",
        )
        (directory / "content.zh.md").unlink()
        workspace = _build_workspace(tmp_path)
        _write_empty_remote_state(workspace)

        version = ProjectVersion(major=1, minor=0, patch=0)

        with pytest.MonkeyPatch.context() as mp:
            mp.setattr(
                "bootstrap.cli.remote.announce.get_announce_workspace",
                lambda: tmp_path / "announce-workspace",
            )
            mp.setattr("bootstrap.config.CONFIGURATION.version", version)

            group = click.Group()
            register_remote_announce(group)
            cmd = group.commands["announce"].commands["add-release-note"]
            result = CliRunner().invoke(cmd, [f"--directory={directory}"])
            assert result.exit_code != 0
            assert "Missing required locale file" in result.output

    def test_duplicate_entry_fails(self, tmp_path: Path) -> None:
        import bootstrap.config

        bootstrap.config.ProjectConfiguration.ensure_loaded()
        from bootstrap.cli.remote.announce import register_remote_announce

        directory = _make_release_note_dir(
            tmp_path,
            "1-0-0",
            app_version="1.0.0",
            zh_body="# 标题\n\n摘要。\n",
            en_body="# Title\n\nSummary.\n",
            changelog="- Fix\n",
        )
        workspace = _build_workspace(tmp_path)
        _write_empty_remote_state(workspace)

        version = ProjectVersion(major=1, minor=0, patch=0)

        with pytest.MonkeyPatch.context() as mp:
            mp.setattr(
                "bootstrap.cli.remote.announce.get_announce_workspace",
                lambda: tmp_path / "announce-workspace",
            )
            mp.setattr("bootstrap.config.CONFIGURATION.version", version)

            group = click.Group()
            register_remote_announce(group)
            cmd = group.commands["announce"].commands["add-release-note"]
            result = CliRunner().invoke(cmd, [f"--directory={directory}"])
            assert result.exit_code == 0

            result = CliRunner().invoke(cmd, [f"--directory={directory}"])
            assert result.exit_code != 0
            assert "already exists" in result.output

    def test_spec_id_mismatch_fails(self, tmp_path: Path) -> None:
        import bootstrap.config

        bootstrap.config.ProjectConfiguration.ensure_loaded()
        from bootstrap.cli.remote.announce import register_remote_announce

        directory = _make_release_note_dir(
            tmp_path,
            "1-0-0",
            app_version="1.0.0",
            zh_body="# 标题\n\n摘要。\n",
            en_body="# Title\n\nSummary.\n",
            changelog="- Fix\n",
            extra_spec="id: version-wrong\n",
        )
        workspace = _build_workspace(tmp_path)
        _write_empty_remote_state(workspace)

        version = ProjectVersion(major=1, minor=0, patch=0)

        with pytest.MonkeyPatch.context() as mp:
            mp.setattr(
                "bootstrap.cli.remote.announce.get_announce_workspace",
                lambda: tmp_path / "announce-workspace",
            )
            mp.setattr("bootstrap.config.CONFIGURATION.version", version)

            group = click.Group()
            register_remote_announce(group)
            cmd = group.commands["announce"].commands["add-release-note"]
            result = CliRunner().invoke(cmd, [f"--directory={directory}"])
            assert result.exit_code != 0
            assert "does not match expected id" in result.output


class TestDocumentParser:
    def test_extracts_title_and_summary(self, tmp_path: Path) -> None:
        path = tmp_path / "doc.md"
        path.write_text(
            "# Real Title\n\nReal summary for users.\n\n- List item\n",
            encoding="utf-8",
        )
        parsed = parse_locale_document(path, "en")
        assert parsed.title == "Real Title"
        assert parsed.summary == "Real summary for users."

    def test_missing_heading_raises(self, tmp_path: Path) -> None:
        path = tmp_path / "doc.md"
        path.write_text("No heading here.\n", encoding="utf-8")
        with pytest.raises(ValueError, match="level-1 heading"):
            parse_locale_document(path, "en")

    def test_empty_body_raises(self, tmp_path: Path) -> None:
        path = tmp_path / "doc.md"
        path.write_text("# Title\n", encoding="utf-8")
        with pytest.raises(ValueError, match="no body"):
            parse_locale_document(path, "en")

    def test_no_summary_raises(self, tmp_path: Path) -> None:
        path = tmp_path / "doc.md"
        path.write_text("# Title\n\n- Only\n- Lists\n", encoding="utf-8")
        with pytest.raises(ValueError, match="usable summary paragraph"):
            parse_locale_document(path, "en")
