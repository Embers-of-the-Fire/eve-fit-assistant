# efa_platform_client_ts

Scope: the TypeScript platform account client exposed as `efa-platform-client-ts`.

The package provides:

- `PlatformSession`, the facade embedders talk to: account auth flows (signup,
  verification, login, password reset, logout, deregistration) plus the whole token
  lifecycle (storage via the embedder-implemented `PlatformSessionStore`, expiry
  tracking, mutex-serialized refresh, cold-start rotation, 401 retry, session
  clearing). It is the TypeScript port of the Dart
  `packages/efa_platform_client` `PlatformSession`; keep their semantics aligned.
- `PlatformIdentity`/`me`/`subscribeIdentity` for the signed-in profile (derived
  locally: JWT subject + cached email; no server `/me` endpoint exists yet).
- `PlatformAuthRequiredError` plus the `onAuthRequired` hook for the "interactive
  login required" signal (throttled to once per signed-out stretch).
- `AccountApiError` (`statusCode`, `code`, `retryAfterSec`, `isInvalidToken`,
  `isEmailUnverified`) mirroring the worker's error envelope.
- `LocalStorageSessionStore`, the browser store (single-key JSON document). The
  auth API issues tokens in JSON bodies and sets no cookies by design, so the
  refresh token necessarily lives in script-readable storage.
- `platformApiProductionOrigin`, the single production-origin constant.

Only the entrypoint (`src/lib/index.ts`) is public API. The package is
framework-agnostic (no Svelte/DOM-framework imports beyond standard web APIs);
reactivity is bridged by the embedder (see `site/platform/src/lib/auth.svelte.ts`).

Validation:

```sh
pnpm --filter efa-platform-client-ts check
pnpm --filter efa-platform-client-ts test
```
