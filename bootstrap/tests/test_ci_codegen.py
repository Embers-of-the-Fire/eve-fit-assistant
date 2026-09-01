"""Tests for the Layer 2 codegen step graph."""

from __future__ import annotations

import pytest

from bootstrap.ci.codegen import all_step_names
from bootstrap.ci.codegen import resolve_steps
from bootstrap.ci.codegen import steps_for_packages


def test_leaf_package_without_codegen_generates_nothing():
    assert steps_for_packages(["efa_compat"]) == []


def test_protobuf_consumer_generates_exactly_protobuf():
    # efa_fit depends only on efa_proto; its closure requires the protobuf
    # step and nothing more.
    assert steps_for_packages(["efa_fit"]) == ["protobuf"]


def test_efa_constant_generates_dart_tools():
    # lib/eve.dart imports the gitignored eve_attr_generated.dart produced by
    # the attr_id generator.
    assert steps_for_packages(["efa_constant"]) == ["dart_tools"]


def test_app_closure_resolves_full_step_set():
    steps = set(steps_for_packages(["eve_fit_assistant"]))
    assert steps == {"protobuf", "frb", "dart_tools", "build_runner", "l10n", "acl"}


def test_step_level_dependencies_are_included():
    # build_runner requires the FRB bridge and protobuf outputs.
    steps = resolve_steps(["build_runner"])
    assert set(steps) == {"build_runner", "frb", "protobuf"}
    assert steps.index("build_runner") > steps.index("frb")
    assert steps.index("build_runner") > steps.index("protobuf")


def test_steps_are_topologically_ordered():
    for packages in (["eve_fit_assistant"], ["acl", "efa-proto-ts"], ["efa-chat"]):
        steps = steps_for_packages(packages)
        assert steps == resolve_steps(steps)


def test_unknown_step_raises():
    with pytest.raises(ValueError, match="Unknown codegen step"):
        resolve_steps(["does-not-exist"])


def test_unknown_package_raises():
    with pytest.raises(ValueError, match="Unknown package"):
        steps_for_packages(["does-not-exist"])


def test_all_steps_excludes_local_only_steps():
    # dogma_units needs a selected data workspace; it is never in CI/release.
    assert "dogma_units" not in all_step_names()
    assert set(all_step_names()) == {
        "protobuf",
        "protobuf_ts",
        "frb",
        "dart_tools",
        "build_runner",
        "l10n",
        "acl",
    }
