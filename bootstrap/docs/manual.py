"""Build the bundled user-manual registry from docs/manual sources.

Source layout::

    docs/manual/
      folder.yaml              # optional root metadata (children order only)
      {folder-id}/
        folder.yaml            # id, name (zh/en), optional description (zh/en), children order
        {doc-id}/
          zh.md                # frontmatter: optional title/summary overrides
          en.md
"""

from __future__ import annotations

import hashlib
import re
import shutil

from dataclasses import dataclass
from dataclasses import field
from typing import TYPE_CHECKING

import frontmatter
import yaml

from pydantic import BaseModel
from pydantic import ConfigDict
from pydantic import Field
from pydantic import ValidationError

from bootstrap.constant import ASSETS_ROOT
from bootstrap.constant import PROJECT_ROOT
from bootstrap.docs.document_parser import parse_markdown_text
from bootstrap.log import info


if TYPE_CHECKING:
    from pathlib import Path


MANUAL_SOURCE_ROOT = PROJECT_ROOT / "docs" / "manual"

GENERATED_ROOT = ASSETS_ROOT / "content" / "manual" / "generated"
GENERATED_REGISTRY_PATH = GENERATED_ROOT / "manual.pb"
GENERATED_CONTENT_ROOT = GENERATED_ROOT / "content"
GENERATED_GITIGNORE_PATH = GENERATED_ROOT / ".gitignore"
CONTENT_GITKEEP_PATH = GENERATED_CONTENT_ROOT / ".gitkeep"

GENERATED_GITIGNORE_CONTENT = "*\n!.gitignore\n!content/\ncontent/*\n!content/.gitkeep\n"

MANUAL_REGISTRY_SCHEMA_VERSION = 1
ID_PATTERN = re.compile(r"^[a-z0-9][a-z0-9-]*$")
REQUIRED_LOCALES = ("zh", "en")
FRONTMATTER_ALLOWED_KEYS = {"title", "summary"}


