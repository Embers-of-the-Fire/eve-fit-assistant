"""Tests for the APK versionCode guard in `x build apk`."""

from __future__ import annotations

import os
import stat
import sys

from typing import TYPE_CHECKING

import click
import pytest

from bootstrap.cli.build import _apk_version_code
from bootstrap.cli.build import _find_apkanalyzer
from bootstrap.cli.build import _verify_apk_version_code


if TYPE_CHECKING:
    from pathlib import Path


def _make_fake_apkanalyzer(root: Path, *, output: str = "5000", exit_code: int = 0) -> Path:
    if sys.platform == "win32":
        output_file = root / "apkanalyzer-output.txt"
        output_file.write_text(output, encoding="utf-8")
        script = root / "apkanalyzer.cmd"
        lines = ["@echo off"]
        if exit_code == 0:
            lines.append(f'type "{output_file}"')
        else:
            lines.append("echo apkanalyzer failed >&2")
        lines.append(f"exit /b {exit_code}")
        script.write_text("\r\n".join(lines) + "\r\n", encoding="utf-8")
        return script
    script = root / "apkanalyzer"
    lines = ["#!/usr/bin/env bash"]
    if exit_code == 0:
        lines.append(f"cat <<'APKANALYZER_EOF'\n{output}\nAPKANALYZER_EOF")
    else:
        lines.append("echo 'apkanalyzer failed' >&2")
    lines.append(f"exit {exit_code}")
    script.write_text("\n".join(lines) + "\n", encoding="utf-8")
    script.chmod(script.stat().st_mode | stat.S_IXUSR)
    return script


def _put_apkanalyzer_on_path(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    *,
    output: str = "5000",
    exit_code: int = 0,
) -> Path:
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir(exist_ok=True)
    script = _make_fake_apkanalyzer(bin_dir, output=output, exit_code=exit_code)
    monkeypatch.setenv("PATH", f"{bin_dir}{os.pathsep}{os.environ.get('PATH', '')}")
    return script


class TestFindApkanalyzer:
    def test_finds_on_path(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        script = _put_apkanalyzer_on_path(tmp_path, monkeypatch)
        assert _find_apkanalyzer() == str(script)

    def test_missing_raises(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setenv("PATH", str(tmp_path))
        with pytest.raises(click.ClickException, match="apkanalyzer not found"):
            _find_apkanalyzer()


class TestApkVersionCode:
    def test_parses_output(self, tmp_path: Path) -> None:
        apkanalyzer = _make_fake_apkanalyzer(tmp_path, output="2037")
        assert _apk_version_code(str(apkanalyzer), tmp_path / "app.apk") == 2037

    def test_unparseable_output_raises(self, tmp_path: Path) -> None:
        apkanalyzer = _make_fake_apkanalyzer(tmp_path, output="not-a-number")
        with pytest.raises(click.ClickException, match="Cannot parse versionCode"):
            _apk_version_code(str(apkanalyzer), tmp_path / "app.apk")


class TestVerifyApkVersionCode:
    def test_matching_build_passes(self, tmp_path: Path) -> None:
        apkanalyzer = _make_fake_apkanalyzer(tmp_path, output="5000")
        _verify_apk_version_code(str(apkanalyzer), tmp_path / "app.apk", 5000)

    def test_abi_offset_fails(self, tmp_path: Path) -> None:
        # Legacy Flutter --split-per-abi offset: arm64 carries build + 2000.
        apkanalyzer = _make_fake_apkanalyzer(tmp_path, output="2037")
        with pytest.raises(click.ClickException, match="versionCode 2037 does not match"):
            _verify_apk_version_code(str(apkanalyzer), tmp_path / "app.apk", 37)
