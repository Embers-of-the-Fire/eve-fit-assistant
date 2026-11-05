# Packages

Scope: shared Dart/TypeScript packages and the `eve-fit-os` fitting-engine submodule.

- Use the nearest package-level `AGENTS.md` when one exists; it takes precedence over this
  file.
- `packages/eve-fit-os/` is a Git submodule with independent history and versioning; do not
  create commits or leave unrelated changes inside it while working on the parent
  repository. Initialize it after clone with `git submodule update --init`.
- Use the package manifest as the source of truth for commands; run the narrowest relevant
  format/lint/test command first and `./x lint` for mixed-language changes.

## Docs

- Workspace/package inventory and path conventions: [docs/dev/workspace.md](../docs/dev/workspace.md)
- Engineering conventions and validation: [docs/dev/engineering-conventions.md](../docs/dev/engineering-conventions.md)
