"""Build the FTS5 full-text search index for the bundled user manual.

The index is a SQLite database with one FTS5 table per supported locale:

- ``manual_fts_zh`` uses the built-in ``trigram`` tokenizer, which enables
  substring matching for CJK text (queries of 3+ characters).
- ``manual_fts_en`` uses ``porter unicode61`` for word tokens with English
  stemming.

Both tables store the normalized plain-text title and body, so search
results can be turned into display snippets directly from the index.
"""

from __future__ import annotations

import re
import sqlite3

from typing import TYPE_CHECKING

from bootstrap.log import info


if TYPE_CHECKING:
    from pathlib import Path

    from bootstrap.docs.manual import ManualFolderNode


SEARCH_DB_FILE_NAME = "manual_search.db"
SEARCH_SCHEMA_VERSION = "2"

FTS_TABLES = {
    "zh": "manual_fts_zh",
    "en": "manual_fts_en",
}

_CREATE_META_SQL = "CREATE TABLE manual_search_meta(key TEXT PRIMARY KEY, value TEXT NOT NULL)"
_CREATE_FTS_SQL = {
    "zh": (
        "CREATE VIRTUAL TABLE manual_fts_zh USING fts5("
        "doc_id UNINDEXED, title, body, id_tokens, tokenize='trigram')"
    ),
    "en": (
        "CREATE VIRTUAL TABLE manual_fts_en USING fts5("
        "doc_id UNINDEXED, title, body, id_tokens, tokenize='porter unicode61')"
    ),
}

_WHITESPACE_PATTERN = re.compile(r"\s+")
_FENCE_PATTERN = re.compile(r"^```.*$", re.MULTILINE)
_HEADING_PATTERN = re.compile(r"^#{1,6}\s*", re.MULTILINE)
_BLOCKQUOTE_PATTERN = re.compile(r"^>\s?", re.MULTILINE)
_LIST_MARKER_PATTERN = re.compile(r"^(?:[-*+]|\d+\.)\s+", re.MULTILINE)
_IMAGE_PATTERN = re.compile(r"!\[[^\]]*\]\([^)]*\)")
_LINK_PATTERN = re.compile(r"\[([^\]]*)\]\([^)]*\)")
_TABLE_PIPE_PATTERN = re.compile(r"^\||\|$|\|", re.MULTILINE)
_EMPHASIS_PATTERN = re.compile(r"[*_~`]+")


def normalize_search_text(text: str) -> str:
    """Normalize text for indexing and querying: lowercase, single spaces."""
    return _WHITESPACE_PATTERN.sub(" ", text).strip().lower()


def strip_markdown(markdown: str) -> str:
    """Reduce a Markdown body to plain text for indexing."""
    text = _FENCE_PATTERN.sub(" ", markdown)
    text = _HEADING_PATTERN.sub("", text)
    text = _BLOCKQUOTE_PATTERN.sub("", text)
    text = _LIST_MARKER_PATTERN.sub("", text)
    text = _IMAGE_PATTERN.sub(" ", text)
    text = _LINK_PATTERN.sub(r"\1", text)
    text = _TABLE_PIPE_PATTERN.sub(" ", text)
    text = _EMPHASIS_PATTERN.sub("", text)
    return text


def doc_id_tokens(doc_id: str) -> str:
    """Tokenized form of a path-joined doc id, e.g. ``fitting/modules`` ->
    ``fitting modules``; appended to the indexed body so id-path queries hit."""
    return doc_id.replace("/", " ").replace("-", " ")


def build_manual_search(root: ManualFolderNode, db_path: Path) -> int:
    """Write the FTS5 search database for the manual tree to ``db_path``.

    Returns the number of indexed docs (per locale).
    """
    from bootstrap.docs.manual import _iter_docs

    db_path.unlink(missing_ok=True)
    connection = sqlite3.connect(db_path)
    try:
        connection.execute(_CREATE_META_SQL)
        for create_sql in _CREATE_FTS_SQL.values():
            connection.execute(create_sql)

        doc_count = 0
        for doc in _iter_docs(root):
            doc_count += 1
            id_tokens = doc_id_tokens(doc.id)
            for locale, localization in doc.localizations.items():
                table = FTS_TABLES[locale]
                title = normalize_search_text(localization.title)
                body = normalize_search_text(strip_markdown(localization.body_markdown))
                connection.execute(
                    f"INSERT INTO {table}(doc_id, title, body, id_tokens) VALUES (?, ?, ?, ?)",
                    (doc.id, title, body, id_tokens),
                )

        connection.execute(
            "INSERT INTO manual_search_meta(key, value) VALUES ('schema_version', ?)",
            (SEARCH_SCHEMA_VERSION,),
        )
        connection.commit()
    finally:
        connection.close()

    info(f"Generated manual search index ({doc_count} docs x {len(FTS_TABLES)} locales): {db_path}")
    return doc_count
