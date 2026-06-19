"""Remote announcement workspace management.

Provides CLI workspace for authoring, validating, and publishing
remote announcements served via the EFA V2 remote content endpoint.

Workspace structure:
    cache/announce/
    ├── remote/                       # Last-known server state
    │   ├── catalog.json
    │   ├── active.json               # Active (filling) page, 0-19 entries
    │   └── pages/
    │       └── {uuid}.json           # Archived pages, exactly 20 entries
    ├── staging.json                  # Delta overlay on top of remote
    └── documents/                    # Shared body files (content-addressed)
        └── {bodyHash}.md

Staging is a delta overlay, not a mirror.  add / edit / remove modify
staging.json.  On publish, a full workspace is constructed in a temp
directory by applying the overlay to the remote state; rotation (chunking
into 20-entry archived pages) happens during construction.
"""

from __future__ import annotations

import contextlib
import hashlib
import json
import re
import shutil
import subprocess
import uuid as _uuid

from datetime import UTC
from datetime import datetime
from typing import TYPE_CHECKING
from typing import Any
from urllib.request import Request
from urllib.request import urlopen

from pydantic import BaseModel
from pydantic import ConfigDict
from pydantic import Field
from pydantic import field_validator


if TYPE_CHECKING:
    from pathlib import Path


DOCUMENT_ID_PATTERN = r"^[a-z0-9][a-z0-9._-]*$"
ACTIVE_KEY = "active"


# ---------------------------------------------------------------------------
# Data models
# ---------------------------------------------------------------------------


class AnnouncementCatalog(BaseModel):
    model_config = ConfigDict(extra="forbid", populate_by_name=True)

    schema_version: int = Field(alias="schemaVersion", default=1)
    pages: list[AnnouncementCatalogPage]


class AnnouncementCatalogPage(BaseModel):
    model_config = ConfigDict(extra="forbid", populate_by_name=True)

    uuid: str
    published_at: str = Field(alias="publishedAt")
    min_app_version: str = Field(alias="minAppVersion", default="0.0.0")
    channels: list[str] = Field(default_factory=list)
    count: int = 0
    active: bool = False


class AnnouncementPage(BaseModel):
    model_config = ConfigDict(extra="forbid", populate_by_name=True)

    uuid: str
    published_at: str = Field(alias="publishedAt")
    max_entries: int = Field(alias="maxEntries", default=50)
    entries: list[AnnouncementEntry]


class AnnouncementEntry(BaseModel):
    model_config = ConfigDict(extra="forbid", populate_by_name=True)

    id: str
    published_at: str = Field(alias="publishedAt")
    tags: list[str] = Field(default_factory=list)
    startup: bool = False
    min_app_version: str | None = Field(alias="minAppVersion", default=None)
    max_app_version: str | None = Field(alias="maxAppVersion", default=None)
    channels: list[str] = Field(default_factory=list)
    platforms: list[str] = Field(default_factory=list)
    app_version: str | None = Field(alias="appVersion", default=None)
    localizations: dict[str, AnnouncementLocalization]

    @field_validator("id")
    @classmethod
    def validate_id(cls, v: str) -> str:
        if not re.match(DOCUMENT_ID_PATTERN, v):
            raise ValueError(f"Invalid entry ID: {v!r} (must match {DOCUMENT_ID_PATTERN})")
        return v


class AnnouncementLocalization(BaseModel):
    model_config = ConfigDict(extra="forbid", populate_by_name=True)

    title: str
    summary: str
    body_hash: str = Field(alias="bodyHash")


class StagingOverlay(BaseModel):
    """Delta overlay recording local changes on top of the remote state.

    Key = page UUID, or ``"active"`` for the active filling page.
    Value = dict of entryId → full AnnouncementEntry (add/edit) or None (remove).
    """

    model_config = ConfigDict(extra="forbid", populate_by_name=True)

    schema_version: int = Field(alias="schemaVersion", default=1)
    pages: dict[str, dict[str, AnnouncementEntry | None]] = Field(default_factory=dict)


class PreflightError(Exception):
    """Raised when preflight validation fails."""


# ---------------------------------------------------------------------------
# AnnouncementWorkspace
# ---------------------------------------------------------------------------


