# acl

A tiny, self-contained ACL token library with first-class TypeScript and Dart
support. It defines a token DSL and a code generator that turns a YAML schema
into fully type-safe bindings for both languages.

An ACL token grants one action in one domain, optionally narrowed by a
qualifier:

```text
{domain}:{action}[:{qualifier}]

post:create
post:delete:own
post:delete:all
```

## Layout

| Path | Contents |
| ---- | -------- |
| `ts/` | TypeScript runtime (`acl-ts`): token parser and `Acl` token set. |
| `dart/` | Dart runtime (`package:acl`): same semantics for Flutter/Dart. |
| `tool/` | Code generator (`acl-tool`): YAML schema → TS + Dart bindings. |
| `example/` | Example schema used as the shared test fixture. |
| `docs/` | DSL specification, token semantics, and codegen usage. |

## Quickstart (TypeScript)

Run the generator from the repository root; all paths below resolve from it.
Substitute your own schema for the bundled example fixture:

```sh
node packages/acl/tool/src/cli.ts --schema packages/acl/example/acl.yaml --ts src/lib/acl.generated.ts
```

```ts
import { createAcl } from "./acl.generated";

const acl = createAcl(["post:create", "post:delete:all"]);

acl.has("post:delete:own"); // false
acl.can("post:create"); // true            :: boolean
acl.can("post:delete"); // ["all"]         :: ("own" | "all")[] | false
acl.can("comment:delete"); // false
```

## Quickstart (Dart)

Same working directory as above — the repository root:

```sh
node packages/acl/tool/src/cli.ts --schema packages/acl/example/acl.yaml --dart lib/acl.generated.dart
```

```dart
final acl = Acl(["post:create", "post:delete:all"]);

acl.hasToken(const PostDelete(PostDeleteQualifier.all)); // true
acl.canPostCreate(); // true
acl.canPostDelete(); // {PostDeleteQualifier.all}
```

## Semantics

Matching is **exact**: a token covers only its own qualifier. Broader
qualifiers never imply narrower ones (`post:delete:all` does not satisfy a
query for `own`). `can` returns `boolean` for actions declared without
qualifiers and the matched qualifiers (or `false`/`null` when absent) for
qualified actions.

See [docs/tokens.md](docs/tokens.md) for the grammar,
[docs/dsl.md](docs/dsl.md) for the schema format, and
[docs/codegen.md](docs/codegen.md) for generator usage.
