"""Tests for the remote announcement workspace management module.

Covers data models, staging overlay CRUD, workspace construction,
preflight validation, and status diff.
"""

from __future__ import annotations

import hashlib
import json
import tempfile

from pathlib import Path

import pytest

from bootstrap.docs.announcements_remote import ACTIVE_KEY
from bootstrap.docs.announcements_remote import DOCUMENT_ID_PATTERN
from bootstrap.docs.announcements_remote import AnnouncementCatalog
from bootstrap.docs.announcements_remote import AnnouncementCatalogPage
from bootstrap.docs.announcements_remote import AnnouncementEntry
from bootstrap.docs.announcements_remote import AnnouncementLocalization
from bootstrap.docs.announcements_remote import AnnouncementPage
from bootstrap.docs.announcements_remote import AnnouncementWorkspace
from bootstrap.docs.announcements_remote import StagingOverlay
from bootstrap.docs.announcements_remote import compute_status_diff
from bootstrap.docs.announcements_remote import run_preflight_validation


SAMPLE_UUID = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _make_entry(
    entry_id: str = "test-entry",
    zh_title: str = "\u6d4b\u8bd5\u6807\u9898",
    zh_summary: str = "\u6d4b\u8bd5\u6458\u8981",
    zh_body: str = "\u6d4b\u8bd5\u6b63\u6587",
    en_title: str = "Test Title",
    en_summary: str = "Test Summary",
    en_body: str = "Test Body",
    published_at: str = "2026-06-19T12:00:00Z",
    tags: list[str] | None = None,
    startup: bool = False,
    channels: list[str] | None = None,
    platforms: list[str] | None = None,
    min_app_version: str | None = None,
    max_app_version: str | None = None,
    app_version: str | None = None,
) -> AnnouncementEntry:
    zh_hash = hashlib.sha256(zh_body.encode("utf-8")).hexdigest()
    en_hash = hashlib.sha256(en_body.encode("utf-8")).hexdigest()
    return AnnouncementEntry(
        id=entry_id,
        published_at=published_at,
        tags=tags or [],
        startup=startup,
        min_app_version=min_app_version,
        max_app_version=max_app_version,
        channels=channels if channels is not None else ["testing"],
        platforms=platforms if platforms is not None else ["android", "ios"],
        app_version=app_version,
        localizations={
            "zh": AnnouncementLocalization(title=zh_title, summary=zh_summary, body_hash=zh_hash),
            "en": AnnouncementLocalization(title=en_title, summary=en_summary, body_hash=en_hash),
        },
    )


def _setup_remote(
    workspace: AnnouncementWorkspace,
    entries: list[AnnouncementEntry],
    *,
    uuid: str = SAMPLE_UUID,
    archived_pages: list[tuple[str, list[AnnouncementEntry]]] | None = None,
) -> None:
    """Write a remote workspace with active page + optional archived pages."""
    workspace.ensure_remote_directories()

    active_page = AnnouncementPage(
        uuid=uuid,
        published_at="2026-06-19T12:00:00Z",
        max_entries=50,
        entries=list(entries),
    )

    catalog = AnnouncementCatalog(
        schema_version=1,
        pages=[
            AnnouncementCatalogPage(
                uuid=uuid,
                published_at=active_page.published_at,
                count=len(entries),
                active=True,
            )
        ],
    )

    if archived_pages:
        for a_uuid, a_entries in archived_pages:
            archive_page = AnnouncementPage(
                uuid=a_uuid,
                published_at="2026-06-19T12:00:00Z",
                entries=list(a_entries),
            )
            workspace._write_page(workspace.remote_dir, archive_page)
            catalog.pages.append(
                AnnouncementCatalogPage(
                    uuid=a_uuid,
                    published_at=archive_page.published_at,
                    count=len(a_entries),
                    active=False,
                )
            )

    workspace._write_catalog(workspace.remote_dir, catalog)
    workspace._write_active(workspace.remote_dir, active_page)


# ---------------------------------------------------------------------------
# Data model tests
# ---------------------------------------------------------------------------


