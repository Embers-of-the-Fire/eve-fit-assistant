"""Tests for the Layer 4 resolver."""

from __future__ import annotations

import subprocess

import bootstrap.ci.resolve as resolver

from bootstrap.ci.catalog import STANDALONE_KINDS
from bootstrap.ci.catalog import TASK_KINDS
from bootstrap.ci.registry import PACKAGES


ALL_PACKAGE_IDS = {p.id for p in PACKAGES}
ALL_STANDALONE_IDS = {k.id for k in STANDALONE_KINDS}


def _task_ids(files: list[str]) -> set[str]:
    return {i.id for i in resolver.resolve(files).instances}


def test_changed_files_map_to_packages_by_longest_prefix():
    resolution = resolver.resolve(["apps/eve-fit-assistant/rust/lib/efa-chat/src/lib.rs"])
    # efa-chat is nested inside the FRB crate's directory; the most specific
    # package owns the file, and dependents close over it.
    assert "efa-chat" in resolution.packages
    assert "rust_lib_eve_fit_assistant" in resolution.packages
    assert "eve_fit_assistant" in resolution.packages


def test_dependents_closure_marks_app_for_base_package_change():
    resolution = resolver.resolve(["packages/efa_proto/lib/eve.pb.dart"])
    assert {"efa_proto", "efa_fit", "efa_platform_client", "eve_fit_assistant"} <= set(
        resolution.packages
    )


def test_ts_leaf_change_pulls_in_ts_dependents_only():
    resolution = resolver.resolve(["packages/efa_proto_ts/src/index.ts"])
    assert {"efa-proto-ts", "efa-fit-snapshot-ts", "efa-platform", "efa-platform-api"} <= set(
        resolution.packages
    )
    assert not any(p.ecosystem == "dart" for p in PACKAGES if p.id in resolution.packages)


def test_unrelated_files_affect_nothing():
    resolution = resolver.resolve(["README.md", "docs/agents/README.md", "AGENTS.md"])
    assert not resolution.escalated
    assert not resolution.packages
    assert not resolution.instances


def test_empty_change_list_affects_nothing():
    resolution = resolver.resolve([])
    assert not resolution.escalated
    assert not resolution.packages
    assert not resolution.instances


def test_prefix_siblings_do_not_match_package_directories():
    assert not resolver.resolve(["apps/eve-fit-assistant-webfoo/x.txt"]).packages


def test_blast_radius_ecosystem_effect():
    resolution = resolver.resolve(["pubspec.lock"])
    assert {p.id for p in PACKAGES if p.ecosystem == "dart"} <= set(resolution.packages)
    assert "efa-platform-api" not in resolution.packages


def test_blast_radius_schema_change_marks_protobuf_consumers():
    resolution = resolver.resolve(["data/schema/fit.proto"])
    assert {"efa_proto", "efa-proto-ts", "efa-platform-fit-storage"} <= set(resolution.packages)
    assert "python" in resolution.standalone


def test_standalone_triggers_select_standalone_kinds():
    resolution = resolver.resolve(["bootstrap/cli/build.py"])
    assert "python" in resolution.standalone
    resolution = resolver.resolve(["apps/eve-fit-assistant/l10n/app_zh.arb"])
    assert "l10n" in resolution.standalone
    assert "eve_fit_assistant" in resolution.packages


def test_escalation_instantiates_the_entire_catalog():
    resolution = resolver.escalated_resolution(())
    assert resolution.escalated
    assert set(resolution.packages) == ALL_PACKAGE_IDS
    assert set(resolution.standalone) == ALL_STANDALONE_IDS
    # Full coverage is defined by escalation itself: every package x every
    # applicable kind, plus all standalone kinds.
    expected = set(ALL_STANDALONE_IDS)
    for package in PACKAGES:
        for kind in TASK_KINDS:
            if kind.applies(package):
                expected.add(f"{kind.id}:{package.id}")
    assert {i.id for i in resolution.instances} == expected


def test_escalating_blast_radius_equals_explicit_escalation():
    assert {i.id for i in resolver.resolve(["flake.nix"]).instances} == {
        i.id for i in resolver.escalated_resolution(()).instances
    }


def test_web_bundle_gate_is_a_query_over_the_resolver_output():
    assert resolver.web_bundle_gate(resolver.resolve(["packages/efa_fit/lib/fit.dart"]))
    assert resolver.web_bundle_gate(resolver.resolve(["packages/eve-fit-os/src/lib.rs"]))
    assert resolver.web_bundle_gate(resolver.resolve(["flake.nix"]))
    assert not resolver.web_bundle_gate(resolver.resolve(["site/home/src/routes/+page.svelte"]))
    assert not resolver.web_bundle_gate(resolver.resolve([]))


def test_affected_report_shape():
    report = resolver.affected_report(resolver.resolve(["worker/email-filter/src/index.ts"]))
    assert report["escalated"] is False
    assert report["packages"] == ["email-filter"]
    assert report["tasks"] == ["ts:email-filter"]


def test_job_matrix_renders_specs_for_every_instance():
    resolution = resolver.resolve(["packages/efa_fit/lib/fit.dart"])
    specs = resolver.job_matrix(resolution)
    assert {s["id"] for s in specs} == {i.id for i in resolution.instances}


# --------------------------------------------------------- change detection


def _git(repo, *args: str) -> None:
    subprocess.run(["git", *args], cwd=repo, check=True, capture_output=True)


def test_changed_files_uses_merge_base_three_dot_diff(tmp_path, monkeypatch):
    monkeypatch.setattr(resolver, "PROJECT_ROOT", tmp_path)
    repo = tmp_path
    _git(repo, "init", "-b", "main")
    _git(repo, "config", "user.email", "test@example.com")
    _git(repo, "config", "user.name", "Test")
    (repo / "base.txt").write_text("base\n")
    _git(repo, "add", ".")
    _git(repo, "commit", "-m", "base")

    _git(repo, "checkout", "-b", "feature")
    (repo / "feature.txt").write_text("feature\n")
    _git(repo, "add", ".")
    _git(repo, "commit", "-m", "feature work")

    # The target branch advances after the branch point; the three-dot diff
    # must not report the target's own new commits as changes.
    _git(repo, "checkout", "main")
    (repo / "target.txt").write_text("target\n")
    _git(repo, "add", ".")
    _git(repo, "commit", "-m", "target advanced")

    assert resolver.changed_files("main", "feature") == ["feature.txt"]
