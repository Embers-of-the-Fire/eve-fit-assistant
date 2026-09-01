"""Layer 4 — resolution: changed files in, task instances out.

Resolution is a single function: ``resolve(changed files) -> Resolution``.
Changed files map to packages by longest-prefix directory match; blast-radius
entries expand the set (specific packages, whole ecosystems, or escalation);
the set is closed over dependents; every applicable task kind produces one
instance per affected package. Escalation instantiates the entire catalog —
it is the only definition of "run everything".

Change detection has exactly one implementation: the merge-base (three-dot)
diff between the target branch and the head, shared by CI jobs and local
inspection. All inspection surfaces (job matrix, affected report, web-bundle
gate) are thin projections over the resolver.
"""

from __future__ import annotations

import re
import subprocess

from dataclasses import dataclass
from typing import TYPE_CHECKING

from bootstrap.ci.catalog import STANDALONE_KINDS
from bootstrap.ci.catalog import TaskInstance
from bootstrap.ci.catalog import instantiate
from bootstrap.ci.registry import BLAST_RADIUS
from bootstrap.ci.registry import PACKAGES
from bootstrap.constant import PROJECT_ROOT


if TYPE_CHECKING:
    from collections.abc import Iterable


# ---------------------------------------------------------------------- globs


def glob_to_regex(pattern: str) -> str:
    """Convert a glob-style pattern to an anchored regex (``**`` = any depth)."""
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
        else:
            parts.append(re.escape(c))
        i += 1
    return "^" + "".join(parts) + "$"


def match_any_pattern(file_path: str, patterns: Iterable[str]) -> bool:
    """Check if a repository-relative file path matches any of the globs."""
    return any(re.match(glob_to_regex(pattern), file_path) for pattern in patterns)


# ------------------------------------------------------------------ graph


_PACKAGES_BY_ID = {p.id: p for p in PACKAGES}


def _dependents_map() -> dict[str, set[str]]:
    dependents: dict[str, set[str]] = {p.id: set() for p in PACKAGES}
    for package in PACKAGES:
        for dep in package.depends_on:
            if dep not in dependents:
                raise ValueError(f"Unknown dependency {dep!r} declared by {package.id!r}")
            dependents[dep].add(package.id)
    return dependents


_DEPENDENTS = _dependents_map()


def match_package(path: str) -> str | None:
    """The package whose directory contains ``path`` (longest prefix wins)."""
    best: str | None = None
    for package in PACKAGES:
        if (path == package.path or path.startswith(package.path + "/")) and (
            best is None or len(package.path) > len(_PACKAGES_BY_ID[best].path)
        ):
            best = package.id
    return best


def dependency_closure(package_ids: Iterable[str]) -> frozenset[str]:
    """The given packages plus everything they transitively depend on."""
    seen: set[str] = set()
    stack = list(package_ids)
    while stack:
        current = stack.pop()
        if current in seen:
            continue
        seen.add(current)
        stack.extend(_PACKAGES_BY_ID[current].depends_on)
    return frozenset(seen)


# -------------------------------------------------------------- resolution


@dataclass(frozen=True)
class Resolution:
    """The result of resolving a change set into CI workload."""

    escalated: bool  # everything matched: the entire catalog is instantiated
    files: tuple[str, ...]  # normalized changed files
    packages: frozenset[str]  # affected package ids (including dependents)
    standalone: frozenset[str]  # selected standalone task kinds
    instances: tuple[TaskInstance, ...]  # the selected task instances


def escalated_resolution(files: tuple[str, ...] = ()) -> Resolution:
    """Escalation: the entire catalog instantiated — the only "run everything".

    Change sets that cannot meaningfully diff (pushes to the main development
    branch) skip diffing and resolve as if ``everything`` matched.
    """
    packages = frozenset(_PACKAGES_BY_ID)
    standalone = frozenset(kind.id for kind in STANDALONE_KINDS)
    return Resolution(
        escalated=True,
        files=files,
        packages=packages,
        standalone=standalone,
        instances=tuple(instantiate(packages, standalone)),
    )