class TestAnnouncementEntry:
    def test_valid_entry_id(self):
        entry = _make_entry(entry_id="valid-id")
        assert entry.id == "valid-id"

    def test_entry_id_with_dots(self):
        entry = _make_entry(entry_id="v1.0.0")
        assert entry.id == "v1.0.0"

    def test_entry_id_with_underscore(self):
        entry = _make_entry(entry_id="maintenance_2026")
        assert entry.id == "maintenance_2026"

    def test_entry_id_rejects_uppercase(self):
        with pytest.raises(ValueError, match="Invalid entry ID"):
            _make_entry(entry_id="Invalid")

    def test_entry_id_rejects_leading_hyphen(self):
        with pytest.raises(ValueError, match="Invalid entry ID"):
            _make_entry(entry_id="-test")

    def test_entry_id_rejects_empty(self):
        with pytest.raises(ValueError):
            AnnouncementEntry.model_validate({"id": "", "localizations": {}})

    def test_missing_localizations(self):
        with pytest.raises(ValueError):
            AnnouncementEntry.model_validate({"id": "test"})

    def test_version_entry_fields(self):
        entry = _make_entry(entry_id="v1.0.0", app_version="1.0.0", startup=True)
        assert entry.app_version == "1.0.0"
        assert entry.startup is True

    def test_pydantic_default_values(self):
        entry = AnnouncementEntry(
            id="default-test",
            published_at="2026-01-01T00:00:00Z",
            localizations={
                "zh": AnnouncementLocalization(title="T", summary="S", body_hash="a" * 64),
                "en": AnnouncementLocalization(title="T", summary="S", body_hash="b" * 64),
            },
        )
        assert entry.tags == []
        assert entry.channels == []
        assert entry.platforms == []
        assert entry.startup is False
        assert entry.min_app_version is None
        assert entry.max_app_version is None
        assert entry.app_version is None


class TestAnnouncementLocalization:
    def test_valid_localization(self):
        loc = AnnouncementLocalization(title="Title", summary="Summary", body_hash="abc123")
        assert loc.title == "Title"
        assert loc.summary == "Summary"
        assert loc.body_hash == "abc123"

    def test_missing_title(self):
        with pytest.raises(ValueError):
            AnnouncementLocalization.model_validate({"summary": "S", "bodyHash": "abc"})

    def test_missing_summary(self):
        with pytest.raises(ValueError):
            AnnouncementLocalization.model_validate({"title": "T", "bodyHash": "abc"})

    def test_missing_body_hash(self):
        with pytest.raises(ValueError):
            AnnouncementLocalization.model_validate({"title": "T", "summary": "S"})


class TestStagingOverlay:
    def test_empty_overlay(self):
        overlay = StagingOverlay()
        assert overlay.schema_version == 1
        assert overlay.pages == {}

    def test_overlay_json_roundtrip(self):
        e = _make_entry(entry_id="e1", zh_body="b", en_body="b")
        overlay = StagingOverlay(
            schema_version=1,
            pages={ACTIVE_KEY: {"e1": e}},
        )
        data = overlay.model_dump(mode="json", by_alias=True)
        assert data["schemaVersion"] == 1
        assert "active" in data["pages"]
        assert data["pages"]["active"]["e1"]["id"] == "e1"
        parsed = StagingOverlay.model_validate(data)
        assert parsed.pages[ACTIVE_KEY]["e1"].id == "e1"

    def test_overlay_roundtrip_with_removal(self):
        overlay = StagingOverlay(pages={ACTIVE_KEY: {"e1": None}})
        data = overlay.model_dump(mode="json", by_alias=True)
        assert data["pages"]["active"]["e1"] is None
        parsed = StagingOverlay.model_validate(data)
        assert parsed.pages[ACTIVE_KEY]["e1"] is None


class TestAnnouncementCatalog:
    def test_valid_catalog(self):
        catalog = AnnouncementCatalog(
            schema_version=1,
            pages=[
                AnnouncementCatalogPage(
                    uuid=SAMPLE_UUID,
                    published_at="2026-01-01T00:00:00Z",
                    count=1,
                    active=True,
                )
            ],
        )
        assert catalog.schema_version == 1
        assert len(catalog.pages) == 1

    def test_minimal_catalog(self):
        data = {
            "schemaVersion": 1,
            "pages": [
                {
                    "uuid": SAMPLE_UUID,
                    "publishedAt": "2026-01-01T00:00:00Z",
                    "active": True,
                }
            ],
        }
        catalog = AnnouncementCatalog.model_validate(data)
        assert catalog.pages[0].count == 0
        assert catalog.pages[0].channels == []
        assert catalog.pages[0].min_app_version == "0.0.0"


