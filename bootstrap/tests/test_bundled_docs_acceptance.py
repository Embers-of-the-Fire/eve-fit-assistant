from __future__ import annotations

import hashlib
import json

from pathlib import Path
from typing import TYPE_CHECKING

import pytest

from bootstrap.docs.announcements_remote import AnnouncementCatalogPage
from bootstrap.docs.announcements_remote import AnnouncementEntry
from bootstrap.docs.announcements_remote import AnnouncementPage
from bootstrap.docs.bundled_docs import build_bundled_docs


if TYPE_CHECKING:
    from collections.abc import Set


_OLD_GENERAL_IDS: Set[str] = {
    "open-preview-note",
}

_OLD_VERSION_IDS: Set[str] = {
    "version-alpha-0-0-0",
    "version-alpha-0-0-1",
    "version-0-1-0-beta-1",
    "version-0-1-0-beta-2",
    "version-0-1-0-beta-3",
    "version-0-1-0-beta-4",
    "version-0-1-0-beta-5",
    "version-0-1-0-beta-6",
}


@pytest.fixture(scope="module")
def project_root() -> Path:
    return Path(__file__).resolve().parent.parent.parent


@pytest.fixture(scope="module")
def generated_root(project_root: Path) -> Path:
    return project_root / "assets" / "content" / "announcements" / "generated"


@pytest.fixture(scope="module")
def catalog_path(generated_root: Path) -> Path:
    return generated_root / "catalog.json"


@pytest.fixture(scope="module")
def documents_root(generated_root: Path) -> Path:
    return generated_root / "documents"


@pytest.fixture(scope="module", autouse=True)
def _ensure_built_catalog() -> None:
    build_bundled_docs()


class TestMigratedCatalog:
    def test_migrated_general_announcements_build(self, catalog_path: Path) -> None:
        catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
        entry_ids = {entry["id"] for entry in catalog["bundledPage"]["entries"]}
        assert _OLD_GENERAL_IDS.issubset(entry_ids)

    def test_migrated_release_notes_build(self, catalog_path: Path) -> None:
        catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
        release_entries = [
            entry for entry in catalog["bundledPage"]["entries"] if entry["id"] in _OLD_VERSION_IDS
        ]
        assert {entry["id"] for entry in release_entries} == _OLD_VERSION_IDS
        for entry in release_entries:
            assert entry["appVersion"] is not None
            assert entry["tags"] == ["release-note"]

    def test_generated_catalog_matches_wire_schema(self, catalog_path: Path) -> None:
        catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
        AnnouncementCatalogPage.model_validate(catalog["pages"][0])
        AnnouncementPage.model_validate(catalog["bundledPage"])
        for entry in catalog["bundledPage"]["entries"]:
            AnnouncementEntry.model_validate(entry)

    def test_all_document_hashes_match_filenames(self, documents_root: Path) -> None:
        for path in documents_root.glob("*.md"):
            content = path.read_text(encoding="utf-8")
            expected_hash = hashlib.sha256(content.encode("utf-8")).hexdigest()
            assert path.stem == expected_hash, f"hash mismatch for {path.name}"

    def test_no_duplicate_ids(self, catalog_path: Path) -> None:
        catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
        ids = [entry["id"] for entry in catalog["bundledPage"]["entries"]]
        assert len(set(ids)) == len(ids)


class TestBuildIdempotency:
    def test_build_docs_idempotent(self, generated_root: Path) -> None:
        catalog_path = generated_root / "catalog.json"
        first_catalog = catalog_path.read_text(encoding="utf-8")
        first_documents = {
            path.name: path.read_text(encoding="utf-8")
            for path in generated_root.joinpath("documents").glob("*.md")
        }

        build_bundled_docs()

        second_catalog = catalog_path.read_text(encoding="utf-8")
        second_documents = {
            path.name: path.read_text(encoding="utf-8")
            for path in generated_root.joinpath("documents").glob("*.md")
        }

        assert second_catalog == first_catalog
        assert second_documents == first_documents


class TestLegacyCleanup:
    def test_old_source_directories_removed(self, project_root: Path) -> None:
        assert not (project_root / "assets" / "content" / "announcements" / "zh").exists()
        assert not (project_root / "assets" / "content" / "announcements" / "en").exists()

    def test_legacy_announcements_module_removed(self, project_root: Path) -> None:
        assert not (project_root / "bootstrap" / "docs" / "announcements.py").exists()

    def test_legacy_announcements_tests_removed(self, project_root: Path) -> None:
        assert not (project_root / "bootstrap" / "tests" / "test_announcements.py").exists()

    def test_build_announcements_command_removed(self, project_root: Path) -> None:
        build_py = project_root / "bootstrap" / "cli" / "build.py"
        source = build_py.read_text(encoding="utf-8")
        assert '@build.command("announcements")' not in source
        assert '@build.command("docs")' in source
