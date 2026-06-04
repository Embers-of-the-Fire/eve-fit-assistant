"""
Git utilities for the release workflow — branch checks, tag resolution,
and submodule state inspection.
"""

from __future__ import annotations

import subprocess

from typing import TYPE_CHECKING
from typing import NamedTuple

from data.lib.constant import PROJECT_ROOT


if TYPE_CHECKING:
    from pathlib import Path


class GitCheckResult(NamedTuple):
    ok: bool
    message: str


def _run(cmd: list[str], cwd: Path | None = None) -> subprocess.CompletedProcess:
    return subprocess.run(
        cmd,
        cwd=cwd or PROJECT_ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )


def _run_ok(cmd: list[str], cwd: Path | None = None) -> tuple[bool, str, str]:
    proc = _run(cmd, cwd)
    return proc.returncode == 0, proc.stdout.strip(), proc.stderr.strip()


def get_current_branch() -> str | None:
    ok, stdout, _ = _run_ok(["git", "rev-parse", "--abbrev-ref", "HEAD"])
    return stdout if ok else None


def check_working_tree_clean() -> GitCheckResult:
    ok, stdout, _ = _run_ok(["git", "status", "--porcelain"])
    if not ok:
        return GitCheckResult(False, "Failed to run git status")
    if stdout:
        # Count changed files for a useful message
        files = [line for line in stdout.split("\n") if line.strip()]
        return GitCheckResult(
            False,
            f"Working tree is dirty ({len(files)} file(s) changed):\n"
            + "\n".join(f"    {f}" for f in files[:20])
            + ("\n    ..." if len(files) > 20 else ""),
        )
    return GitCheckResult(True, "Working tree is clean")


def check_on_dev_branch() -> GitCheckResult:
    branch = get_current_branch()
    if branch is None:
        return GitCheckResult(False, "Unable to determine current branch")
    if branch != "dev":
        return GitCheckResult(
            False,
            f"Not on the dev branch (current: {branch}). "
            "main and release-* branches are deprecated.",
        )
    return GitCheckResult(True, f"On branch: {branch}")


def check_head_pushed() -> GitCheckResult:
    ok, stdout, stderr = _run_ok(["git", "rev-list", "--count", "origin/dev..dev"])
    if not ok:
        return GitCheckResult(False, f"Failed to compare with origin/dev: {stderr}")
    if stdout.strip() != "0":
        return GitCheckResult(
            False,
            f"HEAD has {stdout.strip()} unpushed commit(s) to origin/dev",
        )
    return GitCheckResult(True, "HEAD is pushed to origin/dev")


def _parse_semver_tag(tag: str) -> tuple[int, int, int, str, int, int] | None:
    """Parse tag like 'v0.1.0-beta.1+5' into (major, minor, patch, pre_label, pre_num, build)."""
    if not tag.startswith("v"):
        return None
    rest = tag[1:]

    build = 0
    if "+" in rest:
        rest, build_str = rest.split("+", 1)
        try:
            build = int(build_str)
        except ValueError:
            build = 0

    pre_label = ""
    pre_num = 0
    if "-" in rest:
        rest, pre_str = rest.split("-", 1)
        parts = pre_str.split(".")
        if len(parts) >= 2:
            pre_label = parts[0]
            try:
                pre_num = int(parts[1])
            except ValueError:
                pre_num = 0
        else:
            pre_label = pre_str

    parts = rest.split(".")
    if len(parts) < 3:
        return None
    try:
        return (int(parts[0]), int(parts[1]), int(parts[2]), pre_label, pre_num, build)
    except ValueError:
        return None


def find_last_release_tag() -> str | None:
    ok, stdout, _ = _run_ok(["git", "tag", "--merged", "HEAD", "-l", "v*"])
    if not ok or not stdout:
        return None

    tags = stdout.strip().split("\n")

    parsed = []
    for t in tags:
        v = _parse_semver_tag(t)
        if v is not None:
            major, minor, patch, pre_label, pre_num, build = v
            is_not_pre = 0 if pre_label else 1
            sort_key = (major, minor, patch, is_not_pre, pre_label, pre_num, build)
            parsed.append((sort_key, t))

    parsed.sort(key=lambda x: x[0], reverse=True)
    return parsed[0][1] if parsed else None


def check_tag_exists(tag: str) -> bool:
    ok, stdout, _ = _run_ok(["git", "tag", "-l", tag])
    return ok and stdout.strip() == tag


def check_tag_at_head(tag: str) -> GitCheckResult:
    if not check_tag_exists(tag):
        return GitCheckResult(False, f"Tag {tag} does not exist")
    ok, head, _ = _run_ok(["git", "rev-parse", "HEAD"])
    if not ok:
        return GitCheckResult(False, "Failed to resolve HEAD")
    ok, tag_commit, _ = _run_ok(["git", "rev-list", "-n", "1", tag])
    if not ok:
        return GitCheckResult(False, f"Failed to resolve tag {tag}")
    if head.strip() != tag_commit.strip():
        return GitCheckResult(
            False,
            f"Tag {tag} does not point to HEAD (tag points to {tag_commit.strip()[:8]})",
        )
    return GitCheckResult(True, f"Tag {tag} points to HEAD")


def get_unpushed_tags() -> list[str]:
    ok, stdout, _ = _run_ok(["git", "ls-remote", "--tags", "origin"])
    if not ok:
        return []
    remote_tags = {
        line.split("\t")[-1].removeprefix("refs/tags/").removesuffix("^{}")
        for line in stdout.splitlines()
        if line
    }
    ok, stdout, _ = _run_ok(["git", "tag", "-l"])
    if not ok:
        return []
    local = [t for t in stdout.splitlines() if t.strip()]
    return [t for t in local if t not in remote_tags]


SUBMODULE_PATH = PROJECT_ROOT / "rust" / "lib" / "eve-fit-os"


def check_submodule_state() -> GitCheckResult:
    if not (SUBMODULE_PATH / ".git").exists():
        return GitCheckResult(True, "No submodule at rust/lib/eve-fit-os")

    # Check if submodule is initialized
    ok, stdout, _ = _run_ok(["git", "submodule", "status", "--cached", "rust/lib/eve-fit-os"])
    if not ok:
        return GitCheckResult(False, "Failed to check submodule status")

    status = stdout.strip()
    if not status:
        return GitCheckResult(True, "Submodule not configured (no .gitmodules entry)")

    # Leading character: ' ' = clean, '+' = dirty, '-' = not init, 'U' = merge
    prefix = status[0] if status else " "
    commit = status[1:].split(" ")[0].lstrip() if len(status) > 1 else "unknown"

    if prefix == "-":
        return GitCheckResult(False, "Submodule rust/lib/eve-fit-os is not initialized")
    if prefix == "+":
        return GitCheckResult(
            False,
            "Submodule rust/lib/eve-fit-os has local changes (dirty). "
            "Commit submodule changes before releasing.",
        )
    if prefix == "U":
        return GitCheckResult(False, "Submodule rust/lib/eve-fit-os has merge conflicts")

    # Check if the pinned commit is a tag
    ok, tag_output, _ = _run_ok(
        ["git", "tag", "--points-at", commit.strip()],
        cwd=SUBMODULE_PATH,
    )
    tag_info = ""
    if ok and tag_output.strip():
        tag_info = f", tagged as {tag_output.strip()}"
    else:
        tag_info = ", no git tag (consider tagging the submodule)"

    return GitCheckResult(
        True,
        f"Submodule at {commit.strip()[:8]}{tag_info}",
    )