class TestAnnouncementPage:
    def test_valid_page(self):
        entry = _make_entry()
        page = AnnouncementPage(
            uuid=SAMPLE_UUID,
            published_at="2026-01-01T00:00:00Z",
            entries=[entry],
        )
        assert page.max_entries == 50
        assert len(page.entries) == 1

    def test_json_roundtrip(self):
        entry = _make_entry()
        page = AnnouncementPage(
            uuid=SAMPLE_UUID,
            published_at="2026-06-19T12:00:00Z",
            entries=[entry],
        )
        data = page.model_dump(mode="json", by_alias=True)
        assert data["uuid"] == SAMPLE_UUID
        assert data["maxEntries"] == 50
        parsed = AnnouncementPage.model_validate(data)
        assert parsed.uuid == SAMPLE_UUID
        assert len(parsed.entries) == 1


# ---------------------------------------------------------------------------
# Workspace & overlay tests
# ---------------------------------------------------------------------------


class TestWorkspaceOverlay:
    @pytest.fixture
    def tmp_root(self) -> Path:
        d = tempfile.mkdtemp(prefix="efa-anno-overlay-")
        yield Path(d)
        import shutil

        shutil.rmtree(d, ignore_errors=True)

    @pytest.fixture
    def workspace(self, tmp_root: Path) -> AnnouncementWorkspace:
        ws = AnnouncementWorkspace(tmp_root)
        ws.ensure_remote_directories()
        return ws

    def test_read_overlay_when_missing_returns_empty(self, workspace: AnnouncementWorkspace):
        overlay = workspace.read_overlay()
        assert overlay.pages == {}
        assert overlay.schema_version == 1

    def test_write_and_read_overlay(self, workspace: AnnouncementWorkspace):
        e = _make_entry(entry_id="e1", zh_body="b", en_body="b")
        overlay = workspace.overlay_upsert_entry(ACTIVE_KEY, e)
        workspace.write_overlay(overlay)
        loaded = workspace.read_overlay()
        assert loaded.pages[ACTIVE_KEY]["e1"].id == "e1"

    def test_clear_overlay(self, workspace: AnnouncementWorkspace):
        e = _make_entry(entry_id="e1", zh_body="b", en_body="b")
        overlay = workspace.overlay_upsert_entry(ACTIVE_KEY, e)
        workspace.write_overlay(overlay)
        workspace.clear_overlay()
        assert workspace.read_overlay().pages == {}

    def test_overlay_upsert_adds_entry(self, workspace: AnnouncementWorkspace):
        e = _make_entry(entry_id="new-entry", zh_body="b", en_body="b")
        overlay = workspace.overlay_upsert_entry(ACTIVE_KEY, e)
        assert overlay.pages[ACTIVE_KEY]["new-entry"].id == "new-entry"

    def test_overlay_upsert_modifies_existing(self, workspace: AnnouncementWorkspace):
        e1 = _make_entry(entry_id="e1", zh_title="Old", zh_body="b", en_body="b")
        overlay = workspace.overlay_upsert_entry(ACTIVE_KEY, e1)
        workspace.write_overlay(overlay)

        e2 = _make_entry(entry_id="e1", zh_title="New", zh_body="b", en_body="b")
        overlay = workspace.overlay_upsert_entry(ACTIVE_KEY, e2)
        assert overlay.pages[ACTIVE_KEY]["e1"].localizations["zh"].title == "New"

    def test_overlay_remove_added_entry_drops_key(self, workspace: AnnouncementWorkspace):
        e = _make_entry(entry_id="e1", zh_body="b", en_body="b")
        overlay = workspace.overlay_upsert_entry(ACTIVE_KEY, e)
        workspace.write_overlay(overlay)
        overlay = workspace.overlay_remove_entry("e1")
        assert "e1" not in overlay.pages.get(ACTIVE_KEY, {})

    def test_overlay_remove_remote_entry_sets_none(self, workspace: AnnouncementWorkspace):
        """Removing an entry not yet in overlay marks it as None (deletion)."""
        overlay = workspace.overlay_remove_entry("remote-entry")
        assert overlay.pages[ACTIVE_KEY]["remote-entry"] is None

    def test_get_effective_entry_ids_no_remote(self, workspace: AnnouncementWorkspace):
        assert workspace.get_effective_entry_ids(ACTIVE_KEY) == set()

    def test_get_effective_entry_ids_from_remote(self, workspace: AnnouncementWorkspace):
        _setup_remote(workspace, [_make_entry(entry_id="r1", zh_body="b", en_body="b")])
        assert workspace.get_effective_entry_ids(ACTIVE_KEY) == {"r1"}

    def test_get_effective_entry_ids_with_overlay_add(self, workspace: AnnouncementWorkspace):
        _setup_remote(workspace, [_make_entry(entry_id="r1", zh_body="b", en_body="b")])
        e = _make_entry(entry_id="s1", zh_body="b", en_body="b")
        overlay = workspace.overlay_upsert_entry(ACTIVE_KEY, e)
        workspace.write_overlay(overlay)
        assert workspace.get_effective_entry_ids(ACTIVE_KEY) == {"r1", "s1"}

    def test_get_effective_entry_ids_with_overlay_remove(self, workspace: AnnouncementWorkspace):
        """Removing a remote entry (not first added) marks it for deletion."""
        _setup_remote(
            workspace,
            [
                _make_entry(entry_id="r1", zh_body="b", en_body="b"),
                _make_entry(entry_id="r2", zh_body="b", en_body="b"),
            ],
        )
        overlay = workspace.overlay_remove_entry("r2")
        workspace.write_overlay(overlay)
        assert workspace.get_effective_entry_ids(ACTIVE_KEY) == {"r1"}

    def test_add_then_remove_cancels_out(self, workspace: AnnouncementWorkspace):
        """Adding then removing an entry in the same session cancels out."""
        _setup_remote(
            workspace,
            [_make_entry(entry_id="r1", zh_body="b", en_body="b")],
        )
        e = _make_entry(entry_id="new-one", zh_body="b", en_body="b")
        overlay = workspace.overlay_upsert_entry(ACTIVE_KEY, e)
        workspace.write_overlay(overlay)
        overlay = workspace.overlay_remove_entry("new-one")
        workspace.write_overlay(overlay)
        assert workspace.get_effective_entry_ids(ACTIVE_KEY) == {"r1"}

    def test_ensure_remote_directories(self, workspace: AnnouncementWorkspace):
        assert workspace.remote_dir.exists()
        assert (workspace.remote_dir / "pages").exists()
        assert workspace.documents_dir.exists()

    def test_store_and_get_document(self, workspace: AnnouncementWorkspace):
        body = "# Test\nContent"
        h = workspace.store_document(body)
        assert workspace.get_document(h) == body

    def test_verify_document_hash(self, workspace: AnnouncementWorkspace):
        body = "verify me"
        h = workspace.store_document(body)
        assert workspace.verify_document_hash(h) is True

    def test_verify_document_hash_bad(self, workspace: AnnouncementWorkspace):
        body = "original"
        h = workspace.store_document(body)
        (workspace.documents_dir / f"{h}.md").write_text("tampered")
        assert workspace.verify_document_hash(h) is False


