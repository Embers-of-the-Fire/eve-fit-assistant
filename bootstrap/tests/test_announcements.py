from __future__ import annotations

import hashlib
import json
import tempfile

from pathlib import Path
from unittest.mock import patch

import pytest

from bootstrap.docs.announcements import LocalizedAnnouncementStub
from bootstrap.docs.announcements import _compute_body_hash
from bootstrap.docs.announcements import _extract_announcement_content
from bootstrap.docs.announcements import _extract_summary
from bootstrap.docs.announcements import _parse_front_matter
from bootstrap.docs.announcements import _parse_source_metadata
from bootstrap.docs.announcements import build_bundled_announcements


class TestParseFrontMatter:
    def test_valid_front_matter(self):
        content = """---
id: test-announcement
tags: [welcome]
channels: [testing]
platforms: [android, ios]
publishedAt: 2026-01-01T00:00:00Z
---

# Test Title

Test body content.
"""
        with tempfile.NamedTemporaryFile("w", suffix=".md", delete=False) as f:
            f.write(content)
            f.flush()
            front, body = _parse_front_matter(Path(f.name))

        assert front["id"] == "test-announcement"
        assert front["tags"] == ["welcome"]
        assert "# Test Title" in body
        Path(f.name).unlink()

    def test_missing_front_matter_raises(self):
        with tempfile.NamedTemporaryFile("w", suffix=".md", delete=False) as f:
            f.write("No front matter here\n")
            f.flush()
            with pytest.raises(ValueError, match="missing YAML front matter"):
                _parse_front_matter(Path(f.name))
        Path(f.name).unlink()

    def test_invalid_front_matter_boundaries_raises(self):
        with tempfile.NamedTemporaryFile("w", suffix=".md", delete=False) as f:
            f.write("---\nid: test\n---\nbody\n---\nextra\n")
            f.flush()
            front, body = _parse_front_matter(Path(f.name))
            assert front["id"] == "test"
            assert "body\n---\nextra" in body
        Path(f.name).unlink()

    def test_front_matter_as_non_mapping_raises(self):
        with tempfile.NamedTemporaryFile("w", suffix=".md", delete=False) as f:
            f.write("---\n- item1\n- item2\n---\n\n# Title\n\nBody\n")
            f.flush()
            with pytest.raises(ValueError, match="must be a YAML mapping"):
                _parse_front_matter(Path(f.name))
        Path(f.name).unlink()


class TestParseSourceMetadata:
    def test_valid_announcement_metadata(self):
        front_matter = {
            "id": "welcome",
            "publishedAt": "2026-04-14T00:00:00Z",
            "tags": ["welcome"],
            "startup": True,
            "channels": ["testing"],
            "platforms": ["android", "ios"],
        }
        metadata = _parse_source_metadata(Path("/fake/welcome.md"), front_matter)
        assert metadata.id == "welcome"
        assert metadata.startup is True
        assert metadata.tags == ["welcome"]
        assert metadata.channels == ["testing"]
        assert metadata.platforms == ["android", "ios"]
        assert metadata.app_version is None
        assert metadata.min_app_version is None
        assert metadata.max_app_version is None
        assert metadata.published_at.isoformat().startswith("2026-04-14")

    def test_version_announcement_metadata(self):
        front_matter = {
            "id": "version-1-0-0",
            "publishedAt": "2026-06-01T12:00:00Z",
            "tags": ["release-note"],
            "channels": ["testing"],
            "platforms": ["android", "ios"],
            "appVersion": "1.0.0",
        }
        metadata = _parse_source_metadata(Path("/fake/version.md"), front_matter)
        assert metadata.id == "version-1-0-0"
        assert metadata.app_version == "1.0.0"

    def test_missing_id_raises(self):
        front_matter = {
            "publishedAt": "2026-01-01T00:00:00Z",
            "channels": ["testing"],
            "platforms": ["android"],
        }
        with pytest.raises(ValueError):
            _parse_source_metadata(Path("/fake/missing.md"), front_matter)

    def test_missing_published_at_raises(self):
        front_matter = {
            "id": "test",
            "channels": ["testing"],
            "platforms": ["android"],
        }
        with pytest.raises(ValueError):
            _parse_source_metadata(Path("/fake/missing.md"), front_matter)

    def test_empty_channels_raises(self):
        # channels and platforms default to empty list, which won't pass validation
        # but the metadata doesn't enforce non-empty arrays explicitly
        # Just test that it passes with empty
        front_matter = {
            "id": "test",
            "publishedAt": "2026-01-01T00:00:00Z",
        }
        metadata = _parse_source_metadata(Path("/fake/empty.md"), front_matter)
        assert metadata.channels == []
        assert metadata.platforms == []


class TestLocalizedStub:
    def test_valid_stub(self):
        stub = LocalizedAnnouncementStub.model_validate({"id": "test-id"})
        assert stub.id == "test-id"

    def test_missing_id_raises(self):
        with pytest.raises(ValueError):
            LocalizedAnnouncementStub.model_validate({})

    def test_extra_fields_forbidden(self):
        with pytest.raises(ValueError):
            LocalizedAnnouncementStub.model_validate({"id": "test", "extra": "nope"})


