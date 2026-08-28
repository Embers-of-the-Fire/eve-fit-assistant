from __future__ import annotations

import click

from click.testing import CliRunner

from bootstrap.cli import runtime
from bootstrap.cli.test import register_test_commands


def _run_test_all(monkeypatch, scope, argv):
    executed: list[list[str]] = []
    monkeypatch.setattr(runtime, "execute", lambda cmd, *a, **k: executed.append(list(cmd)))
    monkeypatch.setattr(runtime, "run_melos", lambda *a, **k: executed.append(["melos"]))
    monkeypatch.setattr(runtime, "resolve_change_scope", lambda *a: scope)
    monkeypatch.setattr("bootstrap.cli.test.get_command", lambda name: name)
    monkeypatch.setattr("bootstrap.cli.test.get_melos_command", lambda: ["melos"])
    cli = click.Group()
    register_test_commands(cli)
    result = CliRunner().invoke(cli, ["test", "all", *argv])
    assert result.exit_code == 0, result.output
    return executed


def _ran_pytest(executed: list[list[str]]) -> bool:
    return any("pytest" in cmd for cmd in executed)


def test_all_unscoped_runs_python(monkeypatch):
    executed = _run_test_all(monkeypatch, (None, None), [])
    assert _ran_pytest(executed)


def test_all_skips_python_for_dart_only_package_scope(monkeypatch):
    executed = _run_test_all(monkeypatch, (("efa_fit",), None), ["--packages", "efa_fit"])
    assert not _ran_pytest(executed)
    assert any("exec" in cmd for cmd in executed)  # scoped dart run still happens


def test_all_skips_python_for_dart_only_changes(monkeypatch):
    scope = (("efa_fit",), ("packages/efa_fit/lib/fit.dart",))
    executed = _run_test_all(monkeypatch, scope, ["--changed"])
    assert not _ran_pytest(executed)


def test_all_runs_python_for_python_relevant_changes(monkeypatch):
    scope = (("efa_fit",), ("bootstrap/cli/build.py",))
    executed = _run_test_all(monkeypatch, scope, ["--changed"])
    assert _ran_pytest(executed)


def test_all_runs_python_on_infra_escalation(monkeypatch):
    # Infrastructure changes escalate to an unscoped run, which includes Python.
    scope = (None, ("flake.nix",))
    executed = _run_test_all(monkeypatch, scope, ["--changed"])
    assert _ran_pytest(executed)