class AnnouncementWorkspace:
    """Manages the announcement workspace (remote mirror + staging overlay)."""

    def __init__(self, root: Path) -> None:
        self.root = root
        self.remote_dir = root / "remote"
        self.documents_dir = root / "documents"
        self._overlay_path = root / "staging.json"

    def ensure_remote_directories(self) -> None:
        """Create remote/ and documents/ directories if they don't exist."""
        self.remote_dir.mkdir(parents=True, exist_ok=True)
        (self.remote_dir / "pages").mkdir(exist_ok=True)
        self.documents_dir.mkdir(parents=True, exist_ok=True)

    # -- overlay I/O -----------------------------------------------------------

    def read_overlay(self) -> StagingOverlay:
        """Read the staging overlay. Returns an empty overlay if the file doesn't exist."""
        if not self._overlay_path.exists():
            return StagingOverlay()
        data = json.loads(self._overlay_path.read_text(encoding="utf-8"))
        return StagingOverlay.model_validate(data)

    def write_overlay(self, overlay: StagingOverlay) -> None:
        """Write the staging overlay to disk."""
        self._overlay_path.parent.mkdir(parents=True, exist_ok=True)
        self._overlay_path.write_text(
            json.dumps(overlay.model_dump(mode="json", by_alias=True), indent=2, ensure_ascii=False)
            + "\n",
            encoding="utf-8",
        )

    def clear_overlay(self) -> None:
        """Reset the overlay to empty."""
        self.write_overlay(StagingOverlay())

    # -- overlay helpers -------------------------------------------------------

    def overlay_upsert_entry(self, page_key: str, entry: AnnouncementEntry) -> StagingOverlay:
        """Add or edit an entry in the overlay for a given page key.

        Returns the updated overlay (not yet written to disk).
        """
        overlay = self.read_overlay()
        page_overlay = overlay.pages.setdefault(page_key, {})
        page_overlay[entry.id] = entry
        return overlay

    def overlay_remove_entry(self, entry_id: str) -> StagingOverlay:
        """Mark an entry for removal from the active page.

        If the entry was added this session (already in overlay), drops it
        from the overlay entirely.  Otherwise sets it to None (removal marker).
        """
        overlay = self.read_overlay()
        active_overlay = overlay.pages.setdefault(ACTIVE_KEY, {})
        if entry_id in active_overlay and active_overlay[entry_id] is not None:
            # Entry was added this session — just drop it
            del active_overlay[entry_id]
        else:
            active_overlay[entry_id] = None
        return overlay

    def get_effective_entry_ids(self, page_key: str) -> set[str]:
        """Return the set of entry IDs that will exist in *page_key* after applying overlay.

        Looks up remote first, then applies overlay for that page.
        """
        if not (self.remote_dir / "catalog.json").exists():
            return set()

        if page_key == ACTIVE_KEY:
            try:
                page = self._read_active(self.remote_dir)
            except FileNotFoundError:
                return set()
        else:
            try:
                page = self._read_page(self.remote_dir, page_key)
            except FileNotFoundError:
                return set()

        ids = {e.id for e in page.entries}
        overlay = self.read_overlay()
        page_overlay = overlay.pages.get(page_key, {})
        for eid, value in page_overlay.items():
            if value is None:
                ids.discard(eid)
            else:
                ids.add(eid)
        return ids

    # -- catalog / page / active I/O -------------------------------------------

    def _read_catalog(self, workspace_dir: Path) -> AnnouncementCatalog:
        path = workspace_dir / "catalog.json"
        if not path.exists():
            raise FileNotFoundError(f"Catalog not found: {path}")
        data = json.loads(path.read_text(encoding="utf-8"))
        return AnnouncementCatalog.model_validate(data)

    def _write_catalog(self, workspace_dir: Path, catalog: AnnouncementCatalog) -> None:
        path = workspace_dir / "catalog.json"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            json.dumps(catalog.model_dump(mode="json", by_alias=True), indent=2, ensure_ascii=False)
            + "\n",
            encoding="utf-8",
        )

    def _read_page(self, workspace_dir: Path, uuid: str) -> AnnouncementPage:
        path = workspace_dir / "pages" / f"{uuid}.json"
        if not path.exists():
            raise FileNotFoundError(f"Page not found: {path}")
        data = json.loads(path.read_text(encoding="utf-8"))
        return AnnouncementPage.model_validate(data)

    def _write_page(self, workspace_dir: Path, page: AnnouncementPage) -> None:
        path = workspace_dir / "pages" / f"{page.uuid}.json"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            json.dumps(page.model_dump(mode="json", by_alias=True), indent=2, ensure_ascii=False)
            + "\n",
            encoding="utf-8",
        )

    def _read_active(self, workspace_dir: Path) -> AnnouncementPage:
        path = workspace_dir / "active.json"
        if not path.exists():
            raise FileNotFoundError(f"Active page not found: {path}")
        data = json.loads(path.read_text(encoding="utf-8"))
        return AnnouncementPage.model_validate(data)

    def _write_active(self, workspace_dir: Path, page: AnnouncementPage) -> None:
        path = workspace_dir / "active.json"
        path.write_text(
            json.dumps(page.model_dump(mode="json", by_alias=True), indent=2, ensure_ascii=False)
            + "\n",
            encoding="utf-8",
        )

    def _get_active_uuid(self, workspace_dir: Path) -> str | None:
        try:
            catalog = self._read_catalog(workspace_dir)
        except FileNotFoundError:
            return None
        for page in catalog.pages:
            if page.active:
                return page.uuid
        return None

    def _read_any_page(self, workspace_dir: Path, uuid: str) -> AnnouncementPage:
        active_uuid = self._get_active_uuid(workspace_dir)
        if uuid == active_uuid:
            return self._read_active(workspace_dir)
        return self._read_page(workspace_dir, uuid)

    # -- remote convenience ----------------------------------------------------

    def get_remote_catalog(self) -> AnnouncementCatalog:
        return self._read_catalog(self.remote_dir)

    def get_remote_page(self) -> AnnouncementPage:
        return self._read_active(self.remote_dir)

    def get_remote_active_uuid(self) -> str | None:
        return self._get_active_uuid(self.remote_dir)

    # -- build publish workspace -----------------------------------------------

    def build_publish_workspace(self, temp_dir: Path) -> None:
        """Construct the full workspace in *temp_dir* by applying the overlay to remote.

        Copies remote/ → temp_dir, then:
        - Applies archived-page edits from the overlay.
        - Applies active-page adds / edits / removals.
        - Handles rotation: if the active page has ≥ 20 entries it is chunked
          into 20-entry archived pages, leaving the remainder (< 20) as the new
          active page.
        """
        overlay = self.read_overlay()

        # Copy remote/ to temp/
        if temp_dir.exists():
            shutil.rmtree(temp_dir)
        shutil.copytree(self.remote_dir, temp_dir)

        # 1. Apply overlay to archived pages
        for page_key, page_overlay in overlay.pages.items():
            if page_key == ACTIVE_KEY:
                continue
            try:
                page = self._read_page(temp_dir, page_key)
            except FileNotFoundError:
                continue
            entries_by_id = {e.id: e for e in page.entries}
            for eid, value in page_overlay.items():
                if value is not None:
                    entries_by_id[eid] = value
                else:
                    entries_by_id.pop(eid, None)
            page.entries = sorted(
                entries_by_id.values(), key=lambda e: e.published_at, reverse=True
            )
            self._write_page(temp_dir, page)

        # 2. Apply overlay to active page
        active_uuid = self._get_active_uuid(temp_dir)
        if active_uuid is None:
            raise RuntimeError("Remote has no active page — cannot construct workspace")

        active_page = self._read_active(temp_dir)
        active_overlay = overlay.pages.get(ACTIVE_KEY, {})

        entries_by_id = {e.id: e for e in active_page.entries}
        for eid, value in active_overlay.items():
            if value is None:
                entries_by_id.pop(eid, None)
            else:
                entries_by_id[eid] = value

        all_entries = sorted(entries_by_id.values(), key=lambda e: e.published_at, reverse=True)

        # 3. Rotation: chunk into pages of 20
        temp_catalog = self._read_catalog(temp_dir)

        if len(all_entries) >= 20:
            chunks = [all_entries[i : i + 20] for i in range(0, len(all_entries), 20)]

            # Remove old active from catalog + pages/
            temp_catalog.pages = [p for p in temp_catalog.pages if p.uuid != active_uuid]
            old_active_path = temp_dir / "pages" / f"{active_uuid}.json"
            if old_active_path.exists():
                old_active_path.unlink()

            now = datetime.now(UTC).isoformat().replace("+00:00", "Z")

            for chunk in chunks[:-1]:
                self._add_archived_page(temp_dir, temp_catalog, chunk, now)

            last_chunk = chunks[-1]
            if len(last_chunk) == 20:
                self._add_archived_page(temp_dir, temp_catalog, last_chunk, now)
                new_active = AnnouncementPage(
                    uuid=str(_uuid.uuid4()),
                    published_at=now,
                    max_entries=50,
                    entries=[],
                )
                temp_catalog.pages.append(
                    _make_catalog_page(new_active.uuid, now, count=0, active=True)
                )
                self._write_active(temp_dir, new_active)
            else:
                new_active = AnnouncementPage(
                    uuid=str(_uuid.uuid4()),
                    published_at=now,
                    max_entries=50,
                    entries=last_chunk,
                )
                temp_catalog.pages.append(
                    _make_catalog_page(new_active.uuid, now, count=len(last_chunk), active=True)
                )
                self._write_active(temp_dir, new_active)
        else:
            # No rotation — just update
            active_page.entries = all_entries
            self._write_active(temp_dir, active_page)
            for p in temp_catalog.pages:
                if p.uuid == active_uuid:
                    p.count = len(all_entries)
                    break

        self._write_catalog(temp_dir, temp_catalog)

    def _add_archived_page(
        self,
        temp_dir: Path,
        catalog: AnnouncementCatalog,
        entries: list[AnnouncementEntry],
        now: str,
    ) -> None:
        archive_uuid = str(_uuid.uuid4())
        archive_page = AnnouncementPage(
            uuid=archive_uuid,
            published_at=now,
            max_entries=50,
            entries=entries,
        )
        self._write_page(temp_dir, archive_page)
        catalog.pages.append(_make_catalog_page(archive_uuid, now, count=20, active=False))

    # -- document I/O ----------------------------------------------------------

    def store_document(self, body: str) -> str:
        """Store a document body and return its SHA-256 hash."""
        body_hash = hashlib.sha256(body.encode("utf-8")).hexdigest()
        doc_path = self.documents_dir / f"{body_hash}.md"
        if not doc_path.exists():
            doc_path.parent.mkdir(parents=True, exist_ok=True)
            doc_path.write_text(body, encoding="utf-8")
        return body_hash

    def get_document(self, body_hash: str) -> str:
        """Get a document body by its hash."""
        doc_path = self.documents_dir / f"{body_hash}.md"
        if not doc_path.exists():
            raise FileNotFoundError(f"Document not found: {doc_path}")
        return doc_path.read_text(encoding="utf-8")

    def verify_document_hash(self, body_hash: str, documents_dir: Path | None = None) -> bool:
        """Verify that a document's content hashes to its filename."""
        dd = documents_dir or self.documents_dir
        doc_path = dd / f"{body_hash}.md"
        if not doc_path.exists():
            return False
        content = doc_path.read_text(encoding="utf-8")
        actual_hash = hashlib.sha256(content.encode("utf-8")).hexdigest()
        return actual_hash == body_hash


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _make_catalog_page(
    uuid: str,
    published_at: str,
    *,
    count: int,
    active: bool,
    channels: list[str] | None = None,
    min_app_version: str = "0.0.0",
) -> AnnouncementCatalogPage:
    return AnnouncementCatalogPage(
        uuid=uuid,
        published_at=published_at,
        min_app_version=min_app_version,
        channels=channels or [],
        count=count,
        active=active,
    )


