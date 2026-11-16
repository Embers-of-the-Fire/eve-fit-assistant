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
- [ ] Migrate Android to built-in Kotlin (`android.builtInKotlin=true`) and remove
  legacy KGP once a published `fluttertoast` release supports it. The AGP 9.2.1
  build currently uses legacy KGP 2.4.0 compatibility mode because `fluttertoast`
  10.0.2, the latest published release, still applies `kotlin-android`. This keeps
  the build on published dependencies, but retains Flutter's future-deprecation
  warning and prevents enabling AGP's built-in Kotlin support. Revisit when
  updating `fluttertoast`.
