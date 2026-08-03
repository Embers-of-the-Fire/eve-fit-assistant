from __future__ import annotations

from bootstrap.ci.suites import SUITE_DEFINITIONS
from bootstrap.ci.suites import calculate_ci_matrix


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
    names = _suite_names(["lib/main.dart"])
    assert "dart" in names
    assert "dart-web" in names


def test_dart_web_not_included_for_python_only_changes():
    names = _suite_names(["bootstrap/cli/test.py"])
    assert "dart-web" not in names


def test_dart_web_included_on_infra_change():
    names = _suite_names(["bootstrap/ci/suites.py"])
    assert "dart-web" in names
