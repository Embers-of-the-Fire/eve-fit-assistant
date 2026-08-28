"""Change-aware monorepo model: package registry, dependency graph, resolution.

This package is the single source of truth for selecting what to lint, test,
and build in response to a set of changed files. It is consumed by the CI
matrix generator (``bootstrap.ci.suites``), the change-aware lint/test
commands, and the web-preview gate.
"""

from __future__ import annotations

from bootstrap.monorepo.graph import ALL_SUITES
from bootstrap.monorepo.graph import AffectedSet
from bootstrap.monorepo.graph import changed_files_from_git
from bootstrap.monorepo.graph import resolve_affected
from bootstrap.monorepo.graph import web_relevant_packages
from bootstrap.monorepo.packages import META_ENTRIES
from bootstrap.monorepo.packages import PACKAGES
from bootstrap.monorepo.packages import MetaEntry
from bootstrap.monorepo.packages import Package
from bootstrap.monorepo.patterns import glob_to_regex
from bootstrap.monorepo.patterns import match_any_pattern


__all__ = [
    "ALL_SUITES",
    "META_ENTRIES",
    "PACKAGES",
    "AffectedSet",
    "MetaEntry",
    "Package",
    "changed_files_from_git",
    "glob_to_regex",
    "match_any_pattern",
    "resolve_affected",
    "web_relevant_packages",
]
