# Cloudflare Workers

Scope: repository-managed Cloudflare Workers under `worker/`. The directory holds both
JavaScript/TypeScript workers (`efa-platform-api`, `efa-platform-data-sync`, `email-filter`,
`issue-redirect`) and Rust workers (`efa-platform-fit-storage`, `release`); the rules below
are scoped by worker type.

## Hard Constraints

- JavaScript/TypeScript workers: use pnpm and the worker's own `package.json`/`wrangler.toml`
  as the command source of truth. Rust workers: use Cargo (`Cargo.toml`, root workspace
  member) and `wrangler.toml` instead.
- Do not deploy or mutate remote Cloudflare state unless the user explicitly asks for that
  operation.
- Keep worker bindings, routes, environment names, and D1 database IDs synchronized with the
  consuming site or release workflow.
- JavaScript/TypeScript worker tests use Vitest with `@cloudflare/vitest-plugin` against the
  real bindings in `wrangler.toml`; do not re-introduce `node:test` or hand-written binding
  mocks (node:sqlite D1 shims, in-memory KV/DO doubles). Not all JS/TS workers define a test
  script — `email-filter` and `issue-redirect` ship none.

## Docs

- Builds and tests (JS/TS test pipeline): [docs/dev/build-and-test.md](../docs/dev/build-and-test.md)
- Release/data-sync integration: [docs/dev/ci-release.md](../docs/dev/ci-release.md)
- Validation: run only the scripts the selected worker defines — JS/TS workers expose
  `check`/`lint`/`test` from their `package.json` (not all define every script); Rust workers
  use `cargo check`/`cargo clippy`/`cargo test` with `-p release -p efa-platform-fit-storage`
  (run from the repository root — plain `cargo` commands only build the workspace
  default-members, which exclude both Rust workers).
