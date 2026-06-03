"""
Pre-release check orchestrator — runs all 12 gates, produces a report,
and exits with an appropriate code.
"""

from __future__ import annotations

import enum
import subprocess

from dataclasses import dataclass
from dataclasses import field

from data.lib.constant import PROJECT_ROOT


class CheckSeverity(enum.Enum):
    FATAL = "FATAL"
    WARN = "WARN"
    INFO = "INFO"


@dataclass
class CheckResult:
    name: str
    passed: bool
    severity: CheckSeverity
    message: str
    details: str = ""

    @property
    def icon(self) -> str:
        if self.passed:
            return "[PASS]"
        if self.severity == CheckSeverity.FATAL:
            return "[FAIL]"
        if self.severity == CheckSeverity.WARN:
            return "[WARN]"
        return "[INFO]"


@dataclass
class CheckReport:
    results: list[CheckResult] = field(default_factory=list)

    @property
    def all_passed(self) -> bool:
        return all(r.passed for r in self.results)

    @property
    def fatal_failures(self) -> list[CheckResult]:
        return [r for r in self.results if not r.passed and r.severity == CheckSeverity.FATAL]

    @property
    def warnings(self) -> list[CheckResult]:
        return [r for r in self.results if not r.passed and r.severity == CheckSeverity.WARN]

    def has_fatal_failure(self) -> bool:
        return len(self.fatal_failures) > 0


