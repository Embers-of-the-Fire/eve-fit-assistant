"""Shared Markdown document parsing for announcement/release-note bodies."""

from __future__ import annotations

import re

from dataclasses import dataclass
from typing import TYPE_CHECKING


if TYPE_CHECKING:
    from pathlib import Path


@dataclass(frozen=True)
class ParsedDocument:
    locale: str
    source_path: Path
    title: str
    summary: str
    body_markdown: str


def parse_locale_document(path: Path, locale: str) -> ParsedDocument:
    """Parse a localized Markdown announcement document.

    The file must contain a single level-1 heading that becomes the title.
    The first non-empty, non-heading, non-list, non-code paragraph becomes
    the summary.  Everything after the title (including the summary paragraph
    and any remaining content) becomes ``body_markdown``.
    """
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

    summary = extract_summary(body_text)
    if summary is None:
        raise ValueError(f"Locale file has no usable summary paragraph: {path}")

    body_markdown = body_text + "\n"
    return ParsedDocument(
        locale=locale,
        source_path=path,
        title=title,
        summary=summary,
        body_markdown=body_markdown,
    )


def extract_summary(body_markdown: str) -> str | None:
    """Return the first plain paragraph from a Markdown body."""
    paragraphs = re.split(r"\n\s*\n", body_markdown.strip())
    for block in paragraphs:
        stripped = block.strip()
        if not stripped or stripped.startswith(("#", "```")):
            continue
        if stripped.startswith(("- ", "* ", "+ ")) or re.match(r"\d+\.\s", stripped):
            continue
        return " ".join(line.strip() for line in stripped.splitlines()).strip()
    return None
