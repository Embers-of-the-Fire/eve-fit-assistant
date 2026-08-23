# Cloudflare Workers

Scope: repository-managed Cloudflare Workers under `worker/`.

## Worker Map

| Path | Role |
| ---- | ---- |
| `efa-platform-api/` | Platform API worker. |
| `efa-platform-data-sync/` | Snapshot engine-data sync into the platform D1. |
| `efa-platform-fit-storage/` | Fit storage worker sharing the platform `FIT_DB` D1 database. |
| `email-filter/` | Email handling/filter worker. |
| `issue-redirect/` | GitHub issue redirect/integration worker. |
| `release/` | Release worker and its build package. |

## Local Rules

- Use pnpm and each worker's own `package.json`/`wrangler.toml` as the command source of
  truth.
- Keep worker bindings, routes, environment names, and D1 database IDs synchronized with the
  consuming site or release workflow.
- Do not deploy or mutate remote Cloudflare state unless the user explicitly asks for that
  operation.
- TypeScript workers use the repository Biome style; run the worker's `check` and `lint`
  scripts where present.
- Worker tests use Vitest with `@cloudflare/vitest-plugin`: tests run in `workerd` against
  the real local D1/KV/Durable Object bindings declared in `wrangler.toml` plus test-only
  bindings in `vitest.config.ts`; do not re-introduce `node:test` or hand-written binding
  mocks (node:sqlite D1 shims, in-memory KV/DO doubles). See the "JS/TS Test Pipeline"
  section of @docs/agents/build-and-test.

Common validation pattern:

```sh
pnpm --filter <worker-package> check
pnpm --filter <worker-package> lint
pnpm --filter <worker-package> test
```

Use @docs/agents/ci-release for release/data-sync integration details.
