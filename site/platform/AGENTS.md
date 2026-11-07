# Platform Site

Scope: the Astro + Svelte-islands SSR app for the discussion platform and fit-share landing
page.

## Hard Constraints

- **Never pass `--env` to `wrangler deploy` to select the environment.** The target
  environment is selected **at build time** via `CLOUDFLARE_ENV`, which flattens the
  matching `[env.<name>]` overrides from `wrangler.toml` into the adapter-emitted
  `dist/server/wrangler.json` and stamps it with `targetEnvironment`. Deploying a build
  made without `CLOUDFLARE_ENV` via `--env=preview` silently deploys the **production**
  configuration. Deploy with `wrangler deploy --config dist/server/wrangler.json` only.
- Platform HTTP API behavior lives in `worker/efa-platform-api/`, not in this Astro app.
  `src/pages/platform/[...path].ts` is a same-origin reverse proxy (gated by the build-time
  `__PLATFORM_API_PROXY_ENABLED__`, preview builds only; production answers its requests
  with 400); preview browser traffic must keep routing through it because cross-origin API
  calls fail under Cloudflare Access.
- The D1 binding `FIT_DB` points to `efa-platform`. It is defined in
  `worker/efa-platform-api/wrangler.toml` and `worker/efa-platform-fit-storage/wrangler.toml`
  — not in `site/platform/wrangler.toml`; keep bindings in sync with those workers and do
  not add `FIT_DB` to the site configuration.
- Permission-gated UI gates on ACL tokens, never role names — real authorization is always
  enforced by the API. Role keys are internal vocabulary; label-map them before display.
- Route caching is deliberately scoped to `/post/[id]` (`maxAge: 31536000`, `swr: 86400`);
  deleting a post does not purge that cache (staleness accepted by design), so post-delete
  UI must live in client-side islands, never in SSR output. List/account pages are
  data-free shells and must remain uncached. Never set `cross_version_cache`.
- Account/auth pages (`/account*`, `/account/login|register|reset`) must stay uncached.
- Tokens live in `localStorage`; the auth API sets no cookies by design.
- The canonical `/share/fit/raw` landing page must not decode fit payloads; it validates
  the envelope shape and forwards to an app target.

## Docs

- Fit deep links and sharing: [docs/dev/app-links.md](../../docs/dev/app-links.md)
- Style and color: [docs/dev/style.md](../../docs/dev/style.md), [docs/dev/color.md](../../docs/dev/color.md)
- Builds and tests: [docs/dev/build-and-test.md](../../docs/dev/build-and-test.md)
- Release/deploy integration: [docs/dev/ci-release.md](../../docs/dev/ci-release.md)
- Site-wide rules: [AGENTS.md](../AGENTS.md)
- Validation: `pnpm --filter efa-platform check`, `pnpm biome check --fix site/platform`.