# ---------------------------------------------------------------------------
# Preflight validation
# ---------------------------------------------------------------------------


def run_preflight_validation(
    workspace_dir: Path,
    documents_dir: Path,
    *,
    remote_dir: Path | None = None,
    check_remote: bool = True,
) -> list[str]:
    """Run preflight validation on a constructed workspace directory.

    *workspace_dir* is typically a temp directory built by
    ``AnnouncementWorkspace.build_publish_workspace()``.

    Returns a list of error messages.  Empty list means validation passed.
    """
    errors: list[str] = []

    # Check 1: catalog.json exists and is valid JSON
    catalog_path = workspace_dir / "catalog.json"
    if not catalog_path.exists():
        errors.append("catalog.json is missing")
        return errors
    try:
        catalog_data = json.loads(catalog_path.read_text(encoding="utf-8"))
        catalog = AnnouncementCatalog.model_validate(catalog_data)
    except (json.JSONDecodeError, ValueError) as e:
        errors.append(f"catalog.json is invalid JSON or model: {e}")
        return errors

    # Check 2: catalog.schemaVersion == 1
    if catalog.schema_version != 1:
        errors.append(f"catalog.json: unsupported schemaVersion {catalog.schema_version}")

    # Check 3: Exactly one active page
    active_pages = [p for p in catalog.pages if p.active]
    if len(active_pages) != 1:
        errors.append(f"catalog.json: expected exactly 1 active page, found {len(active_pages)}")

    # Check 4 + 12: Every inactive page has pages/{uuid}.json with exactly 20 entries
    active_uuid = active_pages[0].uuid if active_pages else None
    for page_meta in catalog.pages:
        if page_meta.active:
            continue
        page_path = workspace_dir / "pages" / f"{page_meta.uuid}.json"
        if not page_path.exists():
            errors.append(
                f"page {page_meta.uuid} listed in catalog but "
                f"pages/{page_meta.uuid}.json is missing"
            )
        else:
            try:
                page_data = json.loads(page_path.read_text(encoding="utf-8"))
                archived_page = AnnouncementPage.model_validate(page_data)
                n = len(archived_page.entries)
                if n != 20:
                    errors.append(
                        f"page {page_meta.uuid} in pages/ has {n} entries; "
                        f"archived pages must have exactly 20"
                    )
            except (json.JSONDecodeError, ValueError) as e:
                errors.append(f"Failed to load archived page {page_meta.uuid}: {e}")

    # Check 5: active.json must exist
    active_path = workspace_dir / "active.json"
    if active_uuid and not active_path.exists():
        errors.append("active.json is missing")

    # Check 13: Active page ≤ 20 entries
    if active_uuid and active_path.exists():
        try:
            active_data = json.loads(active_path.read_text(encoding="utf-8"))
            active_page = AnnouncementPage.model_validate(active_data)
            if len(active_page.entries) > 20:
                errors.append(
                    f"active page has {len(active_page.entries)} entries; "
                    f"expected ≤ 20 (preflight check)"
                )
        except (json.JSONDecodeError, ValueError) as e:
            errors.append(f"Failed to load active.json: {e}")

    # Check 6-10: Entry-level validations across all pages
    ws = _FakeWorkspaceRead(workspace_dir)
    for page_meta in catalog.pages:
        page_uuid = page_meta.uuid
        try:
            page = ws._read_any_page(workspace_dir, page_uuid)
        except Exception as e:
            errors.append(f"Failed to load page {page_uuid}: {e}")
            continue

        seen_ids: set[str] = set()
        for entry in page.entries:
            entry_id = entry.id

            # Check 10: No duplicate entry IDs
            if entry_id in seen_ids:
                errors.append(f"page {page_uuid}: duplicate entry id '{entry_id}'")
            seen_ids.add(entry_id)

            for locale in ("zh", "en"):
                if locale not in entry.localizations:
                    errors.append(f"entry {entry_id}: missing locale {locale}")
                    continue

                loc = entry.localizations[locale]

                if not loc.title:
                    errors.append(f"entry {entry_id}/{locale}: title is empty")
                if not loc.summary:
                    errors.append(f"entry {entry_id}/{locale}: summary is empty")
                if not loc.body_hash:
                    errors.append(f"entry {entry_id}/{locale}: bodyHash is empty")

                doc_path = documents_dir / f"{loc.body_hash}.md"
                if not doc_path.exists():
                    errors.append(
                        f"entry {entry_id}/{locale}: body {loc.body_hash} not found in documents/"
                    )
                    continue

                actual_hash = hashlib.sha256(doc_path.read_bytes()).hexdigest()
                if actual_hash != loc.body_hash:
                    errors.append(
                        f"documents/{loc.body_hash}.md: content hash mismatch "
                        f"(expected {loc.body_hash}, got {actual_hash})"
                    )

    # Check 11: Remote compatibility
    if check_remote and remote_dir is not None:
        errors.extend(
            _run_remote_compatibility_check(
                remote_dir=remote_dir,
                workspace_dir=workspace_dir,
            )
        )

    return errors