class ManualFolderMetadata(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id: str
    name: dict[str, str] = Field(default_factory=dict)
    description: dict[str, str] = Field(default_factory=dict)
    children: list[str] = Field(default_factory=list)


class ManualRootMetadata(BaseModel):
    model_config = ConfigDict(extra="forbid")

    children: list[str] = Field(default_factory=list)


@dataclass(frozen=True)
class ManualDocLocalization:
    locale: str
    title: str
    summary: str
    body_markdown: str
    content_hash: str

    @property
    def content_file(self) -> str:
        return f"{self.content_hash}.md"


@dataclass
class ManualDocNode:
    id: str
    order: int
    localizations: dict[str, ManualDocLocalization] = field(default_factory=dict)


@dataclass
class ManualFolderNode:
    id: str
    order: int
    name: dict[str, str] = field(default_factory=dict)
    description: dict[str, str] = field(default_factory=dict)
    folders: list[ManualFolderNode] = field(default_factory=list)
    docs: list[ManualDocNode] = field(default_factory=list)


def content_file_hash(doc_id: str, locale: str) -> str:
    """Content file name hash: sha256("{doc_id}:{locale}"), full lowercase hex."""
    return hashlib.sha256(f"{doc_id}:{locale}".encode()).hexdigest()


def _load_yaml_mapping(path: Path) -> dict:
    if not path.exists():
        raise FileNotFoundError(f"Metadata file not found: {path}")
    raw = yaml.safe_load(path.read_text(encoding="utf-8"))
    if raw is None:
        raw = {}
    if not isinstance(raw, dict):
        raise TypeError(f"Metadata file must contain a YAML mapping: {path}")
    return raw


def _load_folder_metadata(path: Path) -> ManualFolderMetadata:
    raw = _load_yaml_mapping(path)
    try:
        return ManualFolderMetadata.model_validate(raw)
    except ValidationError as exception:
        raise ValueError(f"Invalid folder metadata in '{path}': {exception}") from exception


def _load_root_metadata(path: Path) -> ManualRootMetadata:
    raw = _load_yaml_mapping(path)
    try:
        return ManualRootMetadata.model_validate(raw)
    except ValidationError as exception:
        raise ValueError(f"Invalid root metadata in '{path}': {exception}") from exception


def _validate_entry_id(entry_id: str, directory: Path, path: Path) -> None:
    if not ID_PATTERN.match(entry_id):
        raise ValueError(
            f"Invalid manual entry id {entry_id!r} (must match {ID_PATTERN.pattern}): {path}"
        )
    if entry_id != directory.name:
        raise ValueError(
            f"Manual entry id {entry_id!r} does not match directory {directory.name!r}: {path}"
        )


def _require_locales(mapping: dict[str, str], path: Path, field_name: str) -> None:
    for locale in REQUIRED_LOCALES:
        if locale not in mapping:
            raise ValueError(f"Missing required locale {locale!r} in {field_name}: {path}")


def _resolve_children_order(directory: Path, declared: list[str]) -> list[str]:
    """Return child directory names in display order.

    When ``declared`` (the parent's ``children`` list) is non-empty it must
    match the actual child directory names exactly; otherwise children are
    ordered alphabetically.
    """
    actual = sorted(
        child.name
        for child in directory.iterdir()
        if child.is_dir() and not child.name.startswith(".")
    )
    if not declared:
        return actual
    if len(declared) != len(set(declared)):
        raise ValueError(f"Duplicate entries in children list: {directory}")
    unknown = sorted(set(declared) - set(actual))
    missing = sorted(set(actual) - set(declared))
    if unknown or missing:
        parts = []
        if unknown:
            parts.append(f"unknown: {', '.join(unknown)}")
        if missing:
            parts.append(f"missing: {', '.join(missing)}")
        raise ValueError(f"Children list mismatch in {directory} ({'; '.join(parts)})")
    return list(declared)


def _load_doc(directory: Path, parent_id: str, order: int, seen_ids: set[str]) -> ManualDocNode:
    _validate_entry_id(directory.name, directory, directory)
    doc_id = f"{parent_id}/{directory.name}" if parent_id else directory.name
    if doc_id in seen_ids:
        raise ValueError(f"Duplicate manual doc id: {doc_id!r}")
    seen_ids.add(doc_id)

    localizations: dict[str, ManualDocLocalization] = {}
    for locale in REQUIRED_LOCALES:
        file_path = directory / f"{locale}.md"
        if not file_path.exists():
            raise ValueError(f"Missing required locale file: {file_path}")

        post = frontmatter.load(file_path)
        unknown_keys = set(post.metadata) - FRONTMATTER_ALLOWED_KEYS
        if unknown_keys:
            raise ValueError(
                f"Unknown frontmatter keys {sorted(unknown_keys)} "
                f"(allowed: {sorted(FRONTMATTER_ALLOWED_KEYS)}): {file_path}"
            )

        parsed = parse_markdown_text(post.content, locale, file_path)
        title = post.metadata.get("title", parsed.title)
        summary = post.metadata.get("summary", parsed.summary)
        if not isinstance(title, str) or not isinstance(summary, str):
            raise TypeError(f"Frontmatter title/summary must be strings: {file_path}")

        localizations[locale] = ManualDocLocalization(
            locale=locale,
            title=title,
            summary=summary,
            body_markdown=parsed.body_markdown,
            content_hash=content_file_hash(doc_id, locale),
        )

    return ManualDocNode(id=doc_id, order=order, localizations=localizations)


def _load_folder(
    directory: Path, parent_id: str, order: int, seen_ids: set[str]
) -> ManualFolderNode:
    spec_path = directory / "folder.yaml"
    metadata = _load_folder_metadata(spec_path)

    _validate_entry_id(metadata.id, directory, spec_path)
    _require_locales(metadata.name, spec_path, "name")

    folder_id = f"{parent_id}/{metadata.id}" if parent_id else metadata.id
    if folder_id in seen_ids:
        raise ValueError(f"Duplicate manual folder id: {folder_id!r}")
    seen_ids.add(folder_id)

    node = ManualFolderNode(
        id=folder_id, order=order, name=dict(metadata.name), description=dict(metadata.description)
    )
    _load_children(directory, folder_id, seen_ids, node, metadata.children)
    return node


def _load_children(
    directory: Path,
    parent_id: str,
    seen_ids: set[str],
    parent: ManualFolderNode,
    declared_children: list[str],
) -> None:
    for order, child_name in enumerate(_resolve_children_order(directory, declared_children)):
        child = directory / child_name
        if (child / "folder.yaml").exists():
            parent.folders.append(_load_folder(child, parent_id, order, seen_ids))
        elif (child / "zh.md").exists() or (child / "en.md").exists():
            if not parent_id:
                raise ValueError(f"Top-level doc not allowed; wrap it in a folder: {child}")
            parent.docs.append(_load_doc(child, parent_id, order, seen_ids))
        else:
            raise ValueError(
                f"Directory is neither a folder (folder.yaml) nor a doc (zh.md/en.md): {child}"
            )


def load_manual_tree() -> ManualFolderNode:
    """Load and validate the full docs/manual tree into an in-memory root node."""
    root = ManualFolderNode(id="", order=0, name={})
    seen_ids: set[str] = set()
    if MANUAL_SOURCE_ROOT.exists():
        declared: list[str] = []
        root_spec = MANUAL_SOURCE_ROOT / "folder.yaml"
        if root_spec.exists():
            declared = _load_root_metadata(root_spec).children
        _load_children(MANUAL_SOURCE_ROOT, "", seen_ids, root, declared)
    return root


def _prepare_generated_root() -> None:
    GENERATED_ROOT.mkdir(parents=True, exist_ok=True)
    GENERATED_CONTENT_ROOT.mkdir(parents=True, exist_ok=True)
    GENERATED_GITIGNORE_PATH.write_text(GENERATED_GITIGNORE_CONTENT, encoding="utf-8")
    CONTENT_GITKEEP_PATH.write_text("", encoding="utf-8")

    for path in GENERATED_ROOT.iterdir():
        if path.name in (".gitignore", "content"):
            continue
        if path.is_file():
            path.unlink()
        elif path.is_dir():
            shutil.rmtree(path)

    for path in GENERATED_CONTENT_ROOT.iterdir():
        if path.name == ".gitkeep":
            continue
        if path.is_file():
            path.unlink()
        elif path.is_dir():
            shutil.rmtree(path)


def _write_content(localization: ManualDocLocalization) -> None:
    path = GENERATED_CONTENT_ROOT / localization.content_file
    if path.exists():
        return
    path.write_text(localization.body_markdown, encoding="utf-8")


def _iter_docs(node: ManualFolderNode):
    yield from node.docs
    for folder in node.folders:
        yield from _iter_docs(folder)


def _fill_folder(node: ManualFolderNode, message) -> None:
    for folder in node.folders:
        child = message.folders.add()
        child.id = folder.id
        child.order = folder.order
        for locale, name in sorted(folder.name.items()):
            child.name[locale] = name
        for locale, description in sorted(folder.description.items()):
            child.description[locale] = description
        _fill_folder(folder, child)
    for doc in node.docs:
        entry = message.docs.add()
        entry.id = doc.id
        entry.order = doc.order
        for locale, localization in sorted(doc.localizations.items()):
            loc = entry.localizations[locale]
            loc.title = localization.title
            loc.summary = localization.summary
            loc.content_file = localization.content_file


def build_manual() -> None:
    """Build the bundled manual registry and content files from docs/manual."""
    from bootstrap.data.schema import manual_pb2

    info("Building bundled manual...")
    root = load_manual_tree()
    _prepare_generated_root()

    doc_count = 0
    for doc in _iter_docs(root):
        doc_count += 1
        for localization in doc.localizations.values():
            _write_content(localization)

    registry = manual_pb2.ManualRegistry()
    registry.schema_version = MANUAL_REGISTRY_SCHEMA_VERSION
    _fill_folder(root, registry)

    GENERATED_REGISTRY_PATH.write_bytes(registry.SerializeToString())
    info(f"Generated bundled manual registry ({doc_count} docs): {GENERATED_REGISTRY_PATH}")
