from __future__ import annotations

from typing import TYPE_CHECKING
from unittest.mock import patch

import pytest

from bootstrap.docs.bundled_docs import _iter_announcement_dirs
from bootstrap.docs.bundled_docs import _iter_changelog_dirs
from bootstrap.docs.bundled_docs import _load_spec
from bootstrap.utils import normalize_version_dir
from bootstrap.utils import version_dir_to_entry_id


if TYPE_CHECKING:
    from pathlib import Path


class TestBundledSourceMetadata:
    def test_valid_general_metadata_defaults(self, tmp_path: Path) -> None:
        spec_path = tmp_path / "announcements" / "welcome" / "spec.yaml"
        spec_path.parent.mkdir(parents=True)
        spec_path.write_text(
            "id: welcome\npublishedAt: 2026-01-01T00:00:00Z\n",
            encoding="utf-8",
        )

        metadata = _load_spec(spec_path)

        assert metadata.id == "welcome"
        assert metadata.published_at.isoformat().startswith("2026-01-01")
        assert metadata.tags == []
        assert metadata.startup is False
        assert metadata.channels == ["testing"]
        assert metadata.platforms == []
        assert metadata.min_app_version is None
        assert metadata.max_app_version is None
        assert metadata.app_version is None

    def test_explicit_values_override_defaults(self, tmp_path: Path) -> None:
        spec_path = tmp_path / "announcements" / "override" / "spec.yaml"
        spec_path.parent.mkdir(parents=True)
        spec_path.write_text(
            """\
id: override
publishedAt: 2026-02-01T00:00:00Z
tags: [featured]
startup: true
channels: [stable]
platforms: [android]
minAppVersion: \"1.0.0\"
maxAppVersion: \"2.0.0\"
appVersion: \"1.5.0\"
""",
            encoding="utf-8",
        )

        metadata = _load_spec(spec_path)

        assert metadata.tags == ["featured"]
        assert metadata.startup is True
        assert metadata.channels == ["stable"]
        assert metadata.platforms == ["android"]
        assert metadata.min_app_version == "1.0.0"
        assert metadata.max_app_version == "2.0.0"
        assert metadata.app_version == "1.5.0"

    def test_missing_published_at_raises(self, tmp_path: Path) -> None:
        spec_path = tmp_path / "announcements" / "no-date" / "spec.yaml"
        spec_path.parent.mkdir(parents=True)
        spec_path.write_text("id: no-date\n", encoding="utf-8")

        with pytest.raises(ValueError):
            _load_spec(spec_path)

    def test_general_id_must_match_directory(self, tmp_path: Path) -> None:
        spec_path = tmp_path / "announcements" / "foo" / "spec.yaml"
        spec_path.parent.mkdir(parents=True)
        spec_path.write_text(
            "id: bar\npublishedAt: 2026-01-01T00:00:00Z\n",
            encoding="utf-8",
        )

        with pytest.raises(ValueError, match="id"):
            _load_spec(spec_path)


class TestVersionNormalization:
    def test_version_dir_normalization(self) -> None:
        assert normalize_version_dir("0.1.0-beta.6") == "0-1-0-beta-6"
        assert version_dir_to_entry_id("0.1.0-beta.6") == "version-0-1-0-beta-6"
        assert normalize_version_dir("version-1.2.3") == "1-2-3"
        assert version_dir_to_entry_id("version-1.2.3") == "version-1-2-3"


class TestChangelogLoading:
    def test_changelog_app_version_required(self, tmp_path: Path) -> None:
        spec_path = tmp_path / "changelog" / "1-0-0" / "spec.yaml"
        spec_path.parent.mkdir(parents=True)
        spec_path.write_text(
            "publishedAt: 2026-01-01T00:00:00Z\n",
            encoding="utf-8",
        )

        with pytest.raises(ValueError, match="appVersion"):
            _load_spec(spec_path)


class TestPathDiscovery:
    def test_path_discovery_skips_hidden_and_files(self, tmp_path: Path) -> None:
        announcements_root = tmp_path / "announcements"
        announcements_root.mkdir()
        (announcements_root / "visible").mkdir()
        (announcements_root / ".hidden").mkdir()
        (announcements_root / "stray-file").write_text("nope", encoding="utf-8")

        changelog_root = tmp_path / "changelog"
        changelog_root.mkdir()
        (changelog_root / "1-0-0").mkdir()
        (changelog_root / ".hidden").mkdir()
        (changelog_root / "not-a-dir.txt").write_text("nope", encoding="utf-8")

        with patch("bootstrap.docs.bundled_docs.ANNOUNCEMENTS_SOURCE_ROOT", announcements_root):
            announcement_results = list(_iter_announcement_dirs())
        assert announcement_results == [("visible", announcements_root / "visible")]

        with patch("bootstrap.docs.bundled_docs.CHANGELOG_SOURCE_ROOT", changelog_root):
            changelog_results = list(_iter_changelog_dirs())
        assert changelog_results == [("1-0-0", changelog_root / "1-0-0")]
