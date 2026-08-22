# Packages

Scope: shared Dart/TypeScript packages and the `eve-fit-os` fitting-engine submodule.

Use the nearest package-level `AGENTS.md` when one exists. `packages/eve-fit-os/` is a Git
submodule with independent history and versioning; do not create commits or leave unrelated
changes inside it while working on the parent repository. Initialize it after clone with
`git submodule update --init`.

## Package Map

| Package | Role |
| ------- | ---- |
| `efa_compat/` | Platform compatibility shims for `dart:io`, isolates, and web WASM preconditions. |
| `efa_component/` | Shared presentational Flutter widgets and image assets. |
| `efa_constant/` | Dependency-free EVE static constant definitions. |
| `efa_fit/` | Fit payload/link/EFT codecs and snapshot construction/encoding. |
| `efa_fit_snapshot/` | Read-only, localization-aware Flutter display of `FitSnapshot` protobuf data. |
| `efa_fit_snapshot_ts/` | TypeScript/Svelte fit-snapshot rendering support. |
| `efa_proto/` | Generated Dart protobuf bindings for schemas in `data/schema/`. |
| `efa_proto_ts/` | Generated protobuf-es TypeScript bindings for platform-facing schemas. |
| `eve-fit-os/` | Rust fitting-engine submodule. |

## Validation

Use the package manifest as the source of truth. Broad commands:

```sh
melos run pkg:test
./x generate protobuf
pnpm --filter efa-proto-ts check
pnpm --filter efa-fit-snapshot-ts check
cargo test -p eve-fit-os
```

For package changes, run the narrowest relevant format/lint/test command first and `./x lint`
for mixed-language changes.
