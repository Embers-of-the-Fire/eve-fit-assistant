from __future__ import annotations

import hashlib

from typing import TYPE_CHECKING

import pytest

from bootstrap.docs.bundled_docs import BundledEntry
from bootstrap.docs.bundled_docs import LocalizedDocument
from bootstrap.docs.bundled_docs import _load_general_announcement


if TYPE_CHECKING:
    from pathlib import Path


def _make_announcement_dir(tmp_path: Path, entry_id: str) -> Path:
    directory = tmp_path / "announcements" / entry_id
    directory.mkdir(parents=True)
    return directory


def _write_spec(directory: Path, entry_id: str, extra: str = "") -> None:
    spec_content = f"""\
id: {entry_id}
publishedAt: 2026-01-01T00:00:00Z
{extra}"""
    (directory / "spec.yaml").write_text(spec_content, encoding="utf-8")


def _write_locale(directory: Path, locale: str, content: str) -> None:
    (directory / f"{locale}.md").write_text(content, encoding="utf-8")


class TestLoadGeneralAnnouncement:
    def test_valid_general_announcement(self, tmp_path: Path) -> None:
        directory = _make_announcement_dir(tmp_path, "welcome")
        _write_spec(directory, "welcome")
        _write_locale(
            directory,
            "zh",
            "# 欢迎\n\n这是摘要。\n\n更多内容。\n",
        )
        _write_locale(
            directory,
            "en",
            "# Welcome\n\nThis is the summary.\n\nMore content.\n",
        )

        entry = _load_general_announcement("welcome", directory)

        assert isinstance(entry, BundledEntry)
        assert entry.id == "welcome"
        assert entry.metadata.id == "welcome"
        assert set(entry.localizations) == {"zh", "en"}

        zh = entry.localizations["zh"]
        assert isinstance(zh, LocalizedDocument)
        assert zh.locale == "zh"
        assert zh.title == "欢迎"
        assert zh.summary == "这是摘要。"
        assert zh.body_markdown == "这是摘要。\n\n更多内容。\n"

        en = entry.localizations["en"]
        assert en.title == "Welcome"
        assert en.summary == "This is the summary."
        assert en.body_markdown == "This is the summary.\n\nMore content.\n"

    def test_title_removed_from_body(self, tmp_path: Path) -> None:
        directory = _make_announcement_dir(tmp_path, "title-test")
        _write_spec(directory, "title-test")
        _write_locale(
            directory,
            "zh",
            "# Title\n\nBody after title.\n",
        )
        _write_locale(
            directory,
            "en",
            "# Title\n\nBody after title.\n",
        )

        entry = _load_general_announcement("title-test", directory)

        assert "# Title" not in entry.localizations["zh"].body_markdown
        assert "# Title" not in entry.localizations["en"].body_markdown

    def test_summary_from_first_paragraph(self, tmp_path: Path) -> None:
        directory = _make_announcement_dir(tmp_path, "multi-line")
        _write_spec(directory, "multi-line")
        _write_locale(
            directory,
            "en",
            "# Title\n\nLine one continues\nline two.\n\nMore content.\n",
        )
        _write_locale(directory, "zh", "# 标题\n\n第一行继续\n第二行。\n\n更多内容。\n")

        entry = _load_general_announcement("multi-line", directory)

        assert entry.localizations["en"].summary == "Line one continues line two."
        assert entry.localizations["zh"].summary == "第一行继续 第二行。"

    def test_missing_zh_raises(self, tmp_path: Path) -> None:
        directory = _make_announcement_dir(tmp_path, "missing-zh")
        _write_spec(directory, "missing-zh")
        _write_locale(directory, "en", "# Title\n\nBody.\n")

        with pytest.raises(ValueError, match="Missing required locale file"):
            _load_general_announcement("missing-zh", directory)

    def test_missing_en_raises(self, tmp_path: Path) -> None:
        directory = _make_announcement_dir(tmp_path, "missing-en")
        _write_spec(directory, "missing-en")
        _write_locale(directory, "zh", "# 标题\n\n正文。\n")

        with pytest.raises(ValueError, match="Missing required locale file"):
            _load_general_announcement("missing-en", directory)

    def test_missing_title_raises(self, tmp_path: Path) -> None:
        directory = _make_announcement_dir(tmp_path, "no-title")
        _write_spec(directory, "no-title")
        _write_locale(directory, "zh", "No heading here.\n")
        _write_locale(directory, "en", "No heading here.\n")

        with pytest.raises(ValueError, match="level-1 heading"):
            _load_general_announcement("no-title", directory)

    def test_empty_body_after_title_raises(self, tmp_path: Path) -> None:
        directory = _make_announcement_dir(tmp_path, "empty-body")
        _write_spec(directory, "empty-body")
        _write_locale(directory, "zh", "# 标题\n")
        _write_locale(directory, "en", "# Title\n")

        with pytest.raises(ValueError, match="no body"):
            _load_general_announcement("empty-body", directory)

    def test_no_usable_summary_raises(self, tmp_path: Path) -> None:
        directory = _make_announcement_dir(tmp_path, "no-summary")
        _write_spec(directory, "no-summary")
        _write_locale(
            directory,
            "en",
            "# Title\n\n- List item\n- Another\n\n```code\nblock\n```\n",
        )
        _write_locale(directory, "zh", "# 标题\n\n- 列表项\n- 另一个\n\n```代码\n块\n```\n")

        with pytest.raises(ValueError, match="no usable summary"):
            _load_general_announcement("no-summary", directory)

    def test_body_hash_matches_sha256(self, tmp_path: Path) -> None:
        directory = _make_announcement_dir(tmp_path, "hash-test")
        _write_spec(directory, "hash-test")
        _write_locale(directory, "en", "# Title\n\nBody text.\n")
        _write_locale(directory, "zh", "# 标题\n\n正文。\n")

        entry = _load_general_announcement("hash-test", directory)

        for locale in ("zh", "en"):
            document = entry.localizations[locale]
            expected = hashlib.sha256(document.body_markdown.encode("utf-8")).hexdigest()
            assert document.body_hash == expected

    def test_id_mismatch_raises(self, tmp_path: Path) -> None:
        directory = _make_announcement_dir(tmp_path, "mismatch")
        _write_spec(directory, "different-id")
        _write_locale(directory, "zh", "# 标题\n\n正文。\n")
        _write_locale(directory, "en", "# Title\n\nBody.\n")

        with pytest.raises(ValueError, match="does not match directory"):
            _load_general_announcement("mismatch", directory)
