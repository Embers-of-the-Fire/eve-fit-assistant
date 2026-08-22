# efa_proto_ts

Scope: protobuf-es TypeScript bindings for the platform-facing fit schemas (`utils`, `fit`,
`fit_snapshot`, and `fit_request`).

- Import bindings as `efa-proto-ts/<name>_pb`.
- `buf.gen.yaml` is the schema list and generation template.
- `src/gen/` is generated and gitignored; never edit generated files by hand.
- Generate from the repository root with `./x generate protobuf` or from the pnpm workspace
  with `pnpm --filter efa-proto-ts generate`.
- The runtime is `@bufbuild/protobuf`; keep versions aligned with `package.json` and the
  lockfile instead of assuming memorized versions.

Validation:

```sh
pnpm --filter efa-proto-ts generate
pnpm --filter efa-proto-ts check
```
