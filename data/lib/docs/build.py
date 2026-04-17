from __future__ import annotations

import datetime as dt
import json
import re

from dataclasses import dataclass
from pathlib import Path
from typing import Annotated
from typing import Any
from typing import Literal

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


DATETIME_TYPE = dt.datetime
PATH_TYPE = Path


DOCUMENTS_ROOT = ASSETS_ROOT / "content" / "documents"
AUTHORED_LOCALES = ("zh", "en")
GENERATED_ROOT = DOCUMENTS_ROOT / "generated"
GENERATED_INDEX_PATH = GENERATED_ROOT / "index.json"
GENERATED_GITIGNORE_PATH = GENERATED_ROOT / ".gitignore"
GENERATED_GITIGNORE_CONTENT = "*\n!.gitignore\n"
DOCUMENT_ID_PATTERN = r"^[a-z0-9][a-z0-9_-]*$"
DOCUMENT_ID_TYPE = Annotated[str, Field(pattern=DOCUMENT_ID_PATTERN)]


class ZhDocumentBase(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id: DOCUMENT_ID_TYPE
    publishedAt: DATETIME_TYPE
    tags: list[str] = Field(default_factory=list)


class ZhAnnouncementDocument(ZhDocumentBase):
    kind: Literal["announcement"]
    startup: bool = False
    minAppVer: str | None = None
    appVer: None = None


class ZhInformationDocument(ZhDocumentBase):
    kind: Literal["information"]
    minAppVer: str | None = None
    appVer: None = None


class ZhVersionDocument(ZhDocumentBase):
    kind: Literal["version"]
    appVer: str
    minAppVer: None = None


ZhDocumentVariant = ZhAnnouncementDocument | ZhInformationDocument | ZhVersionDocument


ZhDocumentMetadata = Annotated[
    ZhDocumentVariant,
    Field(discriminator="kind"),
]

ZhAnnouncementDocument.model_rebuild()
ZhInformationDocument.model_rebuild()
ZhVersionDocument.model_rebuild()
ZH_DOCUMENT_METADATA_ADAPTER = TypeAdapter(ZhDocumentMetadata)
ZH_DOCUMENT_METADATA_ADAPTER.rebuild()


class LocalizedDocumentStub(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id: DOCUMENT_ID_TYPE


@dataclass(frozen=True)
class ParsedLocalizedDocument:
    source_path: PATH_TYPE
    id: str
    title: str
    summary: str
    body_markdown: str


@dataclass(frozen=True)
class AuthoredDocumentEntry:
    document: ParsedLocalizedDocument
    metadata: ZhDocumentVariant | None = None


def build_documents() -> None:
    info("Building document assets...")
    authored_documents = _load_authored_documents()
    _prepare_generated_root()

    entries: list[dict[str, Any]] = []
    for document_id in sorted(authored_documents["zh"]):
        zh_entry = authored_documents["zh"][document_id]
        en_entry = authored_documents["en"].get(document_id)
        zh_document = zh_entry.document
        en_document = en_entry.document if en_entry is not None else zh_document

        generated_localizations = {
            "zh": _write_generated_markdown("zh", document_id, zh_document.body_markdown),
            "en": _write_generated_markdown("en", document_id, en_document.body_markdown),
        }

        metadata = zh_entry.metadata
        if metadata is None:
            message = f"Zh document '{document_id}' is missing required metadata."
            error(message)
            raise ValueError(message)

        entries.append(
            {
                "id": document_id,
                "kind": metadata.kind,
                "source": "bundled",
                "publishedAt": _serialize_published_at(metadata.publishedAt),
                "tags": metadata.tags,
                "startup": getattr(metadata, "startup", False),
                "minAppVer": getattr(metadata, "minAppVer", None),
                "appVer": getattr(metadata, "appVer", None),
                "localizations": {
                    "zh": {
                        "title": zh_document.title,
                        "summary": zh_document.summary,
                        "bodyAssetPath": generated_localizations["zh"],
                    },
                    "en": {
                        "title": en_document.title,
                        "summary": en_document.summary,
                        "bodyAssetPath": generated_localizations["en"],
                    },
                },
            }
        )

    GENERATED_INDEX_PATH.write_text(
        json.dumps({"version": 1, "entries": entries}, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    info(f"Generated document registry: {GENERATED_INDEX_PATH}")


def _serialize_published_at(published_at: dt.datetime) -> str:
    if published_at.tzinfo is None or published_at.utcoffset() is None:
        message = f"Document publishedAt must include a timezone offset: {published_at.isoformat()}"
        error(message)
        raise ValueError(message)

    return published_at.astimezone(dt.UTC).isoformat().replace("+00:00", "Z")


def _load_authored_documents() -> dict[str, dict[str, AuthoredDocumentEntry]]:
    documents: dict[str, dict[str, AuthoredDocumentEntry]] = {
        locale: {} for locale in AUTHORED_LOCALES
    }

    for locale in AUTHORED_LOCALES:
        locale_dir = DOCUMENTS_ROOT / locale
        if not locale_dir.exists():
            continue

        for file_path in sorted(locale_dir.glob("*.md")):
            front_matter, markdown_body = _parse_front_matter(file_path)
            metadata = _parse_zh_metadata(file_path, front_matter) if locale == "zh" else None
            document_id = (
                metadata.id
                if metadata is not None
                else _parse_localized_stub(file_path, front_matter).id
            )
            parsed_document = _parse_localized_document(file_path, document_id, markdown_body)

            if parsed_document.id in documents[locale]:
                message = f"Duplicate document id '{parsed_document.id}' in locale '{locale}'."
                error(message)
                raise ValueError(message)

            documents[locale][parsed_document.id] = AuthoredDocumentEntry(
                document=parsed_document,
                metadata=metadata,
            )

    for document_id in documents["en"]:
        if document_id not in documents["zh"]:
            message = f"English document '{document_id}' is missing a matching zh base document."
            error(message)
            raise ValueError(message)

    return documents


def _prepare_generated_root() -> None:
    GENERATED_ROOT.mkdir(parents=True, exist_ok=True)
    GENERATED_GITIGNORE_PATH.write_text(GENERATED_GITIGNORE_CONTENT, encoding="utf-8")

    for path in GENERATED_ROOT.iterdir():
        if path.name == ".gitignore":
            continue
        if path.is_file():
            path.unlink()
        elif path.is_dir():
            message = f"Unexpected directory inside generated documents: {path}"
            error(message)
            raise ValueError(message)


def _parse_front_matter(file_path: Path) -> tuple[dict[str, Any], str]:
    content = file_path.read_text(encoding="utf-8")
    if not content.startswith("---\n"):
        message = f"Document '{file_path}' is missing YAML front matter."
        error(message)
        raise ValueError(message)

    parts = content.split("\n---\n", 1)
    if len(parts) != 2:
        message = f"Document '{file_path}' has invalid YAML front matter boundaries."
        error(message)
        raise ValueError(message)

    raw_front_matter = parts[0][len("---\n") :]
    remaining = parts[1]
    data = yaml.safe_load(raw_front_matter)
    if data is None:
        data = {}
    if not isinstance(data, dict):
        message = f"Document '{file_path}' front matter must be a YAML mapping."
        error(message)
        raise ValueError(message)
    return data, remaining.lstrip("\n")


def _parse_zh_metadata(file_path: Path, front_matter: dict[str, Any]) -> ZhDocumentVariant:
    normalized_front_matter = _normalize_zh_front_matter(file_path, front_matter)
    try:
        return ZH_DOCUMENT_METADATA_ADAPTER.validate_python(normalized_front_matter)
    except ValidationError as exception:
        message = f"Invalid zh document metadata in '{file_path}': {exception}"
        error(message)
        raise ValueError(message) from exception


def _normalize_zh_front_matter(file_path: Path, front_matter: dict[str, Any]) -> dict[str, Any]:
    kind = front_matter.get("kind")
    if kind == "announcement" or "startup" not in front_matter:
        return front_matter

    warning(
        f"Document '{file_path}' sets 'startup' on a non-announcement entry; ignoring the field."
    )
    normalized_front_matter = dict(front_matter)
    normalized_front_matter.pop("startup")
    return normalized_front_matter


def _parse_localized_stub(file_path: Path, front_matter: dict[str, Any]) -> LocalizedDocumentStub:
    try:
        return LocalizedDocumentStub.model_validate(front_matter)
    except ValidationError as exception:
        message = f"Invalid localized document stub in '{file_path}': {exception}"
        error(message)
        raise ValueError(message) from exception


def _parse_localized_document(
    file_path: Path,
    document_id: str,
    markdown_body: str,
) -> ParsedLocalizedDocument:
    title, summary, body_markdown = _extract_document_content(file_path, markdown_body)
    return ParsedLocalizedDocument(
        source_path=file_path,
        id=document_id,
        title=title,
        summary=summary,
        body_markdown=body_markdown,
    )


def _extract_document_content(file_path: Path, markdown_body: str) -> tuple[str, str, str]:
    content = markdown_body.lstrip()
    lines = content.splitlines()

    title_index = next((index for index, line in enumerate(lines) if line.strip()), None)
    if title_index is None:
        message = f"Document '{file_path}' has an empty markdown body."
        error(message)
        raise ValueError(message)

    title_line = lines[title_index].strip()
    if not title_line.startswith("# "):
        message = f"Document '{file_path}' must start with a level-1 heading after front matter."
        error(message)
        raise ValueError(message)

    title = title_line[2:].strip()
    body_lines = lines[title_index + 1 :]
    while body_lines and not body_lines[0].strip():
        body_lines.pop(0)

    body_markdown = "\n".join(body_lines).strip()
    if not body_markdown:
        message = f"Document '{file_path}' has no body after removing the title heading."
        error(message)
        raise ValueError(message)

    summary = _extract_summary(body_markdown)
    if not summary:
        message = f"Document '{file_path}' is missing a summary paragraph after the title heading."
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


def _write_generated_markdown(locale: str, document_id: str, body_markdown: str) -> str:
    output_file = GENERATED_ROOT / f"{locale}-{document_id}.md"
    output_file.write_text(body_markdown, encoding="utf-8")
    info(f"Generated document body: {output_file}")
    return output_file.relative_to(ASSETS_ROOT.parent).as_posix()
