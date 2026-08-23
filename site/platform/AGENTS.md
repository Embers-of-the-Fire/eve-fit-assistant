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

## Account Auth

- `/account` (profile, sign-out, deregistration) and `/account/login`, `/account/register`,
  `/account/reset` are data-free shells over Svelte islands under `src/components/auth/`;
  they follow the app's account flows and must stay uncached.
- Browser islands call the auth API (`https://api.efa-tech.dev/platform/auth`) directly via
  `efa-platform-client-ts` (`packages/efa_platform_client_ts`); `src/lib/auth.svelte.ts`
  holds the singleton `PlatformSession` and bridges identity into `$state` runes.
- Tokens live in `localStorage` (`LocalStorageSessionStore`); the auth API sets no cookies
  by design. Local auth development relies on the loopback entries in the worker's auth
  CORS allowlist (`worker/efa-platform-api/src/root.ts`).

## Caching

Route caching uses Astro's Cloudflare CDN cache provider (`cacheCloudflare()` in
`astro.config.mjs`). `routeRules` is deliberately scoped to `/post/[id]` with
`maxAge: 31536000` and `swr: 86400`.

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