class _FakeWorkspaceRead:
    """Minimal helper so preflight can read pages from an arbitrary directory."""

    def __init__(self, root: Path) -> None:
        self._root = root

    def _read_catalog(self, workspace_dir: Path) -> AnnouncementCatalog:
        path = workspace_dir / "catalog.json"
        data = json.loads(path.read_text(encoding="utf-8"))
        return AnnouncementCatalog.model_validate(data)

    def _read_page(self, workspace_dir: Path, uuid: str) -> AnnouncementPage:
        path = workspace_dir / "pages" / f"{uuid}.json"
        data = json.loads(path.read_text(encoding="utf-8"))
        return AnnouncementPage.model_validate(data)

    def _read_active(self, workspace_dir: Path) -> AnnouncementPage:
        path = workspace_dir / "active.json"
        data = json.loads(path.read_text(encoding="utf-8"))
        return AnnouncementPage.model_validate(data)

    def _get_active_uuid(self, workspace_dir: Path) -> str | None:
        catalog = self._read_catalog(workspace_dir)
        for p in catalog.pages:
            if p.active:
                return p.uuid
        return None

    def _read_any_page(self, workspace_dir: Path, uuid: str) -> AnnouncementPage:
        active_uuid = self._get_active_uuid(workspace_dir)
        if uuid == active_uuid:
            return self._read_active(workspace_dir)
        return self._read_page(workspace_dir, uuid)


