"""Tests enforcing the architectural invariants of the CI selection system.

1. Fail-safe — changes to any selection-system module (``bootstrap/ci/``),
   the selection tests, the CI runner workflow (``.github/workflows/ci.yml``),
   repository automation outside ``.github/workflows/`` and
   ``.github/actions/``, or the environment flake escalate to full
   instantiation. Other workflow/action definitions only select the zizmor
   scan task.
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
import posixpath
import re
import subprocess

from pathlib import Path

import bootstrap.ci.resolve as resolver

from bootstrap.ci.catalog import STANDALONE_KINDS
from bootstrap.ci.catalog import TASK_KINDS
from bootstrap.ci.catalog import applicable_kinds
from bootstrap.ci.codegen import STEPS
from bootstrap.ci.codegen import steps_for_packages
from bootstrap.ci.registry import PACKAGES
from bootstrap.ci.resolve import match_any_pattern
from bootstrap.constant import PROJECT_ROOT


# 1. Fail-safe ---------------------------------------------------------------


def test_selection_system_changes_escalate():
    ci_dir = PROJECT_ROOT / "bootstrap/ci"
    for module in ci_dir.rglob("*.py"):
        path = module.relative_to(PROJECT_ROOT).as_posix()
        assert resolver.resolve([path]).escalated, path
    for path in (
        "flake.nix",
        "flake.lock",
        ".github/workflows/ci.yml",
        ".github/AGENTS.md",
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


# 3. Referential integrity (extended) ----------------------------------------

_DART_REF = re.compile(r"""(?:import|part|export)\s+['"]([^'"]+)['"]""")


def _git_tracked_files() -> set[str]:
    out = subprocess.run(
        ["git", "ls-files"],
        cwd=PROJECT_ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    return set(out.stdout.splitlines())


def test_untracked_dart_references_are_produced_by_the_codegen_closure():
    """Every generated Dart file a package references must be produced by a
    codegen step in that package's dependency closure.

    A missing codegen fact fails ``dart analyze`` in CI (gitignored generated
    files never exist there); this test fails locally instead.
    """
    tracked = _git_tracked_files()
    steps_by_name = {s.name: s for s in STEPS}
    by_id = {p.id: p for p in PACKAGES}

    for package in PACKAGES:
        if package.ecosystem != "dart":
            continue
        package_dir = PROJECT_ROOT / package.path
        closure_steps = steps_for_packages([package.id])
        dart_sources = sorted(
            p
            for subdir in ("lib", "test")
            if package_dir.joinpath(subdir).is_dir()
            for p in package_dir.joinpath(subdir).rglob("*.dart")
        )
        for dart_file in dart_sources:
            rel_dir = posixpath.dirname(dart_file.relative_to(PROJECT_ROOT).as_posix())
            for match in _DART_REF.finditer(dart_file.read_text(encoding="utf-8")):
                uri = match.group(1)
                if uri.startswith("dart:"):
                    continue
                if uri.startswith("package:"):
                    pkg_name, _, path_rest = uri.removeprefix("package:").partition("/")
                    target = by_id.get(pkg_name)
                    if target is None or target.ecosystem != "dart":
                        continue
                    resolved = posixpath.normpath(f"{target.path}/lib/{path_rest}")
                else:
                    resolved = posixpath.normpath(f"{rel_dir}/{uri}")
                if resolved in tracked:
                    continue
                producing = [
                    step
                    for step in closure_steps
                    if match_any_pattern(resolved, steps_by_name[step].outputs)
                ]
                assert producing, (
                    f"{dart_file.relative_to(PROJECT_ROOT)} references {resolved!r}, "
                    f"which is not tracked by git and is not produced by any codegen "
                    f"step in {package.id}'s closure {closure_steps}"
                )


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
