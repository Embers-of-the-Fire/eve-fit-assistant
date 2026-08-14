from __future__ import annotations

import subprocess
import sys

from pathlib import Path


SCRIPT_PATH = (
    Path(__file__).resolve().parent.parent.parent / "site" / "share" / "render_assetlinks.py"
)


def _run(
    output: Path, env: dict[str, str] | None, allow_missing: bool = False
) -> subprocess.CompletedProcess[str]:
    command = [sys.executable, str(SCRIPT_PATH), str(output)]
    if allow_missing:
        command.append("--allow-missing")
    return subprocess.run(command, capture_output=True, env=env, text=True, check=False)


def test_substitutes_fingerprint(tmp_path: Path) -> None:
    output = tmp_path / "assetlinks.json"
    result = _run(output, {"APP_KEY_SHA256": "AB:CD", "PATH": "/usr/bin"})
    assert result.returncode == 0, result.stderr
    content = output.read_text(encoding="utf-8")
    assert "AB:CD" in content
    assert "@APP_KEY_SHA256@" not in content


def test_missing_env_fails(tmp_path: Path) -> None:
    output = tmp_path / "assetlinks.json"
    result = _run(output, {"PATH": "/usr/bin"})
    assert result.returncode != 0
    assert not output.exists()


def test_allow_missing_emits_placeholder(tmp_path: Path) -> None:
    output = tmp_path / "nested" / "assetlinks.json"
    result = _run(output, {"PATH": "/usr/bin"}, allow_missing=True)
    assert result.returncode == 0, result.stderr
    content = output.read_text(encoding="utf-8")
    assert "@APP_KEY_SHA256@" not in content
    assert "00:00" in content