def _run_remote_compatibility_check(
    *,
    remote_dir: Path,
    workspace_dir: Path,
) -> list[str]:
    """Check that publishing won't delete entries present on remote."""
    errors: list[str] = []

    remote_catalog_path = remote_dir / "catalog.json"
    if not remote_catalog_path.exists():
        errors.append("remote/catalog.json is missing — run `sync` first")
        return errors

    try:
        remote_catalog_data = json.loads(remote_catalog_path.read_text(encoding="utf-8"))
        remote_catalog = AnnouncementCatalog.model_validate(remote_catalog_data)
    except Exception as e:
        errors.append(f"failed to load remote catalog: {e}")
        return errors

    ws_remote = _FakeWorkspaceRead(remote_dir)
    ws_temp = _FakeWorkspaceRead(workspace_dir)

    for remote_page_meta in remote_catalog.pages:
        remote_uuid = remote_page_meta.uuid
        try:
            remote_page = ws_remote._read_any_page(remote_dir, remote_uuid)
        except FileNotFoundError:
            errors.append(f"page {remote_uuid} listed in remote catalog but file is missing")
            continue

        remote_ids = {e.id for e in remote_page.entries}

        try:
            staging_page = ws_temp._read_any_page(workspace_dir, remote_uuid)
            staging_ids = {e.id for e in staging_page.entries}
        except FileNotFoundError:
            staging_ids = set()

        only_on_remote = remote_ids - staging_ids
        for entry_id in sorted(only_on_remote):
            remote_entry = next(e for e in remote_page.entries if e.id == entry_id)
            zh_title = (
                remote_entry.localizations["zh"].title if "zh" in remote_entry.localizations else ""
            )
            en_title = (
                remote_entry.localizations["en"].title if "en" in remote_entry.localizations else ""
            )
            errors.append(
                f"entry {entry_id} exists on remote but not in staging "
                f'(zh:"{zh_title}" en:"{en_title}" — run `sync` and `add`/`edit` to recover)'
            )

    return errors


