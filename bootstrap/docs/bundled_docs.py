from __future__ import annotations

import datetime as dt
import hashlib
import json
import re
import shutil

from dataclasses import dataclass
from typing import TYPE_CHECKING

import yaml

from pydantic import BaseModel
from pydantic import ConfigDict
from pydantic import Field
from pydantic import ValidationError

from bootstrap.constant import ASSETS_ROOT
from bootstrap.constant import PROJECT_ROOT
from bootstrap.docs.announcements_remote import AnnouncementCatalogPage
from bootstrap.docs.announcements_remote import AnnouncementEntry
from bootstrap.docs.announcements_remote import AnnouncementPage
from bootstrap.log import info


if TYPE_CHECKING:
    from collections.abc import Iterable
    from pathlib import Path
    from typing import Any


DOCS_ROOT = PROJECT_ROOT / "docs"
ANNOUNCEMENTS_SOURCE_ROOT = DOCS_ROOT / "announcements"
CHANGELOG_SOURCE_ROOT = DOCS_ROOT / "changelog"

GENERATED_ROOT = ASSETS_ROOT / "content" / "announcements" / "generated"
GENERATED_CATALOG_PATH = GENERATED_ROOT / "catalog.json"
GENERATED_DOCUMENTS_ROOT = GENERATED_ROOT / "documents"
GENERATED_GITIGNORE_PATH = GENERATED_ROOT / ".gitignore"
DOCUMENTS_GITKEEP_PATH = GENERATED_DOCUMENTS_ROOT / ".gitkeep"

GENERATED_GITIGNORE_CONTENT = "*\n!.gitignore\n!documents/\ndocuments/*\n!documents/.gitkeep\n"

BUNDLED_PAGE_UUID = "00000000-0000-0000-0000-000000000001"
BUNDLED_PAGE_MAX_ENTRIES = 50
DOCUMENT_ID_PATTERN = r"^[a-z0-9][a-z0-9._-]*$"

_FALLBACK_PUBLISHED_AT = dt.datetime(2026, 1, 1, tzinfo=dt.UTC)

_SOURCE_TYPE_ANNOUNCEMENT = "announcement"
_SOURCE_TYPE_CHANGELOG = "changelog"


class BundledSourceMetadata(BaseModel):
    model_config = ConfigDict(extra="forbid", populate_by_name=True)

    id: str | None = None
    published_at: dt.datetime = Field(alias="publishedAt")
    tags: list[str] = Field(default_factory=list)
    startup: bool = False
    channels: list[str] = Field(default=["testing"])
    platforms: list[str] = Field(default=["android", "ios"])
    min_app_version: str | None = Field(alias="minAppVersion", default=None)
    max_app_version: str | None = Field(alias="maxAppVersion", default=None)
    app_version: str | None = Field(alias="appVersion", default=None)


def _normalize_version_dir(name: str) -> str:
    """Replace dots with hyphens and strip a leading 'version-' prefix."""
    name = name.replace(".", "-")
    return name.removeprefix("version-")


def _version_dir_to_entry_id(name: str) -> str:
    return f"version-{_normalize_version_dir(name)}"


def _iter_announcement_dirs() -> Iterable[tuple[str, Path]]:
    """Yield (id, directory path) for docs/announcements/<id>."""
    root = ANNOUNCEMENTS_SOURCE_ROOT
    if not root.exists():
        return
    for path in root.iterdir():
        if path.name.startswith(".") or not path.is_dir():
            continue
        yield path.name, path


def _iter_changelog_dirs() -> Iterable[tuple[str, Path]]:
    """Yield (normalized_version_dir, directory path) for docs/changelog/<dir>."""
    root = CHANGELOG_SOURCE_ROOT
    if not root.exists():
        return
    for path in root.iterdir():
        if path.name.startswith(".") or not path.is_dir():
            continue
        yield _normalize_version_dir(path.name), path


def _load_spec(path: Path) -> BundledSourceMetadata:
    """Load and validate a spec.yaml file."""
    if not path.exists():
        raise FileNotFoundError(f"Spec file not found: {path}")

    raw = yaml.safe_load(path.read_text(encoding="utf-8"))
    if raw is None:
        raw = {}
    if not isinstance(raw, dict):
        raise ValueError(f"Spec file must contain a YAML mapping: {path}")

    source_type = _detect_source_type(path)
    directory_name = path.parent.name

    try:
        metadata = BundledSourceMetadata.model_validate(raw)
    except ValidationError as exception:
        raise ValueError(f"Invalid spec metadata in '{path}': {exception}") from exception

    if source_type == _SOURCE_TYPE_ANNOUNCEMENT:
        if metadata.id is None:
            raise ValueError(f"Announcement spec must provide id: {path}")
        if metadata.id != directory_name:
            raise ValueError(
                f"Announcement id '{metadata.id}' does not match directory "
                f"'{directory_name}': {path}"
            )
    elif source_type == _SOURCE_TYPE_CHANGELOG:
        expected_id = _version_dir_to_entry_id(directory_name)
        if metadata.id is not None and metadata.id != expected_id:
            raise ValueError(
                f"Changelog id '{metadata.id}' does not match derived id '{expected_id}': {path}"
            )
        metadata.id = expected_id
        if metadata.app_version is None:
            raise ValueError(f"Changelog spec must provide appVersion: {path}")
        if not metadata.tags:
            metadata.tags = ["release-note"]

    return metadata


