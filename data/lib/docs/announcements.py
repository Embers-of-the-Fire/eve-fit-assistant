from __future__ import annotations

import datetime as dt
import hashlib
import json
import re

from dataclasses import dataclass
from typing import TYPE_CHECKING
from typing import Annotated
from typing import Any

import yaml

from pydantic import BaseModel
from pydantic import ConfigDict
from pydantic import Field
from pydantic import TypeAdapter
from pydantic import ValidationError

from data.lib.constant import ASSETS_ROOT
from data.lib.log import error
from data.lib.log import info
from data.lib.log import warning


if TYPE_CHECKING:
    from pathlib import Path


ANNOUNCEMENTS_ROOT = ASSETS_ROOT / "content" / "announcements"
AUTHORED_LOCALES = ("zh", "en")
GENERATED_ROOT = ANNOUNCEMENTS_ROOT / "generated"
GENERATED_CATALOG_PATH = GENERATED_ROOT / "catalog.json"
GENERATED_DOCUMENTS_ROOT = GENERATED_ROOT / "documents"
GENERATED_GITIGNORE_PATH = GENERATED_ROOT / ".gitignore"
GENERATED_GITIGNORE_CONTENT = "*\n!.gitignore\n!documents/\ndocuments/*\n!documents/.gitkeep\n"
DOCUMENTS_GITKEEP_PATH = GENERATED_DOCUMENTS_ROOT / ".gitkeep"
BUNDLED_PAGE_UUID = "00000000-0000-0000-0000-000000000001"
BUNDLED_PAGE_MAX_ENTRIES = 50
DOCUMENT_ID_PATTERN = r"^[a-z0-9][a-z0-9._-]*$"
SEMVER_PATTERN = (
    r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)"
    r"(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)"
    r"(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?"
    r"(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$"
)
DOCUMENT_ID_TYPE = Annotated[str, Field(pattern=DOCUMENT_ID_PATTERN)]


