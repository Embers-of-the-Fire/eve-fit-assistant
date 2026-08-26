# Platform Site

Scope: the Astro + Svelte-islands SSR app for the discussion platform and fit-share landing
page.

## Architecture

- Astro 7 with `@astrojs/cloudflare` v14, Svelte islands, Tailwind v4, and server output.
- Deployed as Cloudflare Worker `efa-platform` with static assets at
  `platform.efa-tech.dev`; the legacy fit-link host `share.platform.efa-tech.dev` remains
  attached for App Links verification.
- Deploy with `wrangler deploy --config dist/server/wrangler.json` after building.
- Cloudflare bindings and platform APIs use `import { env } from "cloudflare:workers"`,
  `Astro.locals.cfContext`, and global `caches` where appropriate.
- The D1 binding `FIT_DB` points to `efa-platform` and is shared with
  `worker/efa-platform-fit-storage`.
- Platform HTTP API behavior lives in `worker/efa-platform-api/`, not in this Astro app.

## Deploying

The adapter emits a generated deploy config (`dist/server/wrangler.json`) and a redirect
(`.wrangler/deploy/config.json`) that every `wrangler deploy`/`dev` in this directory
follows. The generated config contains no environment sections: the target environment is
selected **at build time** via `CLOUDFLARE_ENV`, which flattens the matching
`[env.<name>]` overrides from `wrangler.toml` into the generated config and stamps it with
`targetEnvironment`.

```sh
# Production (worker efa-platform, custom domains attached):
pnpm build
wrangler deploy --config dist/server/wrangler.json

# Preview (worker efa-platform-preview, routes = [], PLATFORM_API → efa-platform-api-preview):
CLOUDFLARE_ENV=preview pnpm build
wrangler deploy --config dist/server/wrangler.json
```

Never pass `--env` to select the environment at deploy time. On the redirected config the
flag cannot apply `wrangler.toml` env overrides; if the build was made without
`CLOUDFLARE_ENV`, `wrangler deploy --env=preview` silently deploys the **production**
configuration (worker `efa-platform`, both custom domains). Only a matching
`targetEnvironment` build makes `--env` safe (a mismatch then errors instead).

## Account Auth

- `/account` (profile, sign-out, deregistration), `/account/posts` (the signed-in
  account's own posts, via the auth-required `GET /platform/internal/my/posts`), and
  `/account/login`, `/account/register`, `/account/reset` are data-free shells over Svelte
  islands under `src/components/` (account flows under `src/components/auth/`); they follow
  the app's account flows and must stay uncached.
- Browser islands call the platform API directly (public reads in `src/lib/api.ts`,
  authenticated internal-mount calls in `src/lib/account-api.ts` through the session's
  `authedFetch`, auth flows via `efa-platform-client-ts` in
  `packages/efa_platform_client_ts`); `src/lib/auth.svelte.ts` holds the singleton
  `PlatformSession` and bridges identity into `$state` runes, and `src/lib/acl.svelte.ts`
  bridges the account's ACL tokens for permission-gated UI (gate on tokens, never role
  names — real authorization is always enforced by the API).
- The API origin is the build-time constant `__PLATFORM_API_ORIGIN__` (defined in
  `astro.config.mjs`): production `https://api.efa-tech.dev`, or the preview API when built
  with `CLOUDFLARE_ENV=preview`. The worker's auth CORS allowlist
  (`worker/efa-platform-api/src/root.ts`) carries the matching site origins, including the
  preview site origin and loopback dev origins. Note the preview API itself sits behind
  Cloudflare Access; browser access to it depends on that Access policy.
- Tokens live in `localStorage` (`LocalStorageSessionStore`); the auth API sets no cookies
  by design.

## Caching

Route caching uses Astro's Cloudflare CDN cache provider (`cacheCloudflare()` in
`astro.config.mjs`). `routeRules` is deliberately scoped to `/post/[id]` with
`maxAge: 31536000` and `swr: 86400`. Deleting a post does not purge that cache: a deleted
post's page may keep serving stale HTML until the SWR window or the next deploy (cache keys
include the Worker version). This staleness is accepted by design; post-delete UI must live
in client-side islands, never in SSR output.

List/account pages are data-free shells whose islands fetch live data client-side and must
remain uncached. The post page opts out through `Astro.cache.set(false)` on its 404 branch.
The adapter enables Workers Cache in generated `dist/server/wrangler.json`; cache keys include
the Worker version by default, so every deploy invalidates cached HTML. Never set
`cross_version_cache`. Uncached routes default to `no-store`; `/_astro/*` assets receive
immutable headers through adapter-emitted `dist/client/_headers`.

## Fit Sharing

This app hosts the canonical `/share/fit/raw` landing page and renders
`public/.well-known/assetlinks.json` at build time. The landing page must not decode fit
payloads; it validates the envelope shape and forwards to an app target. See
@docs/agents/app-links before changing link behavior.

## Validation

```sh
pnpm --filter efa-platform check
pnpm dlx biome check --fix site/platform
```