# ---------------------------------------------------------------------------
# AnnouncementRemoteSync
# ---------------------------------------------------------------------------


class AnnouncementRemoteSync:
    """Handles sync and publish operations with remote storage."""

    def __init__(
        self,
        workspace: AnnouncementWorkspace,
        target: str,
        endpoint: str,
        bucket: str,
        access_key: str,
        secret_key: str,
        alias_name: str,
        resource_root: str = "efa/v2",
    ) -> None:
        self.workspace = workspace
        self.target = target
        self.endpoint = endpoint
        self.bucket = bucket
        self.access_key = access_key
        self.secret_key = secret_key
        self.alias_name = alias_name
        self.resource_root = resource_root.rstrip("/")

    def _build_url(self, path: str) -> str:
        return f"{self.endpoint.rstrip('/')}/{self.bucket}/{self.resource_root}/{path.lstrip('/')}"

    def _download_json(self, path: str) -> dict[str, Any]:
        url = self._build_url(path)
        req = Request(url)
        try:
            with urlopen(req, timeout=30) as response:
                if response.status != 200:
                    raise RuntimeError(f"HTTP {response.status} for {url}")
                return json.loads(response.read().decode("utf-8"))
        except Exception as e:
            raise RuntimeError(f"Failed to download {url}: {e}") from e

    def _download_file(self, path: str) -> bytes:
        url = self._build_url(path)
        req = Request(url)
        try:
            with urlopen(req, timeout=30) as response:
                if response.status != 200:
                    raise RuntimeError(f"HTTP {response.status} for {url}")
                return response.read()
        except Exception as e:
            raise RuntimeError(f"Failed to download {url}: {e}") from e

    def sync(self, full: bool = False) -> None:
        """Sync remote state to local workspace."""
        self.workspace.ensure_remote_directories()

        # Download catalog.json
        try:
            catalog_data = self._download_json("announcements/catalog.json")
            catalog = AnnouncementCatalog.model_validate(catalog_data)
        except Exception as e:
            raise RuntimeError(f"Failed to download catalog.json: {e}") from e

        (self.workspace.remote_dir / "catalog.json").write_text(
            json.dumps(catalog.model_dump(mode="json", by_alias=True), indent=2, ensure_ascii=False)
            + "\n",
            encoding="utf-8",
        )

        # Download each archived page
        for page_meta in catalog.pages:
            if page_meta.active:
                continue
            try:
                page_data = self._download_json(f"announcements/pages/{page_meta.uuid}.json")
                page = AnnouncementPage.model_validate(page_data)
                page_path = self.workspace.remote_dir / "pages" / f"{page_meta.uuid}.json"
                page_path.parent.mkdir(parents=True, exist_ok=True)
                page_path.write_text(
                    json.dumps(
                        page.model_dump(mode="json", by_alias=True),
                        indent=2,
                        ensure_ascii=False,
                    )
                    + "\n",
                    encoding="utf-8",
                )
            except Exception as e:
                raise RuntimeError(f"Failed to download page {page_meta.uuid}: {e}") from e

        # Download active.json
        try:
            active_data = self._download_json("announcements/active.json")
            active = AnnouncementPage.model_validate(active_data)
            (self.workspace.remote_dir / "active.json").write_text(
                json.dumps(
                    active.model_dump(mode="json", by_alias=True),
                    indent=2,
                    ensure_ascii=False,
                )
                + "\n",
                encoding="utf-8",
            )
        except Exception as e:
            raise RuntimeError(f"Failed to download active.json: {e}") from e

        # If --full, download all document bodies
        if full:
            for page_meta in catalog.pages:
                page = self.workspace._read_any_page(self.workspace.remote_dir, page_meta.uuid)
                for entry in page.entries:
                    for loc in entry.localizations.values():
                        body_hash = loc.body_hash
                        doc_path = self.workspace.documents_dir / f"{body_hash}.md"
                        if doc_path.exists():
                            continue
                        try:
                            content = self._download_file(f"announcements/documents/{body_hash}.md")
                            doc_path.write_bytes(content)
                        except Exception as e:
                            raise RuntimeError(
                                f"Failed to download document {body_hash}: {e}"
                            ) from e

    def init_remote(self, force: bool = False) -> None:
        """Initialize a new empty announcement workspace on the remote.

        Creates a fresh catalog.json + active.json locally, then uploads
        them.  Fails if the remote already has a catalog unless *force*
        is True.
        """
        self.workspace.ensure_remote_directories()

        # Check if remote already has content (unless --force)
        if not force:
            try:
                self._download_json("announcements/catalog.json")
            except Exception:
                pass  # download failed (404, etc.) → remote is empty, proceed
            else:
                raise RuntimeError(
                    "Remote already has an announcement catalog. Use --force to overwrite."
                )

        page_uuid = str(_uuid.uuid4())
        now = datetime.now(UTC).isoformat().replace("+00:00", "Z")

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

        # Write locally
        self.workspace._write_catalog(self.workspace.remote_dir, catalog)
        self.workspace._write_active(self.workspace.remote_dir, page)

        # Upload
        uploads: list[tuple[Path, str]] = [
            (self.workspace.remote_dir / "catalog.json", "announcements/catalog.json"),
            (self.workspace.remote_dir / "active.json", "announcements/active.json"),
        ]

        mc_bin = "mc"
        alias_target = f"{self.alias_name}/{self.bucket}"

        for local_path, remote_path in uploads:
            target_url = f"{alias_target}/{self.resource_root}/{remote_path}"
            cmd = [mc_bin, "cp", str(local_path), target_url]
            result = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8")
            if result.returncode != 0:
                raise RuntimeError(f"Failed to upload {local_path}: {result.stderr}")

    def publish_dir(self, publish_dir: Path, dry_run: bool = False) -> None:
        """Upload a constructed workspace directory to remote.

        *publish_dir* should be the output of
        ``AnnouncementWorkspace.build_publish_workspace()``.
        """
        documents_dir = self.workspace.documents_dir

        files_to_upload: list[tuple[Path, str]] = [
            (publish_dir / "catalog.json", "announcements/catalog.json"),
            (publish_dir / "active.json", "announcements/active.json"),
        ]

        for page_file in (publish_dir / "pages").glob("*.json"):
            remote_path = f"announcements/pages/{page_file.name}"
            files_to_upload.append((page_file, remote_path))

        catalog = self.workspace._read_catalog(publish_dir)
        for page_meta in catalog.pages:
            page = self.workspace._read_any_page(publish_dir, page_meta.uuid)
            for entry in page.entries:
                for loc in entry.localizations.values():
                    doc_path = documents_dir / f"{loc.body_hash}.md"
                    if doc_path.exists():
                        remote_path = f"announcements/documents/{loc.body_hash}.md"
                        files_to_upload.append((doc_path, remote_path))

        if dry_run:
            deduped = {(str(lp), rp) for lp, rp in files_to_upload}
            for local_path, remote_path in sorted(deduped, key=lambda x: x[1]):
                print(f"Would upload: {local_path} → {remote_path}")
            return

        mc_bin = "mc"
        alias_target = f"{self.alias_name}/{self.bucket}"
        seen: set[str] = set()

        for local_path, remote_path in files_to_upload:
            if not local_path.exists():
                continue
            key = str(local_path) + remote_path
            if key in seen:
                continue
            seen.add(key)
            target_url = f"{alias_target}/{self.resource_root}/{remote_path}"
            cmd = [mc_bin, "cp", str(local_path), target_url]
            result = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8")
            if result.returncode != 0:
                raise RuntimeError(f"Failed to upload {local_path}: {result.stderr}")