def _shell(cmd: list[str]) -> tuple[int, str, str]:
    """Run a command and capture output. Returns (returncode, stdout, stderr)."""
    proc = subprocess.run(
        cmd,
        cwd=PROJECT_ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    return proc.returncode, proc.stdout.strip(), proc.stderr.strip()


def _shell_ok(cmd: list[str], error_msg: str, ok_msg: str) -> CheckResult:
    rc, _, stderr = _shell(cmd)
    if rc == 0:
        return CheckResult(
            name="",
            passed=True,
            severity=CheckSeverity.FATAL,
            message=ok_msg,
        )
    return CheckResult(
        name="",
        passed=False,
        severity=CheckSeverity.FATAL,
        message=error_msg,
        details=stderr or f"exit code {rc}",
    )


# ---------------------------------------------------------------------------
# Individual checks
# ---------------------------------------------------------------------------


def check_version_sync(force: bool) -> CheckResult:
    from data.lib.release.version import load_version
    from data.lib.release.version import verify_sync

    v = load_version()
    mismatches = verify_sync(v)

    if not mismatches:
        return CheckResult(
            name="version-sync",
            passed=True,
            severity=CheckSeverity.FATAL,
            message="All version targets match efa.config.toml",
        )

    detail = "\n".join(f"    {m.label}: expected {m.expected!r}" for m in mismatches)
    return CheckResult(
        name="version-sync",
        passed=False,
        severity=CheckSeverity.FATAL,
        message=f"{len(mismatches)} target(s) out of sync",
        details=detail,
    )


def check_git_clean(force: bool) -> CheckResult:
    from data.lib.release.git_util import check_head_pushed
    from data.lib.release.git_util import check_on_dev_branch
    from data.lib.release.git_util import check_working_tree_clean

    r = check_working_tree_clean()
    if not r.ok:
        return CheckResult(
            name="git-clean",
            passed=False,
            severity=CheckSeverity.FATAL,
            message=r.message,
        )

    r = check_on_dev_branch()
    if not r.ok:
        return CheckResult(
            name="git-clean",
            passed=False,
            severity=CheckSeverity.FATAL,
            message=r.message,
        )

    r = check_head_pushed()
    if not r.ok:
        return CheckResult(
            name="git-clean",
            passed=False,
            severity=CheckSeverity.FATAL,
            message=r.message,
        )

    return CheckResult(
        name="git-clean",
        passed=True,
        severity=CheckSeverity.FATAL,
        message="Working tree clean, on dev, pushed to origin/dev",
    )


def check_git_tag(force: bool) -> CheckResult:
    from data.lib.release.git_util import check_tag_at_head
    from data.lib.release.git_util import check_tag_exists
    from data.lib.release.version import load_version

    v = load_version()
    tag = v.render_tag()

    if not check_tag_exists(tag):
        return CheckResult(
            name="git-tag",
            passed=False,
            severity=CheckSeverity.WARN,
            message=f"Tag {tag} does not exist yet — create with `./x release commit`",
        )

    r = check_tag_at_head(tag)
    return CheckResult(
        name="git-tag",
        passed=r.ok,
        severity=CheckSeverity.WARN,
        message=r.message,
    )


def check_schema_diff(force: bool, since_tag: str | None = None) -> CheckResult:
    from data.lib.release.git_util import find_last_release_tag
    from data.lib.release.schema_diff import run_schema_diff

    tag = since_tag or find_last_release_tag()
    if tag is None:
        return CheckResult(
            name="schema-diff",
            passed=True,
            severity=CheckSeverity.INFO,
            message="No previous release tag found — skipping schema diff",
        )

    report = run_schema_diff(tag)

    lines = [f"Changed files since {tag}:"]
    for e in report.breaking_entries:
        lines.append(f"  {e.severity.value:10s} {e.path}")
        lines.append(f"               -> {e.action}")
    for e in report.compatible_entries:
        lines.append(f"  {e.severity.value:10s} {e.path}")

    if len(report.info_entries) > 0:
        lines.append(f"  ... ({len(report.info_entries)} additional INFO changes)")

    return CheckResult(
        name="schema-diff",
        passed=True,
        severity=CheckSeverity.INFO,
        message=f"Schema impact analysis against {tag}",
        details="\n".join(lines),
    )


def check_schema_bump(force: bool, since_tag: str | None = None) -> CheckResult:
    from data.lib.release.git_util import find_last_release_tag
    from data.lib.release.schema_diff import run_schema_diff

    tag = since_tag or find_last_release_tag()
    if tag is None:
        return CheckResult(
            name="schema-bump",
            passed=True,
            severity=CheckSeverity.INFO,
            message="No previous release tag — cannot verify bundle_schema bump",
        )

    report = run_schema_diff(tag)

    if not report.bump_verification.proto_changed:
        return CheckResult(
            name="schema-bump",
            passed=True,
            severity=CheckSeverity.FATAL,
            message="No proto changes — bundle_schema bump not required",
        )

    bv = report.bump_verification
    if bv.current_bumped:
        return CheckResult(
            name="schema-bump",
            passed=True,
            severity=CheckSeverity.FATAL,
            message=bv.message,
        )
    elif bv.old_current is None:
        return CheckResult(
            name="schema-bump",
            passed=False,
            severity=CheckSeverity.WARN if force else CheckSeverity.FATAL,
            message=bv.message,
            details="Manually verify bundle_schema.current is correct",
        )
    else:
        return CheckResult(
            name="schema-bump",
            passed=False,
            severity=CheckSeverity.WARN if force else CheckSeverity.FATAL,
            message=bv.message,
            details="Increment bundle_schema.current in efa.config.toml, then run `./x generate all -f`",
        )


def check_persistence(force: bool, since_tag: str | None = None) -> CheckResult:
    from data.lib.release.git_util import find_last_release_tag
    from data.lib.release.schema_diff import run_schema_diff

    tag = since_tag or find_last_release_tag()
    if tag is None:
        return CheckResult(
            name="persistence-check",
            passed=True,
            severity=CheckSeverity.INFO,
            message="No previous release tag — cannot verify persistence version",
        )

    report = run_schema_diff(tag)
    pv = report.persistence_verification

    if not pv.fit_version_changed:
        return CheckResult(
            name="persistence-check",
            passed=True,
            severity=CheckSeverity.FATAL,
            message=pv.message or "Fit persistence version unchanged",
        )

    return CheckResult(
        name="persistence-check",
        passed=False,
        severity=CheckSeverity.WARN if force else CheckSeverity.FATAL,
        message=pv.message,
        details="Ensure migration code handles the version transition",
    )


def check_submodule(force: bool) -> CheckResult:
    from data.lib.release.git_util import check_submodule_state

    r = check_submodule_state()
    return CheckResult(
        name="submodule",
        passed=r.ok,
        severity=CheckSeverity.FATAL,
        message=r.message,
    )


def check_generate(force: bool) -> CheckResult:
    rc, _, stderr = _shell(["uv", "run", "x.py", "generate", "all", "-f"])
    if rc != 0:
        return CheckResult(
            name="generate",
            passed=False,
            severity=CheckSeverity.WARN if force else CheckSeverity.FATAL,
            message="./x generate all -f failed",
            details=stderr,
        )

    # Verify no dirty generated files
    rc, _stdout, _ = _shell(["git", "diff", "--exit-code"])
    if rc != 0:
        return CheckResult(
            name="generate",
            passed=False,
            severity=CheckSeverity.WARN if force else CheckSeverity.FATAL,
            message="Generated code has uncommitted changes",
            details="Run `./x generate all -f` and commit the results",
        )

    return CheckResult(
        name="generate",
        passed=True,
        severity=CheckSeverity.FATAL,
        message="./x generate all -f succeeded with no diff",
    )


def check_lint(force: bool) -> CheckResult:
    rc, _, stderr = _shell(["uv", "run", "x.py", "lint"])
    if rc != 0:
        return CheckResult(
            name="lint",
            passed=False,
            severity=CheckSeverity.WARN if force else CheckSeverity.FATAL,
            message="./x lint failed",
            details=stderr,
        )
    return CheckResult(
        name="lint",
        passed=True,
        severity=CheckSeverity.FATAL,
        message="./x lint passed",
    )


def check_test(force: bool) -> CheckResult:
    rc, _, stderr = _shell(
        ["cargo", "test", "-p", "eve-fit-os", "-p", "rust_lib_eve_fit_assistant"]
    )
    if rc != 0:
        return CheckResult(
            name="test",
            passed=False,
            severity=CheckSeverity.WARN if force else CheckSeverity.FATAL,
            message="cargo test failed",
            details=stderr,
        )
    return CheckResult(
        name="test",
        passed=True,
        severity=CheckSeverity.FATAL,
        message="Rust tests passed",
    )


def check_build_data(force: bool) -> CheckResult:
    rc, _, stderr = _shell(["uv", "run", "x.py", "build", "data"])
    if rc != 0:
        return CheckResult(
            name="build-data",
            passed=False,
            severity=CheckSeverity.WARN if force else CheckSeverity.FATAL,
            message="./x build data failed",
            details=stderr,
        )
    return CheckResult(
        name="build-data",
        passed=True,
        severity=CheckSeverity.FATAL,
        message="./x build data succeeded",
    )


def check_changelog_entry(force: bool) -> CheckResult:
    from data.lib.release.changelog import check_changelog
    from data.lib.release.version import load_version

    v = load_version()
    ok, msg = check_changelog(v)

    return CheckResult(
        name="changelog",
        passed=ok,
        severity=CheckSeverity.WARN,
        message=msg,
    )


# ---------------------------------------------------------------------------
# Orchestrator
# ---------------------------------------------------------------------------

_CHECK_FUNCTIONS = [
    check_version_sync,
    check_git_clean,
    check_git_tag,
    check_schema_diff,
    check_schema_bump,
    check_persistence,
    check_submodule,
    check_generate,
    check_lint,
    check_test,
    check_build_data,
    check_changelog_entry,
]


def run_all_checks(force: bool, since_tag: str | None = None) -> CheckReport:
    report = CheckReport()

    for fn in _CHECK_FUNCTIONS:
        if "since_tag" in fn.__code__.co_varnames:
            result = fn(force, since_tag=since_tag)
        else:
            result = fn(force)

        fn_name = fn.__name__.replace("check_", "")
        result.name = fn_name
        report.results.append(result)

    return report
