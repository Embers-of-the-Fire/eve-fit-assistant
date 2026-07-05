from __future__ import annotations

from typing import TYPE_CHECKING

import pytest

from bootstrap.docs.bundled_docs import BundledEntry
from bootstrap.docs.bundled_docs import LocalizedDocument
from bootstrap.docs.bundled_docs import _compose_release_body
from bootstrap.docs.bundled_docs import _load_release_note


if TYPE_CHECKING:
    from pathlib import Path


def _make_changelog_dir(tmp_path: Path, version_dir_name: str) -> Path:
    directory = tmp_path / "changelog" / version_dir_name
    directory.mkdir(parents=True)
    return directory


def _write_spec(
    directory: Path,
    app_version: str,
    extra: str = "",
    entry_id: str | None = None,
) -> None:
    id_line = f"id: {entry_id}\n" if entry_id is not None else ""
    spec_content = f"""\
{id_line}publishedAt: 2026-01-01T00:00:00Z
appVersion: {app_version}
{extra}"""
    (directory / "spec.yaml").write_text(spec_content, encoding="utf-8")


def _write_content(directory: Path, locale: str, content: str) -> None:
    (directory / f"content.{locale}.md").write_text(content, encoding="utf-8")


def _write_changelog(directory: Path, content: str) -> None:
    (directory / "changelog.md").write_text(content, encoding="utf-8")


