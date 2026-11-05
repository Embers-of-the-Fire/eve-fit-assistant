# AGENTS.md

Top-level routing and repository-wide rules for AI coding sessions. Detailed developer
documentation lives in [docs/dev/](docs/dev/README.md); read the nearest scoped `AGENTS.md`
before editing a subtree (more local instructions take precedence over this file).

## Repository-Wide Rules

- `packages/eve-fit-os/` is a Git submodule with independent history and versioning; do not
  create commits or leave unrelated parent-repository changes inside it.
- `CLAUDE.md` is a symlink to this file.
- `docs/temp` is ignored by git. **DO NOT** reference files there or any other
  git-untracked location; every reference must point to a valid anchor in the git repo.
- Follow [docs/dev/engineering-conventions.md](docs/dev/engineering-conventions.md) for
  generated-code and style rules and [docs/dev/setup-and-config.md](docs/dev/setup-and-config.md)
  for environment/tooling facts (`flake.nix`, `./x --help`, and package manifests are local
  sources of truth; there is no `.cursor/rules/`, `.cursorrules`, or `opencode.json` file).
- After edits, run the relevant formatter and linter; use `./x lint` for mixed-language or
  uncertain changes.

## Top-Level Organization

| Area | Scoped guide |
| ---- | ------------ |
| `apps/eve-fit-assistant/` | `apps/eve-fit-assistant/AGENTS.md` |
| `packages/` | `packages/AGENTS.md` plus package-local files |
| `bootstrap/` + `x.py` | `bootstrap/AGENTS.md` |
| `data/` | `data/AGENTS.md` |
| `site/` | `site/AGENTS.md` and nested site guides |
| `worker/` | `worker/AGENTS.md` |
| `distro/` | `distro/AGENTS.md` |
| `.github/` + `ci/` | `.github/AGENTS.md`, `ci/AGENTS.md` |

## Command Routing

Use these root-level entry points first, then follow the scoped guide:

```sh
./x lint                 # all-language fix/lint/format pass
./x format               # formatting only
./x generate -f all      # all generators, then format
./x test all             # full test suite
./x build data           # selected workspace data
./x ci release verify --check-all
```

## Docs

- Documentation index and repository overview: [docs/dev/README.md](docs/dev/README.md)
- Workspace and path conventions: [docs/dev/workspace.md](docs/dev/workspace.md)
- Engineering conventions and validation: [docs/dev/engineering-conventions.md](docs/dev/engineering-conventions.md)
- Setup and environment: [docs/dev/setup-and-config.md](docs/dev/setup-and-config.md)
- Builds and tests: [docs/dev/build-and-test.md](docs/dev/build-and-test.md)
- CI and release automation: [docs/dev/ci-release.md](docs/dev/ci-release.md)
