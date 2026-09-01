"""Tests enforcing the architectural invariants of the CI selection system.

1. Fail-safe — changes to the registry, the step graph, the catalog, the
   resolver, or the workflow definitions escalate to full instantiation.
2. Coverage — every package is reachable by at least one applicable task
   kind, or is explicitly declared opaque.
3. Referential integrity — every codegen step named by a package exists in
   the codegen step graph (also covered by test_ci_registry.py).
4. Manifest consistency — covered by test_ci_registry.py.
5. Separation — the package registry contains no CI vocabulary; workflow
   definitions contain no package or task-kind names; codegen is scoped by
   packages only.
"""

from __future__ import annotations

import ast

from pathlib import Path

import bootstrap.ci.resolve as resolver

from bootstrap.ci.catalog import STANDALONE_KINDS
from bootstrap.ci.catalog import TASK_KINDS
from bootstrap.ci.catalog import applicable_kinds
from bootstrap.ci.registry import PACKAGES
from bootstrap.constant import PROJECT_ROOT


# 1. Fail-safe ---------------------------------------------------------------


def test_selection_system_changes_escalate():
    for path in (
        "bootstrap/ci/registry.py",
        "bootstrap/ci/codegen.py",
        "bootstrap/ci/catalog.py",
        "bootstrap/ci/resolve.py",
        "bootstrap/ci/commands.py",
        "flake.nix",
        ".github/workflows/ci.yml",
        ".github/actions/build-web/action.yml",
    ):
        assert resolver.resolve([path]).escalated, path


def test_selection_tests_changes_escalate():
    for test_file in Path(__file__).parent.glob("test_ci_*.py"):
        path = test_file.relative_to(PROJECT_ROOT).as_posix()
        assert resolver.resolve([path]).escalated, path


# 2. Coverage ----------------------------------------------------------------


def test_every_package_is_covered_or_opaque():
    for package in PACKAGES:
        kinds = applicable_kinds(package)
        assert kinds or package.opaque, (
            f"{package.id} is matched by no task kind and is not declared opaque"
        )


def test_opaque_packages_are_explicit():
    assert {p.id for p in PACKAGES if p.opaque} == {"eve-fit-os", "release"}


# 5. Separation --------------------------------------------------------------


def test_registry_contains_no_ci_vocabulary():
    """The registry must not know about catalogs, resolvers, or jobs."""
    source = (PROJECT_ROOT / "bootstrap/ci/registry.py").read_text(encoding="utf-8")
    tree = ast.parse(source)
    for node in ast.walk(tree):
        if isinstance(node, ast.Import | ast.ImportFrom):
            names = [a.name for a in node.names]
            module = getattr(node, "module", "") or ""
            for name in [module, *names]:
                assert "catalog" not in name and "resolve" not in name, (
                    f"registry imports CI machinery: {name}"
                )
    for forbidden in ("suite", "job", "matrix", "task_kind", "workflow"):
        for package in PACKAGES:
            assert not hasattr(package, forbidden), f"Package gained CI field {forbidden!r}"


def test_workflow_definitions_contain_no_package_or_kind_names():
    """The CI workflow is a generic parameterized runner."""
    source = (PROJECT_ROOT / ".github/workflows/ci.yml").read_text(encoding="utf-8")
    for package in PACKAGES:
        assert package.id not in source, f"ci.yml names package {package.id!r}"
        assert package.path not in source, f"ci.yml names package path {package.path!r}"
    for kind in (*TASK_KINDS, *STANDALONE_KINDS):
        # Kind ids appear in job specs, never in the workflow definition.
        assert f"'{kind.id}'" not in source and f'"{kind.id}"' not in source, (
            f"ci.yml names task kind {kind.id!r}"
        )