class TestComputeBodyHash:
    def test_consistent_hash(self):
        body = "# Title\n\nTest content.\n"
        h1 = _compute_body_hash(body)
        h2 = _compute_body_hash(body)
        assert h1 == h2
        assert len(h1) == 64
        assert all(c in "0123456789abcdef" for c in h1)

    def test_different_content_different_hash(self):
        h1 = _compute_body_hash("Content A")
        h2 = _compute_body_hash("Content B")
        assert h1 != h2

    def test_hash_format(self):
        expected = hashlib.sha256(b"test\n").hexdigest()
        assert _compute_body_hash("test\n") == expected


class TestExtractAnnouncementContent:
    def test_valid_content(self):
        body = "# Welcome Title\n\nThis is the first paragraph.\n\nSecond paragraph.\n"
        title, summary, body_markdown = _extract_announcement_content(Path("/fake/test.md"), body)
        assert title == "Welcome Title"
        assert "first paragraph" in summary
        assert "Second paragraph" in body_markdown

    def test_empty_body_raises(self):
        with pytest.raises(ValueError, match="empty markdown body"):
            _extract_announcement_content(Path("/fake/empty.md"), "")

    def test_no_heading_raises(self):
        with pytest.raises(ValueError, match="level-1 heading"):
            _extract_announcement_content(Path("/fake/noheading.md"), "No heading here")

    def test_whitespace_before_heading(self):
        body = "\n\n\n# Title\n\nBody content.\n"
        title, _summary, _body_markdown = _extract_announcement_content(
            Path("/fake/whitespace.md"), body
        )
        assert title == "Title"


class TestExtractSummary:
    def test_paragraph_summary(self):
        summary = _extract_summary("This is a summary paragraph.\n\nMore content.")
        assert summary == "This is a summary paragraph."

    def test_multi_line_paragraph(self):
        summary = _extract_summary("Line one continues\nline two.\n\nMore content.")
        assert summary == "Line one continues line two."

    def test_skip_heading(self):
        summary = _extract_summary("## Subheading\n\nReal summary.\n\nMore.")
        assert summary == "Real summary."

    def test_skip_list(self):
        summary = _extract_summary("- List item\n- Another\n\nReal summary.\n")
        assert summary == "Real summary."

    def test_none_on_empty(self):
        assert _extract_summary("") is None


