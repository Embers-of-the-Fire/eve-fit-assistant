"""Layer 1 — the package graph: pure factual data about the repository.

This module is the single registry of the monorepo's lintable/testable
packages and the blast radius of paths that are not packages (or have an
impact wider than their directory). It contains no CI vocabulary: no suites,
no jobs, no task names — only packages, dependency edges, codegen facts, and
path effects.

The registry is validated against the real manifests (root ``pubspec.yaml``
workspace list, per-package ``pubspec.yaml``/``package.json``/``Cargo.toml``,
``pnpm-workspace.yaml``, and the root ``Cargo.toml`` workspace) by
``bootstrap/tests/test_ci_registry.py``. Adding or removing a package without
updating this file fails those tests.

Edges are declared from the dependent to its dependency, exactly as written
in the manifests, plus explicitly documented cross-language build edges that
manifests cannot express (see ``ALLOWED_EXTRA_EDGES``). Edges between nested
packages resolve by longest path prefix: a file belongs to the most specific
package whose directory contains it.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Literal


Ecosystem = Literal["dart", "ts", "rust"]


@dataclass(frozen=True)
class Package:
    """A lintable/testable unit of the monorepo."""

    id: str  # manifest name (pubspec name / package.json name / crate name)
    path: str  # repository-relative package directory
    ecosystem: Ecosystem
    depends_on: tuple[str, ...] = ()  # intra-repo edges (dependent -> dependency)
    tests: bool = False  # the package has its own test suite
    codegen: tuple[str, ...] = ()  # codegen step outputs required before lint/test
    opaque: bool = False  # covered only through its dependents' tasks


# Edges that are declared in the registry but intentionally absent from the
# manifests (cross-language build wiring). The consistency tests allow
# exactly these extras.
ALLOWED_EXTRA_EDGES: frozenset[tuple[str, str]] = frozenset(
    {
        # cargokit (rust_builder) builds the FRB crate into the Flutter app;
        # this edge is invisible to pub.
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
            "efa_fit_snapshot",
            "efa_platform_client",
            "efa_proto",
            "rust_lib_eve_fit_assistant",
        ),
        tests=True,
        codegen=("dart_tools", "build_runner", "l10n"),
    ),
    Package(
        id="acl",
        path="packages/acl/dart",
        ecosystem="dart",
        tests=True,
        # The test suite imports the gitignored generated ACL fixtures.
        codegen=("acl",),
    ),
    Package(
        id="efa_acl",
        path="packages/efa_acl/dart",
        ecosystem="dart",
        depends_on=("acl",),
        tests=True,
    ),
    Package(id="efa_compat", path="packages/efa_compat", ecosystem="dart"),
    Package(
        id="efa_component",
        path="packages/efa_component",
        ecosystem="dart",
        tests=True,
    ),
    Package(
        id="efa_constant",
        path="packages/efa_constant",
        ecosystem="dart",
        # `lib/eve_attr_generated.dart` (from the `attr_id` generator in
        # `dart_tools`) is gitignored and imported by `lib/eve.dart`.
        codegen=("dart_tools",),
    ),
    Package(
        id="efa_fit",
        path="packages/efa_fit",
        ecosystem="dart",
        depends_on=("efa_proto",),
        tests=True,
    ),
    Package(
        id="efa_fit_snapshot",
        path="packages/efa_fit_snapshot",
        ecosystem="dart",
        depends_on=("efa_component", "efa_fit", "efa_proto"),
        tests=True,
        # `flutter gen-l10n` output is gitignored; analyze and tests need it.
        codegen=("l10n",),
    ),
    Package(
        id="efa_platform_client",
        path="packages/efa_platform_client",
        ecosystem="dart",
        depends_on=("efa_proto",),
        tests=True,
    ),
    Package(
        id="efa_proto",
        path="packages/efa_proto",
        ecosystem="dart",
        # Generated protobuf bindings are gitignored.
        codegen=("protobuf",),
    ),
    # ------------------------------------------------------------------ Rust
    Package(
        id="rust_lib_eve_fit_assistant",
        path="apps/eve-fit-assistant/rust",
        ecosystem="rust",
        depends_on=("efa-chat", "eve-fit-os"),
        # `rust/src/frb_generated.rs` is gitignored; clippy needs it.
        codegen=("frb",),
    ),
    Package(
        id="efa-chat",
        path="apps/eve-fit-assistant/rust/lib/efa-chat",
        ecosystem="rust",
        depends_on=("eve-fit-os",),
        tests=True,
    ),
    # The fitting engine is a Git submodule with independent history and
    # versioning; it is covered through its dependents' tasks.
    Package(id="eve-fit-os", path="packages/eve-fit-os", ecosystem="rust", opaque=True),
    # cdylib built into the committed wasm-pack artifact under
    # `worker/release/build/`; no lint/test surface of its own in CI.
    Package(id="release", path="worker/release", ecosystem="rust", opaque=True),
    Package(
        id="efa-platform-fit-storage",
        path="worker/efa-platform-fit-storage",
        ecosystem="rust",
        depends_on=("eve-fit-os",),
        tests=True,
    ),
    # ------------------------------------------------------------- TypeScript
    Package(id="efa-tech", path="site/home", ecosystem="ts"),
    Package(id="manual", path="site/manual", ecosystem="ts"),
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
    ),
    Package(
        id="efa-platform-api",
        path="worker/efa-platform-api",
        ecosystem="ts",
        depends_on=("efa-acl-ts", "efa-proto-ts"),
        tests=True,
    ),
    Package(
        id="efa-platform-data-sync",
        path="worker/efa-platform-data-sync",
        ecosystem="ts",
        tests=True,
    ),
    Package(id="email-filter", path="worker/email-filter", ecosystem="ts"),
    Package(id="issue-redirect", path="worker/issue-redirect", ecosystem="ts"),
    Package(
        id="acl-ts", path="packages/acl/ts", ecosystem="ts", depends_on=("acl-tool",), tests=True
    ),
    Package(id="acl-tool", path="packages/acl/tool", ecosystem="ts", tests=True),
    Package(
        id="efa-acl-ts",
        path="packages/efa_acl/ts",
        ecosystem="ts",
        depends_on=("acl-ts",),
        tests=True,
    ),
    Package(
        id="efa-platform-client-ts",
        path="packages/efa_platform_client_ts",
        ecosystem="ts",
        tests=True,
    ),
    Package(
        id="efa-proto-ts",
        path="packages/efa_proto_ts",
        ecosystem="ts",
        # Generated protobuf bindings are gitignored.
        codegen=("protobuf_ts",),
    ),
    Package(
        id="efa-fit-snapshot-ts",
        path="packages/efa_fit_snapshot_ts",
        ecosystem="ts",
        depends_on=("efa-proto-ts",),
    ),
)


@dataclass(frozen=True)
class BlastRadius:
    """Paths that are not packages, or whose impact exceeds their directory.

    Each entry maps a set of path globs to one of three effects:

    - ``packages``: specific packages are treated as changed;
    - ``ecosystems``: every package of the named ecosystems is treated as
      changed;
    - ``everything``: every package is treated as changed (pure escalation).
    """

    id: str
    patterns: tuple[str, ...]
    packages: tuple[str, ...] = ()
    ecosystems: tuple[Ecosystem, ...] = ()
    everything: bool = False


BLAST_RADIUS: tuple[BlastRadius, ...] = (
    # Fail-safe: the selection system itself, the workflow definitions, and
    # the environment flake. A defect in the code that decides what CI runs
    # must never merge with work unrun.
    BlastRadius(
        id="selection",
        patterns=(
            "bootstrap/ci/registry.py",
            "bootstrap/ci/codegen.py",
            "bootstrap/ci/catalog.py",
            "bootstrap/ci/resolve.py",
            "bootstrap/ci/commands.py",
            "bootstrap/tests/test_ci_*.py",
        ),
        everything=True,
    ),
    BlastRadius(
        id="workflows",
        patterns=(".github/workflows/**", ".github/actions/**"),
        everything=True,
    ),
    BlastRadius(id="flake", patterns=("flake.nix", "flake.lock"), everything=True),
    # Workspace-level manifests affect their whole ecosystem.
    BlastRadius(
        id="dart-workspace",
        patterns=("pubspec.yaml", "pubspec.lock"),
        ecosystems=("dart",),
    ),
    BlastRadius(
        id="ts-workspace",
        patterns=("pnpm-workspace.yaml", "pnpm-lock.yaml", "package.json", "biome.json"),
        ecosystems=("ts",),
    ),
    BlastRadius(
        id="rust-workspace",
        patterns=("Cargo.toml", "Cargo.lock"),
        ecosystems=("rust",),
    ),
    # Protobuf schemas generate code consumed by Dart and TS packages, and
    # are compiled into the Rust worker crates at build time (prost-build).
    BlastRadius(
        id="data-schema",
        patterns=("data/schema/**",),
        packages=("efa_proto", "efa-proto-ts", "efa-platform-fit-storage", "release"),
    ),
    # Web delivery plumbing (Cloudflare Pages) only affects the app bundle's
    # deployment configuration.
    BlastRadius(
        id="web-delivery",
        patterns=("ci/config/wrangler.*.toml",),
        packages=("eve_fit_assistant",),
    ),
)
