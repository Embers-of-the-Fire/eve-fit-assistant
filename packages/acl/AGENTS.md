# acl

Scope: the ACL token DSL library in `packages/acl/` — a single package containing both
runtimes plus the code generator. This layout (`dart/`, `ts/`, `tool/` subdirectories) is a
deliberate exception to the repository's `efa_*` / `efa_*_ts` sibling-package convention.

## Hard Constraints

- Generated fixtures (`ts/test/fixtures/generated/`, `dart/test/fixtures/generated/`) are
  gitignored outputs of `./x generate acl` / `melos run acl:gen`; never edit them by hand —
  change the emitters in `tool/src/` and regenerate.
- Keep `tool/` sources erasable-syntax-only (no enums, namespaces, or parameter properties)
  with explicit `.ts` extensions and `import type` (it runs on Node's native type
  stripping).
- Semantics that must stay aligned across both runtimes: exact matching only (no qualifier
  implication); `can` returns `boolean` for unqualified actions and the matched qualifiers
  (or `false` when no token matches) for qualified actions — callers must not iterate the
  `false` result.
- Only `src/index.ts` (TS) and `lib/acl.dart` (Dart) are public API.

## Docs

- DSL format: `docs/dsl.md` in this directory.
- Engineering conventions: [docs/dev/engineering-conventions.md](../../docs/dev/engineering-conventions.md)
- Validation: `./x generate acl`, `pnpm --filter acl-ts check`,
  `pnpm --filter acl-ts test`, `pnpm --filter acl-tool check`,
  `pnpm --filter acl-tool test`, `melos run pkg:test`.
