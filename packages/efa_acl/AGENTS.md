# efa_acl

Scope: the EFA platform product ACL bindings in `packages/efa_acl/` — a single package
containing both runtimes (`dart/`, `ts/`) plus the product schema `acl.yaml` at the root,
following the `packages/acl/` single-package layout exception.

## Hard Constraints

- `acl.yaml` is the single source of truth for all generated bindings (schema and the
  placeholder permission roles); the DSL format is documented in `packages/acl/docs/dsl.md`.
- `ts/src/acl.generated.ts` and `dart/lib/acl.generated.dart` are committed generated
  outputs — never edit them by hand. Regenerate with `pnpm --filter efa-acl-ts generate` or
  `./x generate acl`, then format.
- Consumers gate on tokens (`acl.can(...)` / `can*()` helpers), never on role names. Role
  keys are internal vocabulary: they must be label-mapped to localized display names before
  being shown in any UI, and must never be exposed for accounts other than the signed-in
  user's own.
- Unknown role names must be ignored (never throw) so a stale stored role cannot crash a
  consumer.
- Only `src/index.ts` (TS) and the `lib/efa_acl.dart` barrel (Dart) are public API.

## Docs

- Validation: `pnpm --filter efa-acl-ts check`, `pnpm --filter efa-acl-ts test`,
  `cd packages/efa_acl/dart && dart analyze`, `cd packages/efa_acl/dart && flutter test`.