# ---------------------------------------------------------------------------
# Status diff
# ---------------------------------------------------------------------------


def _compute_page_diff(
    remote_page: AnnouncementPage | None,
    staging_page: AnnouncementPage | None,
) -> dict[str, Any]:
    """Compute diff for a single page pair."""
    remote_entries = {e.id: e for e in remote_page.entries} if remote_page else {}
    staging_entries = {e.id: e for e in staging_page.entries} if staging_page else {}

    added: list[dict[str, str]] = []
    removed: list[dict[str, str]] = []
    modified: list[dict[str, Any]] = []

    all_ids = set(remote_entries.keys()) | set(staging_entries.keys())

    for entry_id in all_ids:
        remote_entry = remote_entries.get(entry_id)
        staging_entry = staging_entries.get(entry_id)

        if staging_entry is None and remote_entry is not None:
            removed.append(
                {
                    "id": entry_id,
                    "zhTitle": remote_entry.localizations["zh"].title
                    if "zh" in remote_entry.localizations
                    else "",
                    "enTitle": remote_entry.localizations["en"].title
                    if "en" in remote_entry.localizations
                    else "",
                }
            )
        elif remote_entry is None and staging_entry is not None:
            added.append(
                {
                    "id": entry_id,
                    "zhTitle": staging_entry.localizations["zh"].title
                    if "zh" in staging_entry.localizations
                    else "",
                    "enTitle": staging_entry.localizations["en"].title
                    if "en" in staging_entry.localizations
                    else "",
                }
            )
        elif remote_entry is not None and staging_entry is not None:
            changes: dict[str, dict[str, str]] = {}
            for locale in ("zh", "en"):
                if (
                    locale not in remote_entry.localizations
                    or locale not in staging_entry.localizations
                ):
                    continue
                remote_loc = remote_entry.localizations[locale]
                staging_loc = staging_entry.localizations[locale]

                if remote_loc.title != staging_loc.title:
                    changes[f"{locale}.title"] = {
                        "from": remote_loc.title,
                        "to": staging_loc.title,
                    }
                if remote_loc.summary != staging_loc.summary:
                    changes[f"{locale}.summary"] = {
                        "from": remote_loc.summary,
                        "to": staging_loc.summary,
                    }
                if remote_loc.body_hash != staging_loc.body_hash:
                    changes[f"{locale}.bodyHash"] = {
                        "from": remote_loc.body_hash,
                        "to": staging_loc.body_hash,
                    }

            if remote_entry.published_at != staging_entry.published_at:
                changes["publishedAt"] = {
                    "from": remote_entry.published_at,
                    "to": staging_entry.published_at,
                }

            if changes:
                modified.append(
                    {
                        "id": entry_id,
                        "changes": changes,
                        "zhTitle": staging_entry.localizations["zh"].title
                        if "zh" in staging_entry.localizations
                        else "",
                        "enTitle": staging_entry.localizations["en"].title
                        if "en" in staging_entry.localizations
                        else "",
                    }
                )

    return {
        "added": added,
        "removed": removed,
        "modified": modified,
        "summary": {
            "added": len(added),
            "removed": len(removed),
            "modified": len(modified),
            "totalRemote": len(remote_entries),
            "totalStaging": len(staging_entries),
        },
    }


