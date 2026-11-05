# efa_fit_snapshot_ts

Scope: TypeScript/Svelte fit-snapshot rendering support consumed by the platform app.

- Keep rendering read-only and data-driven from `FitSnapshot`; do not re-resolve fitting
  data in this package.
- Import package entry points from `efa-fit-snapshot-ts`; protobuf bindings come from
  `efa-proto-ts`.
- Follow [docs/dev/style.md](../../docs/dev/style.md) and [docs/dev/color.md](../../docs/dev/color.md)
  for UI work.

## Docs

- Validation: `pnpm --filter efa-fit-snapshot-ts check`,
  `pnpm biome check --fix packages/efa_fit_snapshot_ts`.
