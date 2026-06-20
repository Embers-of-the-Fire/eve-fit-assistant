"""
Changelog generator — wraps git-cliff for CHANGELOG.md and bi-lingual
in-app version announcements.
"""

from __future__ import annotations

import datetime as dt
import os
import shlex
import subprocess
import tempfile

from pathlib import Path
from typing import TYPE_CHECKING

from data.lib.constant import PROJECT_ROOT
from data.lib.utils import get_command


if TYPE_CHECKING:
    from data.lib.config import ProjectVersion


CHANGELOG_PATH = PROJECT_ROOT / "CHANGELOG.md"
ANNOUNCEMENTS_ROOT = PROJECT_ROOT / "assets" / "content" / "announcements"


def _cliff_cmd() -> list[str]:
    return [get_command("git-cliff")]


def _run_cliff(args: list[str], **kwargs: object) -> subprocess.CompletedProcess[str]:
    return subprocess.run([*_cliff_cmd(), *args], **kwargs)  # type: ignore[call-overload]


def generate_full(version: ProjectVersion) -> None:
    tag = version.render_tag()
    if CHANGELOG_PATH.exists():
        _run_cliff(
            ["--unreleased", "--tag", tag, "--prepend", str(CHANGELOG_PATH)],
            check=True,
            cwd=PROJECT_ROOT,
        )
    else:
        _run_cliff(
            ["--unreleased", "--tag", tag, "-o", str(CHANGELOG_PATH)],
            check=True,
            cwd=PROJECT_ROOT,
        )


def generate_detail(version: ProjectVersion, *, no_edit: bool = False) -> None:
    commits = _get_commit_list()
    template = _build_editor_template(version, commits)

    fd, tmp_path = tempfile.mkstemp(suffix=".md", text=True)
    try:
        with open(fd, "w", encoding="utf-8") as f:
            f.write(template)

        if not no_edit:
            _open_editor(tmp_path)

        raw = Path(tmp_path).read_text(encoding="utf-8")
        en_body, zh_body = _parse_editor_output(raw)

        if not no_edit and (not en_body or not zh_body):
            raise RuntimeError(
                "Both en-us and zh-cn sections must contain content. Use --no-edit to skip editing."
            )

        cliff_body = _get_cliff_body(version)
        _write_version_documents(version, en_body, zh_body, cliff_body)
    finally:
        Path(tmp_path).unlink(missing_ok=True)


def _version_to_doc_id(version: ProjectVersion) -> str:
    parts = [str(version.major), str(version.minor), str(version.patch)]
    if version.is_prerelease():
        parts.append(version.pre_label.lower())
        parts.append(str(version.pre_num))
    return "version-" + "-".join(parts)


def _get_commit_list() -> list[str]:
    from data.lib.release.git_util import find_last_release_tag

    last_tag = find_last_release_tag()
    if last_tag:
        cmd = ["git", "log", "--oneline", "--no-decorate", f"{last_tag}..HEAD"]
    else:
        cmd = ["git", "log", "--oneline", "--no-decorate"]

    result = subprocess.run(cmd, capture_output=True, text=True, cwd=PROJECT_ROOT)
    if result.returncode != 0:
        raise RuntimeError(f"git log failed: {result.stderr.strip()}")
    output = result.stdout.strip()
    return output.split("\n") if output else []


def _get_cliff_body(version: ProjectVersion) -> str:
    tag = version.render_tag()
    result = _run_cliff(
        ["--unreleased", "--tag", tag, "--strip", "header"],
        capture_output=True,
        text=True,
        cwd=PROJECT_ROOT,
    )
    if result.returncode != 0:
        raise RuntimeError(f"git-cliff failed: {result.stderr.strip()}")
    return result.stdout.strip() + "\n"


def _build_editor_template(version: ProjectVersion, commits: list[str]) -> str:
    semver = version.render_semver()
    lines = [
        f"# Write release summary for v{semver}.",
        "# Lines starting with '#' are stripped on save.",
        '# Write English after "en-us", Chinese after "zh-cn".',
        "",
        "en-us",
        "",
        "zh-cn",
        "",
        "# ---- Change log (auto-generated, for reference) ----",
    ]
    for commit in commits:
        lines.append(f"# {commit}")
    lines.append("")
    return "\n".join(lines)


def _parse_editor_output(raw: str) -> tuple[str, str]:
    en_lines: list[str] = []
    zh_lines: list[str] = []
    state: str = "init"

    for line in raw.splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        if stripped == "en-us":
            state = "en"
            continue
        if stripped == "zh-cn":
            state = "zh"
            continue
        if stripped.startswith("#"):
            continue
        if state == "en":
            en_lines.append(line)
        elif state == "zh":
            zh_lines.append(line)

    return "\n".join(en_lines).strip(), "\n".join(zh_lines).strip()


def _write_version_documents(
    version: ProjectVersion,
    en_body: str,
    zh_body: str,
    cliff_body: str,
) -> None:
    doc_id = _version_to_doc_id(version)
    semver = version.render_semver()
    published_at = dt.datetime.now(dt.UTC).strftime("%Y-%m-%dT%H:%M:%SZ")

    en_path = ANNOUNCEMENTS_ROOT / "en" / f"{doc_id}.md"
    en_path.parent.mkdir(parents=True, exist_ok=True)
    en_content = f"---\nid: {doc_id}\n---\n\n# v{semver} Release Notes\n{en_body}\n\n{cliff_body}"
    en_path.write_text(en_content, encoding="utf-8")

    zh_path = ANNOUNCEMENTS_ROOT / "zh" / f"{doc_id}.md"
    zh_path.parent.mkdir(parents=True, exist_ok=True)
    zh_lines = [
        "---",
        f"id: {doc_id}",
        f"publishedAt: {published_at}",
        "tags: [release-note]",
        "channels: [testing]",
        "platforms: [android, ios]",
        f'appVersion: "{semver}"',
        "---",
        "",
        f"# v{semver} 发布说明",
        zh_body,
        "",
        cliff_body,
    ]
    zh_path.write_text("\n".join(zh_lines), encoding="utf-8")


def _open_editor(filepath: str) -> None:
    editor = os.environ.get("EDITOR") or os.environ.get("VISUAL") or "vim"
    subprocess.run([*shlex.split(editor), filepath], check=True)
