from __future__ import annotations

import sys

import click
import pytest

import bootstrap.ci.resolve as resolver

from bootstrap.cli import runtime
from bootstrap.constant import PROTOC_GEN_DART_VERSION


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


def _stub_dart_pub_global(monkeypatch, tmp_path, commands: list):
    """Fake the pub cache and dart CLI so no real activation or compile runs."""
    monkeypatch.setenv("PUB_CACHE", str(tmp_path))
    monkeypatch.setattr(runtime, "get_command", lambda name: name)

    def fake_execute(cmd, title, **kwargs):
        commands.append(cmd)
        if "list" in cmd:
            return f"protoc_plugin {PROTOC_GEN_DART_VERSION}"
        return ""

    monkeypatch.setattr(runtime, "execute", fake_execute)


def _write_activated_plugin_layout(tmp_path):
    entrypoint = (
        tmp_path
        / "hosted"
        / "pub.dev"
        / f"protoc_plugin-{PROTOC_GEN_DART_VERSION}"
        / "bin"
        / "protoc_plugin.dart"
    )
    entrypoint.parent.mkdir(parents=True)
    entrypoint.write_text("void main() {}\n")
    package_config = (
        tmp_path / "global_packages" / "protoc_plugin" / ".dart_tool" / "package_config.json"
    )
    package_config.parent.mkdir(parents=True)
    package_config.write_text("{}\n")
    return entrypoint, package_config


def test_protoc_gen_dart_plugin_uses_shim_off_windows(monkeypatch, tmp_path):
    commands = []
    _stub_dart_pub_global(monkeypatch, tmp_path, commands)
    monkeypatch.setattr(sys, "platform", "linux")
    plugin = runtime.protoc_gen_dart_plugin()
    assert plugin == str(tmp_path / "bin" / "protoc-gen-dart")
    assert all(cmd[:3] != ["dart", "compile", "exe"] for cmd in commands)


def test_protoc_gen_dart_plugin_compiles_native_exe_on_windows(monkeypatch, tmp_path):
    commands = []
    _stub_dart_pub_global(monkeypatch, tmp_path, commands)
    monkeypatch.setattr(sys, "platform", "win32")
    entrypoint, package_config = _write_activated_plugin_layout(tmp_path)
    plugin = runtime.protoc_gen_dart_plugin()
    assert plugin == str(tmp_path / "bin" / f"protoc-gen-dart-{PROTOC_GEN_DART_VERSION}.exe")
    compile_cmd = next(cmd for cmd in commands if cmd[:3] == ["dart", "compile", "exe"])
    assert str(entrypoint) in compile_cmd
    assert f"--packages={package_config}" in compile_cmd


def test_protoc_gen_dart_plugin_reuses_cached_exe_on_windows(monkeypatch, tmp_path):
    commands = []
    _stub_dart_pub_global(monkeypatch, tmp_path, commands)
    monkeypatch.setattr(sys, "platform", "win32")
    executable = tmp_path / "bin" / f"protoc-gen-dart-{PROTOC_GEN_DART_VERSION}.exe"
    executable.parent.mkdir(parents=True)
    executable.write_bytes(b"")
    assert runtime.protoc_gen_dart_plugin() == str(executable)
    assert all(cmd[:3] != ["dart", "compile", "exe"] for cmd in commands)


def test_protoc_gen_dart_plugin_missing_activation_layout_raises(monkeypatch, tmp_path):
    commands = []
    _stub_dart_pub_global(monkeypatch, tmp_path, commands)
    monkeypatch.setattr(sys, "platform", "win32")
    with pytest.raises(click.ClickException, match="layout not found"):
        runtime.protoc_gen_dart_plugin()
