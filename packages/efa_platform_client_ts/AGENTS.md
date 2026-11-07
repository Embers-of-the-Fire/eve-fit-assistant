# efa_platform_client_ts

Scope: the TypeScript platform account client exposed as `efa-platform-client-ts`.

## Hard Constraints

- It is the TypeScript port of the Dart `packages/efa_platform_client` `PlatformSession`;
  keep their semantics aligned.
- Only the entrypoint (`src/lib/index.ts`) is public API. The package is framework-agnostic
  (no Svelte/DOM-framework imports beyond standard web APIs); reactivity is bridged by the
  embedder (see `site/platform/src/lib/auth.svelte.ts`).
- The auth API issues tokens in JSON bodies and sets no cookies by design, so the refresh
  token necessarily lives in script-readable storage (`LocalStorageSessionStore`).

## Docs

- ACL roles/tokens: [../efa_acl/AGENTS.md](../efa_acl/AGENTS.md)
- Validation: `pnpm --filter efa-platform-client-ts check`,
  `pnpm --filter efa-platform-client-ts test`.