# ---------------------------------------------------------------------------
# build_publish_workspace tests
# ---------------------------------------------------------------------------


class TestBuildPublishWorkspace:
    @pytest.fixture
    def tmp_root(self) -> Path:
        d = tempfile.mkdtemp(prefix="efa-anno-build-")
        yield Path(d)
        import shutil

        shutil.rmtree(d, ignore_errors=True)

    @pytest.fixture
    def workspace(self, tmp_root: Path) -> AnnouncementWorkspace:
        ws = AnnouncementWorkspace(tmp_root)
        ws.ensure_remote_directories()
        return ws

    @pytest.fixture
    def temp_dir(self, tmp_root: Path) -> Path:
        td = tmp_root / "temp"
        td.mkdir(exist_ok=True)
        return td

    def test_empty_overlay_no_remote_raises(self, workspace: AnnouncementWorkspace, temp_dir: Path):
        with pytest.raises(RuntimeError, match="no active page"):
            workspace.build_publish_workspace(temp_dir)

    def test_empty_overlay_keeps_remote_as_is(
        self, workspace: AnnouncementWorkspace, temp_dir: Path
    ):
        _setup_remote(workspace, [_make_entry(entry_id="r1", zh_body="b", en_body="b")])
        workspace.build_publish_workspace(temp_dir)
        active = workspace._read_active(temp_dir)
        assert len(active.entries) == 1
        assert active.entries[0].id == "r1"

    def test_add_entry_via_overlay(self, workspace: AnnouncementWorkspace, temp_dir: Path):
        _setup_remote(workspace, [_make_entry(entry_id="r1", zh_body="b", en_body="b")])
        e = _make_entry(entry_id="s1", zh_body="b", en_body="b")
        overlay = workspace.overlay_upsert_entry(ACTIVE_KEY, e)
        workspace.write_overlay(overlay)
        workspace.build_publish_workspace(temp_dir)
        active = workspace._read_active(temp_dir)
        assert {e.id for e in active.entries} == {"r1", "s1"}

    def test_edit_entry_via_overlay(self, workspace: AnnouncementWorkspace, temp_dir: Path):
        _setup_remote(
            workspace, [_make_entry(entry_id="r1", zh_title="Old", zh_body="b", en_body="b")]
        )
        e = _make_entry(entry_id="r1", zh_title="New", zh_body="b", en_body="b")
        overlay = workspace.overlay_upsert_entry(ACTIVE_KEY, e)
        workspace.write_overlay(overlay)
        workspace.build_publish_workspace(temp_dir)
        active = workspace._read_active(temp_dir)
        assert active.entries[0].localizations["zh"].title == "New"

    def test_remove_entry_via_overlay(self, workspace: AnnouncementWorkspace, temp_dir: Path):
        _setup_remote(
            workspace,
            [
                _make_entry(entry_id="r1", zh_body="b", en_body="b"),
                _make_entry(entry_id="r2", zh_body="b", en_body="b"),
            ],
        )
        overlay = workspace.overlay_remove_entry("r2")
        workspace.write_overlay(overlay)
        workspace.build_publish_workspace(temp_dir)
        active = workspace._read_active(temp_dir)
        assert {e.id for e in active.entries} == {"r1"}

    def test_rotation_20_entries(self, workspace: AnnouncementWorkspace, temp_dir: Path):
        """Adding entries to reach exactly 20 triggers rotation."""
        _setup_remote(
            workspace, [_make_entry(entry_id=f"r{i}", zh_body="b", en_body="b") for i in range(10)]
        )
        for i in range(10, 20):
            e = _make_entry(entry_id=f"s{i}", zh_body="b", en_body="b")
            overlay = workspace.overlay_upsert_entry(ACTIVE_KEY, e)
            workspace.write_overlay(overlay)
        workspace.build_publish_workspace(temp_dir)
        catalog = workspace._read_catalog(temp_dir)
        active_meta = next(p for p in catalog.pages if p.active)
        assert active_meta.count == 0
        archived_count = sum(1 for p in catalog.pages if not p.active)
        assert archived_count == 1

    def test_rotation_more_than_20(self, workspace: AnnouncementWorkspace, temp_dir: Path):
        """25 entries → 1 archived page of 20 + active page of 5."""
        _setup_remote(
            workspace, [_make_entry(entry_id=f"r{i}", zh_body="b", en_body="b") for i in range(10)]
        )
        for i in range(10, 25):
            e = _make_entry(entry_id=f"s{i}", zh_body="b", en_body="b")
            overlay = workspace.overlay_upsert_entry(ACTIVE_KEY, e)
            workspace.write_overlay(overlay)
        workspace.build_publish_workspace(temp_dir)
        catalog = workspace._read_catalog(temp_dir)
        active_meta = next(p for p in catalog.pages if p.active)
        assert active_meta.count == 5
        archived = [p for p in catalog.pages if not p.active]
        assert len(archived) == 1
        assert archived[0].count == 20

    def test_rotation_40_entries(self, workspace: AnnouncementWorkspace, temp_dir: Path):
        """40 entries → 2 archived pages of 20 each + active page of 0."""
        _setup_remote(
            workspace, [_make_entry(entry_id=f"r{i}", zh_body="b", en_body="b") for i in range(20)]
        )
        for i in range(20, 40):
            e = _make_entry(entry_id=f"s{i}", zh_body="b", en_body="b")
            overlay = workspace.overlay_upsert_entry(ACTIVE_KEY, e)
            workspace.write_overlay(overlay)
        workspace.build_publish_workspace(temp_dir)
        catalog = workspace._read_catalog(temp_dir)
        active_meta = next(p for p in catalog.pages if p.active)
        assert active_meta.count == 0
        archived = [p for p in catalog.pages if not p.active]
        assert len(archived) == 2
        for a in archived:
            assert a.count == 20

    def test_edit_archived_page_via_overlay(self, workspace: AnnouncementWorkspace, temp_dir: Path):
        """Editing an entry in an archived page via overlay."""
        a_uuid = "11111111-1111-1111-1111-111111111111"
        archive_entries = [
            _make_entry(entry_id=f"a{i}", zh_body="b", en_body="b") for i in range(20)
        ]
        _setup_remote(
            workspace,
            [_make_entry(entry_id="r1", zh_body="b", en_body="b")],
            uuid=SAMPLE_UUID,
            archived_pages=[(a_uuid, archive_entries)],
        )
        edited = _make_entry(entry_id="a0", zh_title="Edited Archived", zh_body="b", en_body="b")
        overlay = workspace.overlay_upsert_entry(a_uuid, edited)
        workspace.write_overlay(overlay)
        workspace.build_publish_workspace(temp_dir)
        archived_page = workspace._read_page(temp_dir, a_uuid)
        entry = next(e for e in archived_page.entries if e.id == "a0")
        assert entry.localizations["zh"].title == "Edited Archived"

    def test_preserves_archived_pages_without_overlay(
        self, workspace: AnnouncementWorkspace, temp_dir: Path
    ):
        """Archived pages not in the overlay are copied unchanged."""
        a_uuid = "22222222-2222-2222-2222-222222222222"
        archive_entries = [
            _make_entry(entry_id=f"a{i}", zh_body="b", en_body="b") for i in range(20)
        ]
        _setup_remote(
            workspace,
            [_make_entry(entry_id="r1", zh_body="b", en_body="b")],
            uuid=SAMPLE_UUID,
            archived_pages=[(a_uuid, archive_entries)],
        )
        workspace.build_publish_workspace(temp_dir)
        archived_page = workspace._read_page(temp_dir, a_uuid)
        assert len(archived_page.entries) == 20