def _detect_source_type(path: Path) -> str:
    grandparent = path.parent.parent.name
    if grandparent == "announcements":
        return _SOURCE_TYPE_ANNOUNCEMENT
    if grandparent == "changelog":
        return _SOURCE_TYPE_CHANGELOG
    raise ValueError(f"Spec file is not inside announcements or changelog directory: {path}")


@dataclass(frozen=True)
class LocalizedDocument:
    locale: str
    source_path: Path
    title: str
    summary: str
    body_markdown: str
    body_hash: str


@dataclass(frozen=True)
class BundledEntry:
    id: str
    metadata: BundledSourceMetadata
    localizations: dict[str, LocalizedDocument]


def _load_general_announcement(entry_id: str, directory: Path) -> BundledEntry:
    spec = _load_spec(directory / "spec.yaml")
    if spec.id != entry_id:
        raise ValueError(f"spec id {spec.id!r} does not match directory {entry_id!r}")

    localizations: dict[str, LocalizedDocument] = {}
    for locale in ("zh", "en"):
        file_path = directory / f"{locale}.md"
        if not file_path.exists():
            raise ValueError(f"Missing required locale file: {file_path}")
        localizations[locale] = _parse_locale_document(file_path, locale)

    return BundledEntry(id=entry_id, metadata=spec, localizations=localizations)


def _parse_locale_document(path: Path, locale: str) -> LocalizedDocument:
    raw = path.read_text(encoding="utf-8")
    lines = raw.splitlines()

    title_index = next(
        (index for index, line in enumerate(lines) if line.strip().startswith("# ")),
        None,
    )
    if title_index is None:
        raise ValueError(f"Locale file is missing a level-1 heading: {path}")

    title = lines[title_index].strip()[2:].strip()
    body_lines = lines[title_index + 1 :]
    while body_lines and not body_lines[0].strip():
        body_lines.pop(0)

    body_text = "\n".join(body_lines).strip()
    if not body_text:
        raise ValueError(f"Locale file has no body after removing the title: {path}")

    summary = _extract_summary(body_text)
    if summary is None:
        raise ValueError(f"Locale file has no usable summary paragraph: {path}")

    body_markdown = body_text + "\n"
    body_hash = hashlib.sha256(body_markdown.encode("utf-8")).hexdigest()
    return LocalizedDocument(
        locale=locale,
        source_path=path,
        title=title,
        summary=summary,
        body_markdown=body_markdown,
        body_hash=body_hash,
    )


def _extract_summary(body_markdown: str) -> str | None:
    paragraphs = re.split(r"\n\s*\n", body_markdown.strip())
    for block in paragraphs:
        stripped = block.strip()
        if not stripped or stripped.startswith(("#", "```")):
            continue
        if stripped.startswith(("- ", "* ", "+ ")) or re.match(r"\d+\.\s", stripped):
            continue
        return " ".join(line.strip() for line in stripped.splitlines()).strip()
    return None


def _compose_release_body(human_body: str, changelog: str) -> str:
    human_body = human_body.strip()
    changelog = changelog.strip()
    parts = [human_body, "## Changelog", "", changelog]
    return "\n".join(parts).strip() + "\n"


def _load_release_note(version_dir_name: str, directory: Path) -> BundledEntry:
    entry_id = _version_dir_to_entry_id(version_dir_name)
    spec = _load_spec(directory / "spec.yaml")

    if spec.id is not None and spec.id != entry_id:
        raise ValueError(f"changelog spec id {spec.id!r} must be {entry_id!r}")

    if spec.app_version is None:
        raise ValueError(f"changelog {entry_id!r} is missing appVersion")

    if not spec.tags:
        spec = spec.model_copy(update={"tags": ["release-note"]})

    changelog_path = directory / "changelog.md"
    if not changelog_path.exists():
        raise ValueError(f"Missing required changelog file: {changelog_path}")
    changelog_body = changelog_path.read_text(encoding="utf-8")

    localizations: dict[str, LocalizedDocument] = {}
    for locale in ("zh", "en"):
        content_path = directory / f"content.{locale}.md"
        if not content_path.exists():
            raise ValueError(f"Missing required locale file: {content_path}")
        human_doc = _parse_locale_document(content_path, locale)
        composed_body = _compose_release_body(human_doc.body_markdown, changelog_body)
        composed_hash = hashlib.sha256(composed_body.encode("utf-8")).hexdigest()
        localizations[locale] = LocalizedDocument(
            locale=locale,
            source_path=content_path,
            title=human_doc.title,
            summary=human_doc.summary,
            body_markdown=composed_body,
            body_hash=composed_hash,
        )

    return BundledEntry(id=entry_id, metadata=spec, localizations=localizations)


