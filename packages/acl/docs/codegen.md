# Code Generation

`acl-codegen` (package `acl-tool`, in `tool/`) turns a YAML ACL schema into
type-safe TypeScript and Dart bindings.

## Usage

```sh
node packages/acl/tool/src/cli.ts \
    --schema path/to/acl.yaml \
    [--ts path/to/acl.generated.ts] \
    [--dart path/to/acl.generated.dart] \
    [--ts-runtime-import acl-ts]
```

- `--schema` is required; at least one of `--ts` / `--dart` is required.
- Output directories are created as needed.
- `--ts-runtime-import` controls the module specifier the generated TypeScript
  uses to import the runtime (default: `acl-ts`). Inside this repository the
  test fixture uses a relative specifier instead.

Within this repository, the wrapper regenerates both test fixtures from
`example/acl.yaml`:

```sh
./x generate acl      # bootstrap wrapper (skips gracefully without pnpm)
melos run acl:gen     # melos wrapper
pnpm --filter acl-tool generate:fixtures  # direct
```

## Consumer workflow

1. Write `acl.yaml` (see [dsl.md](dsl.md)).
2. Run `acl-codegen` into your project's sources (typically as a prebuild or
   pretest step; treat the outputs as generated files).
3. Import the runtime (`acl-ts` / `package:acl`) and the generated bindings.

## Errors

Malformed YAML, invalid names, unknown keys, and empty descriptions fail with
`AclSchemaError` messages that include the schema path, e.g.:

```text
Invalid ACL schema at "post.delete.qualifiers": invalid qualifier name "Own"
```
