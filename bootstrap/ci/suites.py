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
            "apps/eve-fit-assistant/lib/**",
            "apps/eve-fit-assistant/test/**",
            "apps/eve-fit-assistant/rust/src/**",
            "apps/eve-fit-assistant/rust/Cargo.toml",
            "apps/eve-fit-assistant/pubspec.yaml",
            "packages/**",
            "Cargo.toml",
            "Cargo.lock",
            "pubspec.yaml",
            "pubspec.lock",
        ],
    },
    {
        # Web-platform tests run alongside the Linux native dart suite: same
        # triggers, same shell, same lint/codegen. No Rust/native data needed.
        "suite": "dart-web",
        "shell": "dart",
        "lint_command": "uv run x.py ci lint --lang dart",
        "command": "uv run x.py test web",
        "codegen_command": "uv run x.py ci codegen --lang dart",
        "patterns": [
            "apps/eve-fit-assistant/lib/**",
            "apps/eve-fit-assistant/test/**",
            "apps/eve-fit-assistant/rust/src/**",
            "apps/eve-fit-assistant/rust/Cargo.toml",
            "apps/eve-fit-assistant/pubspec.yaml",
            "packages/**",
            "Cargo.toml",
            "Cargo.lock",
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
        "suite": "snapshot-ts",
        "shell": "js",
        "lint_command": "uv run x.py ci lint --lang snapshot-ts",
        "command": "true",
        "codegen_command": "uv run x.py ci codegen --lang snapshot-ts",
        "patterns": [
            "packages/efa_fit_snapshot_ts/**",
            "packages/efa_proto_ts/**",
            "data/schema/**",
            "pnpm-workspace.yaml",
            "pnpm-lock.yaml",
            "biome.json",
            "package.json",
        ],
    },
    {
        "suite": "worker",
        "shell": "js",
        "lint_command": "true",
        "command": "pnpm test:js",
        # The platform API worker's entrypoint imports the generated TS
        # protobuf bindings, and the Vitest plugin loads that entrypoint.
        "codegen_command": "uv run x.py ci codegen --lang snapshot-ts",
        "patterns": [
            "worker/**",
            "packages/efa_proto_ts/**",
            "data/schema/**",
            "pnpm-workspace.yaml",
            "pnpm-lock.yaml",
            "biome.json",
            "package.json",
        ],
    },
    {
        "suite": "workflows",
        "shell": "ci",
        "lint_command": "true",
        "command": "uv run x.py ci zizmor",
        "codegen_command": "true",
        "patterns": [
            ".github/workflows/**",
            ".github/actions/**",
            "flake.nix",
            "flake.lock",
        ],
    },
    {
        "suite": "l10n",
        "shell": "python",
        "lint_command": "uv run x.py ci lint --lang l10n",
        "command": "true",
        "codegen_command": "true",
        "patterns": [
            "apps/eve-fit-assistant/l10n.yaml",
            "apps/eve-fit-assistant/l10n/*.arb",
            "packages/efa_fit_snapshot/l10n.yaml",
            "packages/efa_fit_snapshot/l10n/*.arb",
        ],
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


# Paths that can change the Flutter web bundle (build/web) and therefore
# require a web preview rebuild. Generated Dart output is gitignored, so the
# sources feeding codegen (proto schemas, ARB files) are included as well.
WEB_PREVIEW_PATTERNS = [
    "flake.nix",
    "flake.lock",
    "Cargo.toml",
    "Cargo.lock",
    "packages/eve-fit-os",
    "packages/eve-fit-os/**",
    "apps/eve-fit-assistant/rust/**",
    "apps/eve-fit-assistant/web/**",
    "apps/eve-fit-assistant/lib/**",
    "pubspec.yaml",
    "pubspec.lock",
    "apps/eve-fit-assistant/l10n.yaml",
    "apps/eve-fit-assistant/l10n/*.arb",
    "data/schema/**",
    "bootstrap/**",
    "x.py",
    "pyproject.toml",
    "uv.lock",
    ".github/workflows/web-preview.yml",
    ".github/workflows/site-nightly.yml",
    ".github/actions/build-web/**",
    ".github/actions/deploy-web-pages/**",
    "ci/config/wrangler.*.toml",
]


def web_preview_affected(files: list[str]) -> bool:
    """Check whether changed files require a web preview rebuild."""
    return any(match_any_pattern(f, WEB_PREVIEW_PATTERNS) for f in files)


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
