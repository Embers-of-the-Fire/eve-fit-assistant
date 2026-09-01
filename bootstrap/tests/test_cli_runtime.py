from __future__ import annotations

import pytest

import bootstrap.ci.resolve as resolver

from bootstrap.cli import runtime


def _fake_resolver(monkeypatch, resolution: resolver.Resolution) -> None:
    monkeypatch.setattr(resolver, "changed_files_local", lambda base_ref: list(resolution.files))
    monkeypatch.setattr(resolver, "resolve", lambda files: resolution)


def test_escalated_scope_drops_package_and_file_scope(monkeypatch, capsys):
    _fake_resolver(monkeypatch, resolver.escalated_resolution(("flake.nix",)))
    package_ids, files = runtime.resolve_change_scope(True, None, None)
    assert package_ids is None
    assert files is None
    assert "full pass" in capsys.readouterr().out


def test_changed_scope_keeps_packages_and_files(monkeypatch):
    resolution = resolver.Resolution(
        escalated=False,
        files=("packages/efa_fit/lib/fit.dart",),
        packages=frozenset({"efa_fit"}),
        standalone=frozenset(),
        instances=(),
    )
    _fake_resolver(monkeypatch, resolution)
    package_ids, files = runtime.resolve_change_scope(True, None, None)
    assert package_ids == ("efa_fit",)
    assert files == ("packages/efa_fit/lib/fit.dart",)


def test_packages_option_and_unscoped_default():
    assert runtime.resolve_change_scope(False, None, None) == (None, None)
    assert runtime.resolve_change_scope(False, None, "efa_fit, eve_fit_assistant") == (
        ("efa_fit", "eve_fit_assistant"),
        None,
    )
    with pytest.raises(Exception, match="cannot be used together"):
        runtime.resolve_change_scope(True, None, "efa_fit")
