"""
Schema change detector — compares HEAD against a baseline tag,
categorizes changed paths by schema impact, and enforces bump rules.
"""

from __future__ import annotations

import enum
import re
import subprocess
import tomllib

from dataclasses import dataclass
from dataclasses import field

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
class PersistenceVerification:
    fit_version_changed: bool = False
    fit_old_version: int | None = None
    fit_new_version: int | None = None
    message: str = ""


@dataclass
class RepoVersionVerification:
    """Result of verifying whether the v2 repo schema_version was bumped."""

    repo_file_changed: bool = False
    schema_version_bumped: bool = False
    old_schema_version: int | None = None
    new_schema_version: int | None = None
    message: str = ""


@dataclass
class SchemaDiffReport:
    since_tag: str
    entries: list[DiffEntry] = field(default_factory=list)
    persistence_verification: PersistenceVerification = field(
        default_factory=PersistenceVerification
    )
    repo_version_verification: RepoVersionVerification = field(
        default_factory=RepoVersionVerification
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
        "protobuf schema changed — verify client compatibility",
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
        r"^lib/features/remote_content/endpoint\.dart$",
        DiffSeverity.BREAKING,
        "REMOTE_API: remote API version changed — verify client/server compatibility",
    ),
    (
        r"^lib/storage/repo/repo_version\.dart$",
        DiffSeverity.BREAKING,
        "generated repo schema constant changed — must match efa.config.toml [version]",
    ),
    (
        r"^lib/storage/repo/schema_version\.dart$",
        DiffSeverity.BREAKING,
        "repo schema version service changed — verify schema_version in efa.config.toml",
    ),
    (
        r"^lib/storage/repo/models/",
        DiffSeverity.BREAKING,
        "DART_MODEL: repo schema model changed — breaking change requiring version bump",
    ),
    (
        r"^lib/storage/repo/paths\.dart$",
        DiffSeverity.BREAKING,
        "repo path resolution changed — verify schema compatibility",
    ),
    (
        r"^lib/storage/repo/providers\.dart$",
        DiffSeverity.BREAKING,
        "repo state providers changed — verify initialization flow compatibility",
    ),
    (
        r"^lib/storage/repo/migration/",
        DiffSeverity.INFO,
        "migration code changed — informational (no bump required)",
    ),
    (
        r"^lib/features/schema_guard/",
        DiffSeverity.BREAKING,
        "startup schema guard changed — verify migration compatibility and schema version",
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
        "project config changed — verify version sync",
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
                result.message = f"currentFitStorageVersion unchanged at {new_ver}"
        elif new_ver is not None:
            result.message = (
                f"currentFitStorageVersion = {new_ver} (no previous tag value to compare)"
            )
        else:
            result.message = "Could not parse currentFitStorageVersion"
    except FileNotFoundError:
        result.message = "Could not read current fit persistence.dart"

    return result


def _verify_repo_schema_version(since_tag: str) -> RepoVersionVerification:
    """Check if [version].data_schema was bumped when v2 repo files changed."""
    old_config = _get_file_at_tag(since_tag, "efa.config.toml")
    old_schema_version = None
    if old_config is not None:
        try:
            old_parsed = tomllib.loads(old_config)
            old_schema_version = old_parsed.get("version", {}).get("data_schema")
        except Exception:
            pass

    ProjectConfiguration.ensure_loaded()
    new_schema_version = data.lib.config.CONFIGURATION.version.data_schema

    result = RepoVersionVerification(
        repo_file_changed=False,
        schema_version_bumped=False,
        old_schema_version=old_schema_version,
        new_schema_version=new_schema_version,
    )

    if old_schema_version is None:
        result.message = (
            f"Could not determine previous [version].data_schema from tag {since_tag} "
            f"(current = {new_schema_version})"
        )
        return result

    if new_schema_version > old_schema_version:
        result.schema_version_bumped = True
        result.message = (
            f"[version].data_schema bumped: {old_schema_version} -> {new_schema_version}"
        )
    else:
        result.message = (
            f"[version].data_schema has NOT been bumped "
            f"(was {old_schema_version}, still {new_schema_version})"
        )

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

    has_repo_model_change = False
    for path in changed_paths:
        severity, action = _categorize_path(path)
        report.entries.append(DiffEntry(path=path, severity=severity, action=action))
        if re.search(r"^lib/storage/repo/", path) and severity == DiffSeverity.BREAKING:
            has_repo_model_change = True
        if re.search(r"^lib/features/schema_guard/", path):
            has_repo_model_change = True

    # Only verify v2 schema version bump if repo files changed
    if has_repo_model_change:
        report.repo_version_verification = _verify_repo_schema_version(since_tag)
        report.repo_version_verification.repo_file_changed = True

    # Check persistence regardless — it handles its own diff detection
    report.persistence_verification = _verify_persistence_versions(since_tag)

    return report