# ---------------------------------------------------------------------------
# Preflight validation tests
# ---------------------------------------------------------------------------


class TestPreflightValidation:
    @pytest.fixture
    def tmp_root(self) -> Path:
        d = tempfile.mkdtemp(prefix="efa-anno-preflight-")
        yield Path(d)
        import shutil

        shutil.rmtree(d, ignore_errors=True)

    @pytest.fixture
    def workspace(self, tmp_root: Path) -> AnnouncementWorkspace:
        ws = AnnouncementWorkspace(tmp_root)
        ws.ensure_remote_directories()
        return ws

    def test_pass_with_valid_temp_workspace(self, workspace: AnnouncementWorkspace):
        zh_body = "zh content"
        en_body = "en content"
        workspace.store_document(zh_body)
        workspace.store_document(en_body)
        _setup_remote(workspace, [_make_entry(zh_body=zh_body, en_body=en_body)])
        temp = workspace.root / "temp"
        workspace.build_publish_workspace(temp)
        errors = run_preflight_validation(
            workspace_dir=temp,
            documents_dir=workspace.documents_dir,
            check_remote=False,
        )
        assert errors == []

    def test_fail_catalog_missing(self, tmp_root: Path):
        ws_dir = tmp_root / "nope"
        ws_dir.mkdir()
        errors = run_preflight_validation(
            workspace_dir=ws_dir, documents_dir=tmp_root / "docs", check_remote=False
        )
        assert any("catalog.json is missing" in e for e in errors)

    def test_fail_unsupported_schema(self, tmp_root: Path):
        ws_dir = tmp_root / "bad"
        ws_dir.mkdir()
        catalog = AnnouncementCatalog(schema_version=99, pages=[])
        json_path = ws_dir / "catalog.json"
        json_path.write_text(
            json.dumps(catalog.model_dump(mode="json", by_alias=True)), encoding="utf-8"
        )
        errors = run_preflight_validation(
            workspace_dir=ws_dir, documents_dir=tmp_root / "docs", check_remote=False
        )
        assert any("unsupported schemaVersion 99" in e for e in errors)

    def test_fail_archived_page_not_20(self, workspace: AnnouncementWorkspace):
        a_uuid = "33333333-3333-3333-3333-333333333333"
        archive_entries = [
            _make_entry(entry_id=f"a{i}", zh_body="b", en_body="b") for i in range(5)
        ]
        _setup_remote(
            workspace,
            [_make_entry(entry_id="r1", zh_body="b", en_body="b")],
            archived_pages=[(a_uuid, archive_entries)],
        )
        temp = workspace.root / "temp"
        workspace.build_publish_workspace(temp)
        errors = run_preflight_validation(
            workspace_dir=temp, documents_dir=workspace.documents_dir, check_remote=False
        )
        assert any("archived pages must have exactly 20" in e for e in errors)

    def test_fail_active_page_exceeds_20(self, workspace: AnnouncementWorkspace):
        """If rotation is broken, active > 20 should fail."""
        _setup_remote(workspace, [])
        page = AnnouncementPage(
            uuid=SAMPLE_UUID,
            published_at="2026-01-01T00:00:00Z",
            entries=[_make_entry(entry_id=f"e{i}", zh_body="b", en_body="b") for i in range(21)],
        )
        temp = workspace.root / "temp"
        temp.mkdir(parents=True, exist_ok=True)
        workspace._write_catalog(
            temp,
            AnnouncementCatalog(
                pages=[
                    AnnouncementCatalogPage(
                        uuid=SAMPLE_UUID, published_at="2026-01-01T00:00:00Z", active=True
                    )
                ]
            ),
        )
        workspace._write_active(temp, page)
        errors = run_preflight_validation(
            workspace_dir=temp, documents_dir=workspace.documents_dir, check_remote=False
        )
        assert any("expected \u2264 20" in e for e in errors)

    def test_fail_missing_locale(self, workspace: AnnouncementWorkspace):
        entry = AnnouncementEntry(
            id="bad-entry",
            published_at="2026-01-01T00:00:00Z",
            localizations={
                "zh": AnnouncementLocalization(title="T", summary="S", body_hash="abc123"),
            },
        )
        _setup_remote(workspace, [entry])
        temp = workspace.root / "temp"
        workspace.build_publish_workspace(temp)
        errors = run_preflight_validation(
            workspace_dir=temp, documents_dir=workspace.documents_dir, check_remote=False
        )
        assert any("missing locale en" in e for e in errors)

    def test_remote_compat_prevents_deletion(self, workspace: AnnouncementWorkspace):
        zh_body = "body"
        en_body = "body"
        workspace.store_document(zh_body)
        workspace.store_document(en_body)

        # Remote has 2 entries, overlay removes 1
        _setup_remote(
            workspace,
            [
                _make_entry(entry_id="keep", zh_body=zh_body, en_body=en_body),
                _make_entry(entry_id="delete-me", zh_body=zh_body, en_body=en_body),
            ],
        )
        overlay = workspace.overlay_remove_entry("delete-me")
        workspace.write_overlay(overlay)

        # Also need remote dir for compatibility check
        remote_dir = workspace.remote_dir

        temp = workspace.root / "temp"
        workspace.build_publish_workspace(temp)

        errors = run_preflight_validation(
            workspace_dir=temp,
            documents_dir=workspace.documents_dir,
            remote_dir=remote_dir,
            check_remote=True,
        )
        assert any("exists on remote but not in staging" in e for e in errors)

    def test_unchanged_remote_bodies_not_required_locally(self, workspace: AnnouncementWorkspace):
        """Publish scenario: remote entries keep their bodies on the remote.

        Only the newly staged entry's bodies are stored locally; preflight
        must not demand local copies of unchanged remote bodies.
        """
        old_entry = _make_entry(entry_id="old-entry", zh_body="old zh", en_body="old en")
        _setup_remote(workspace, [old_entry])

        new_entry = _make_entry(entry_id="new-entry", zh_body="new zh", en_body="new en")
        workspace.store_document("new zh")
        workspace.store_document("new en")
        overlay = workspace.overlay_upsert_entry(ACTIVE_KEY, new_entry)
        workspace.write_overlay(overlay)

        temp = workspace.root / "temp"
        workspace.build_publish_workspace(temp)
        errors = run_preflight_validation(
            workspace_dir=temp,
            documents_dir=workspace.documents_dir,
            remote_dir=workspace.remote_dir,
            check_remote=True,
        )
        assert errors == []

    def test_changed_body_still_required_locally(self, workspace: AnnouncementWorkspace):
        """Editing an entry's body requires the new body in documents/."""
        old_entry = _make_entry(entry_id="edit-me", zh_body="old zh", en_body="old en")
        _setup_remote(workspace, [old_entry])

        edited = _make_entry(entry_id="edit-me", zh_body="revised zh", en_body="old en")
        overlay = workspace.overlay_upsert_entry(ACTIVE_KEY, edited)
        workspace.write_overlay(overlay)

        temp = workspace.root / "temp"
        workspace.build_publish_workspace(temp)
        errors = run_preflight_validation(
            workspace_dir=temp,
            documents_dir=workspace.documents_dir,
            remote_dir=workspace.remote_dir,
            check_remote=True,
        )
        zh_hash = edited.localizations["zh"].body_hash
        assert any(f"body {zh_hash} not found" in e for e in errors)
        assert not any("edit-me/en" in e for e in errors)


