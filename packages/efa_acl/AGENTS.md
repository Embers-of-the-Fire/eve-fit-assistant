# efa_acl

Scope: the EFA platform product ACL bindings in `packages/efa_acl/` — a single
package containing both runtimes (`dart/`, `ts/`) plus the product schema
`acl.yaml` at the root, following the `packages/acl/` single-package layout
exception.

The package provides:

- `acl.yaml` — the product ACL schema (domains/actions/qualifiers) **and** the
  placeholder permission roles (`roles` section: `user` default, `moderator`,
  `admin`). Single source of truth for all generated bindings; the DSL format
  is documented in `packages/acl/docs/dsl.md`.
- `ts/` — TypeScript package, npm name `efa-acl-ts`. Exports the generated
  token types/factories and role bindings (`AclRole`, `aclRoles`,
  `aclDefaultRoles`, `isAclRole`, `tokensForRoles`, `aclForRoles`). Only
  `src/index.ts` is public API. Depends on `acl-ts`.
- `dart/` — Dart package, `package:efa_acl`. Same surface via the barrel
  `lib/efa_acl.dart`. Depends on `package:acl`.

Unknown role names must be ignored (never throw) so a stale stored role cannot
crash a consumer — the generated resolvers already guarantee this.

Consumers gate on tokens (`acl.can(...)` / `can*()` helpers), never on role
names. Role keys are internal vocabulary: they must be label-mapped to
localized display names before being shown in any UI, and must never be
exposed for accounts other than the signed-in user's own.

`ts/src/acl.generated.ts` and `dart/lib/acl.generated.dart` are committed
generated outputs of `acl.yaml` — never edit them by hand. Regenerate with
`pnpm --filter efa-acl-ts generate` or `./x generate acl`, then format.

Consumers: `worker/efa-platform-api` (role storage + permission resolution),
`site/platform` (via `efa-acl-ts`), `apps/eve-fit-assistant` (via
`package:efa_acl`).

Validation:

```sh
pnpm --filter efa-acl-ts check
pnpm --filter efa-acl-ts test
dart analyze        # in dart/
flutter test        # in dart/
```
