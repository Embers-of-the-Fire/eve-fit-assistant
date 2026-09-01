"""Consistency tests between the Layer 1 package registry and the manifests.

The registry in ``bootstrap/ci/registry.py`` is the single source of truth for
change-aware CI selection; these tests make sure it cannot drift from the
actual ``pubspec.yaml``/``package.json``/``Cargo.toml`` manifests. Adding or
removing a package without updating the registry fails here.
"""

from __future__ import annotations

import json
import tomllib

from typing import TYPE_CHECKING

import yaml

from bootstrap.ci.codegen import STEPS
from bootstrap.ci.registry import ALLOWED_EXTRA_EDGES
from bootstrap.ci.registry import BLAST_RADIUS
from bootstrap.ci.registry import PACKAGES
from bootstrap.constant import PROJECT_ROOT


if TYPE_CHECKING:
    from pathlib import Path


PACKAGES_BY_ID = {p.id: p for p in PACKAGES}
ECOSYSTEMS = {p.ecosystem for p in PACKAGES}
STEP_NAMES = {step.name for step in STEPS}


def _load_yaml(path: Path) -> dict:
    with path.open(encoding="utf-8") as f:
        return yaml.safe_load(f)


def _load_toml(path: Path) -> dict:
    with path.open("rb") as f:
        return tomllib.load(f)


# ------------------------------------------------------------------ registry


def test_package_ids_and_paths_are_unique():
    ids = [p.id for p in PACKAGES]
    paths = [p.path for p in PACKAGES]
    assert len(ids) == len(set(ids)), f"duplicate package ids: {ids}"
    assert len(paths) == len(set(paths)), f"duplicate package paths: {paths}"


def test_declared_edges_reference_known_packages():
    for package in PACKAGES:
        for dep in package.depends_on:
            assert dep in PACKAGES_BY_ID, f"{package.id} depends on unknown {dep}"


def test_blast_radius_entries_reference_known_targets():
    for entry in BLAST_RADIUS:
        for package_id in entry.packages:
            assert package_id in PACKAGES_BY_ID, f"{entry.id} references unknown {package_id}"
        for ecosystem in entry.ecosystems:
            assert ecosystem in ECOSYSTEMS, f"{entry.id} references unknown {ecosystem}"


def test_codegen_facts_reference_known_steps():
    """Referential integrity: every codegen step named by a package exists."""
    for package in PACKAGES:
        for step in package.codegen:
            assert step in STEP_NAMES, f"{package.id} requires unknown codegen step {step}"


# ---------------------------------------------------------------------- Dart


def _dart_workspace_members() -> list[str]:
    return list(_load_yaml(PROJECT_ROOT / "pubspec.yaml").get("workspace", []))


def test_dart_workspace_members_match_registry():
    manifest = set(_dart_workspace_members())
    registry = {p.path for p in PACKAGES if p.ecosystem == "dart"}
    assert manifest == registry


def test_dart_package_names_and_edges():
    workspace_names: dict[str, str] = {}  # name -> path
    for member in _dart_workspace_members():
        pubspec = _load_yaml(PROJECT_ROOT / member / "pubspec.yaml")
        workspace_names[pubspec["name"]] = member

    for name, path in workspace_names.items():
        package = PACKAGES_BY_ID[name]
        assert package.path == path
        pubspec = _load_yaml(PROJECT_ROOT / path / "pubspec.yaml")
        manifest_edges: set[str] = set()
        for section in ("dependencies", "dev_dependencies"):
            deps = pubspec.get(section) or {}
            manifest_edges.update(d for d in deps if d in workspace_names)
        declared = set(package.depends_on) & workspace_names.keys()
        extras = {d for a, d in ALLOWED_EXTRA_EDGES if a == name}
        assert manifest_edges == declared - extras, (
            f"{name}: manifest edges {sorted(manifest_edges)} != declared {sorted(declared - extras)}"
        )
        assert declared - manifest_edges <= extras


# -------------------------------------------------------------- TypeScript


def _pnpm_workspace_dirs() -> list[str]:
    config = _load_yaml(PROJECT_ROOT / "pnpm-workspace.yaml")
    dirs: list[str] = []
    for pattern in config.get("packages", []):
        if pattern.endswith("/*"):
            parent = PROJECT_ROOT / pattern[:-2]
            if not parent.is_dir():
                continue
            dirs.extend(
                str(child.relative_to(PROJECT_ROOT))
                for child in sorted(parent.iterdir())
                if (child / "package.json").is_file()
            )
        else:
            dirs.append(pattern)
    return dirs


def test_pnpm_workspace_members_match_registry():
    manifest = set(_pnpm_workspace_dirs())
    registry = {p.path for p in PACKAGES if p.ecosystem == "ts"}
    assert manifest == registry


def test_pnpm_package_names_and_edges():
    names: dict[str, str] = {}  # name -> path
    for directory in _pnpm_workspace_dirs():
        manifest = json.loads((PROJECT_ROOT / directory / "package.json").read_text())
        names[manifest["name"]] = directory

    for name, path in names.items():
        package = PACKAGES_BY_ID[name]
        assert package.path == path
        manifest = json.loads((PROJECT_ROOT / path / "package.json").read_text())
        manifest_edges: set[str] = set()
        for section in ("dependencies", "devDependencies"):
            deps = manifest.get(section) or {}
            manifest_edges.update(d for d in deps if d in names)
        declared = set(package.depends_on) & names.keys()
        assert manifest_edges == declared, (
            f"{name}: manifest edges {sorted(manifest_edges)} != declared {sorted(declared)}"
        )


# ---------------------------------------------------------------------- Rust


def _cargo_workspace_members() -> list[str]:
    return list(_load_toml(PROJECT_ROOT / "Cargo.toml")["workspace"]["members"])


def test_cargo_workspace_members_match_registry():
    manifest = set(_cargo_workspace_members())
    registry = {p.path for p in PACKAGES if p.ecosystem == "rust"}
    assert manifest == registry


def test_cargo_package_names_and_edges():
    names: dict[str, str] = {}  # crate name -> member dir
    for member in _cargo_workspace_members():
        manifest_path = PROJECT_ROOT / member / "Cargo.toml"
        if not manifest_path.is_file():  # submodule not checked out
            continue
        names[_load_toml(manifest_path)["package"]["name"]] = member

    for name, path in names.items():
        package = PACKAGES_BY_ID[name]
        assert package.path == path
        manifest = _load_toml(PROJECT_ROOT / path / "Cargo.toml")
        manifest_edges: set[str] = set()
        for section in ("dependencies", "dev-dependencies", "build-dependencies"):
            deps = manifest.get(section) or {}
            for spec in deps.values():
                if isinstance(spec, dict) and "path" in spec:
                    target = (PROJECT_ROOT / path / spec["path"]).resolve()
                    for other_name, other_path in names.items():
                        if (PROJECT_ROOT / other_path).resolve() == target:
                            manifest_edges.add(other_name)
        declared = set(package.depends_on) & names.keys()
        assert manifest_edges == declared, (
            f"{name}: manifest edges {sorted(manifest_edges)} != declared {sorted(declared)}"
        )
