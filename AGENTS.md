# AGENTS.md

Top-level routing and repository-wide rules for OpenCode sessions. Keep this file compact:
component architecture and workflow detail belong in @docs/agents/README or the nearest
scoped `AGENTS.md`.

## Overall Guidelines

- Always fetch official documentation as the source of truth. Do not rely on world knowledge
  for external APIs, tools, or platform behavior.
- For every assumption or conclusion made without accessing documentation, provide a URL that
  supports it.
- Prefer executable configuration and `./x --help` over documentation when they conflict.
- Read the nearest scoped `AGENTS.md` before editing a subtree; more local instructions take
  precedence over this file.
- Make the smallest change that satisfies the task. Do not edit generated outputs by hand;
  update sources and run the matching generator.
- After edits, run the relevant formatter, linter, and tests. Use `./x lint` for
  mixed-language or uncertain changes.
- `packages/eve-fit-os/` is a Git submodule with independent history and versioning; do not
  leave unrelated parent-repository changes inside it.
- `CLAUDE.md` is a symlink to this file.

## Top-Level Organization

| Area | Scope | Scoped guide | Detail docs |
| ---- | ----- | ------------ | ----------- |
| `apps/eve-fit-assistant/` | Flutter app, FRB bridge, chat crate | `apps/eve-fit-assistant/AGENTS.md` | @docs/agents/workspace, @docs/agents/storage, @docs/agents/app-links, @docs/agents/efa-chat |
| `packages/` | Shared Dart/TS packages and fitting-engine submodule | `packages/AGENTS.md` plus package-local files | @docs/agents/workspace, @docs/agents/engineering-conventions |
| `bootstrap/` + `x.py` | Python workspace CLI, codegen, CI/release/data tooling | `bootstrap/AGENTS.md` | @docs/agents/python-pipeline, @docs/agents/environment |
| `data/` | Raw EVE resources and protobuf schemas | `data/AGENTS.md` | @docs/agents/data-versioning |
| `site/` | Homepage, manual, and platform web apps | `site/AGENTS.md`; nested site guides | @docs/agents/style, @docs/agents/color, @docs/agents/app-links |
| `worker/` | Cloudflare Workers | `worker/AGENTS.md` | @docs/agents/ci-release |
| `distro/` | Linux and Windows packaging assets | `distro/AGENTS.md` | @docs/agents/build-and-test |
| `.github/` + `ci/` | Workflows, composite actions, tracked CI config | `.github/AGENTS.md`, `ci/AGENTS.md` | @docs/agents/ci-release |

## Project-Wide Anchors

- Detailed documentation index and repository statistics: @docs/agents/README.
- Workspace/package inventory and path conventions: @docs/agents/workspace.
- Environment setup: @docs/agents/environment.
- Builds and tests: @docs/agents/build-and-test.
- Style, generated-code, and validation rules: @docs/agents/engineering-conventions.
- Data workspaces and canonical versioning: @docs/agents/data-versioning.
- Release automation: @docs/agents/ci-release.
- Cross-product visual and language design: @docs/agents/style and @docs/agents/color.

## Command Routing

Use these root-level entry points first, then follow the scoped guide for narrower commands:

```sh
./x lint                 # all-language fix/lint/format pass
./x format               # formatting only
./x generate -f all      # all generators, then format
./x test all             # full test suite
./x build data           # selected workspace data
./x ci release verify --check-all
```

`flake.nix`, package manifests, workflow files, `RELEASING.md`, and `./x --help` are local
sources of truth for environment, commands, CI, and release behavior. There is no
`.cursor/rules/`, `.cursorrules`, or `opencode.json` project instruction file.
