"""Glob-style path matching helpers (prefix-anchored, ``**`` = any depth)."""

from __future__ import annotations

import re


def glob_to_regex(pattern: str) -> str:
    """Convert a glob-style pattern to a prefix-anchored regex."""
    parts = []
    i = 0
    while i < len(pattern):
        c = pattern[i]
        if c == "*":
            if i + 1 < len(pattern) and pattern[i + 1] == "*":
                parts.append(r".*")
                i += 1
            else:
                parts.append(r"[^/]*")
        elif c == "?":
            parts.append(r"[^/]")
        elif c == ".":
            parts.append(r"\.")
        else:
            parts.append(re.escape(c))
        i += 1
    return "^" + "".join(parts) + "$"


def match_any_pattern(file_path: str, patterns: list[str] | tuple[str, ...]) -> bool:
    """Check if a file path matches any of the given glob patterns."""
    return any(re.match(glob_to_regex(pattern), file_path) for pattern in patterns)
