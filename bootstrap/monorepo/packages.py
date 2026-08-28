"""Static registry of monorepo packages and non-package blast radii.

This module is the single source of truth for change-aware selection:
changed files are mapped to packages, the dependency graph expands them to
their dependents, and lint/test/suite commands are derived from the result.

The registry is validated against the real manifests (root ``pubspec.yaml``
workspace list, per-package ``pubspec.yaml``/``package.json``/``Cargo.toml``,
and ``pnpm-workspace.yaml``) by ``bootstrap/tests/test_monorepo.py``. When
adding or removing a package, update this file; the consistency tests will
fail otherwise.

Edges are declared from the dependent to its dependency, exactly as written
in the manifests, plus one documented cross-language edge: the Flutter app
depends on its FRB Rust crate through cargokit (``rust_builder``), which is
not visible to pub.
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class Package:
    """A lintable/testable package in the monorepo."""

    id: str  # manifest name (pubspec name / package.json name / crate name)
    path: str  # repo-relative package directory
    ecosystem: str  # "dart" | "ts" | "rust"
    depends_on: tuple[str, ...] = ()  # intra-repo edges (dependent -> dependency)
    suites: tuple[str, ...] = ()  # CI suites this package directly feeds
    tests: bool = False  # the package has its own test suite


# Edges that are declared in the registry but intentionally absent from the
# manifests (cross-language build wiring). The consistency tests allow
# exactly these extras.
ALLOWED_EXTRA_EDGES: frozenset[tuple[str, str]] = frozenset(
    {
        # cargokit (rust_builder) builds the FRB crate into the Flutter app.
        ("eve_fit_assistant", "rust_lib_eve_fit_assistant"),
    }
)


PACKAGES: tuple[Package, ...] = (
    # ------------------------------------------------------------------ Dart
    Package(
        id="eve_fit_assistant",
        path="apps/eve-fit-assistant",
        ecosystem="dart",
        depends_on=(
            "efa_compat",
            "efa_acl",
            "efa_component",
            "efa_constant",
            "efa_fit",
            "efa_platform_client",
            "efa_proto",
            "rust_lib_eve_fit_assistant",
        ),
        suites=("dart", "dart-web"),
        tests=True,
    ),
    Package(
        id="acl",
        path="packages/acl/dart",
        ecosystem="dart",
        suites=("dart", "dart-web"),
        tests=True,
    ),
    Package(
        id="efa_acl",
        path="packages/efa_acl/dart",
        ecosystem="dart",
        depends_on=("acl",),
        suites=("dart", "dart-web"),
        tests=True,
    ),
    Package(
        id="efa_compat", path="packages/efa_compat", ecosystem="dart", suites=("dart", "dart-web")
    ),
    Package(
        id="efa_component",
        path="packages/efa_component",
        ecosystem="dart",
        suites=("dart", "dart-web"),
        tests=True,
    ),
    Package(
        id="efa_constant",
        path="packages/efa_constant",
        ecosystem="dart",
        suites=("dart", "dart-web"),
    ),
    Package(
        id="efa_fit",
        path="packages/efa_fit",
        ecosystem="dart",
        depends_on=("efa_proto",),
        suites=("dart", "dart-web"),
        tests=True,
    ),
    Package(
        id="efa_fit_snapshot",
        path="packages/efa_fit_snapshot",
        ecosystem="dart",
        depends_on=("efa_component", "efa_fit", "efa_proto"),
        suites=("dart", "dart-web"),
        tests=True,
    ),
    Package(
        id="efa_platform_client",
        path="packages/efa_platform_client",
        ecosystem="dart",
        depends_on=("efa_proto",),
        suites=("dart", "dart-web"),
        tests=True,
    ),
    Package(
        id="efa_proto", path="packages/efa_proto", ecosystem="dart", suites=("dart", "dart-web")
    ),
    # ------------------------------------------------------------------ Rust
    Package(
        id="rust_lib_eve_fit_assistant",
        path="apps/eve-fit-assistant/rust",
        ecosystem="rust",
        depends_on=("efa-chat", "eve-fit-os"),
        suites=("dart", "dart-web"),
    ),
    Package(
        id="efa-chat",
        path="apps/eve-fit-assistant/rust/lib/efa-chat",
        ecosystem="rust",
        depends_on=("eve-fit-os",),
        suites=("dart", "dart-web"),
    ),
    Package(id="eve-fit-os", path="packages/eve-fit-os", ecosystem="rust"),
    Package(id="release", path="worker/release", ecosystem="rust", suites=("worker",)),
    Package(
        id="efa-platform-fit-storage",
        path="worker/efa-platform-fit-storage",
        ecosystem="rust",
        depends_on=("eve-fit-os",),
        suites=("worker",),
    ),
    # ------------------------------------------------------------- TypeScript
    Package(id="efa-tech", path="site/home", ecosystem="ts", suites=("site",)),
    Package(id="manual", path="site/manual", ecosystem="ts", suites=("site",)),
    Package(
        id="efa-platform",
        path="site/platform",
        ecosystem="ts",
        depends_on=(
            "efa-acl-ts",
            "efa-fit-snapshot-ts",
            "efa-platform-client-ts",
            "efa-proto-ts",
        ),
        suites=("site",),
    ),
    Package(
        id="efa-platform-api",
        path="worker/efa-platform-api",
        ecosystem="ts",
        depends_on=("efa-acl-ts", "efa-proto-ts"),
        suites=("worker",),
        tests=True,
    ),
    Package(
        id="efa-platform-data-sync",
        path="worker/efa-platform-data-sync",
        ecosystem="ts",
        suites=("worker",),
        tests=True,
    ),
    Package(id="email-filter", path="worker/email-filter", ecosystem="ts", suites=("worker",)),
    Package(id="issue-redirect", path="worker/issue-redirect", ecosystem="ts", suites=("worker",)),
    Package(id="acl-ts", path="packages/acl/ts", ecosystem="ts", depends_on=("acl-tool",)),
    Package(id="acl-tool", path="packages/acl/tool", ecosystem="ts"),
    Package(id="efa-acl-ts", path="packages/efa_acl/ts", ecosystem="ts", depends_on=("acl-ts",)),
    Package(id="efa-platform-client-ts", path="packages/efa_platform_client_ts", ecosystem="ts"),
    Package(
        id="efa-proto-ts", path="packages/efa_proto_ts", ecosystem="ts", suites=("snapshot-ts",)
    ),
    Package(
        id="efa-fit-snapshot-ts",
        path="packages/efa_fit_snapshot_ts",
        ecosystem="ts",
        depends_on=("efa-proto-ts",),
        suites=("snapshot-ts",),
    ),
)


@dataclass(frozen=True)
class MetaEntry:
    """Non-package (or cross-package) paths with an explicit blast radius."""

    id: str
    patterns: tuple[str, ...]
    packages: tuple[str, ...] = ()  # packages directly affected
    ecosystems: tuple[str, ...] = ()  # every package of these ecosystems
    suites: tuple[str, ...] = ()  # additional CI suites affected
    full: bool = False  # escalate to a full CI run
    web: bool = False  # affects the Flutter web bundle


META_ENTRIES: tuple[MetaEntry, ...] = (
    # Infrastructure changes fail safe: run everything.
    MetaEntry(
        id="infra-ci",
        patterns=("bootstrap/ci/**", "flake.nix", ".github/workflows/**"),
        full=True,
    ),
    # Python tooling feeds the codegen pipeline that produces the web bundle.
    MetaEntry(
        id="python-tooling",
        patterns=("bootstrap/**", "x.py", "pyproject.toml", "uv.lock"),
        suites=("python",),
        web=True,
    ),
    # Protobuf schemas generate code consumed by Dart and TS packages.
    MetaEntry(
        id="data-schema",
        patterns=("data/schema/**",),
        packages=("efa_proto", "efa-proto-ts"),
        suites=("python",),
        web=True,
    ),
    MetaEntry(
        id="data-raw",
        patterns=("data/**",),
        suites=("python",),
    ),
    # Workspace-level manifests affect their whole ecosystem.
    MetaEntry(
        id="dart-root",
        patterns=("pubspec.yaml", "pubspec.lock"),
        ecosystems=("dart",),
        web=True,
    ),
    MetaEntry(
        id="rust-root",
        patterns=("Cargo.toml", "Cargo.lock"),
        ecosystems=("rust",),
        web=True,
    ),
    MetaEntry(
        id="ts-root",
        patterns=("pnpm-workspace.yaml", "pnpm-lock.yaml", "biome.json", "package.json"),
        ecosystems=("ts",),
    ),
    MetaEntry(
        id="flake-lock",
        patterns=("flake.lock",),
        suites=("workflows",),
        web=True,
    ),
    MetaEntry(
        id="github-actions",
        patterns=(".github/**",),
        suites=("workflows",),
    ),
    MetaEntry(
        id="l10n",
        patterns=(
            "apps/eve-fit-assistant/l10n.yaml",
            "apps/eve-fit-assistant/l10n/*.arb",
            "packages/efa_fit_snapshot/l10n.yaml",
            "packages/efa_fit_snapshot/l10n/*.arb",
        ),
        suites=("l10n",),
    ),
    # Web delivery plumbing (Cloudflare Pages) only affects the web bundle.
    MetaEntry(
        id="web-delivery",
        patterns=(
            ".github/actions/build-web/**",
            ".github/actions/deploy-web-pages/**",
            "ci/config/wrangler.*.toml",
        ),
        web=True,
    ),
)
