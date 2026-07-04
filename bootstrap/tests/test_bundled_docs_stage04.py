from __future__ import annotations

import hashlib
import json

from contextlib import contextmanager
from typing import TYPE_CHECKING
from unittest.mock import patch

import pytest

from bootstrap.docs.announcements_remote import AnnouncementCatalogPage
from bootstrap.docs.announcements_remote import AnnouncementEntry
from bootstrap.docs.announcements_remote import AnnouncementPage
from bootstrap.docs.bundled_docs import BUNDLED_PAGE_UUID
from bootstrap.docs.bundled_docs import build_bundled_docs


if TYPE_CHECKING:
    from pathlib import Path


@contextmanager
def _patch_roots(tmp_path: Path):
    announcements = tmp_path / "announcements"
    changelog = tmp_path / "changelog"
    generated = tmp_path / "generated"
    documents = generated / "documents"
    with (
        patch("bootstrap.docs.bundled_docs.ANNOUNCEMENTS_SOURCE_ROOT", announcements),
        patch("bootstrap.docs.bundled_docs.CHANGELOG_SOURCE_ROOT", changelog),
        patch("bootstrap.docs.bundled_docs.GENERATED_ROOT", generated),
        patch("bootstrap.docs.bundled_docs.GENERATED_CATALOG_PATH", generated / "catalog.json"),
        patch("bootstrap.docs.bundled_docs.GENERATED_DOCUMENTS_ROOT", documents),
        patch("bootstrap.docs.bundled_docs.GENERATED_GITIGNORE_PATH", generated / ".gitignore"),
        patch(
            "bootstrap.docs.bundled_docs.DOCUMENTS_GITKEEP_PATH",
            documents / ".gitkeep",
        ),
    ):
        yield generated, announcements, changelog


def _write_general(
    announcements_root: Path,
    entry_id: str,
    published_at: str,
    zh_body: str,
    en_body: str,
    **kwargs: object,
) -> None:
    directory = announcements_root / entry_id
    directory.mkdir(parents=True)
    spec_lines = [f"id: {entry_id}", f"publishedAt: {published_at}"]
    for key, value in kwargs.items():
        if isinstance(value, list):
            spec_lines.append(f"{key}: [{', '.join(repr(v) for v in value)}]")
        elif isinstance(value, bool):
            spec_lines.append(f"{key}: {'true' if value else 'false'}")
        elif value is None:
            spec_lines.append(f"{key}:")
        else:
            spec_lines.append(f"{key}: {value!r}")
    (directory / "spec.yaml").write_text("\n".join(spec_lines) + "\n", encoding="utf-8")
    (directory / "zh.md").write_text(zh_body, encoding="utf-8")
    (directory / "en.md").write_text(en_body, encoding="utf-8")


def _write_release(
    changelog_root: Path,
    version_dir: str,
    published_at: str,
    app_version: str,
    zh_body: str,
    en_body: str,
    changelog: str,
    **kwargs: object,
) -> None:
    directory = changelog_root / version_dir
    directory.mkdir(parents=True)
    spec_lines = [f"publishedAt: {published_at}", f"appVersion: {app_version!r}"]
    for key, value in kwargs.items():
        if isinstance(value, list):
            spec_lines.append(f"{key}: [{', '.join(repr(v) for v in value)}]")
        elif isinstance(value, bool):
            spec_lines.append(f"{key}: {'true' if value else 'false'}")
        elif value is None:
            spec_lines.append(f"{key}:")
        else:
            spec_lines.append(f"{key}: {value!r}")
    (directory / "spec.yaml").write_text("\n".join(spec_lines) + "\n", encoding="utf-8")
    (directory / "content.zh.md").write_text(zh_body, encoding="utf-8")
    (directory / "content.en.md").write_text(en_body, encoding="utf-8")
    (directory / "changelog.md").write_text(changelog, encoding="utf-8")


