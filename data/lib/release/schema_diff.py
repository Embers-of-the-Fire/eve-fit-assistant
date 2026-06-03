"""
Schema change detector — compares HEAD against a baseline tag,
categorizes changed paths by schema impact, and enforces bump rules.
"""

from __future__ import annotations

import enum
import re
import subprocess
from dataclasses import dataclass
from dataclasses import field
from pathlib import Path

import data.lib.config

from data.lib.config import ProjectConfiguration
from data.lib.constant import PROJECT_ROOT


class DiffSeverity(enum.Enum):
    BREAKING = "BREAKING"
    COMPATIBLE = "COMPATIBLE"
    INFO = "INFO"


@dataclass
class DiffEntry:
    path: str
    severity: DiffSeverity
    action: str


@dataclass
class BumpVerification:
    """Result of verifying whether a schema version bump is needed."""

    proto_changed: bool = False
    current_bumped: bool = False
    old_current: int | None = None
    new_current: int | None = None
    message: str = ""


@dataclass
class PersistenceVerification:
    fit_version_changed: bool = False
    fit_old_version: int | None = None
    fit_new_version: int | None = None
    message: str = ""


@dataclass
class SchemaDiffReport:
    since_tag: str
    entries: list[DiffEntry] = field(default_factory=list)
    bump_verification: BumpVerification = field(default_factory=BumpVerification)
    persistence_verification: PersistenceVerification = field(
        default_factory=PersistenceVerification
    )

    @property
    def has_breaking(self) -> bool:
        return any(e.severity == DiffSeverity.BREAKING for e in self.entries)

    @property
    def breaking_entries(self) -> list[DiffEntry]:
        return [e for e in self.entries if e.severity == DiffSeverity.BREAKING]

    @property
    def compatible_entries(self) -> list[DiffEntry]:
        return [e for e in self.entries if e.severity == DiffSeverity.COMPATIBLE]

    @property
    def info_entries(self) -> list[DiffEntry]:
        return [e for e in self.entries if e.severity == DiffSeverity.INFO]


_CATEGORIES: list[tuple[str, DiffSeverity, str]] = [
    (
        r"^data/schema/.*\.proto$",
        DiffSeverity.BREAKING,
        "bundle_schema.current must be bumped in efa.config.toml",
    ),
    (
        r"^lib/storage/fit/persistence\.dart$",
        DiffSeverity.BREAKING,
        "currentFitStorageVersion may need bump + migration code",
    ),
    (
        r"^lib/storage/character/schema\.dart$",
        DiffSeverity.BREAKING,
        "character schema changed — verify persistence version + migration",
    ),
    (
        r"^lib/storage/character/persistence\.dart$",
        DiffSeverity.BREAKING,
        "character persistence version changed — verify migration code",
    ),
    (
        r"^lib/storage/bundle/schema_version\.dart$",
        DiffSeverity.BREAKING,
        "generated schema constant changed — must match efa.config.toml",
    ),
    (
        r"^lib/features/remote_content/endpoint\.dart$",
        DiffSeverity.BREAKING,
        "remote API version changed — verify client/server compatibility",
    ),
    (
        r"^rust/lib/eve-fit-os$",
        DiffSeverity.BREAKING,
        "fitting engine submodule changed — verify ABI compatibility",
    ),
    (
        r"^data/resources/.*/descriptor\.toml$",
        DiffSeverity.COMPATIBLE,
        "data source config changed — rebuild data required",
    ),
    (
        r"^efa\.config\.toml$",
        DiffSeverity.COMPATIBLE,
        "project config changed — verify version sync and bundle_schema",
    ),
    (
        r"^l10n/.*\.arb$",
        DiffSeverity.COMPATIBLE,
        "localization strings changed — regenerate l10n",
    ),
    (
        r"^data/lib/workspace/generate/.*",
        DiffSeverity.COMPATIBLE,
        "data generation pipeline changed — verify output",
    ),
    (
        r"^data/lib/workspace/.*",
        DiffSeverity.COMPATIBLE,
        "workspace logic changed — verify data builds",
    ),
]


def _categorize_path(path: str) -> tuple[DiffSeverity, str]:
    for pattern, severity, action in _CATEGORIES:
        if re.search(pattern, path):
            return severity, action
    return DiffSeverity.INFO, "general code change"


