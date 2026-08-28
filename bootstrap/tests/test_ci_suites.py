from __future__ import annotations

from bootstrap.ci.suites import calculate_ci_matrix
from bootstrap.ci.suites import full_matrix
from bootstrap.ci.suites import web_preview_affected
from bootstrap.monorepo import ALL_SUITES


def _suite_names(files: list[str]) -> set[str]:
    return {entry["suite"] for entry in calculate_ci_matrix(files)}


def _suite_entry(files: list[str], name: str) -> dict:
    return next(e for e in calculate_ci_matrix(files) if e["suite"] == name)


def test_full_matrix_covers_all_suites_unscoped():
    entries = full_matrix()
    assert {e["suite"] for e in entries} == set(ALL_SUITES)
    for entry in entries:
        assert "--packages" not in entry["lint_command"]
        assert "--packages" not in entry["command"]


def test_dart_and_dart_web_included_for_app_changes():
    names = _suite_names(["apps/eve-fit-assistant/lib/main.dart"])
    assert "dart" in names
    assert "dart-web" in names


def test_dart_web_not_included_for_python_only_changes():
    names = _suite_names(["bootstrap/cli/test.py"])
    assert names == {"python"}


def test_all_suites_on_infra_change():
    names = _suite_names(["bootstrap/ci/suites.py"])
    assert names == set(ALL_SUITES)


def test_all_suites_on_selection_source_change():
    # The registry/graph and the scope resolver decide what CI runs; a defect
    # there must not merge with the dart, site, worker, or l10n suites unrun.
    for path in [
        "bootstrap/monorepo/packages.py",
        "bootstrap/monorepo/graph.py",
        "bootstrap/cli/runtime.py",
    ]:
        assert _suite_names([path]) == set(ALL_SUITES), path


def test_infra_matrix_is_unscoped():
    for entry in calculate_ci_matrix(["flake.nix"]):
        assert "--packages" not in entry["lint_command"]
        assert "--packages" not in entry["command"]


def test_package_changes_trigger_dart_suites_and_l10n():
    names = _suite_names(["packages/efa_fit_snapshot/l10n/snapshot_zh.arb"])
    assert "dart" in names
    assert "dart-web" in names
    assert "l10n" in names


def test_worker_changes_trigger_worker_suite_only():
    names = _suite_names(["worker/efa-platform-api/src/index.ts"])
    assert names == {"worker"}


def test_ts_only_package_change_does_not_trigger_dart():
    # The legacy glob matrix matched every `packages/**` change to the Dart
    # suites; the graph restricts this to real dependents.
    names = _suite_names(["packages/efa_fit_snapshot_ts/src/index.ts"])
    assert "snapshot-ts" in names
    assert "dart" not in names
    assert "dart-web" not in names


def test_dart_suite_commands_are_scoped_to_affected_packages():
    entry = _suite_entry(["packages/efa_fit/lib/fit.dart"], "dart")
    # efa_fit_snapshot and the app both (transitively) depend on efa_fit.
    expected = "--packages efa_fit,efa_fit_snapshot,eve_fit_assistant"
    assert expected in entry["lint_command"]
    assert expected in entry["command"]
    assert entry["codegen_command"] == "uv run x.py ci codegen --lang dart"


def test_dart_web_mirrors_dart_scoping():
    files = ["packages/efa_fit/lib/fit.dart"]
    dart = _suite_entry(files, "dart")
    dart_web = _suite_entry(files, "dart-web")
    assert dart_web["shell"] == dart["shell"]
    assert dart_web["lint_command"] == dart["lint_command"]
    assert dart_web["codegen_command"] == dart["codegen_command"]
    assert dart_web["command"] == "uv run x.py test web"


def test_worker_suite_scopes_js_tests():
    entry = _suite_entry(["packages/efa_proto_ts/src/index.ts"], "worker")
    assert entry["command"].startswith("uv run x.py test js --packages ")
    assert "efa-platform-api" in entry["command"]


def test_web_preview_covers_core_build_inputs():
    for path in [
        "flake.nix",
        "flake.lock",
        "Cargo.toml",
        "Cargo.lock",
        "apps/eve-fit-assistant/rust/src/api/fit.rs",
        "packages/eve-fit-os",
        "apps/eve-fit-assistant/web/index.html",
        "apps/eve-fit-assistant/lib/main.dart",
        "pubspec.yaml",
        "pubspec.lock",
        "apps/eve-fit-assistant/l10n.yaml",
        "apps/eve-fit-assistant/l10n/app_zh.arb",
        "data/schema/release_index.proto",
        "bootstrap/cli/build.py",
        "x.py",
        "pyproject.toml",
        "uv.lock",
        ".github/workflows/web-preview.yml",
        "ci/config/wrangler.nightly.toml",
    ]:
        assert web_preview_affected([path]), f"expected {path} to trigger web preview"


def test_web_preview_unaffected_by_unrelated_changes():
    assert not web_preview_affected(
        [
            "site/home/src/routes/+page.svelte",
            "docs/manual/intro.md",
            "AGENTS.md",
            "README.md",
        ]
    )


def test_web_preview_follows_infra_escalation():
    # Infrastructure changes run the full matrix; the web bundle is rebuilt
    # as part of it, so the preview gate must agree.
    assert web_preview_affected([".github/workflows/ci.yml"])
    assert web_preview_affected(["bootstrap/ci/commands.py"])


def test_web_preview_empty_change_list():
    assert not web_preview_affected([])


def test_web_preview_ignores_prefix_siblings():
    # Sibling paths sharing a prefix must not match package directories.
    assert not web_preview_affected(["apps/eve-fit-assistant-webfoo/x.txt"])
