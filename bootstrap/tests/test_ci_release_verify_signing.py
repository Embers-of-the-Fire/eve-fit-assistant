"""Tests for the `x ci release verify-signing` command."""

from __future__ import annotations

import os
import stat

from typing import TYPE_CHECKING

import click
import click.testing
import pytest

from bootstrap.ci.release import _find_apksigner
from bootstrap.ci.release import _normalize_sha256
from bootstrap.ci.release import _parse_apksigner_digest
from bootstrap.ci.release import _verify_apk_signature
from bootstrap.ci.release import _verify_signing
from bootstrap.cli import register_all_commands


if TYPE_CHECKING:
    from pathlib import Path


_DIGEST = "aa11bb22cc33dd44ee55ff6600112233445566778899aabbccddeeff001122"
_DIGEST_COLONED = ":".join(_DIGEST[i : i + 2] for i in range(0, len(_DIGEST), 2)).upper()

_APKSIGNER_OUTPUT = f"""\
Verifies
Verified using v1 scheme (JAR signing): true
Verified using v2 scheme (APK Signature Scheme v2): true
Verified using v3 scheme (APK Signature Scheme v3): false
Number of signers: 1
Signer #1 certificate DN: CN=EFA, O=EFA Tech
Signer #1 certificate SHA-256 digest: {_DIGEST}
Signer #1 certificate SHA-1 digest: 00112233445566778899aabbccddeeff00112233
Signer #1 certificate MD5 digest: 00112233445566778899aabbccddeeff
Signer #1 key algorithm: RSA
Signer #1 key size (bits): 2048
"""


def _make_fake_apksigner(
    root: Path, *, output: str = _APKSIGNER_OUTPUT, exit_code: int = 0
) -> Path:
    script = root / "apksigner"
    lines = ["#!/usr/bin/env bash"]
    if exit_code == 0:
        lines.append(f"cat <<'APKSIGNER_EOF'\n{output}APKSIGNER_EOF")
    else:
        lines.append("echo 'verification failed' >&2")
    lines.append(f"exit {exit_code}")
    script.write_text("\n".join(lines) + "\n", encoding="utf-8")
    script.chmod(script.stat().st_mode | stat.S_IXUSR)
    return script


def _put_apksigner_on_path(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    *,
    output: str = _APKSIGNER_OUTPUT,
    exit_code: int = 0,
) -> Path:
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir(exist_ok=True)
    script = _make_fake_apksigner(bin_dir, output=output, exit_code=exit_code)
    monkeypatch.setenv("PATH", f"{bin_dir}{os.pathsep}{os.environ.get('PATH', '')}")
    return script


class TestNormalizeSha256:
    def test_plain_lowercase(self) -> None:
        assert _normalize_sha256(_DIGEST) == _DIGEST

    def test_coloned_uppercase(self) -> None:
        assert _normalize_sha256(_DIGEST_COLONED) == _DIGEST

    def test_whitespace_stripped(self) -> None:
        assert _normalize_sha256(f"  {_DIGEST_COLONED} \n") == _DIGEST


class TestParseApksignerDigest:
    def test_parses_first_signer_digest(self) -> None:
        assert _parse_apksigner_digest(_APKSIGNER_OUTPUT) == _DIGEST

    def test_missing_digest_raises(self) -> None:
        with pytest.raises(click.ClickException, match="no certificate SHA-256 digest"):
            _parse_apksigner_digest("Verifies\nNumber of signers: 0\n")


class TestFindApksigner:
    def test_finds_on_path(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        script = _put_apksigner_on_path(tmp_path, monkeypatch)
        assert _find_apksigner() == str(script)

    def test_missing_raises(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setenv("PATH", str(tmp_path))
        with pytest.raises(click.ClickException, match="apksigner not found"):
            _find_apksigner()


class TestVerifyApkSignature:
    def test_matching_digest_passes(self, tmp_path: Path) -> None:
        apksigner = _make_fake_apksigner(tmp_path)
        apk = tmp_path / "app-release.apk"
        apk.write_bytes(b"fake-apk")
        _verify_apk_signature(str(apksigner), apk, _DIGEST)

    def test_mismatched_digest_fails(self, tmp_path: Path) -> None:
        apksigner = _make_fake_apksigner(tmp_path)
        apk = tmp_path / "app-release.apk"
        apk.write_bytes(b"fake-apk")
        with pytest.raises(click.ClickException, match="certificate SHA-256 mismatch"):
            _verify_apk_signature(str(apksigner), apk, "ff" * 32)

    def test_apksigner_failure_fails(self, tmp_path: Path) -> None:
        apksigner = _make_fake_apksigner(tmp_path, exit_code=1)
        apk = tmp_path / "app-release.apk"
        apk.write_bytes(b"fake-apk")
        with pytest.raises(SystemExit):
            _verify_apk_signature(str(apksigner), apk, _DIGEST)


class TestVerifySigning:
    def test_verifies_all_apks_recursively(
        self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        _put_apksigner_on_path(tmp_path, monkeypatch)
        apk_dir = tmp_path / "out"
        (apk_dir / "nested").mkdir(parents=True)
        (apk_dir / "app-release.apk").write_bytes(b"fake-apk")
        (apk_dir / "nested" / "app-arm64-release.apk").write_bytes(b"fake-apk")
        _verify_signing(apk_dir, _DIGEST_COLONED)

    def test_no_apks_fails(self, tmp_path: Path) -> None:
        with pytest.raises(click.ClickException, match="No APKs found"):
            _verify_signing(tmp_path, _DIGEST)

    def test_missing_expected_fails(self, tmp_path: Path) -> None:
        with pytest.raises(click.ClickException, match="Expected fingerprint missing"):
            _verify_signing(tmp_path, None)


class TestVerifySigningCommand:
    def test_expected_sha256_from_env(
        self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        _put_apksigner_on_path(tmp_path, monkeypatch)
        monkeypatch.setenv("APP_KEY_SHA256", _DIGEST_COLONED)
        (tmp_path / "app-release.apk").write_bytes(b"fake-apk")

        cli = click.Group()
        register_all_commands(cli)
        runner = click.testing.CliRunner()
        result = runner.invoke(cli, ["ci", "release", "verify-signing", "--apk-dir", str(tmp_path)])
        assert result.exit_code == 0, result.output
        assert "1 APK(s) verified" in result.output

    def test_missing_expected_sha256_fails(self, tmp_path: Path) -> None:
        (tmp_path / "app-release.apk").write_bytes(b"fake-apk")
        env = {k: v for k, v in os.environ.items() if k != "APP_KEY_SHA256"}
        cli = click.Group()
        register_all_commands(cli)
        runner = click.testing.CliRunner(env=env)
        result = runner.invoke(cli, ["ci", "release", "verify-signing", "--apk-dir", str(tmp_path)])
        assert result.exit_code != 0
        assert "Expected fingerprint missing" in result.output
