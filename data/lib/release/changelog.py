"""
Changelog validator — checks that CHANGELOG.md exists and has an entry
for the current version.
"""

from __future__ import annotations

from typing import TYPE_CHECKING

from data.lib.constant import PROJECT_ROOT


if TYPE_CHECKING:
    from pathlib import Path

    from data.lib.config import ProjectVersion


CHANGELOG_PATH = PROJECT_ROOT / "CHANGELOG.md"


def _version_header(version: ProjectVersion) -> str:
    ver = f"v{version.major}.{version.minor}.{version.patch}"
    if version.is_prerelease():
        ver = f"{ver}-{version.pre_label}.{version.pre_num}"
    if version.build:
        ver = f"{ver}+{version.build}"
    return f"## [{ver}]"


def check_changelog(version: ProjectVersion) -> tuple[bool, str]:
    if not CHANGELOG_PATH.exists():
        return False, (
            "CHANGELOG.md does not exist. "
            "Create one with the Keep a Changelog format. "
            "See https://keepachangelog.com/"
        )

    content = CHANGELOG_PATH.read_text(encoding="utf-8")
    header = _version_header(version)

    if header in content:
        return True, f"CHANGELOG.md has entry for {header}"

    return False, f"CHANGELOG.md missing entry for {header}"


_TEMPLATE = """# Changelog

All notable changes to EVE Fit Assistant are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

-
"""


def create_template() -> Path:
    if CHANGELOG_PATH.exists():
        raise FileExistsError(f"{CHANGELOG_PATH} already exists")
    CHANGELOG_PATH.write_text(_TEMPLATE, encoding="utf-8")
    return CHANGELOG_PATH