def _prepare_generated_root() -> None:
    GENERATED_ROOT.mkdir(parents=True, exist_ok=True)
    GENERATED_DOCUMENTS_ROOT.mkdir(parents=True, exist_ok=True)
    GENERATED_GITIGNORE_PATH.write_text(GENERATED_GITIGNORE_CONTENT, encoding="utf-8")
    DOCUMENTS_GITKEEP_PATH.write_text("", encoding="utf-8")

    for path in GENERATED_ROOT.iterdir():
        if path.name in (".gitignore", "documents"):
            continue
        if path.is_file():
            path.unlink()
        elif path.is_dir():
            shutil.rmtree(path)

    for path in GENERATED_DOCUMENTS_ROOT.iterdir():
        if path.name == ".gitkeep":
            continue
        if path.is_file():
            path.unlink()
        elif path.is_dir():
            shutil.rmtree(path)


def _write_document(body_hash: str, body: str) -> None:
    path = GENERATED_DOCUMENTS_ROOT / f"{body_hash}.md"
    if path.exists():
        return
    path.write_text(body, encoding="utf-8")


def _serialize_published_at(published_at: dt.datetime) -> str:
    if published_at.tzinfo is None or published_at.utcoffset() is None:
        raise ValueError(f"publishedAt must include a timezone offset: {published_at.isoformat()}")
    return published_at.astimezone(dt.UTC).isoformat().replace("+00:00", "Z")


def _check_unique(entry: BundledEntry, seen_ids: set[str]) -> None:
    if entry.id in seen_ids:
        raise ValueError(f"Duplicate announcement entry id: {entry.id!r}")
    seen_ids.add(entry.id)


def _load_all_entries() -> list[BundledEntry]:
    entries: list[BundledEntry] = []
    seen_ids: set[str] = set()

    for entry_id, directory in _iter_announcement_dirs():
        entry = _load_general_announcement(entry_id, directory)
        _check_unique(entry, seen_ids)
        entries.append(entry)

    for version_dir_name, directory in _iter_changelog_dirs():
        entry = _load_release_note(version_dir_name, directory)
        _check_unique(entry, seen_ids)
        entries.append(entry)

    entries.sort(key=lambda e: e.metadata.published_at, reverse=True)
    return entries


def _build_catalog(entries: list[BundledEntry]) -> dict[str, Any]:
    has_unbounded = False
    min_app_version: str | None = None
    channels: set[str] = set()
    latest_published_at: dt.datetime | None = None

    for entry in entries:
        if entry.metadata.min_app_version is None:
            has_unbounded = True
        elif min_app_version is None or entry.metadata.min_app_version < min_app_version:
            min_app_version = entry.metadata.min_app_version

        channels.update(entry.metadata.channels)

        if latest_published_at is None or entry.metadata.published_at > latest_published_at:
            latest_published_at = entry.metadata.published_at

    page_min_app_version = "0.0.0" if has_unbounded or min_app_version is None else min_app_version

    if latest_published_at is None:
        latest_published_at = _FALLBACK_PUBLISHED_AT

    page_published_at = _serialize_published_at(latest_published_at)

    page_entries: list[dict[str, Any]] = []
    for entry in entries:
        localizations: dict[str, dict[str, str]] = {}
        for locale, document in entry.localizations.items():
            localizations[locale] = {
                "title": document.title,
                "summary": document.summary,
                "bodyHash": document.body_hash,
            }

        page_entries.append(
            {
                "id": entry.id,
                "publishedAt": _serialize_published_at(entry.metadata.published_at),
                "tags": entry.metadata.tags,
                "startup": entry.metadata.startup,
                "minAppVersion": entry.metadata.min_app_version,
                "maxAppVersion": entry.metadata.max_app_version,
                "channels": entry.metadata.channels,
                "platforms": entry.metadata.platforms,
                "appVersion": entry.metadata.app_version,
                "localizations": localizations,
            }
        )

    return {
        "schemaVersion": 1,
        "pages": [
            {
                "uuid": BUNDLED_PAGE_UUID,
                "publishedAt": page_published_at,
                "minAppVersion": page_min_app_version,
                "channels": sorted(channels),
                "count": len(entries),
                "active": True,
            }
        ],
        "bundledPage": {
            "uuid": BUNDLED_PAGE_UUID,
            "publishedAt": page_published_at,
            "maxEntries": BUNDLED_PAGE_MAX_ENTRIES,
            "entries": page_entries,
        },
    }


def build_bundled_docs() -> None:
    info("Building bundled docs...")
    entries = _load_all_entries()
    _prepare_generated_root()

    for entry in entries:
        for document in entry.localizations.values():
            _write_document(document.body_hash, document.body_markdown)

    catalog = _build_catalog(entries)

    AnnouncementCatalogPage.model_validate(catalog["pages"][0])
    AnnouncementPage.model_validate(catalog["bundledPage"])
    for entry in catalog["bundledPage"]["entries"]:
        AnnouncementEntry.model_validate(entry)

    GENERATED_CATALOG_PATH.write_text(
        json.dumps(catalog, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    info(f"Generated bundled docs catalog: {GENERATED_CATALOG_PATH}")