# ---------------------------------------------------------------------------
# Status diff tests
# ---------------------------------------------------------------------------


class TestComputeStatusDiff:
    @pytest.fixture
    def tmp_root(self) -> Path:
        d = tempfile.mkdtemp(prefix="efa-anno-diff-")
        yield Path(d)
        import shutil

        shutil.rmtree(d, ignore_errors=True)

    @pytest.fixture
    def workspace(self, tmp_root: Path) -> AnnouncementWorkspace:
        ws = AnnouncementWorkspace(tmp_root)
        ws.ensure_remote_directories()
        return ws

    def test_no_difference(self, workspace: AnnouncementWorkspace):
        _setup_remote(workspace, [_make_entry(entry_id="e1", zh_body="b", en_body="b")])
        temp = workspace.root / "temp"
        workspace.build_publish_workspace(temp)
        diff = compute_status_diff(workspace.remote_dir, temp)
        assert diff["summary"]["added"] == 0
        assert diff["summary"]["removed"] == 0
        assert diff["summary"]["modified"] == 0

    def test_added_detected(self, workspace: AnnouncementWorkspace):
        _setup_remote(workspace, [_make_entry(entry_id="r1", zh_body="b", en_body="b")])
        e = _make_entry(entry_id="s1", zh_body="b", en_body="b")
        overlay = workspace.overlay_upsert_entry(ACTIVE_KEY, e)
        workspace.write_overlay(overlay)
        temp = workspace.root / "temp"
        workspace.build_publish_workspace(temp)
        diff = compute_status_diff(workspace.remote_dir, temp)
        assert diff["summary"]["added"] == 1

    def test_removed_detected(self, workspace: AnnouncementWorkspace):
        _setup_remote(
            workspace,
            [
                _make_entry(entry_id="r1", zh_body="b", en_body="b"),
                _make_entry(entry_id="r2", zh_body="b", en_body="b"),
            ],
        )
        overlay = workspace.overlay_remove_entry("r2")
        workspace.write_overlay(overlay)
        temp = workspace.root / "temp"
        workspace.build_publish_workspace(temp)
        diff = compute_status_diff(workspace.remote_dir, temp)
        assert diff["summary"]["removed"] == 1

    def test_modified_detected(self, workspace: AnnouncementWorkspace):
        _setup_remote(
            workspace,
            [_make_entry(entry_id="r1", zh_title="Old", zh_body="b", en_body="b")],
        )
        e = _make_entry(entry_id="r1", zh_title="New", zh_body="b", en_body="b")
        overlay = workspace.overlay_upsert_entry(ACTIVE_KEY, e)
        workspace.write_overlay(overlay)
        temp = workspace.root / "temp"
        workspace.build_publish_workspace(temp)
        diff = compute_status_diff(workspace.remote_dir, temp)
        assert diff["summary"]["modified"] == 1


