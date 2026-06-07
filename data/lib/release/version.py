"""
Version sync engine — reads canonical version from efa.config.toml
and writes to pubspec.yaml, Cargo.toml, and pyproject.toml.
"""

from __future__ import annotations

import re

from dataclasses import dataclass
from dataclasses import field
from typing import TYPE_CHECKING

import data.lib.config

from data.lib.config import ProjectConfiguration
from data.lib.config import ProjectVersion
from data.lib.constant import CONFIG_PATH
from data.lib.constant import PROJECT_ROOT


if TYPE_CHECKING:
    from pathlib import Path


PUBSPEC_PATH = PROJECT_ROOT / "pubspec.yaml"
CARGO_BRIDGE_PATH = PROJECT_ROOT / "rust" / "Cargo.toml"
PYPROJECT_PATH = PROJECT_ROOT / "pyproject.toml"
PACKAGE_JSON_PATH = PROJECT_ROOT / "site" / "package.json"
# The eve-fit-os engine is a git submodule with independent versioning;
# it is not included in sync targets.


@dataclass
class SyncTarget:
    path: Path
    label: str
    expected: str


@dataclass
class SyncReport:
    synced: list[SyncTarget] = field(default_factory=list)
    skipped: list[SyncTarget] = field(default_factory=list)
    errors: list[str] = field(default_factory=list)

    def has_errors(self) -> bool:
        return len(self.errors) > 0


def load_version() -> ProjectVersion:
    ProjectConfiguration.ensure_loaded()
    return data.lib.config.CONFIGURATION.version


def _replace_line(file_path: Path, pattern: str, replacement: str, dry_run: bool) -> bool:
    content = file_path.read_text(encoding="utf-8")

    match_count = sum(1 for _ in re.finditer(pattern, content, flags=re.MULTILINE))
    if match_count == 0:
        raise RuntimeError(
            f"Pattern not found in {file_path.relative_to(PROJECT_ROOT)}: {pattern!r}"
        )
    if match_count > 1:
        raise RuntimeError(
            f"Pattern matched {match_count} times in {file_path.relative_to(PROJECT_ROOT)}, "
            f"expected exactly 1"
        )

    new_content, _ = re.subn(pattern, replacement, content, count=1, flags=re.MULTILINE)

    if not dry_run:
        file_path.write_text(new_content, encoding="utf-8")
    return True


def sync_pubspec(version: ProjectVersion, dry_run: bool = False) -> SyncTarget:
    full = version.render_full()
    _replace_line(PUBSPEC_PATH, r"^version: .*$", f"version: {full}", dry_run)
    return SyncTarget(path=PUBSPEC_PATH, label="pubspec.yaml", expected=full)


def sync_cargo(version: ProjectVersion, dry_run: bool = False) -> SyncTarget:
    semver = version.render_semver()
    _replace_line(CARGO_BRIDGE_PATH, r'^version = ".*"$', f'version = "{semver}"', dry_run)
    return SyncTarget(path=CARGO_BRIDGE_PATH, label="rust/Cargo.toml", expected=semver)


def sync_pyproject(version: ProjectVersion, dry_run: bool = False) -> SyncTarget:
    semver = version.render_semver()
    _replace_line(PYPROJECT_PATH, r'^version = ".*"$', f'version = "{semver}"', dry_run)
    return SyncTarget(path=PYPROJECT_PATH, label="pyproject.toml", expected=semver)


def sync_package_json(version: ProjectVersion, dry_run: bool = False) -> SyncTarget:
    semver = version.render_semver()
    _replace_line(
        PACKAGE_JSON_PATH,
        r'^    "version": ".*",$',
        f'    "version": "{semver}",',
        dry_run,
    )
    return SyncTarget(path=PACKAGE_JSON_PATH, label="site/package.json", expected=semver)


def _read_pubspec_version() -> str | None:
    content = PUBSPEC_PATH.read_text(encoding="utf-8")
    m = re.search(r"^version: (.+)$", content, re.MULTILINE)
    return m.group(1).strip() if m else None


def _read_cargo_version(path: Path) -> str | None:
    content = path.read_text(encoding="utf-8")
    m = re.search(r'^version = "(.+)"$', content, re.MULTILINE)
    return m.group(1).strip() if m else None


def _read_pyproject_version() -> str | None:
    content = PYPROJECT_PATH.read_text(encoding="utf-8")
    m = re.search(r'^version = "(.+)"$', content, re.MULTILINE)
    return m.group(1).strip() if m else None


def _read_package_json_version() -> str | None:
    content = PACKAGE_JSON_PATH.read_text(encoding="utf-8")
    m = re.search(r'"version":\s*"(.+)"', content)
    return m.group(1).strip() if m else None


def verify_sync(version: ProjectVersion) -> list[SyncTarget]:
    mismatches: list[SyncTarget] = []

    pub_ver = _read_pubspec_version()
    expected_full = version.render_full()
    if pub_ver is None or pub_ver != expected_full:
        mismatches.append(
            SyncTarget(path=PUBSPEC_PATH, label="pubspec.yaml", expected=expected_full)
        )

    expected_semver = version.render_semver()

    cargo_ver = _read_cargo_version(CARGO_BRIDGE_PATH)
    if cargo_ver is None or cargo_ver != expected_semver:
        mismatches.append(
            SyncTarget(path=CARGO_BRIDGE_PATH, label="rust/Cargo.toml", expected=expected_semver)
        )

    py_ver = _read_pyproject_version()
    if py_ver is None or py_ver != expected_semver:
        mismatches.append(
            SyncTarget(path=PYPROJECT_PATH, label="pyproject.toml", expected=expected_semver)
        )

    pkg_ver = _read_package_json_version()
    if pkg_ver is None or pkg_ver != expected_semver:
        mismatches.append(
            SyncTarget(path=PACKAGE_JSON_PATH, label="site/package.json", expected=expected_semver)
        )

    return mismatches


def sync_all(version: ProjectVersion, dry_run: bool = False) -> SyncReport:
    report = SyncReport()

    targets = [
        (sync_pubspec, "pubspec.yaml"),
        (sync_cargo, "rust/Cargo.toml"),
        (sync_pyproject, "pyproject.toml"),
        (sync_package_json, "site/package.json"),
    ]

    for sync_fn, label in targets:
        try:
            target = sync_fn(version, dry_run)
            report.synced.append(target)
        except Exception as e:
            report.errors.append(f"{label}: {e}")

    return report


def write_config_version(version: ProjectVersion, dry_run: bool = False) -> None:
    _replace_line(
        CONFIG_PATH,
        r"^major = \d+$",
        f"major = {version.major}",
        dry_run,
    )
    _replace_line(
        CONFIG_PATH,
        r"^minor = \d+$",
        f"minor = {version.minor}",
        dry_run,
    )
    _replace_line(
        CONFIG_PATH,
        r"^patch = \d+$",
        f"patch = {version.patch}",
        dry_run,
    )
    _replace_line(
        CONFIG_PATH,
        r'^pre_label = ".*"$',
        f'pre_label = "{version.pre_label}"',
        dry_run,
    )
    _replace_line(
        CONFIG_PATH,
        r"^pre_num = \d+$",
        f"pre_num = {version.pre_num}",
        dry_run,
    )
    _replace_line(
        CONFIG_PATH,
        r"^build = \d+$",
        f"build = {version.build}",
        dry_run,
    )