def compute_status_diff(
    remote_dir: Path,
    workspace_dir: Path,
) -> dict[str, Any]:
    """Compute diff between remote and a constructed workspace.

    *remote_dir* is the last-synced remote state.
    *workspace_dir* is a temp dir built by ``build_publish_workspace()``.
    """
    if not (remote_dir / "catalog.json").exists():
        raise RuntimeError("No remote state — run `sync` first.")

    remote_ws = _FakeWorkspaceRead(remote_dir)
    workspace_ws = _FakeWorkspaceRead(workspace_dir)

    remote_catalog = remote_ws._read_catalog(remote_dir)
    workspace_catalog = workspace_ws._read_catalog(workspace_dir)

    remote_pages_by_uuid: dict[str, AnnouncementPage] = {}
    for page_meta in remote_catalog.pages:
        with contextlib.suppress(FileNotFoundError):
            remote_pages_by_uuid[page_meta.uuid] = remote_ws._read_any_page(
                remote_dir, page_meta.uuid
            )

    staging_pages_by_uuid: dict[str, AnnouncementPage] = {}
    for page_meta in workspace_catalog.pages:
        with contextlib.suppress(FileNotFoundError):
            staging_pages_by_uuid[page_meta.uuid] = workspace_ws._read_any_page(
                workspace_dir, page_meta.uuid
            )

    all_uuids = set(remote_pages_by_uuid.keys()) | set(staging_pages_by_uuid.keys())

    pages: dict[str, dict[str, Any]] = {}
    global_summary: dict[str, int] = {
        "added": 0,
        "removed": 0,
        "modified": 0,
        "totalRemote": 0,
        "totalStaging": 0,
    }

    for uuid in sorted(all_uuids):
        diff = _compute_page_diff(
            remote_pages_by_uuid.get(uuid),
            staging_pages_by_uuid.get(uuid),
        )
        pages[uuid] = diff
        for key in ("added", "removed", "modified"):
            global_summary[key] += diff["summary"][key]
        global_summary["totalRemote"] += diff["summary"]["totalRemote"]
        global_summary["totalStaging"] += diff["summary"]["totalStaging"]

    return {"pages": pages, "summary": global_summary}
