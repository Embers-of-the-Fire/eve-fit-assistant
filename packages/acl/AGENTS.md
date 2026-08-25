# acl

Scope: the ACL token DSL library in `packages/acl/` — a single package containing both
runtimes plus the code generator. This layout (`dart/`, `ts/`, `tool/` subdirectories) is a
deliberate exception to the repository's `efa_*` / `efa_*_ts` sibling-package convention.

The package provides:

- `ts/` — TypeScript runtime, npm name `acl-ts`, zero dependencies. Exports
  `parseToken`/`formatToken`/`AclTokenError` (grammar level) and the generic
  `Acl<TMap, TToken>` token set. Only `src/index.ts` is public API.
- `dart/` — Dart runtime, package name `acl`, pure Dart. Exports `parseToken`,
  `AclTokenFormatException`, `TokenParts`, and `Acl` from `lib/acl.dart`.
- `tool/` — the `acl-codegen` generator, npm name `acl-tool`. Reads a YAML ACL schema
  (domains/actions/qualifiers, plus an optional reserved `roles` section declaring named
  token bundles with `default` markers) and emits type-safe bindings for both runtimes,
  including the role vocabulary and `tokensForRoles`/`aclForRoles` resolvers. Runs on
  Node's native type stripping;
  keep all sources erasable-syntax-only (no enums, namespaces, or parameter properties)
  and use explicit `.ts` extensions plus `import type`.
- `example/acl.yaml` — the shared example schema. It is a fixture, not a product schema;
  consumers bring their own.

Semantics that must stay aligned across both runtimes: exact matching only (no qualifier
implication); `can` returns `boolean` for unqualified actions and the matched qualifiers
(`[] | false` in TS, `Set<...>?` via generated helpers in Dart) for qualified actions.

Generated fixtures (`ts/test/fixtures/generated/`, `dart/test/fixtures/generated/`) are
gitignored outputs of `./x generate acl` / `melos run acl:gen`; never edit them by hand —
change the emitters in `tool/src/` and regenerate.

Validation:

```sh
./x generate acl
pnpm --filter acl-ts check
pnpm --filter acl-ts test
pnpm --filter acl-tool check
pnpm --filter acl-tool test
melos run acl:gen
melos run pkg:test
```
