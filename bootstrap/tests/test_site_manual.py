from __future__ import annotations

import json

from typing import TYPE_CHECKING
from unittest.mock import patch

import pytest

from bootstrap.docs import bundled_docs
from bootstrap.docs import manual as manual_builder
from bootstrap.docs import site_manual
from bootstrap.docs.site_manual import ManualTargets
from bootstrap.docs.site_manual import _rewrite_links
from bootstrap.docs.site_manual import build_site_manual


if TYPE_CHECKING:
    from pathlib import Path


def _write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def _make_doc(directory: Path, *, zh: str | None = None, en: str | None = None) -> None:
    doc_id = directory.name
    zh_body = zh if zh is not None else f"# {doc_id} 标题\n\n这是 {doc_id} 的摘要段落。\n\n正文。\n"
    en_body = (
        en if en is not None else f"# {doc_id} Title\n\nSummary paragraph for {doc_id}.\n\nBody.\n"
    )
    _write(directory / "zh.md", zh_body)
    _write(directory / "en.md", en_body)


def _make_folder(directory: Path, *, children: list[str]) -> None:
    folder_id = directory.name
    children_block = "children:\n" + "".join(f"  - {child}\n" for child in children)
    _write(
        directory / "folder.yaml",
        f"id: {folder_id}\nname:\n  zh: {folder_id} 名称\n  en: {folder_id} Name\n{children_block}",
    )


def _make_manual_tree(root: Path) -> None:
    _write(root / "folder.yaml", "children:\n  - guides\n")
    _make_folder(root / "guides", children=["intro", "advanced"])
    _make_doc(
        root / "guides" / "intro",
        en=(
            "# Intro\n\nIntro summary.\n\n"
            "See [Advanced](efa://manual/guides/advanced) and "
            "[the folder](efa://manual/guides).\n"
        ),
        zh=(
            "# 介绍\n\n介绍摘要。\n\n"
            "参见[进阶](efa://manual/guides/advanced)和[章节](efa://manual/guides)。\n"
        ),
    )
    _make_doc(root / "guides" / "advanced")


def _make_changelog(root: Path) -> None:
    for version, published_at, app_version in (
        ("0-1-0", "2026-01-01T00:00:00Z", "0.1.0"),
        ("0-2-0", "2026-03-01T00:00:00Z", "0.2.0"),
    ):
        entry = root / version
        _write(
            entry / "spec.yaml",
            f"publishedAt: '{published_at}'\nappVersion: {app_version}\n",
        )
        _write(entry / "changelog.md", f"## [v{app_version}] - {published_at[:10]}\n\n- change\n")
        _write(
            entry / "content.en.md", f"# v{app_version} Release Notes\n\nNotes summary.\n\n- item\n"
        )
        _write(entry / "content.zh.md", f"# v{app_version} 发布说明\n\n说明摘要。\n\n- 条目\n")


def _make_announcement(root: Path) -> None:
    entry = root / "welcome"
    _write(entry / "spec.yaml", "id: welcome\npublishedAt: '2026-02-01T00:00:00Z'\n")
    _write(entry / "en.md", "# Welcome\n\nWelcome summary.\n\nHello.\n")
    _write(entry / "zh.md", "# 欢迎\n\n欢迎摘要。\n\n你好。\n")


@pytest.fixture
def site_paths(tmp_path: Path):
    manual_root = tmp_path / "docs" / "manual"
    changelog_root = tmp_path / "docs" / "changelog"
    announcements_root = tmp_path / "docs" / "announcements"
    docs_root = tmp_path / "site" / "src" / "content" / "docs"
    generated_root = tmp_path / "site" / "src" / "generated"

    _make_manual_tree(manual_root)
    _make_changelog(changelog_root)
    _make_announcement(announcements_root)

    with (
        patch.object(manual_builder, "MANUAL_SOURCE_ROOT", manual_root),
        patch.object(bundled_docs, "CHANGELOG_SOURCE_ROOT", changelog_root),
        patch.object(bundled_docs, "ANNOUNCEMENTS_SOURCE_ROOT", announcements_root),
        patch.object(site_manual, "GENERATED_DOCS_ROOT", docs_root),
        patch.object(site_manual, "GENERATED_DATA_ROOT", generated_root),
        patch.object(site_manual, "SIDEBAR_PATH", generated_root / "sidebar.json"),
    ):
        yield docs_root, generated_root