class TestLoadReleaseNote:
    def test_valid_release_note(self, tmp_path: Path) -> None:
        directory = _make_changelog_dir(tmp_path, "1.0.0")
        _write_spec(directory, "1.0.0")
        _write_content(
            directory,
            "zh",
            "# 版本 1.0.0\n\n这是第一个正式版本。\n",
        )
        _write_content(
            directory,
            "en",
            "# Version 1.0.0\n\nThis is the first stable release.\n",
        )
        _write_changelog(directory, "- Fixed bugs\n- Added features\n")

        entry = _load_release_note("1.0.0", directory)

        assert isinstance(entry, BundledEntry)
        assert entry.id == "version-1-0-0"
        assert entry.metadata.id == "version-1-0-0"
        assert entry.metadata.app_version == "1.0.0"
        assert entry.metadata.tags == ["release-note"]
        assert set(entry.localizations) == {"zh", "en"}

        zh = entry.localizations["zh"]
        assert isinstance(zh, LocalizedDocument)
        assert zh.locale == "zh"
        assert zh.title == "版本 1.0.0"
        assert zh.summary == "这是第一个正式版本。"
        assert "## Changelog" in zh.body_markdown
        assert "- Fixed bugs" in zh.body_markdown

        en = entry.localizations["en"]
        assert en.title == "Version 1.0.0"
        assert en.summary == "This is the first stable release."

    def test_composed_body_contains_human_and_changelog(self, tmp_path: Path) -> None:
        directory = _make_changelog_dir(tmp_path, "1.1.0")
        _write_spec(directory, "1.1.0")
        _write_content(
            directory,
            "en",
            "# Version 1.1.0\n\nHuman prose paragraph.\n",
        )
        _write_content(
            directory,
            "zh",
            "# 版本 1.1.0\n\n人工撰写的段落。\n",
        )
        _write_changelog(directory, "- Changelog item\n")

        entry = _load_release_note("1.1.0", directory)

        en_body = entry.localizations["en"].body_markdown
        assert "Human prose paragraph." in en_body
        assert "## Changelog" in en_body
        assert "- Changelog item" in en_body

        zh_body = entry.localizations["zh"].body_markdown
        assert "人工撰写的段落。" in zh_body
        assert "## Changelog" in zh_body
        assert "- Changelog item" in zh_body

    def test_title_and_summary_come_from_content_file(self, tmp_path: Path) -> None:
        directory = _make_changelog_dir(tmp_path, "1.2.0")
        _write_spec(directory, "1.2.0")
        _write_content(
            directory,
            "en",
            "# Real Title\n\nReal summary for users.\n",
        )
        _write_content(
            directory,
            "zh",
            "# 真实标题\n\n面向用户的真实摘要。\n",
        )
        _write_changelog(directory, "# Changelog Title\n\n- Technical fix\n")

        entry = _load_release_note("1.2.0", directory)

        assert entry.localizations["en"].title == "Real Title"
        assert entry.localizations["en"].summary == "Real summary for users."
        assert entry.localizations["zh"].title == "真实标题"
        assert entry.localizations["zh"].summary == "面向用户的真实摘要。"

    def test_changelog_tags_default(self, tmp_path: Path) -> None:
        directory = _make_changelog_dir(tmp_path, "1.3.0")
        _write_spec(directory, "1.3.0")
        _write_content(directory, "en", "# Title\n\nBody.\n")
        _write_content(directory, "zh", "# 标题\n\n正文。\n")
        _write_changelog(directory, "- Fix\n")

        entry = _load_release_note("1.3.0", directory)

        assert entry.metadata.tags == ["release-note"]

    def test_missing_content_zh_raises(self, tmp_path: Path) -> None:
        directory = _make_changelog_dir(tmp_path, "1.4.0")
        _write_spec(directory, "1.4.0")
        _write_content(directory, "en", "# Title\n\nBody.\n")
        _write_changelog(directory, "- Fix\n")

        with pytest.raises(ValueError, match="Missing required locale file"):
            _load_release_note("1.4.0", directory)

    def test_missing_content_en_raises(self, tmp_path: Path) -> None:
        directory = _make_changelog_dir(tmp_path, "1.5.0")
        _write_spec(directory, "1.5.0")
        _write_content(directory, "zh", "# 标题\n\n正文。\n")
        _write_changelog(directory, "- Fix\n")

        with pytest.raises(ValueError, match="Missing required locale file"):
            _load_release_note("1.5.0", directory)

    def test_missing_changelog_raises(self, tmp_path: Path) -> None:
        directory = _make_changelog_dir(tmp_path, "1.6.0")
        _write_spec(directory, "1.6.0")
        _write_content(directory, "en", "# Title\n\nBody.\n")
        _write_content(directory, "zh", "# 标题\n\n正文。\n")

        with pytest.raises(ValueError, match="Missing required changelog file"):
            _load_release_note("1.6.0", directory)

    def test_missing_app_version_raises(self, tmp_path: Path) -> None:
        directory = _make_changelog_dir(tmp_path, "1.7.0")
        spec_content = "publishedAt: 2026-01-01T00:00:00Z\n"
        (directory / "spec.yaml").write_text(spec_content, encoding="utf-8")
        _write_content(directory, "en", "# Title\n\nBody.\n")
        _write_content(directory, "zh", "# 标题\n\n正文。\n")
        _write_changelog(directory, "- Fix\n")

        with pytest.raises(ValueError, match="appVersion"):
            _load_release_note("1.7.0", directory)

    def test_version_dir_normalization_id(self, tmp_path: Path) -> None:
        directory = _make_changelog_dir(tmp_path, "0.1.0-beta.6")
        _write_spec(directory, "0.1.0-beta.6")
        _write_content(directory, "en", "# Title\n\nBody.\n")
        _write_content(directory, "zh", "# 标题\n\n正文。\n")
        _write_changelog(directory, "- Fix\n")

        entry = _load_release_note("0.1.0-beta.6", directory)

        assert entry.id == "version-0-1-0-beta-6"

    def test_empty_composed_body_raises(self, tmp_path: Path) -> None:
        directory = _make_changelog_dir(tmp_path, "1.8.0")
        _write_spec(directory, "1.8.0")
        _write_content(directory, "en", "# Title\n")
        _write_content(directory, "zh", "# 标题\n")
        _write_changelog(directory, "")

        with pytest.raises(ValueError):
            _load_release_note("1.8.0", directory)


class TestComposeReleaseBody:
    def test_composes_human_and_changelog(self) -> None:
        body = _compose_release_body("Human body.\n", "- Fix A\n- Fix B\n")

        assert body.startswith("Human body.")
        assert "## Changelog" in body
        assert "- Fix A" in body
        assert body.endswith("\n")

    def test_empty_inputs_keep_heading(self) -> None:
        body = _compose_release_body("", "")

        assert body == "## Changelog\n"