class TestEmptyBuild:
    def test_empty_source_builds_empty_catalog(self, tmp_path: Path) -> None:
        with _patch_roots(tmp_path):
            build_bundled_docs()

        catalog_path = tmp_path / "generated" / "catalog.json"
        catalog = json.loads(catalog_path.read_text(encoding="utf-8"))

        assert catalog["schemaVersion"] == 1
        assert len(catalog["pages"]) == 1
        page = catalog["pages"][0]
        assert page["uuid"] == BUNDLED_PAGE_UUID
        assert page["count"] == 0
        assert page["active"] is True
        assert page["minAppVersion"] == "0.0.0"
        assert page["channels"] == []
        assert catalog["bundledPage"]["entries"] == []


class TestSingleEntries:
    def test_single_general_entry(self, tmp_path: Path) -> None:
        with _patch_roots(tmp_path) as (generated, announcements, _changelog):
            _write_general(
                announcements,
                "welcome",
                "2026-01-01T00:00:00Z",
                "# 欢迎\n\n摘要。\n\n更多。\n",
                "# Welcome\n\nSummary.\n\nMore.\n",
                tags=["featured"],
                channels=["stable"],
            )
            build_bundled_docs()

        catalog = json.loads((generated / "catalog.json").read_text(encoding="utf-8"))
        assert catalog["pages"][0]["count"] == 1

        entry = catalog["bundledPage"]["entries"][0]
        assert entry["id"] == "welcome"
        assert entry["tags"] == ["featured"]
        assert entry["channels"] == ["stable"]
        assert entry["localizations"]["zh"]["title"] == "欢迎"
        assert entry["localizations"]["en"]["title"] == "Welcome"

        for locale in ("zh", "en"):
            body_hash = entry["localizations"][locale]["bodyHash"]
            doc_path = generated / "documents" / f"{body_hash}.md"
            assert doc_path.exists()

    def test_single_release_note_entry(self, tmp_path: Path) -> None:
        with _patch_roots(tmp_path) as (generated, _announcements, changelog):
            _write_release(
                changelog,
                "1.0.0",
                "2026-02-01T00:00:00Z",
                "1.0.0",
                "# 版本 1.0.0\n\n摘要。\n",
                "# Version 1.0.0\n\nSummary.\n",
                "- Fix\n",
            )
            build_bundled_docs()

        catalog = json.loads((generated / "catalog.json").read_text(encoding="utf-8"))
        entry = catalog["bundledPage"]["entries"][0]
        assert entry["id"] == "version-1-0-0"
        assert entry["tags"] == ["release-note"]
        assert entry["appVersion"] == "1.0.0"


class TestEntryOrdering:
    def test_mixed_entries_sorted_by_published_at_desc(self, tmp_path: Path) -> None:
        with _patch_roots(tmp_path) as (generated, announcements, changelog):
            _write_general(
                announcements,
                "older",
                "2026-01-01T00:00:00Z",
                "# 旧\n\n旧摘要。\n",
                "# Old\n\nOld summary.\n",
            )
            _write_general(
                announcements,
                "newer",
                "2026-03-01T00:00:00Z",
                "# 新\n\n新摘要。\n",
                "# New\n\nNew summary.\n",
            )
            _write_release(
                changelog,
                "1.0.0",
                "2026-02-01T00:00:00Z",
                "1.0.0",
                "# 版本\n\n摘要。\n",
                "# Version\n\nSummary.\n",
                "- Fix\n",
            )
            build_bundled_docs()

        catalog = json.loads((generated / "catalog.json").read_text(encoding="utf-8"))
        ids = [e["id"] for e in catalog["bundledPage"]["entries"]]
        assert ids == ["newer", "version-1-0-0", "older"]


