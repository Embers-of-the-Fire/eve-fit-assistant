from __future__ import annotations

from bootstrap.ci.suites import SUITE_DEFINITIONS
from bootstrap.ci.suites import WEB_PREVIEW_PATTERNS
from bootstrap.ci.suites import calculate_ci_matrix
from bootstrap.ci.suites import web_preview_affected


def _suite_names(files: list[str]) -> set[str]:
    return {entry["suite"] for entry in calculate_ci_matrix(files)}


def _suite_def(name: str) -> dict:
    return next(s for s in SUITE_DEFINITIONS if s["suite"] == name)


def test_dart_web_mirrors_dart_triggers_and_environment():
    dart = _suite_def("dart")
    dart_web = _suite_def("dart-web")

    assert dart_web["patterns"] == dart["patterns"]
    assert dart_web["shell"] == dart["shell"]
    assert dart_web["lint_command"] == dart["lint_command"]
    assert dart_web["codegen_command"] == dart["codegen_command"]
    assert dart_web["command"] == "uv run x.py test web"


def test_dart_web_included_for_dart_changes():
    names = _suite_names(["apps/eve-fit-assistant/lib/main.dart"])
    assert "dart" in names
    assert "dart-web" in names


def test_dart_web_not_included_for_python_only_changes():
    names = _suite_names(["bootstrap/cli/test.py"])
    assert "dart-web" not in names


def test_dart_web_included_on_infra_change():
    names = _suite_names(["bootstrap/ci/suites.py"])
    assert "dart-web" in names


def test_package_changes_trigger_dart_suites():
    names = _suite_names(["packages/efa_fit_snapshot/l10n/snapshot_zh.arb"])
    assert "dart" in names
    assert "dart-web" in names
    assert "l10n" in names


def test_worker_changes_trigger_worker_suite():
    names = _suite_names(["worker/efa-platform-api/src/index.ts"])
    assert names == {"worker"}


def test_web_preview_patterns_cover_core_build_inputs():
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
    ]:
        assert web_preview_affected([path]), f"expected {path} to trigger web preview"


def test_web_preview_unaffected_by_unrelated_changes():
    assert not web_preview_affected(
        [
            "site/home/src/routes/+page.svelte",
            "docs/manual/intro.md",
            ".github/workflows/ci.yml",
            "AGENTS.md",
            "README.md",
        ]
    )


def test_web_preview_empty_change_list():
    assert not web_preview_affected([])


def test_web_preview_patterns_are_anchored():
    # Sibling paths sharing a prefix must not match directory patterns.
    assert not web_preview_affected(["webfoo/x.txt", "library/main.dart"])
    assert "apps/eve-fit-assistant/web/**" in WEB_PREVIEW_PATTERNS
