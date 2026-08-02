from __future__ import annotations

import os
import sys

from typing import TYPE_CHECKING

import pytest

from bootstrap.ci.diagnostics import collect_diagnostics
from bootstrap.ci.diagnostics import redact_staged_files


if TYPE_CHECKING:
    from pathlib import Path


def _write(path: Path, content: bytes) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(content)
    return path


def test_redact_literal_metacharacters(tmp_path: Path):
    target = _write(
        tmp_path / "log.txt",
        b"key=a.b*c|d$E and other aXbYc|d$E text\n",
    )
    scanned, redacted = redact_staged_files(tmp_path, ["a.b*c|d$E"])
    assert (scanned, redacted) == (1, 1)
    assert target.read_bytes() == b"key=<redacted> and other aXbYc|d$E text\n"


def test_redact_multiple_values_and_files(tmp_path: Path):
    first = _write(tmp_path / "a.log", b"alpha secret-one omega\n")
    second = _write(tmp_path / "nested" / "b.log", b"alpha secret-two omega\n")
    scanned, redacted = redact_staged_files(tmp_path, ["secret-one", "secret-two"])
    assert (scanned, redacted) == (2, 2)
    assert first.read_bytes() == b"alpha <redacted> omega\n"
    assert second.read_bytes() == b"alpha <redacted> omega\n"


def test_redact_skips_empty_values(tmp_path: Path):
    target = _write(tmp_path / "log.txt", b"unchanged\n")
    scanned, redacted = redact_staged_files(tmp_path, ["", "   \n".strip()])
    assert (scanned, redacted) == (1, 0)
    assert target.read_bytes() == b"unchanged\n"


def test_redact_binary_safe(tmp_path: Path):
    target = _write(tmp_path / "blob.bin", b"\x00\xffsecret\x00\xfe")
    scanned, redacted = redact_staged_files(tmp_path, ["secret"])
    assert (scanned, redacted) == (1, 1)
    assert target.read_bytes() == b"\x00\xff<redacted>\x00\xfe"


def test_redact_non_utf8_secret(tmp_path: Path):
    secret_bytes = b"\xff\xfetoken"
    secret = secret_bytes.decode("utf-8", errors="surrogateescape")
    target = _write(tmp_path / "log.txt", secret_bytes + b" value " + secret_bytes + b"\n")
    _, redacted = redact_staged_files(tmp_path, [secret])
    assert redacted == 1
    assert target.read_bytes() == b"<redacted> value <redacted>\n"


@pytest.mark.skipif(
    sys.platform == "win32",
    reason="relies on POSIX chmod semantics; Windows chmod only toggles the read-only flag",
)
def test_redact_removes_unreadable_files(tmp_path: Path):
    target = _write(tmp_path / "log.txt", b"secret\n")
    os.chmod(target, 0)
    try:
        scanned, _ = redact_staged_files(tmp_path, ["secret"])
        assert scanned == 1
        assert not target.exists()
    finally:
        if target.exists():
            os.chmod(target, 0o644)


def test_collect_xpy_logs_and_byproduct_guard(tmp_path: Path):
    root = tmp_path / "repo"
    _write(root / "cache" / "log" / "20240101-000000.log", b"log line\n")
    _write(root / "cache" / "log" / "not-a-log.txt", b"nope\n")
    stage = tmp_path / "stage"

    staged = collect_diagnostics(root, stage)

    xpy_log = stage / "xpy-log" / "20240101-000000.log"
    assert xpy_log in staged
    assert xpy_log.read_bytes() == b"log line\n"
    assert not (stage / "xpy-log" / "not-a-log.txt").exists()
    assert (stage / "environment.txt").is_file()


def test_collect_jvm_crash_logs_with_pruning(tmp_path: Path):
    root = tmp_path / "repo"
    included = _write(root / "sub" / "hs_err_pid123.log", b"crash\n")
    _write(root / "build" / "hs_err_pid999.log", b"skip\n")
    _write(root / "android" / "build" / "replay_pid1.log", b"skip\n")
    _write(root / ".git" / "hs_err_pid1.log", b"skip\n")
    _write(root / "sub" / "node_modules" / "hs_err_pid5.log", b"skip\n")
    _write(root / "sub" / "nested" / ".dart_tool" / "replay_pid7.log", b"skip\n")
    stage = tmp_path / "stage"

    collect_diagnostics(root, stage)

    crash_dir = stage / "jvm-crash"
    copied = [p.name for p in crash_dir.iterdir()]
    assert copied == [included.name]


def test_collect_drops_crash_byproducts(tmp_path: Path):
    root = tmp_path / "repo"
    _write(root / "hs_err_pid1.log", b"crash\n")
    stage = tmp_path / "stage"
    stage.mkdir(parents=True)
    _write(stage / "jvm-crash" / "dump.hprof", b"heap\n")
    _write(stage / "jvm-crash" / "core.1234", b"core\n")

    staged = collect_diagnostics(root, stage)

    assert not (stage / "jvm-crash" / "dump.hprof").exists()
    assert not (stage / "jvm-crash" / "core.1234").exists()
    assert (stage / "jvm-crash" / "hs_err_pid1.log") in staged


def test_environment_snapshot_content(tmp_path: Path):
    root = tmp_path / "repo"
    root.mkdir()
    stage = tmp_path / "stage"

    collect_diagnostics(root, stage)

    content = (stage / "environment.txt").read_text(encoding="utf-8")
    assert "== date ==" in content
    assert "== uname ==" in content
    assert "== df -h ==" in content
    assert "== free -m ==" in content
    assert "== oom-killer evidence ==" in content