def resolve(files: Iterable[str]) -> Resolution:
    """Resolve changed files into the affected packages and task instances."""
    normalized = tuple(dict.fromkeys(f.strip() for f in files if f.strip()))

    direct: set[str] = set()
    standalone: set[str] = set()

    for path in normalized:
        for entry in BLAST_RADIUS:
            if not match_any_pattern(path, entry.patterns):
                continue
            if entry.everything:
                return escalated_resolution(normalized)
            direct.update(entry.packages)
            for ecosystem in entry.ecosystems:
                direct.update(p.id for p in PACKAGES if p.ecosystem == ecosystem)
        matched = match_package(path)
        if matched is not None:
            direct.add(matched)
        for kind in STANDALONE_KINDS:
            if match_any_pattern(path, kind.trigger):
                standalone.add(kind.id)

    # Close over dependents: a change to a base package marks every package
    # that transitively depends on it as affected.
    affected = set(direct)
    stack = list(direct)
    while stack:
        current = stack.pop()
        for dependent in _DEPENDENTS[current]:
            if dependent not in affected:
                affected.add(dependent)
                stack.append(dependent)

    return Resolution(
        escalated=False,
        files=normalized,
        packages=frozenset(affected),
        standalone=frozenset(standalone),
        instances=tuple(instantiate(frozenset(affected), frozenset(standalone))),
    )


# --------------------------------------------------------- change detection


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


def merge_base(target_ref: str, head_ref: str) -> str | None:
    out = subprocess.run(
        ["git", "merge-base", target_ref, head_ref],
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


def changed_files(target_ref: str, head_ref: str = "HEAD") -> list[str]:
    """The merge-base (three-dot) diff between the target branch and the head.

    This matches what a pull request actually proposes and never over-selects
    when the target branch has advanced since the branch point.
    """
    base = merge_base(target_ref, head_ref)
    if base is None:
        raise RuntimeError(f"Could not resolve merge-base of {target_ref!r} and {head_ref!r}.")
    return sorted(_git(["diff", "--name-only", base, head_ref]))


def changed_files_local(base_ref: str | None = None) -> list[str]:
    """The merge-base diff plus uncommitted changes, for local inspection.

    ``base_ref`` defaults to the merge-base of ``HEAD`` with ``origin/dev``.
    Unstaged, staged, and untracked changes are included so local
    ``--changed`` runs cover work in progress.
    """
    if base_ref is None:
        candidates = ["origin/dev", "origin/main", "dev", "main"]
        base_ref = next(
            (ref for ref in candidates if merge_base(ref, "HEAD") is not None),
            None,
        )
        if base_ref is None:
            raise RuntimeError("Could not determine a base ref; pass --base-ref explicitly.")
    base = merge_base(base_ref, "HEAD")
    if base is None:
        raise RuntimeError(f"Could not resolve merge-base with {base_ref!r}.")

    files = set(_git(["diff", "--name-only", base, "HEAD"]))
    files.update(_git(["diff", "--name-only"]))
    files.update(_git(["diff", "--name-only", "--cached"]))
    files.update(_git(["ls-files", "--others", "--exclude-standard"]))
    return sorted(files)


# ------------------------------------------------------------------ queries


def job_matrix(resolution: Resolution) -> list[dict]:
    """The selected instances rendered as self-describing job specifications."""
    return [instance.job_spec() for instance in resolution.instances]


def affected_report(resolution: Resolution) -> dict:
    """The resolved packages and tasks for a change set, for debugging."""
    return {
        "escalated": resolution.escalated,
        "files": list(resolution.files),
        "packages": sorted(resolution.packages),
        "standalone": sorted(resolution.standalone),
        "tasks": [instance.id for instance in resolution.instances],
    }


def web_bundle_gate(resolution: Resolution) -> bool:
    """Whether the Flutter app's task set is instantiated.

    The web preview bundle must be rebuilt exactly when the app's tasks are
    selected; the gate is a query over the resolver output, not an
    independent flag.
    """
    return "eve_fit_assistant" in resolution.packages
