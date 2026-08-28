"""Resolve changed files to affected packages, suites, and the web gate."""

from __future__ import annotations

import subprocess

from dataclasses import dataclass
from typing import TYPE_CHECKING

from bootstrap.constant import PROJECT_ROOT
from bootstrap.monorepo.packages import META_ENTRIES
from bootstrap.monorepo.packages import PACKAGES
from bootstrap.monorepo.patterns import match_any_pattern


if TYPE_CHECKING:
    from collections.abc import Iterable


# Canonical CI suite identifiers. The "ci" suite is intentionally absent: it
# only exists as the full-run escalation encoded by MetaEntry(full=True).
ALL_SUITES: tuple[str, ...] = (
    "python",
    "dart",
    "dart-web",
    "site",
    "snapshot-ts",
    "worker",
    "workflows",
    "l10n",
)

_PACKAGES_BY_ID = {p.id: p for p in PACKAGES}


def _dependents_map() -> dict[str, set[str]]:
    """Map each package id to the set of packages that depend on it."""
    dependents: dict[str, set[str]] = {p.id: set() for p in PACKAGES}
    for package in PACKAGES:
        for dep in package.depends_on:
            if dep not in dependents:
                raise ValueError(f"Unknown dependency {dep!r} declared by {package.id!r}")
            dependents[dep].add(package.id)
    return dependents


_DEPENDENTS = _dependents_map()


@dataclass(frozen=True)
class AffectedSet:
    """Result of resolving a set of changed files."""

    full: bool  # infrastructure escalation: run every suite
    files: tuple[str, ...]  # normalized changed files
    packages: frozenset[str]  # affected package ids (including dependents)
    suites: frozenset[str]  # affected CI suites
    web: bool  # the Flutter web bundle may be affected


def packages_of_ecosystem(ecosystem: str) -> frozenset[str]:
    return frozenset(p.id for p in PACKAGES if p.ecosystem == ecosystem)


def _match_package(path: str) -> str | None:
    """Return the id of the package whose directory contains ``path``."""
    best: str | None = None
    for package in PACKAGES:
        # Nested packages (e.g. efa-chat inside the FRB crate): the most
        # specific path wins.
        if (path == package.path or path.startswith(package.path + "/")) and (
            best is None or len(package.path) > len(_PACKAGES_BY_ID[best].path)
        ):
            best = package.id
    return best


def web_relevant_packages() -> frozenset[str]:
    """Packages whose sources feed the Flutter web bundle.

    Computed as the forward dependency closure of the Flutter app, which
    includes its Dart dependencies and, via the documented cargokit edge,
    the FRB Rust crates (and therefore ``eve-fit-os``).
    """
    seen: set[str] = set()
    stack = ["eve_fit_assistant"]
    while stack:
        current = stack.pop()
        if current in seen:
            continue
        seen.add(current)
        stack.extend(_PACKAGES_BY_ID[current].depends_on)
    return frozenset(seen)


def resolve_affected(files: Iterable[str]) -> AffectedSet:
    """Map changed files to the affected packages, suites, and web gate.

    The affected package set is closed over dependents: a change to a base
    package (e.g. ``efa_proto``) marks every package depending on it (e.g.
    the app) as affected. Meta entries can additionally pull in whole
    ecosystems, extra suites, or escalate to a full run.
    """
    normalized = tuple(dict.fromkeys(f.strip() for f in files if f.strip()))

    full = False
    web = False
    direct: set[str] = set()
    suites: set[str] = set()

    for path in normalized:
        matched = _match_package(path)
        if matched is not None:
            direct.add(matched)
        for entry in META_ENTRIES:
            if match_any_pattern(path, entry.patterns):
                full = full or entry.full
                web = web or entry.web
                direct.update(entry.packages)
                for ecosystem in entry.ecosystems:
                    direct.update(packages_of_ecosystem(ecosystem))
                suites.update(entry.suites)

    # Close over dependents.
    affected = set(direct)
    stack = list(direct)
    while stack:
        current = stack.pop()
        for dependent in _DEPENDENTS[current]:
            if dependent not in affected:
                affected.add(dependent)
                stack.append(dependent)

    for package_id in affected:
        suites.update(_PACKAGES_BY_ID[package_id].suites)

    web = web or full or bool(affected & web_relevant_packages())
    if full:
        suites.update(ALL_SUITES)

    return AffectedSet(
        full=full,
        files=normalized,
        packages=frozenset(affected),
        suites=frozenset(suites),
        web=web,
    )


def _git(args: list[str]) -> list[str]:
    out = subprocess.run(
        ["git", *args],
        cwd=PROJECT_ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )
    if out.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)} failed: {out.stderr.strip()}")
    return [line.strip() for line in out.stdout.splitlines() if line.strip()]


def changed_files_from_git(base_ref: str | None = None) -> list[str]:
    """Collect files changed relative to ``base_ref`` plus uncommitted changes.

    ``base_ref`` defaults to the merge-base of ``HEAD`` with ``origin/dev``.
    Unstaged, staged, and untracked changes are included so local
    ``--changed`` runs cover work in progress.
    """
    if base_ref is None:
        candidates = ["origin/dev", "origin/main", "dev", "main"]
        base_ref = next(
            (ref for ref in candidates if _try_merge_base(ref) is not None),
            None,
        )
        if base_ref is None:
            raise RuntimeError("Could not determine a base ref; pass --base-ref explicitly.")
        base = _try_merge_base(base_ref)
        assert base is not None
    else:
        base = _try_merge_base(base_ref)
        if base is None:
            raise RuntimeError(f"Could not resolve merge-base with {base_ref!r}.")

    files = set(_git(["diff", "--name-only", base, "HEAD"]))
    files.update(_git(["diff", "--name-only"]))
    files.update(_git(["diff", "--name-only", "--cached"]))
    files.update(_git(["ls-files", "--others", "--exclude-standard"]))
    return sorted(files)


def _try_merge_base(ref: str) -> str | None:
    out = subprocess.run(
        ["git", "merge-base", ref, "HEAD"],
        cwd=PROJECT_ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )
    if out.returncode != 0:
        return None
    return out.stdout.strip() or None