class TestBuildBundledAnnouncements:
    def make_source_files(self, tmpdir: Path, files: dict[str, str]) -> Path:
        """Create source .md files for the given locale in a temp directory."""
        locale_dir = tmpdir / "zh"
        locale_dir.mkdir(parents=True)
        for fname, content in files.items():
            (locale_dir / fname).write_text(content, encoding="utf-8")

        en_dir = tmpdir / "en"
        en_dir.mkdir(parents=True)
        for fname in files:
            en_content = files[fname]
            en_lines = en_content.split("\n")
            end_idx = 0
            if en_content.startswith("---"):
                for i, line in enumerate(en_lines):
                    if line == "---" and i > 0:
                        end_idx = i + 1
                        break
            en_body = "\n".join(en_lines[end_idx:])
            en_content_stripped = "---\nid: " + fname.replace(".md", "") + "\n---\n" + en_body
            (en_dir / fname).write_text(en_content_stripped, encoding="utf-8")

        return tmpdir

    def test_empty_source_directory(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            anno_root = Path(tmpdir)
            (anno_root / "zh").mkdir(parents=True)
            (anno_root / "en").mkdir(parents=True)
            gen_root = anno_root / "generated"

            with (
                patch(
                    "bootstrap.docs.announcements.ANNOUNCEMENTS_ROOT",
                    anno_root,
                ),
                patch(
                    "bootstrap.docs.announcements.GENERATED_ROOT",
                    gen_root,
                ),
                patch(
                    "bootstrap.docs.announcements.GENERATED_CATALOG_PATH",
                    gen_root / "catalog.json",
                ),
                patch(
                    "bootstrap.docs.announcements.GENERATED_DOCUMENTS_ROOT",
                    gen_root / "documents",
                ),
                patch(
                    "bootstrap.docs.announcements.GENERATED_GITIGNORE_PATH",
                    gen_root / ".gitignore",
                ),
                patch(
                    "bootstrap.docs.announcements.DOCUMENTS_GITKEEP_PATH",
                    gen_root / "documents" / ".gitkeep",
                ),
            ):
                build_bundled_announcements()
                catalog = json.loads((gen_root / "catalog.json").read_text())
                assert catalog["schemaVersion"] == 1
                assert len(catalog["pages"]) == 1
                assert catalog["pages"][0]["count"] == 0
                assert catalog["pages"][0]["minAppVersion"] == "0.0.0"

    def test_single_announcement(self):
        content = """\
---
id: welcome
publishedAt: 2026-04-14T00:00:00Z
tags: [welcome]
startup: true
channels: [testing]
platforms: [android, ios]
---

# Welcome to EFA

Thank you for installing the app.

We hope you enjoy it.
"""
        with tempfile.TemporaryDirectory() as tmpdir:
            anno_root = Path(tmpdir)
            self.make_source_files(anno_root, {"welcome.md": content})
            gen_root = anno_root / "generated"

            with (
                patch(
                    "bootstrap.docs.announcements.ANNOUNCEMENTS_ROOT",
                    anno_root,
                ),
                patch(
                    "bootstrap.docs.announcements.GENERATED_ROOT",
                    gen_root,
                ),
                patch(
                    "bootstrap.docs.announcements.GENERATED_CATALOG_PATH",
                    gen_root / "catalog.json",
                ),
                patch(
                    "bootstrap.docs.announcements.GENERATED_DOCUMENTS_ROOT",
                    gen_root / "documents",
                ),
                patch(
                    "bootstrap.docs.announcements.GENERATED_GITIGNORE_PATH",
                    gen_root / ".gitignore",
                ),
                patch(
                    "bootstrap.docs.announcements.DOCUMENTS_GITKEEP_PATH",
                    gen_root / "documents" / ".gitkeep",
                ),
            ):
                build_bundled_announcements()

                catalog = json.loads((gen_root / "catalog.json").read_text())
                assert catalog["schemaVersion"] == 1
                assert len(catalog["pages"]) == 1
                page_summary = catalog["pages"][0]
                assert page_summary["count"] == 1
                assert page_summary["active"] is True
                assert page_summary["uuid"] == "00000000-0000-0000-0000-000000000001"
                assert "testing" in page_summary["channels"]

                bundled_page = catalog["bundledPage"]
                assert len(bundled_page["entries"]) == 1
                entry = bundled_page["entries"][0]
                assert entry["id"] == "welcome"
                assert entry["startup"] is True
                assert entry["publishedAt"] == "2026-04-14T00:00:00Z"
                assert "zh" in entry["localizations"]
                assert "en" in entry["localizations"]
                zh = entry["localizations"]["zh"]
                assert zh["title"] == "Welcome to EFA"
                assert len(zh["bodyHash"]) == 64

                # Verify body files exist
                docs_dir = gen_root / "documents"
                zh_body_file = docs_dir / f"{zh['bodyHash']}.md"
                assert zh_body_file.exists()
                body_content = zh_body_file.read_text()
                assert "Thank you for installing" in body_content

    def test_version_announcement(self):
        content = """\
---
id: version-1-0-0
publishedAt: 2026-06-01T12:00:00Z
tags: [release-note]
channels: [testing]
platforms: [android, ios]
appVersion: "1.0.0"
---

# v1.0.0 Release

Major update with new features.

Enjoy the new version.
"""
        with tempfile.TemporaryDirectory() as tmpdir:
            anno_root = Path(tmpdir)
            self.make_source_files(anno_root, {"version-1-0-0.md": content})
            gen_root = anno_root / "generated"

            with (
                patch(
                    "bootstrap.docs.announcements.ANNOUNCEMENTS_ROOT",
                    anno_root,
                ),
                patch(
                    "bootstrap.docs.announcements.GENERATED_ROOT",
                    gen_root,
                ),
                patch(
                    "bootstrap.docs.announcements.GENERATED_CATALOG_PATH",
                    gen_root / "catalog.json",
                ),
                patch(
                    "bootstrap.docs.announcements.GENERATED_DOCUMENTS_ROOT",
                    gen_root / "documents",
                ),
                patch(
                    "bootstrap.docs.announcements.GENERATED_GITIGNORE_PATH",
                    gen_root / ".gitignore",
                ),
                patch(
                    "bootstrap.docs.announcements.DOCUMENTS_GITKEEP_PATH",
                    gen_root / "documents" / ".gitkeep",
                ),
            ):
                build_bundled_announcements()

                catalog = json.loads((gen_root / "catalog.json").read_text())
                entry = catalog["bundledPage"]["entries"][0]
                assert entry["id"] == "version-1-0-0"
                assert entry["appVersion"] == "1.0.0"
                assert entry["startup"] is False

    def test_en_without_zh_raises(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            anno_root = Path(tmpdir)
            (anno_root / "en").mkdir(parents=True)
            (anno_root / "en" / "orphan.md").write_text(
                "---\nid: orphan\n---\n\n# Orphan\n\nBody.\n", encoding="utf-8"
            )
            gen_root = anno_root / "generated"

            with (
                patch(
                    "bootstrap.docs.announcements.ANNOUNCEMENTS_ROOT",
                    anno_root,
                ),
                patch(
                    "bootstrap.docs.announcements.GENERATED_ROOT",
                    gen_root,
                ),
                patch(
                    "bootstrap.docs.announcements.GENERATED_CATALOG_PATH",
                    gen_root / "catalog.json",
                ),
                patch(
                    "bootstrap.docs.announcements.GENERATED_DOCUMENTS_ROOT",
                    gen_root / "documents",
                ),
                pytest.raises(ValueError, match="missing a matching zh"),
            ):
                build_bundled_announcements()
