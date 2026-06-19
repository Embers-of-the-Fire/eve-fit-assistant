from __future__ import annotations

import tempfile

from pathlib import Path
from unittest.mock import patch

import pytest
import yaml

from data.lib.config import ProjectVersion
from data.lib.release.changelog_gen import _version_to_doc_id
from data.lib.release.changelog_gen import _write_version_documents


def _build_version(**kwargs: object) -> ProjectVersion:
    defaults = {
        "major": 0,
        "minor": 2,
        "patch": 0,
        "pre_label": "",
        "pre_num": 0,
        "build": 0,
    }
    defaults.update(kwargs)
    return ProjectVersion(**defaults)  # type: ignore[arg-type]


class TestVersionToDocId:
    def test_release_version(self):
        v = _build_version(major=1, minor=2, patch=3)
        assert _version_to_doc_id(v) == "version-1-2-3"

    def test_prerelease_version(self):
        v = _build_version(major=0, minor=1, patch=0, pre_label="beta", pre_num=1)
        assert _version_to_doc_id(v) == "version-0-1-0-beta-1"

    def test_zero_version(self):
        v = _build_version(major=0, minor=0, patch=0)
        assert _version_to_doc_id(v) == "version-0-0-0"


class TestWriteVersionDocuments:
    def test_writes_en_and_zh_files(self):
        v = _build_version()
        en_body = "English release notes content."
        zh_body = "Chinese release notes content."
        cliff_body = "### Added\n- Some feature\n"

        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            with patch(
                "data.lib.release.changelog_gen.ANNOUNCEMENTS_ROOT", root
            ):
                _write_version_documents(v, en_body, zh_body, cliff_body)

            en_path = root / "en" / "version-0-2-0.md"
            zh_path = root / "zh" / "version-0-2-0.md"

            assert en_path.exists()
            assert zh_path.exists()

    def test_en_file_has_minimal_front_matter(self):
        v = _build_version()
        en_body = "English body."
        zh_body = "Chinese body."
        cliff_body = "### Fixed\n- A bug\n"

        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            with patch(
                "data.lib.release.changelog_gen.ANNOUNCEMENTS_ROOT", root
            ):
                _write_version_documents(v, en_body, zh_body, cliff_body)

            content = (root / "en" / "version-0-2-0.md").read_text(encoding="utf-8")
            assert content.startswith("---\nid: version-0-2-0\n---")
            assert "English body." in content
            assert "### Fixed" in content

    def test_zh_file_has_announcement_schema(self):
        v = _build_version(major=0, minor=1, patch=0, pre_label="beta", pre_num=3)
        en_body = "English body."
        zh_body = "Chinese body."
        cliff_body = "### Added\n- A feature\n"

        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            with patch(
                "data.lib.release.changelog_gen.ANNOUNCEMENTS_ROOT", root
            ):
                _write_version_documents(v, en_body, zh_body, cliff_body)

            content = (root / "zh" / "version-0-1-0-beta-3.md").read_text(
                encoding="utf-8"
            )
            lines = content.splitlines()

            assert lines[0] == "---"
            assert lines[1] == "id: version-0-1-0-beta-3"
            assert lines[2].startswith("publishedAt:")
            assert lines[3] == "tags: [release-note]"
            assert lines[4] == "channels: [testing]"
            assert lines[5] == "platforms: [android, ios]"
            assert lines[6] == 'appVersion: "0.1.0-beta.3"'
            assert lines[7] == "---"

            assert "# v0.1.0-beta.3 发布说明" in content
            assert "Chinese body." in content
            assert "### Added" in content

    def test_zh_file_has_no_kind_field(self):
        v = _build_version()
        en_body = "English."
        zh_body = "Chinese."
        cliff_body = ""

        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            with patch(
                "data.lib.release.changelog_gen.ANNOUNCEMENTS_ROOT", root
            ):
                _write_version_documents(v, en_body, zh_body, cliff_body)

            content = (root / "zh" / "version-0-2-0.md").read_text(
                encoding="utf-8"
            )
            assert "kind:" not in content
            assert "appVer:" not in content

    def test_zh_front_matter_is_valid_yaml(self):
        v = _build_version(major=1, minor=0, patch=0)
        en_body = "English."
        zh_body = "Chinese."
        cliff_body = ""

        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            with patch(
                "data.lib.release.changelog_gen.ANNOUNCEMENTS_ROOT", root
            ):
                _write_version_documents(v, en_body, zh_body, cliff_body)

            content = (root / "zh" / "version-1-0-0.md").read_text(encoding="utf-8")
            parts = content.split("---", 2)
            front_matter = yaml.safe_load(parts[1])

        assert front_matter["id"] == "version-1-0-0"
        assert "publishedAt" in front_matter
        assert front_matter["tags"] == ["release-note"]
        assert front_matter["channels"] == ["testing"]
        assert front_matter["platforms"] == ["android", "ios"]
        assert front_matter["appVersion"] == "1.0.0"

    def test_creates_parent_directories(self):
        v = _build_version()
        en_body = "Body."
        zh_body = "Body."
        cliff_body = ""

        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            nested = root / "nested" / "path"
            with patch(
                "data.lib.release.changelog_gen.ANNOUNCEMENTS_ROOT", nested
            ):
                _write_version_documents(v, en_body, zh_body, cliff_body)

            assert (nested / "en" / "version-0-2-0.md").exists()
            assert (nested / "zh" / "version-0-2-0.md").exists()

    def test_published_at_is_utc_z_format(self):
        v = _build_version()
        en_body = "Body."
        zh_body = "Body."
        cliff_body = ""

        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            with patch(
                "data.lib.release.changelog_gen.ANNOUNCEMENTS_ROOT", root
            ):
                _write_version_documents(v, en_body, zh_body, cliff_body)

            content = (root / "zh" / "version-0-2-0.md").read_text(encoding="utf-8")
            parts = content.split("---", 2)
            front_matter = yaml.safe_load(parts[1])
            published_at = front_matter["publishedAt"]

        assert published_at.tzinfo is not None
        assert published_at.utcoffset().total_seconds() == 0

    def test_heading_includes_semver(self):
        v = _build_version(major=2, minor=5, patch=1)
        en_body = "English."
        zh_body = "Chinese."
        cliff_body = ""

        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            with patch(
                "data.lib.release.changelog_gen.ANNOUNCEMENTS_ROOT", root
            ):
                _write_version_documents(v, en_body, zh_body, cliff_body)

            en_content = (root / "en" / "version-2-5-1.md").read_text(
                encoding="utf-8"
            )
            zh_content = (root / "zh" / "version-2-5-1.md").read_text(
                encoding="utf-8"
            )

        assert "# v2.5.1 Release Notes" in en_content
        assert "# v2.5.1" in zh_content
