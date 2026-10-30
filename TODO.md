# TODO

## Data pipeline

- [ ] Expand reference-only (in-place) blob entries beyond ship models. The
  `external_entries` mechanism in `generate_resource_snapshot` lets the
  snapshot index point at blobs that already exist in the production store
  without downloading them, but it is currently wired for cache-hit ship
  models only (`ModelsCacheContext.hit_reference`). Generalize it to other
  generated assets once another producer gains a build-state cache.

## Dependencies

- [ ] Adapt `efa-chat` to rig once rig provides a stable version. Since v0.41
  rig has been non-stable with rapid updates, introducing too many breaking
  changes; Renovate is pinned off for `rig` (renovate.json5) until then.
- [ ] Migrate to TypeScript 7 (united, repo-wide). Pinned to 6 in
  renovate.json5: `svelte-check --tsgo` still requires a TS6 +
  `@typescript/native` dual install, and `astro check` (site/platform) has no
  TS7 support at all — it needs `@astrojs/ts-content-mapper` (TS 7.1+).
  Revisit once both tools work with a plain TS7 install (see PR #503).
- [ ] Upgrade vitest to v5. Blocked repo-wide in renovate.json5; the workers
  are gated on `@cloudflare/vitest-plugin` support
  (cloudflare/workers-sdk#15618). Re-enable once the plugin supports v5.
