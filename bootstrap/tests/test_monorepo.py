"""Consistency tests between the monorepo registry and the real manifests.

The registry in ``bootstrap/monorepo/packages.py`` is the single source of
truth for change-aware CI selection; these tests make sure it cannot drift
from the actual ``pubspec.yaml``/``package.json``/``Cargo.toml`` manifests.
"""

from __future__ import annotations

import json
import tomllib

from typing import TYPE_CHECKING

import yaml

from bootstrap.constant import PROJECT_ROOT
from bootstrap.monorepo.graph import ALL_SUITES
from bootstrap.monorepo.graph import resolve_affected
from bootstrap.monorepo.graph import web_relevant_packages
from bootstrap.monorepo.packages import ALLOWED_EXTRA_EDGES
from bootstrap.monorepo.packages import META_ENTRIES
from bootstrap.monorepo.packages import PACKAGES


if TYPE_CHECKING:
    from pathlib import Path


PACKAGES_BY_ID = {p.id: p for p in PACKAGES}


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


def test_package_suites_are_known():
    for package in PACKAGES:
        for suite in package.suites:
            assert suite in ALL_SUITES, f"{package.id} feeds unknown suite {suite}"


def test_meta_entries_reference_known_targets():
    ecosystems = {p.ecosystem for p in PACKAGES}
    for entry in META_ENTRIES:
        for package_id in entry.packages:
            assert package_id in PACKAGES_BY_ID, f"{entry.id} references unknown {package_id}"
        for ecosystem in entry.ecosystems:
            assert ecosystem in ecosystems, f"{entry.id} references unknown {ecosystem}"
        for suite in entry.suites:
            assert suite in ALL_SUITES, f"{entry.id} references unknown suite {suite}"


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


# -------------------------------------------------------------------- graph


def test_dependents_closure_marks_app_for_base_package_change():
    affected = resolve_affected(["packages/efa_proto/lib/eve.pb.dart"])
    assert "eve_fit_assistant" in affected.packages
    assert "efa_fit" in affected.packages
    assert affected.suites >= {"dart", "dart-web"}


def test_leaf_ts_package_change_pulls_in_dependents():
    affected = resolve_affected(["packages/efa_proto_ts/src/index.ts"])
    assert "efa-fit-snapshot-ts" in affected.packages
    assert "efa-platform" in affected.packages
    assert "efa-platform-api" in affected.packages
    assert affected.suites >= {"snapshot-ts", "site", "worker"}


def test_nested_rust_crate_matches_most_specific_package():
    affected = resolve_affected(["apps/eve-fit-assistant/rust/lib/efa-chat/src/lib.rs"])
    assert "efa-chat" in affected.packages
    assert "rust_lib_eve_fit_assistant" in affected.packages  # dependent
    assert "eve_fit_assistant" in affected.packages  # dependent of dependent


def test_submodule_gitlink_path_matches_package():
    affected = resolve_affected(["packages/eve-fit-os"])
    assert "eve-fit-os" in affected.packages
    assert "efa-platform-fit-storage" in affected.packages


def test_infra_change_escalates_to_full_run():
    for path in ["bootstrap/ci/suites.py", "flake.nix", ".github/workflows/ci.yml"]:
        affected = resolve_affected([path])
        assert affected.full, path
        assert affected.suites == set(ALL_SUITES)
        assert affected.web


def test_unrelated_files_affect_nothing():
    affected = resolve_affected(["README.md", "docs/agents/README.md", "AGENTS.md"])
    assert not affected.full
    assert not affected.packages
    assert not affected.suites
    assert not affected.web


def test_empty_change_list_affects_nothing():
    affected = resolve_affected([])
    assert not affected.full
    assert not affected.packages
    assert not affected.suites
    assert not affected.web


def test_web_gate_follows_app_dependency_closure():
    assert resolve_affected(["packages/efa_fit/lib/fit.dart"]).web
    assert resolve_affected(["packages/eve-fit-os/src/lib.rs"]).web
    assert not resolve_affected(["site/home/src/routes/+page.svelte"]).web
    assert not resolve_affected(["packages/efa_fit_snapshot/lib/snapshot.dart"]).web


def test_web_relevant_packages_are_app_closure():
    relevant = web_relevant_packages()
    assert "eve_fit_assistant" in relevant
    assert "rust_lib_eve_fit_assistant" in relevant
    assert "eve-fit-os" in relevant
    assert "efa_fit_snapshot" not in relevant  # not an app dependency
