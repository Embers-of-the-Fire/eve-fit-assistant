"""Tests for the Layer 3 task catalog."""

from __future__ import annotations

from bootstrap.ci.catalog import STANDALONE_KINDS
from bootstrap.ci.catalog import TASK_KINDS
from bootstrap.ci.catalog import TaskInstance
from bootstrap.ci.catalog import instantiate
from bootstrap.ci.registry import PACKAGES


PACKAGES_BY_ID = {p.id: p for p in PACKAGES}
JOB_SPEC_KEYS = {
    "id",
    "slug",
    "shell",
    "uv_sync",
    "pub_get",
    "pnpm_install",
    "native_data",
    "dev_env",
    "codegen",
    "lint",
    "test",
}


def test_task_instance_ids():
    assert TaskInstance(kind="dart", package="efa_fit").id == "dart:efa_fit"
    assert TaskInstance(kind="python", package=None).id == "python"
    assert TaskInstance(kind="dart", package=None, batch=("acl", "efa_acl")).id == "dart:small"


def test_dart_kind_commands_are_scoped_to_the_package():
    package = PACKAGES_BY_ID["efa_fit"]
    kind = next(k for k in TASK_KINDS if k.id == "dart")
    commands = kind.commands(package)
    assert any(f"--scope={package.id}" in cmd and "dart analyze" in cmd for cmd in commands.lint)
    assert any("format --set-exit-if-changed" in cmd for cmd in commands.lint)
    assert commands.test == (f"dart run melos exec --scope={package.id} -- flutter test",)
    # efa_fit depends on efa_proto: the protobuf step and nothing more.
    assert commands.codegen == ("uv run x.py ci codegen --steps protobuf",)


def test_dart_kind_skips_test_command_without_tests():
    package = PACKAGES_BY_ID["efa_compat"]
    kind = next(k for k in TASK_KINDS if k.id == "dart")
    assert kind.commands(package).test == ()


def test_dart_web_kind_only_applies_to_the_app():
    kind = next(k for k in TASK_KINDS if k.id == "dart-web")
    assert kind.applies(PACKAGES_BY_ID["eve_fit_assistant"])
    assert not kind.applies(PACKAGES_BY_ID["efa_fit"])
    commands = kind.commands(PACKAGES_BY_ID["eve_fit_assistant"])
    assert commands.test == ("uv run x.py test web",)


def test_ts_kind_runs_check_script_only_when_defined():
    kind = next(k for k in TASK_KINDS if k.id == "ts")
    with_check = kind.commands(PACKAGES_BY_ID["efa-platform-api"])
    without_check = kind.commands(PACKAGES_BY_ID["manual"])
    assert any(cmd == "pnpm --filter efa-platform-api check" for cmd in with_check.lint)
    assert not any("check" in cmd and "biome" not in cmd for cmd in without_check.lint)


def test_rust_kind_excludes_opaque_crates():
    kind = next(k for k in TASK_KINDS if k.id == "rust")
    assert kind.applies(PACKAGES_BY_ID["efa-chat"])
    assert not kind.applies(PACKAGES_BY_ID["eve-fit-os"])
    assert not kind.applies(PACKAGES_BY_ID["release"])
    commands = kind.commands(PACKAGES_BY_ID["efa-chat"])
    assert commands.lint == (
        "cargo fmt --check --package efa-chat",
        "cargo clippy --package efa-chat",
    )
    assert commands.test == ("cargo test --package efa-chat",)


def test_job_spec_is_fully_self_describing():
    for instance in instantiate({"efa_fit", "eve_fit_assistant"}, {"python"}):
        spec = instance.job_spec()
        assert set(spec) == JOB_SPEC_KEYS
        assert spec["id"] == instance.id
        assert ":" not in spec["slug"]
        # At least one phase must carry work.
        assert spec["codegen"] or spec["lint"] or spec["test"]


def test_instantiate_names_every_selected_work_item():
    instances = instantiate({"efa-chat"}, {"python", "l10n"})
    ids = {i.id for i in instances}
    assert ids == {"rust:efa-chat", "python", "l10n"}


# Batched small-package instances -----------------------------------------------


def test_small_packages_of_one_kind_collapse_into_a_batch():
    instances = instantiate({"acl", "efa_acl", "efa_fit"}, set())
    assert [i.id for i in instances] == ["dart:small"]
    batch = instances[0]
    assert batch.batch == ("acl", "efa_acl", "efa_fit")


def test_large_packages_keep_dedicated_instances():
    instances = instantiate({"efa_fit", "eve_fit_assistant"}, set())
    ids = {i.id for i in instances}
    assert ids == {"dart:small", "dart:eve_fit_assistant", "dart-web:eve_fit_assistant"}


def test_batch_spec_aggregates_member_commands():
    (batch,) = instantiate({"acl", "efa_fit"}, set())
    spec = batch.job_spec()
    assert set(spec) == JOB_SPEC_KEYS
    assert spec["shell"] == "dart"
    # Member commands run per package, in batch order.
    assert "dart analyze" in spec["lint"]
    assert spec["lint"].index("--scope=acl ") < spec["lint"].index("--scope=efa_fit ")
    # acl and efa_fit both have tests; they run in batch order.
    assert spec["test"] == (
        "dart run melos exec --scope=acl -- flutter test"
        " && dart run melos exec --scope=efa_fit -- flutter test"
    )


def test_batch_codegen_is_the_deduped_union_of_member_closures():
    # efa_fit pulls protobuf; acl pulls the acl step; the union runs once.
    (batch,) = instantiate({"acl", "efa_fit", "efa_proto"}, set())
    spec = batch.job_spec()
    assert spec["codegen"] == "uv run x.py ci codegen --steps acl,protobuf"


def test_batch_setup_flags_are_the_member_union():
    (batch,) = instantiate({"acl-tool", "manual"}, set())
    spec = batch.job_spec()
    assert spec["shell"] == "js"
    assert spec["pnpm_install"] is True
    # Neither member has codegen: no Python environment is needed at all.
    assert spec["uv_sync"] is False
    (with_codegen,) = instantiate({"acl-ts", "manual"}, set())
    assert with_codegen.job_spec()["uv_sync"] is True


def test_standalone_kinds_have_triggers_and_work():
    for kind in STANDALONE_KINDS:
        assert kind.trigger, kind.id
        commands = kind.job_commands
        assert commands.codegen or commands.lint or commands.test, kind.id