class AnnouncementSourceMetadata(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id: DOCUMENT_ID_TYPE
    published_at: Annotated[dt.datetime, Field(alias="publishedAt")]
    tags: list[str] = Field(default_factory=list)
    startup: bool = False
    channels: list[str] = Field(default_factory=list)
    platforms: list[str] = Field(default_factory=list)
    min_app_version: Annotated[str | None, Field(alias="minAppVersion")] = None
    max_app_version: Annotated[str | None, Field(alias="maxAppVersion")] = None
    app_version: Annotated[str | None, Field(alias="appVersion")] = None


class LocalizedAnnouncementStub(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id: DOCUMENT_ID_TYPE


ANNOUNCEMENT_METADATA_ADAPTER = TypeAdapter(AnnouncementSourceMetadata)


@dataclass(frozen=True)
class ParsedAnnouncementDocument:
    source_path: Path
    id: str
    title: str
    summary: str
    body_markdown: str
    body_hash: str


@dataclass(frozen=True)
class AuthoredAnnouncementEntry:
    document: ParsedAnnouncementDocument
    metadata: AnnouncementSourceMetadata | None = None


def build_bundled_announcements() -> None:
    info("Building bundled announcement assets...")
    authored_entries = _load_authored_announcements()
    _prepare_generated_root()

    authored_entries.sort(
        key=lambda e: e["zh"].metadata.id if e["zh"].metadata else e["zh"].document.id
    )

    page_entries: list[dict[str, Any]] = []
    channel_union: set[str] = set()
    min_app_version = "0.0.0"
    latest_published_at: dt.datetime | None = None

    for entry in authored_entries:
        zh_entry = entry["zh"]
        en_entry = entry.get("en")

        zh_document = zh_entry.document
        en_document = en_entry.document if en_entry is not None else zh_document
        metadata = zh_entry.metadata

        if metadata is None:
            message = f"Zh announcement '{zh_document.id}' is missing required metadata."
            error(message)
            raise ValueError(message)

        _write_generated_body(zh_document.body_hash, zh_document.body_markdown)
        en_body_hash_differs = en_document.body_hash != zh_document.body_hash
        if en_body_hash_differs:
            _write_generated_body(en_document.body_hash, en_document.body_markdown)

        page_entries.append(
            {
                "id": zh_document.id,
                "publishedAt": _serialize_published_at(metadata.published_at),
                "tags": metadata.tags,
                "startup": metadata.startup,
                "minAppVersion": metadata.min_app_version,
                "maxAppVersion": metadata.max_app_version,
                "channels": metadata.channels,
                "platforms": metadata.platforms,
                "appVersion": metadata.app_version,
                "localizations": {
                    "zh": {
                        "title": zh_document.title,
                        "summary": zh_document.summary,
                        "bodyHash": zh_document.body_hash,
                    },
                    "en": {
                        "title": en_document.title,
                        "summary": en_document.summary,
                        "bodyHash": en_document.body_hash,
                    },
                },
            }
        )

        channel_union.update(metadata.channels)
        if metadata.min_app_version is not None and metadata.min_app_version < min_app_version:
            min_app_version = metadata.min_app_version

        if latest_published_at is None or metadata.published_at > latest_published_at:
            latest_published_at = metadata.published_at

    if not page_entries:
        warning("No bundled announcements to build.")

    if latest_published_at is None:
        latest_published_at = dt.datetime(2026, 1, 1, tzinfo=dt.UTC)

    page_uuid = BUNDLED_PAGE_UUID
    page_published_at = _serialize_published_at(latest_published_at)

    catalog: dict[str, Any] = {
        "schemaVersion": 1,
        "pages": [
            {
                "uuid": page_uuid,
                "publishedAt": page_published_at,
                "minAppVersion": min_app_version,
                "channels": sorted(channel_union),
                "count": len(page_entries),
                "active": True,
            }
        ],
        "bundledPage": {
            "uuid": page_uuid,
            "publishedAt": page_published_at,
            "maxEntries": BUNDLED_PAGE_MAX_ENTRIES,
            "entries": page_entries,
        },
    }

    GENERATED_CATALOG_PATH.write_text(
        json.dumps(catalog, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    info(f"Generated bundled announcement catalog: {GENERATED_CATALOG_PATH}")
    info(
        f"  Entries: {len(page_entries)}, Documents: {len(list(GENERATED_DOCUMENTS_ROOT.rglob('*.md')))}"
    )


def _load_authored_announcements() -> list[dict[str, AuthoredAnnouncementEntry]]:
    entries: dict[str, dict[str, AuthoredAnnouncementEntry]] = {}
    locale_documents: dict[str, dict[str, ParsedAnnouncementDocument]] = {}

    for locale in AUTHORED_LOCALES:
        locale_dir = ANNOUNCEMENTS_ROOT / locale
        if not locale_dir.exists():
            continue

        locale_documents[locale] = {}
        for file_path in sorted(locale_dir.glob("*.md")):
            front_matter, markdown_body = _parse_front_matter(file_path)
            metadata = _parse_source_metadata(file_path, front_matter) if locale == "zh" else None
            document_id = (
                metadata.id
                if metadata is not None
                else _parse_localized_stub(file_path, front_matter).id
            )
            body_hash = _compute_body_hash(markdown_body)
            title, summary, body_markdown = _extract_announcement_content(file_path, markdown_body)
            parsed = ParsedAnnouncementDocument(
                source_path=file_path,
                id=document_id,
                title=title,
                summary=summary,
                body_markdown=body_markdown,
                body_hash=body_hash,
            )

            if document_id in entries:
                entries[document_id][locale] = AuthoredAnnouncementEntry(
                    document=parsed,
                    metadata=metadata,
                )
            else:
                entries[document_id] = {
                    locale: AuthoredAnnouncementEntry(
                        document=parsed,
                        metadata=metadata,
                    ),
                }

            locale_documents[locale][document_id] = parsed

    for document_id in locale_documents.get("en", {}):
        if document_id not in locale_documents.get("zh", {}):
            message = (
                f"English announcement '{document_id}' is missing a matching zh base announcement."
            )
            error(message)
            raise ValueError(message)

    for document_id in locale_documents.get("zh", {}):
        if "zh" not in entries.get(document_id, {}):
            message = (
                f"Chinese announcement '{document_id}' has no metadata; this should not happen."
            )
            error(message)
            raise ValueError(message)

    result = []
    for document_id in sorted(entries):
        result.append(entries[document_id])
    return result


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
            message = f"Unexpected directory inside generated announcements: {path}"
            error(message)
            raise ValueError(message)

    for path in GENERATED_DOCUMENTS_ROOT.iterdir():
        if path.name == ".gitkeep":
            continue
        if path.is_file():
            path.unlink()
        elif path.is_dir():
            message = f"Unexpected directory inside generated announcement documents: {path}"
            error(message)
            raise ValueError(message)


def _compute_body_hash(markdown_body: str) -> str:
    encoded = markdown_body.encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def _parse_front_matter(file_path: Path) -> tuple[dict[str, Any], str]:
    content = file_path.read_text(encoding="utf-8")
    if not content.startswith("---\n"):
        message = f"Announcement '{file_path}' is missing YAML front matter."
        error(message)
        raise ValueError(message)

    parts = content.split("\n---\n", 1)
    if len(parts) != 2:
        message = f"Announcement '{file_path}' has invalid YAML front matter boundaries."
        error(message)
        raise ValueError(message)

    raw_front_matter = parts[0][len("---\n") :]
    remaining = parts[1]
    data = yaml.safe_load(raw_front_matter)
    if data is None:
        data = {}
    if not isinstance(data, dict):
        message = f"Announcement '{file_path}' front matter must be a YAML mapping."
        error(message)
        raise ValueError(message)
    return data, remaining.lstrip("\n")


def _parse_source_metadata(
    file_path: Path, front_matter: dict[str, Any]
) -> AnnouncementSourceMetadata:
    normalized = dict(front_matter)
    if "minAppVersion" in normalized and not isinstance(normalized["minAppVersion"], str):
        normalized["minAppVersion"] = str(normalized["minAppVersion"])
    if "maxAppVersion" in normalized and not isinstance(normalized["maxAppVersion"], str):
        normalized["maxAppVersion"] = str(normalized["maxAppVersion"])
    if "appVersion" in normalized and not isinstance(normalized["appVersion"], str):
        normalized["appVersion"] = str(normalized["appVersion"])

    try:
        return ANNOUNCEMENT_METADATA_ADAPTER.validate_python(normalized)
    except ValidationError as exception:
        message = f"Invalid zh announcement metadata in '{file_path}': {exception}"
        error(message)
        raise ValueError(message) from exception


def _parse_localized_stub(
    file_path: Path, front_matter: dict[str, Any]
) -> LocalizedAnnouncementStub:
    try:
        return LocalizedAnnouncementStub.model_validate(front_matter)
    except ValidationError as exception:
        message = f"Invalid localized announcement stub in '{file_path}': {exception}"
        error(message)
        raise ValueError(message) from exception


def _extract_announcement_content(file_path: Path, markdown_body: str) -> tuple[str, str, str]:
    content = markdown_body.lstrip()
    lines = content.splitlines()

    title_index = next((index for index, line in enumerate(lines) if line.strip()), None)
    if title_index is None:
        message = f"Announcement '{file_path}' has an empty markdown body."
        error(message)
        raise ValueError(message)

    title_line = lines[title_index].strip()
    if not title_line.startswith("# "):
        message = (
            f"Announcement '{file_path}' must start with a level-1 heading after front matter."
        )
        error(message)
        raise ValueError(message)

    title = title_line[2:].strip()
    body_lines = lines[title_index + 1 :]
    while body_lines and not body_lines[0].strip():
        body_lines.pop(0)

    body_markdown = "\n".join(body_lines).strip()
    if not body_markdown:
        message = f"Announcement '{file_path}' has no body after removing the title heading."
        error(message)
        raise ValueError(message)

    summary = _extract_summary(body_markdown)
    if not summary:
        message = f"Announcement '{file_path}' is missing a summary paragraph after the title."
        error(message)
        raise ValueError(message)

    return title, summary, body_markdown + "\n"


def _extract_summary(body_markdown: str) -> str | None:
    paragraphs = re.split(r"\n\s*\n", body_markdown.strip())
    for block in paragraphs:
        stripped = block.strip()
        if not stripped or stripped.startswith(("#", "```")):
            continue
        if stripped.startswith(("- ", "* ", "+ ")) or re.match(r"\d+\.\s", stripped):
            continue
        return " ".join(line.strip() for line in stripped.splitlines()).strip()

    for line in body_markdown.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith(("#", "```")):
            continue
        if stripped.startswith(("- ", "* ", "+ ")):
            return stripped[2:].strip()
        if re.match(r"\d+\.\s", stripped):
            return re.sub(r"^\d+\.\s+", "", stripped).strip()
        return stripped
    return None


def _write_generated_body(body_hash: str, body_markdown: str) -> str:
    output_file = GENERATED_DOCUMENTS_ROOT / f"{body_hash}.md"
    if output_file.exists():
        return _relative_body_path(output_file)

    output_file.write_text(body_markdown, encoding="utf-8")
    info(f"Generated announcement body: {output_file}")
    return _relative_body_path(output_file)


def _relative_body_path(output_file: Path) -> str:
    try:
        return output_file.relative_to(ASSETS_ROOT.parent).as_posix()
    except ValueError:
        return output_file.as_posix()


def _serialize_published_at(published_at: dt.datetime) -> str:
    if published_at.tzinfo is None or published_at.utcoffset() is None:
        message = f"publishedAt must include a timezone offset: {published_at.isoformat()}"
        error(message)
        raise ValueError(message)

    return published_at.astimezone(dt.UTC).isoformat().replace("+00:00", "Z")
