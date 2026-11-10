# Developer Documentation

This directory holds the detailed subsystem and workflow documentation for the
repository. Keep the per-subtree `AGENTS.md` files compact; component
architecture, operational detail, and long command explanations live here or in
the nearest scoped `AGENTS.md`.

## Repository At A Glance

| Area | Count / location | Notes |
| ---- | ---------------- | ----- |
| Flutter app | 1 (`apps/eve-fit-assistant/`) | Main application, including the FRB bridge and AI chat crate. |
| Published/local packages | 13 (`packages/`) | Includes the `eve-fit-os` fitting-engine Git submodule. |
| Rust crates | 3 | FRB bridge, fitting engine, and `efa-chat`. |
| Site apps | 3 (`site/home`, `site/manual`, `site/platform`) | Homepage, Astro manual, and Astro/Svelte platform. |
| Cloudflare workers | 6 (`worker/`) | Platform API/storage/sync, release, email filter, and issue redirect. |
| Native packaging targets | 2 (`distro/linux`, `distro/windows`) | Linux AppImage/native bundle and Windows zip/MSI. |
| Primary implementation languages | 5 | Dart/Flutter, Rust, Python, TypeScript/Svelte/Astro, and shell/config. |

Counts describe the current repository layout, not deploy targets. Use `git submodule status`,
`./x workspace list`, and executable project configuration for live state.

## Documentation

| Document | Scope |
| -------- | ----- |
| [Setup & Configuration](./setup-and-config.md) | Development tools, environment setup, configuration files, workspace management, and the data build routine. |
| [Build & Test](./build-and-test.md) | Canonical format/lint/generate/build/test commands, platform variants, and web test behavior. |
| [Engineering Conventions](./engineering-conventions.md) | Cross-language style, generated-code rules, FRB threading, and validation minimums. |
| [Workspace](./workspace.md) | Repository shape, package inventory, crate boundaries, and path conventions. |
| [App Storage](./app-storage.md) | Riverpod data layering, storage systems, content-addressed repository, account/session handling, startup flow, and data-flow orchestration. |
| [Fit Storage & Versioning](./fit-storage.md) | Fit persistence contract: file layout, versioning, eager normalization, registry and manager logic, and native text import. |
| [App Router](./app-router.md) | AutoRoute page structure, router configuration, and navigation. |
| [Settings](./settings.md) | Reference list of app setting keys, types, defaults, and storage location. |
| [Resource Patches](./resource-patches.md) | Manually maintained data patches that the generic generation workflow cannot produce. |
| [Advanced Fitting Release Scope](./release-scope.md) | Which advanced fitting workflows are included in the initial tester release and which stay deferred. |
| [Remote Content](./remote-content.md) | Local remote-content processing paths, data bundle generation, the mock launcher, and the V1/V2 remote storage contracts. |
| [Web App](./web-app.md) | WebAssembly web app builds and Cloudflare Pages deployment. |
| [App Links](./app-links.md) | Fit deep links, platform registration, assetlinks generation, and the share landing page. |
| [Data Versioning](./data-versioning.md) | Data workspaces, resource prerequisites, canonical version flow, and release-note scaffolding. |
| [CI & Release](./ci-release.md) | GitHub Actions release/data workflows, test-mode publishing, environments, secrets, and web delivery. |
| [Python Pipeline](./python-pipeline.md) | Python workspace CLI, remote session model, and Python-specific operating rules. |
| [Developer Mode](./developer-mode.md) | App developer-mode access, entry points, providers, and localization restrictions. |
| [AI Chat](./efa-chat.md) | AI chat architecture across the `efa-chat` Rust crate, FRB bridge, and Dart feature/storage layers. |
| [Style principles](./style/index.md) | Scoped design principles: global vocabulary and per-place rules for identity, surfaces, motion, typography, voice, bilingual text, and accessibility. |
| [Color](./color.md) | Canonical Brand and Workload color families, concrete tokens, semantic colors, and palette-selection rules. |

Additional material:

- [General](../../README.md) — repository overview and user-facing entry point.
- [Data Collection](../../data/README.md) — raw EVE resources and data build inputs.

## Scoped Guides

Per-subtree `AGENTS.md` files contain local rules for their scope and point back
here for depth. Scopes covered: root, `apps/eve-fit-assistant`, `bootstrap`,
`data`, `packages`, `site`, `distro`, `.github`, `ci`, and `worker`. Read the
nearest scoped `AGENTS.md` before editing a subtree; more local instructions
take precedence over wider ones.

## Suggested Reading Order

1. Read [Setup & Configuration](./setup-and-config.md) and [Workspace](./workspace.md)
   for the environment and repository layout.
2. Read [Build & Test](./build-and-test.md) and [Engineering Conventions](./engineering-conventions.md)
   before making changes.
3. Read the document matching the subsystem being edited for architecture or
   workflow detail.
4. Confirm commands against `./x --help`, `flake.nix`, package manifests,
   workflow files, or official upstream documentation before relying on them.
