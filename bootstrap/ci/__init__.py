from __future__ import annotations

from bootstrap.ci.codegen import CODEGEN_STEPS
from bootstrap.ci.codegen import LANGUAGE_STEPS
from bootstrap.ci.codegen import run_codegen
from bootstrap.ci.commands import register_ci_commands
from bootstrap.ci.diagnostics import collect_diagnostics
from bootstrap.ci.diagnostics import redact_staged_files
from bootstrap.ci.diagnostics import register_ci_diagnostics_commands
from bootstrap.ci.lint import run_lint
from bootstrap.ci.lint import run_site_checks
from bootstrap.ci.suites import SUITE_DEFINITIONS
from bootstrap.ci.suites import calculate_ci_matrix
from bootstrap.ci.suites import glob_to_regex
from bootstrap.ci.suites import match_any_pattern


__all__ = [
    "CODEGEN_STEPS",
    "LANGUAGE_STEPS",
    "SUITE_DEFINITIONS",
    "calculate_ci_matrix",
    "collect_diagnostics",
    "glob_to_regex",
    "match_any_pattern",
    "redact_staged_files",
    "register_ci_commands",
    "register_ci_diagnostics_commands",
    "run_codegen",
    "run_lint",
    "run_site_checks",
]