# ---------------------------------------------------------------------------
# Document ID pattern / roundtrip / hashing
# ---------------------------------------------------------------------------


class TestDocumentIdPattern:
    def test_valid_ids(self):
        import re

        pattern = re.compile(DOCUMENT_ID_PATTERN)
        assert pattern.fullmatch("a")
        assert pattern.fullmatch("test-123")
        assert pattern.fullmatch("v1.0.0")
        assert pattern.fullmatch("hello_world")
        assert pattern.fullmatch("abc.def-ghi_jkl")

    def test_invalid_ids(self):
        import re

        pattern = re.compile(DOCUMENT_ID_PATTERN)
        assert pattern.fullmatch("") is None
        assert pattern.fullmatch("-test") is None
        assert pattern.fullmatch("ABC") is None
        assert pattern.fullmatch("has space") is None


class TestJsonRoundtrip:
    def test_entry_roundtrip(self):
        entry = _make_entry(
            entry_id="roundtrip",
            tags=["welcome"],
            channels=["testing"],
            platforms=["android"],
            min_app_version="0.1.0",
            max_app_version="2.0.0",
        )
        data = entry.model_dump(mode="json", by_alias=True)
        parsed = AnnouncementEntry.model_validate(data)
        assert parsed.id == entry.id

    def test_entry_json_aliases(self):
        entry = _make_entry(entry_id="alias-test")
        data = entry.model_dump(mode="json", by_alias=True)
        assert "publishedAt" in data
        assert "published_at" not in data
        assert "bodyHash" in data["localizations"]["zh"]


class TestDocumentHashing:
    @pytest.fixture
    def tmp_root(self) -> Path:
        d = tempfile.mkdtemp(prefix="efa-anno-hash-")
        yield Path(d)
        import shutil

        shutil.rmtree(d, ignore_errors=True)

    @pytest.fixture
    def workspace(self, tmp_root: Path) -> AnnouncementWorkspace:
        return AnnouncementWorkspace(tmp_root)

    def test_sha256_compatibility(self, workspace: AnnouncementWorkspace):
        body = "test content\n"
        stored = workspace.store_document(body)
        expected = hashlib.sha256(body.encode("utf-8")).hexdigest()
        assert stored == expected
        assert len(stored) == 64

    def test_different_content_different_hash(self, workspace: AnnouncementWorkspace):
        h1 = workspace.store_document("A")
        h2 = workspace.store_document("B")
        assert h1 != h2
