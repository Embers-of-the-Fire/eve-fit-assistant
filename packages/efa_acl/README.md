# efa_acl

Product ACL bindings for the EFA platform, built on the generic ACL token
library in [`packages/acl`](../acl/README.md). This package owns the product
permission schema ([`acl.yaml`](acl.yaml)) — domains/actions/qualifiers **and**
the placeholder permission roles, the single source of truth for both runtimes'
generated bindings:

| Path | Contents |
| ---- | -------- |
| `acl.yaml` | Product ACL schema + role definitions. Source of truth. |
| `ts/` | TypeScript package (`efa-acl-ts`): generated bindings. |
| `dart/` | Dart package (`package:efa_acl`): generated bindings. |

## Placeholder roles

Accounts carry role names; consumers resolve them into a typed token set via
the generated `aclForRoles`/`tokensForRoles` helpers:

| Role | Tokens |
| ---- | ------ |
| `user` (default) | `post:create`, `post:delete:own`, `comment:create`, `comment:delete:own` |
| `moderator` | `user` + `post:delete:all`, `comment:delete:all` |
| `admin` | `post:create`, `post:delete:all`, `comment:create`, `comment:delete:all`, `admin:manage_roles` |

## Quickstart (TypeScript)

```ts
import { aclDefaultRoles, aclForRoles } from "efa-acl-ts";

const acl = aclForRoles(aclDefaultRoles);
acl.can("post:create"); // true
acl.can("post:delete"); // ["own"]
```

## Quickstart (Dart)

```dart
import "package:efa_acl/efa_acl.dart";

final acl = aclForRoles(aclDefaultRoles.map((role) => role.name));
acl.canPostCreate(); // true
acl.canPostDelete(); // {PostDeleteQualifier.own}
```

## Regenerating the bindings

The generated files (`ts/src/acl.generated.ts`, `dart/lib/acl.generated.dart`)
are committed outputs of `acl.yaml`; never edit them by hand. Regenerate with:

```sh
pnpm --filter efa-acl-ts generate   # or ./x generate acl from the repo root
```
