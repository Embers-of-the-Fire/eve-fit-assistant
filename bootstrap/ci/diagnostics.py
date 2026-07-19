from __future__ import annotations

import fnmatch
import os
import shutil
import subprocess

from pathlib import Path

import click

from bootstrap.constant import PROJECT_ROOT
from bootstrap.log import error
from bootstrap.log import info
from bootstrap.log import warning


REDACTED = b"<redacted>"

XPY_LOG_DIR = "xpy-log"
JVM_CRASH_DIR = "jvm-crash"
GRADLE_DAEMON_DIR = "gradle-daemon"
MINIO_DIR = "minio"

JVM_CRASH_PATTERNS = ("hs_err_pid*.log", "replay_pid*.log")
PRUNE_DIR_NAMES = frozenset(
    {
        ".dart_tool",
        ".git",
        ".venv",
        "__pycache__",
        "build",
        "node_modules",
        "target",
    }
)
CRASH_BYPRODUCT_PATTERNS = ("*.hprof", "core.[0-9]*")
MINIO_LOG_PATHS = (Path("/tmp/efa-ci-minio.log"),)


def _copy_into(files: list[Path], dest: Path) -> list[Path]:
    copied = []
    for src in files:
        try:
            dest.mkdir(parents=True, exist_ok=True)
            target = dest / src.name
            shutil.copy2(src, target)
            copied.append(target)
        except OSError as exc:
            warning(f"Failed to stage {src}: {exc}")
    return copied


def _collect_xpy_logs(root: Path, stage: Path) -> list[Path]:
    src = root / "cache" / "log"
    if not src.is_dir():
        return []
    return _copy_into(sorted(src.glob("*.log")), stage / XPY_LOG_DIR)


def _collect_jvm_crash_logs(root: Path, stage: Path) -> list[Path]:
    found = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in PRUNE_DIR_NAMES]
        for name in filenames:
            if any(fnmatch.fnmatch(name, pattern) for pattern in JVM_CRASH_PATTERNS):
                found.append(Path(dirpath) / name)
    return _copy_into(found, stage / JVM_CRASH_DIR)


def _collect_gradle_daemon_logs(stage: Path) -> list[Path]:
    daemon_dir = Path.home() / ".gradle" / "daemon"
    if not daemon_dir.is_dir():
        return []
    return _copy_into(sorted(daemon_dir.glob("**/daemon-*.out.log")), stage / GRADLE_DAEMON_DIR)


def _collect_minio_logs(stage: Path) -> list[Path]:
    return _copy_into([p for p in MINIO_LOG_PATHS if p.is_file()], stage / MINIO_DIR)


def _run_snapshot_command(cmd: list[str]) -> str:
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
    except (OSError, subprocess.SubprocessError) as exc:
        return f"(unavailable: {exc})"
    return (out.stdout + out.stderr).strip() or "(no output)"


def _oom_evidence() -> str:
    if shutil.which("sudo"):
        cmd = ["sudo", "-n", "dmesg", "-T"]
    elif shutil.which("dmesg"):
        cmd = ["dmesg", "-T"]
    else:
        return "(dmesg unavailable)"
    output = _run_snapshot_command(cmd)
    lines = [
        line
        for line in output.splitlines()
        if "oom" in line.lower() or "killed process" in line.lower()
    ]
    return "\n".join(lines) if lines else "(none)"


def _write_environment_snapshot(stage: Path) -> Path:
    sections = [
        ("date", ["date"]),
        ("uname", ["uname", "-a"]),
        ("df -h", ["df", "-h"]),
        ("free -m", ["free", "-m"]),
    ]
    lines = []
    for title, cmd in sections:
        lines.append(f"== {title} ==")
        lines.append(_run_snapshot_command(cmd))
    lines.append("== oom-killer evidence ==")
    lines.append(_oom_evidence())

    target = stage / "environment.txt"
    target.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return target


def _drop_crash_byproducts(stage: Path) -> None:
    for path in stage.rglob("*"):
        if path.is_file() and any(
            fnmatch.fnmatch(path.name, pattern) for pattern in CRASH_BYPRODUCT_PATTERNS
        ):
            try:
                path.unlink()
            except OSError as exc:
                warning(f"Failed to remove crash byproduct {path}: {exc}")


def collect_diagnostics(root: Path, stage: Path) -> list[Path]:
    """Collect failure diagnostics into the staging directory (best effort)."""
    stage.mkdir(parents=True, exist_ok=True)
    staged: list[Path] = []
    collectors = [
        lambda: _collect_xpy_logs(root, stage),
        lambda: _collect_jvm_crash_logs(root, stage),
        lambda: _collect_gradle_daemon_logs(stage),
        lambda: _collect_minio_logs(stage),
        lambda: [_write_environment_snapshot(stage)],
    ]
    for collector in collectors:
        try:
            staged.extend(collector())
        except Exception as exc:
            warning(f"Diagnostics collector failed: {exc}")
    _drop_crash_byproducts(stage)
    return staged


def redact_staged_files(stage: Path, values: list[str]) -> tuple[int, int]:
    """Replace literal secret values in all staged files.

    Matching is byte-level and fully literal (no regex), so secrets containing
    metacharacters or delimiter characters are handled safely. Files that
    cannot be read or rewritten are removed from the staging area instead of
    being uploaded unredacted (fail-closed).

    Returns (files_scanned, files_redacted).
    """
    needles = [v.encode("utf-8", errors="surrogateescape") for v in values if v]
    scanned = 0
    redacted = 0
    for path in sorted(stage.rglob("*")):
        if not path.is_file():
            continue
        scanned += 1
        try:
            data = path.read_bytes()
        except OSError as exc:
            warning(f"Removing unreadable staged file {path}: {exc}")
            path.unlink(missing_ok=True)
            continue
        new_data = data
        for needle in needles:
            new_data = new_data.replace(needle, REDACTED)
        if new_data == data:
            continue
        try:
            path.write_bytes(new_data)
        except OSError as exc:
            warning(f"Failed to redact {path}; removing it from the artifact: {exc}")
            path.unlink(missing_ok=True)
            continue
        redacted += 1
    return scanned, redacted


def register_ci_diagnostics_commands(ci: click.Group) -> None:
    @ci.command("diagnostics")
    @click.option(
        "--stage",
        type=click.Path(file_okay=False, path_type=Path),
        default=".diagnostics",
        help="Staging directory for collected diagnostics (default: .diagnostics).",
    )
    @click.option(
        "--redact-values",
        envvar="REDACT_VALUES",
        default="",
        help="Newline-separated secret values to redact (defaults to REDACT_VALUES env var).",
    )
    def ci_diagnostics(stage: Path, redact_values: str):
        """Collect failure diagnostics into a staging directory and redact secrets."""
        resolved = stage.resolve()
        collect_diagnostics(PROJECT_ROOT, resolved)

        values = [line.rstrip("\r") for line in redact_values.splitlines()]
        values = [v for v in values if v]
        if values:
            try:
                scanned, redacted = redact_staged_files(resolved, values)
            except Exception as exc:
                error(f"Redaction failed unexpectedly: {exc}")
                error("Purging staging directory to avoid uploading unredacted data.")
                shutil.rmtree(resolved, ignore_errors=True)
                resolved.mkdir(parents=True, exist_ok=True)
                return
            info(f"Redacted secrets in {redacted}/{scanned} staged files.")
        else:
            info("No redact values provided; skipping redaction.")

        click.echo("Staged diagnostics:")
        for path in sorted(resolved.rglob("*")):
            if path.is_file():
                click.echo(f"  {path}")
