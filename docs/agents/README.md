# Agent Documentation Index

This directory holds the detailed subsystem and workflow documentation referenced by the
root `AGENTS.md`. Keep the root file compact; put component architecture, operational detail,
and long command explanations here or in the nearest scoped `AGENTS.md`.

## Repository At A Glance

| Area | Count / location | Notes |
| ---- | ---------------- | ----- |
| Flutter app | 1 (`apps/eve-fit-assistant/`) | Main application, including the FRB bridge and AI chat crate. |
| Published/local packages | 9 (`packages/`) | Includes the `eve-fit-os` fitting-engine Git submodule. |
| Rust crates | 3 | FRB bridge, fitting engine, and `efa-chat`. |
| Site apps | 3 (`site/home`, `site/manual`, `site/platform`) | Homepage, Astro manual, and Astro/Svelte platform. |
| Cloudflare workers | 6 (`worker/`) | Platform API/storage/sync, release, email filter, and issue redirect. |
| Native packaging targets | 2 (`distro/linux`, `distro/windows`) | Linux AppImage/native bundle and Windows zip/MSI. |
| Primary implementation languages | 5 | Dart/Flutter, Rust, Python, TypeScript/Svelte/Astro, and shell/config. |

Counts describe the current repository layout, not deploy targets. Use `git submodule status`,
`./x workspace list`, and executable project configuration for live state.

## Documentation Map

| Document | Scope |
| -------- | ----- |
| @docs/agents/workspace | Repository shape, package inventory, crate boundaries, and path conventions. |
| @docs/agents/environment | Nix/dev-shell setup, local configuration, Windows prerequisites, and external data requirements. |
| @docs/agents/build-and-test | Canonical format/lint/generate/build/test commands, platform variants, and web test behavior. |
| @docs/agents/engineering-conventions | Cross-language style, generated-code rules, FRB threading, and validation minimums. |
| @docs/agents/storage | App storage systems, content-addressed repository, account/session handling, startup flow, and data-flow orchestration. |
| @docs/agents/app-links | Fit deep links, platform registration, assetlinks generation, and the share landing page. |
| @docs/agents/data-versioning | Data workspaces, resource prerequisites, canonical version flow, and release-note scaffolding. |
| @docs/agents/ci-release | GitHub Actions release/data workflows, test-mode publishing, environments, secrets, and web delivery. |
| @docs/agents/python-pipeline | Python workspace CLI, remote session model, and Python-specific operating rules. |
| @docs/agents/developer-mode | App developer-mode access, entry points, providers, and localization restrictions. |
| @docs/agents/efa-chat | AI chat architecture across the `efa-chat` Rust crate, FRB bridge, and Dart feature/storage layers. |
| @docs/agents/style | Cross-product design principles: identity, surfaces, motion, typography, voice, bilingual text, and accessibility. |
| @docs/agents/color | Canonical Brand and Workload color families, concrete tokens, semantic colors, and palette-selection rules. |

## Scoped Instruction Files

Use the nearest `AGENTS.md` when editing a subtree. These files contain local rules and point
back here for depth:

| Scope | Instruction file |
| ----- | ---------------- |
| Repository root | `AGENTS.md` |
| Flutter app | `apps/eve-fit-assistant/AGENTS.md` |
| Python bootstrap/CLI | `bootstrap/AGENTS.md` |
| Raw data and schemas | `data/AGENTS.md` |
| Dart/TS packages | `packages/AGENTS.md` plus package-specific files where present |
| Sites | `site/AGENTS.md`, `site/platform/AGENTS.md`, and `site/manual/AGENTS.md` |
| Native packaging | `distro/AGENTS.md` |
| GitHub automation | `.github/AGENTS.md` |
| Tracked CI config | `ci/AGENTS.md` |
| Cloudflare workers | `worker/AGENTS.md` |

## Reading Order

1. Read the root `AGENTS.md` for repository-wide rules and the top-level map.
2. Read the nearest scoped `AGENTS.md` for the subtree being edited.
3. Read the matching document above for architecture or workflow detail.
4. Confirm commands against `./x --help`, `flake.nix`, package manifests, workflow files, or
   official upstream documentation before relying on them.