def _get_file_at_tag(tag: str, file_path: str) -> str | None:
    proc = subprocess.run(
        ["git", "show", f"{tag}:{file_path}"],
        cwd=PROJECT_ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if proc.returncode != 0:
        return None
    return proc.stdout


def _parse_toml_int(content: str, key: str, section: str | None = None) -> int | None:
    """Parse an integer key from a TOML string."""
    if section:
        in_section = False
        for line in content.split("\n"):
            stripped = line.strip()
            if stripped == f"[{section}]":
                in_section = True
                continue
            if in_section:
                if stripped.startswith("[") and stripped.endswith("]"):
                    break
                m = re.match(rf"^{key}\s*=\s*(\d+)", stripped)
                if m:
                    return int(m.group(1))
    else:
        for line in content.split("\n"):
            m = re.match(rf"^{key}\s*=\s*(\d+)", line.strip())
            if m:
                return int(m.group(1))
    return None


def _parse_dart_const_int(content: str, name: str) -> int | None:
    m = re.search(rf"const\s+(?:int\s+)?{name}\s*=\s*(\d+);", content)
    return int(m.group(1)) if m else None


def _verify_bundle_schema_bump(since_tag: str) -> BumpVerification:
    """Check if bundle_schema.current was bumped when protos changed."""
    old_config = _get_file_at_tag(since_tag, "efa.config.toml")
    old_current = None
    if old_config is not None:
        old_current = _parse_toml_int(old_config, "current", "bundle_schema")

    ProjectConfiguration.ensure_loaded()
    new_current = data.lib.config.CONFIGURATION.bundle_schema.current

    result = BumpVerification(
        proto_changed=False,
        current_bumped=False,
        old_current=old_current,
        new_current=new_current,
    )

    if old_current is None:
        result.message = (
            f"Could not determine previous bundle_schema.current from tag {since_tag} "
            f"(current = {new_current})"
        )
        return result

    result.current_bumped = new_current > old_current
    if new_current > old_current:
        result.message = (
            f"bundle_schema.current bumped: {old_current} -> {new_current}"
        )
    else:
        result.message = (
            f"bundle_schema.current has NOT been bumped "
            f"(was {old_current}, still {new_current})"
        )

    return result


def _verify_persistence_versions(since_tag: str) -> PersistenceVerification:
    """Check if fit persistence version changed."""
    result = PersistenceVerification()

    old_fit = _get_file_at_tag(since_tag, "lib/storage/fit/persistence.dart")
    if old_fit is not None:
        old_ver = _parse_dart_const_int(old_fit, "currentFitStorageVersion")
        result.fit_old_version = old_ver

    try:
        fit_path = PROJECT_ROOT / "lib" / "storage" / "fit" / "persistence.dart"
        content = fit_path.read_text(encoding="utf-8")
        new_ver = _parse_dart_const_int(content, "currentFitStorageVersion")
        result.fit_new_version = new_ver

        if result.fit_old_version is not None and new_ver is not None:
            if new_ver != result.fit_old_version:
                result.fit_version_changed = True
                result.message = (
                    f"currentFitStorageVersion changed: "
                    f"{result.fit_old_version} -> {new_ver} "
                    f"(verify migration code exists)"
                )
            else:
                result.message = (
                    f"currentFitStorageVersion unchanged at {new_ver}"
                )
        elif new_ver is not None:
            result.message = (
                f"currentFitStorageVersion = {new_ver} "
                f"(no previous tag value to compare)"
            )
        else:
            result.message = "Could not parse currentFitStorageVersion"
    except FileNotFoundError:
        result.message = "Could not read current fit persistence.dart"

    return result


def run_schema_diff(since_tag: str) -> SchemaDiffReport:
    """Run a schema impact analysis since the given tag."""

    # Get changed files
    proc = subprocess.run(
        ["git", "diff", "--name-only", f"{since_tag}..HEAD"],
        cwd=PROJECT_ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if proc.returncode != 0:
        raise RuntimeError(f"git diff failed: {proc.stderr}")

    changed_paths = [p for p in proc.stdout.strip().split("\n") if p]

    report = SchemaDiffReport(since_tag=since_tag)

    has_proto_change = False
    for path in changed_paths:
        severity, action = _categorize_path(path)
        report.entries.append(DiffEntry(path=path, severity=severity, action=action))
        if re.search(r"^data/schema/.*\.proto$", path):
            has_proto_change = True

    # Only verify bump if protos actually changed
    if has_proto_change:
        report.bump_verification = _verify_bundle_schema_bump(since_tag)
        report.bump_verification.proto_changed = True

    # Check persistence regardless — it handles its own diff detection
    report.persistence_verification = _verify_persistence_versions(since_tag)

    return report
