# efa_fit_snapshot_ts

Scope: TypeScript/Svelte fit-snapshot rendering support consumed by the platform app.

- Import package entry points from `efa-fit-snapshot-ts`; protobuf bindings come from
  `efa-proto-ts`.
- Keep rendering read-only and data-driven from `FitSnapshot`; do not re-resolve fitting data
  in this package.
- Follow @docs/agents/style and @docs/agents/color for UI work.

Validation:

```sh
pnpm --filter efa-fit-snapshot-ts check
pnpm dlx biome check --fix packages/efa_fit_snapshot_ts
```