class TestValidation:
    def test_duplicate_id_raises(self, tmp_path: Path) -> None:
        with _patch_roots(tmp_path) as (_generated, announcements, changelog):
            _write_general(
                announcements,
                "version-1-0-0",
                "2026-01-01T00:00:00Z",
                "# 标题\n\n摘要。\n",
                "# Title\n\nSummary.\n",
            )
            _write_release(
                changelog,
                "1.0.0",
                "2026-02-01T00:00:00Z",
                "1.0.0",
                "# 版本\n\n摘要。\n",
                "# Version\n\nSummary.\n",
                "- Fix\n",
            )

            with pytest.raises(ValueError, match="Duplicate"):
                build_bundled_docs()

    def test_document_filename_matches_body_hash(self, tmp_path: Path) -> None:
        with _patch_roots(tmp_path) as (generated, announcements, _changelog):
            _write_general(
                announcements,
                "hash-check",
                "2026-01-01T00:00:00Z",
                "# 标题\n\n正文。\n",
                "# Title\n\nBody.\n",
            )
            build_bundled_docs()

        catalog = json.loads((generated / "catalog.json").read_text(encoding="utf-8"))
        for entry in catalog["bundledPage"]["entries"]:
            for locale, localization in entry["localizations"].items():
                body_hash = localization["bodyHash"]
                doc_path = generated / "documents" / f"{body_hash}.md"
                assert doc_path.exists(), f"missing document for {locale}"
                content = doc_path.read_text(encoding="utf-8")
                expected_hash = hashlib.sha256(content.encode("utf-8")).hexdigest()
                assert body_hash == expected_hash


class TestPageSummary:
    def test_min_app_version_unbounded_defaults_to_zero(self, tmp_path: Path) -> None:
        with _patch_roots(tmp_path) as (generated, announcements, _changelog):
            _write_general(
                announcements,
                "unbounded",
                "2026-01-01T00:00:00Z",
                "# 标题\n\n摘要。\n",
                "# Title\n\nSummary.\n",
                minAppVersion=None,
            )
            build_bundled_docs()

        catalog = json.loads((generated / "catalog.json").read_text(encoding="utf-8"))
        assert catalog["pages"][0]["minAppVersion"] == "0.0.0"

    def test_min_app_version_min_of_bounds(self, tmp_path: Path) -> None:
        with _patch_roots(tmp_path) as (generated, announcements, _changelog):
            _write_general(
                announcements,
                "one",
                "2026-01-01T00:00:00Z",
                "# 一\n\n摘要。\n",
                "# One\n\nSummary.\n",
                minAppVersion="2.0.0",
            )
            _write_general(
                announcements,
                "two",
                "2026-02-01T00:00:00Z",
                "# 二\n\n摘要。\n",
                "# Two\n\nSummary.\n",
                minAppVersion="1.0.0",
            )
            build_bundled_docs()

        catalog = json.loads((generated / "catalog.json").read_text(encoding="utf-8"))
        assert catalog["pages"][0]["minAppVersion"] == "1.0.0"

    def test_channels_union(self, tmp_path: Path) -> None:
        with _patch_roots(tmp_path) as (generated, announcements, _changelog):
            _write_general(
                announcements,
                "a",
                "2026-01-01T00:00:00Z",
                "# A\n\n摘要。\n",
                "# A\n\nSummary.\n",
                channels=["stable"],
            )
            _write_general(
                announcements,
                "b",
                "2026-02-01T00:00:00Z",
                "# B\n\n摘要。\n",
                "# B\n\nSummary.\n",
                channels=["testing"],
            )
            build_bundled_docs()

        catalog = json.loads((generated / "catalog.json").read_text(encoding="utf-8"))
        assert catalog["pages"][0]["channels"] == ["stable", "testing"]


class TestModelValidation:
    def test_catalog_validates_against_shared_models(self, tmp_path: Path) -> None:
        with _patch_roots(tmp_path) as (generated, announcements, changelog):
            _write_general(
                announcements,
                "general",
                "2026-01-01T00:00:00Z",
                "# 标题\n\n摘要。\n",
                "# Title\n\nSummary.\n",
            )
            _write_release(
                changelog,
                "1.0.0",
                "2026-02-01T00:00:00Z",
                "1.0.0",
                "# 版本\n\n摘要。\n",
                "# Version\n\nSummary.\n",
                "- Fix\n",
            )
            build_bundled_docs()

        catalog = json.loads((generated / "catalog.json").read_text(encoding="utf-8"))
        AnnouncementCatalogPage.model_validate(catalog["pages"][0])
        AnnouncementPage.model_validate(catalog["bundledPage"])
        for entry in catalog["bundledPage"]["entries"]:
            AnnouncementEntry.model_validate(entry)