class TestLinkRewriting:
    def _targets(self) -> ManualTargets:
        return ManualTargets(
            doc_slugs={"guides/intro", "guides/advanced"},
            folder_first_doc={"guides": "guides/intro"},
        )

    def test_doc_link_root_locale(self) -> None:
        body = "See [Advanced](efa://manual/guides/advanced)."
        assert _rewrite_links(body, "en", self._targets()) == "See [Advanced](/guides/advanced/)."

    def test_doc_link_zh_locale(self) -> None:
        body = "参见[进阶](efa://manual/guides/advanced)。"
        assert _rewrite_links(body, "zh", self._targets()) == "参见[进阶](/zh/guides/advanced/)。"

    def test_folder_link_resolves_to_first_doc(self) -> None:
        body = "See [Guides](efa://manual/guides)."
        assert _rewrite_links(body, "en", self._targets()) == "See [Guides](/guides/intro/)."

    def test_unknown_target_raises(self) -> None:
        with pytest.raises(ValueError, match="efa://manual/guides/missing"):
            _rewrite_links("[X](efa://manual/guides/missing)", "en", self._targets())

    def test_inline_code_not_rewritten(self) -> None:
        body = "Use `efa://manual/guides` as an in-app path."
        assert _rewrite_links(body, "en", self._targets()) == body


class TestBuildSiteManual:
    def test_generates_pages_and_sidebar(self, site_paths) -> None:
        docs_root, generated_root = site_paths
        build_site_manual()

        en_intro = (docs_root / "guides" / "intro.md").read_text(encoding="utf-8")
        assert "title: Intro" in en_intro
        assert "[Advanced](/guides/advanced/)" in en_intro
        assert "[the folder](/guides/intro/)" in en_intro

        zh_intro = (docs_root / "zh" / "guides" / "intro.md").read_text(encoding="utf-8")
        assert "[进阶](/zh/guides/advanced/)" in zh_intro

        assert (docs_root / "changelog" / "0-2-0.md").exists()
        assert (docs_root / "zh" / "changelog" / "0-2-0.md").exists()
        assert (docs_root / "announcements" / "welcome.md").exists()
        assert (docs_root / "index.mdx").exists()
        assert (docs_root / "zh" / "index.mdx").exists()

        sidebar = json.loads((generated_root / "sidebar.json").read_text(encoding="utf-8"))
        labels = [group["label"] for group in sidebar]
        assert labels == ["guides Name", "Changelog", "Announcements"]
        assert sidebar[0]["translations"] == {"zh-CN": "guides 名称"}
        assert all(group["collapsed"] for group in sidebar)

        changelog_items = sidebar[1]["items"]
        assert [item["slug"] for item in changelog_items] == [
            "changelog/0-2-0",
            "changelog/0-1-0",
        ]
        assert changelog_items[0]["label"] == "v0.2.0"

    def test_hero_links_to_first_doc_and_newest_changelog(self, site_paths) -> None:
        docs_root, _ = site_paths
        build_site_manual()

        en_index = (docs_root / "index.mdx").read_text(encoding="utf-8")
        assert "link: /guides/intro/" in en_index
        assert "link: /changelog/0-2-0/" in en_index

        zh_index = (docs_root / "zh" / "index.mdx").read_text(encoding="utf-8")
        assert "link: /zh/guides/intro/" in zh_index
        assert "link: /zh/changelog/0-2-0/" in zh_index

    def test_regeneration_cleans_stale_pages(self, site_paths) -> None:
        docs_root, _ = site_paths
        build_site_manual()
        stale = docs_root / "stale" / "page.md"
        _write(stale, "stale")

        build_site_manual()

        assert not stale.exists()
