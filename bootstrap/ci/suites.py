from __future__ import annotations

import re


SUITE_DEFINITIONS = [
    {
        "suite": "python",
        "shell": "python",
        "lint_command": "uv run x.py ci lint --lang python",
        "command": "uv run x.py test python",
        "codegen_command": "uv run x.py ci codegen --lang python",
        "patterns": ["bootstrap/**", "data/**", "x.py", "pyproject.toml", "uv.lock"],
    },
    {
        "suite": "dart",
        "shell": "dart",
        "lint_command": "uv run x.py ci lint --lang dart",
        "command": "uv run x.py test dart",
        "codegen_command": "uv run x.py ci codegen --lang dart",
        "patterns": [
            "lib/**",
            "test/**",
            "rust/src/**",
            "rust/Cargo.toml",
            "rust/Cargo.lock",
            "pubspec.yaml",
            "pubspec.lock",
        ],
    },
    {
        "suite": "site",
        "shell": "js",
        "lint_command": "uv run x.py ci lint --lang site",
        "command": "true",
        "codegen_command": "true",
        "patterns": ["site/**", "pnpm-lock.yaml", "biome.json", "package.json"],
    },
    {
        "suite": "ci",
        "shell": "python",
        "lint_command": "true",
        "command": "true",
        "codegen_command": "true",
        "patterns": ["bootstrap/ci/**", "flake.nix", ".github/workflows/**"],
    },
]


def glob_to_regex(pattern: str) -> str:
    """Convert a glob-style pattern to a prefix-anchored regex."""
    parts = []
    i = 0
    while i < len(pattern):
        c = pattern[i]
        if c == "*":
            if i + 1 < len(pattern) and pattern[i + 1] == "*":
                parts.append(r".*")
                i += 1
            else:
                parts.append(r"[^/]*")
        elif c == "?":
            parts.append(r"[^/]")
        elif c == ".":
            parts.append(r"\.")
        else:
            parts.append(re.escape(c))
        i += 1
    return "^" + "".join(parts) + "$"


def match_any_pattern(file_path: str, patterns: list[str]) -> bool:
    """Check if a file path matches any of the given glob patterns."""
    return any(re.match(glob_to_regex(pattern), file_path) for pattern in patterns)


def calculate_ci_matrix(files: list[str]) -> list[dict]:
    """Determine which CI suites to run based on changed files."""
    result = []
    infra_changed = False
    for suite_def in SUITE_DEFINITIONS:
        if any(match_any_pattern(f, suite_def["patterns"]) for f in files):
            if suite_def["suite"] == "ci":
                infra_changed = True
            else:
                result.append(
                    {
                        "suite": suite_def["suite"],
                        "shell": suite_def["shell"],
                        "lint_command": suite_def["lint_command"],
                        "command": suite_def["command"],
                        "codegen_command": suite_def["codegen_command"],
                    }
                )
    if infra_changed:
        return [
            {
                "suite": s["suite"],
                "shell": s["shell"],
                "lint_command": s["lint_command"],
                "command": s["command"],
                "codegen_command": s["codegen_command"],
            }
            for s in SUITE_DEFINITIONS
            if s["suite"] != "ci"
        ]
    return result
