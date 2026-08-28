"""CI suite matrix generation on top of the monorepo dependency graph.

Suite selection is derived from ``bootstrap.monorepo``: changed files are
mapped to packages, closed over dependents, and each affected suite emits
fully-resolved lint/test/codegen commands (scoped via ``--packages`` where
applicable). Infrastructure changes escalate to a full, unscoped run.
"""

from __future__ import annotations

from bootstrap.monorepo import ALL_SUITES
from bootstrap.monorepo import PACKAGES
from bootstrap.monorepo import AffectedSet
from bootstrap.monorepo import resolve_affected
from bootstrap.monorepo.patterns import glob_to_regex
from bootstrap.monorepo.patterns import match_any_pattern


__all__ = [
    "calculate_ci_matrix",
    "full_matrix",
    "glob_to_regex",
    "match_any_pattern",
    "matrix_from_affected",
    "web_preview_affected",
]


_SUITE_SHELLS = {
    "python": "python",
    "dart": "dart",
    "dart-web": "dart",
    "site": "js",
    "snapshot-ts": "js",
    "worker": "js",
    "workflows": "ci",
    "l10n": "python",
}

_DART_PACKAGES = frozenset(p.id for p in PACKAGES if p.ecosystem == "dart")
_TS_PACKAGES = frozenset(p.id for p in PACKAGES if p.ecosystem == "ts")


def _packages_option(ids: set[str] | frozenset[str]) -> str:
    """Render a ``--packages a,b,c`` CLI suffix (empty when unscoped)."""
    return f" --packages {','.join(sorted(ids))}" if ids else ""


def _entry(suite: str, lint_command: str, command: str, codegen_command: str) -> dict:
    return {
        "suite": suite,
        "shell": _SUITE_SHELLS[suite],
        "lint_command": lint_command,
        "command": command,
        "codegen_command": codegen_command,
    }


def _full_entry(suite: str) -> dict:
    """Unscoped commands for a suite (full runs keep the legacy surface)."""
    match suite:
        case "python":
            return _entry(
                suite,
                "uv run x.py ci lint --lang python",
                "uv run x.py test python",
                "uv run x.py ci codegen --lang python",
            )
        case "dart":
            return _entry(
                suite,
                "uv run x.py ci lint --lang dart",
                "uv run x.py test dart",
                "uv run x.py ci codegen --lang dart",
            )
        case "dart-web":
            return _entry(
                suite,
                "uv run x.py ci lint --lang dart",
                "uv run x.py test web",
                "uv run x.py ci codegen --lang dart",
            )
        case "site":
            return _entry(suite, "uv run x.py ci lint --lang site", "true", "true")
        case "snapshot-ts":
            return _entry(
                suite,
                "uv run x.py ci lint --lang snapshot-ts",
                "true",
                "uv run x.py ci codegen --lang snapshot-ts",
            )
        case "worker":
            return _entry(
                suite, "true", "pnpm test:js", "uv run x.py ci codegen --lang snapshot-ts"
            )
        case "workflows":
            return _entry(suite, "true", "uv run x.py ci zizmor", "true")
        case "l10n":
            return _entry(suite, "uv run x.py ci lint --lang l10n", "true", "true")
    raise ValueError(f"Unknown suite: {suite}")


def _scoped_entry(suite: str, affected: AffectedSet) -> dict:
    """Fully-resolved commands scoped to the affected package set."""
    dart = affected.packages & _DART_PACKAGES
    ts = affected.packages & _TS_PACKAGES
    match suite:
        case "dart":
            return _entry(
                suite,
                f"uv run x.py ci lint --lang dart{_packages_option(dart)}",
                f"uv run x.py test dart{_packages_option(dart)}",
                "uv run x.py ci codegen --lang dart",
            )
        case "dart-web":
            return _entry(
                suite,
                f"uv run x.py ci lint --lang dart{_packages_option(dart)}",
                "uv run x.py test web",
                "uv run x.py ci codegen --lang dart",
            )
        case "site":
            return _entry(
                suite,
                f"uv run x.py ci lint --lang site{_packages_option(ts)}",
                "true",
                "true",
            )
        case "snapshot-ts":
            return _entry(
                suite,
                f"uv run x.py ci lint --lang snapshot-ts{_packages_option(ts)}",
                "true",
                "uv run x.py ci codegen --lang snapshot-ts",
            )
        case "worker":
            return _entry(
                suite,
                "true",
                f"uv run x.py test js{_packages_option(ts)}",
                "uv run x.py ci codegen --lang snapshot-ts",
            )
        case _:
            return _full_entry(suite)


def matrix_from_affected(affected: AffectedSet) -> list[dict]:
    """Build the CI job matrix for an already-resolved change set."""
    if affected.full:
        return full_matrix()
    return [_scoped_entry(suite, affected) for suite in ALL_SUITES if suite in affected.suites]


def full_matrix() -> list[dict]:
    """The complete, unscoped CI job matrix."""
    return [_full_entry(suite) for suite in ALL_SUITES]


def calculate_ci_matrix(files: list[str]) -> list[dict]:
    """Determine which CI suites to run based on changed files."""
    return matrix_from_affected(resolve_affected(files))


def web_preview_affected(files: list[str]) -> bool:
    """Check whether changed files require a web preview rebuild."""
    return resolve_affected(files).web
