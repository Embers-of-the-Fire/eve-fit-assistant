# efa-platform-fit-storage

Pure, content-addressed fit store: a Cloudflare Worker (worker-rs) that accepts
a fit-state upload, computes the fit's statistics with the `eve-fit-os`
fitting engine, stores the result as a self-contained `FitSnapshot`, and
serves snapshots by fit hash. It knows nothing about posts, threads, or
listing.

This worker has **no public route**; it is reachable only through the
`FIT_STORAGE` service binding of `efa-platform-api`. Authentication lives in
`efa-platform-api`; this worker performs no credential checks.

## API

Protobuf-only (`application/x-protobuf`); error responses keep the JSON
envelope.

| Endpoint | Request | Response |
| --- | --- | --- |
| `POST /platform/storage/fit/submit` | `FitUploadRequest` protobuf body | `FitStoreResponse` protobuf |
| `GET /platform/storage/fit/by-hash/:fit_hash` | — | `FitSnapshot` protobuf bytes; 404 if unknown |
| `GET /platform/storage/fit/health` | — | 200 JSON `{ "ok": true }` after a `SELECT 1` on both databases |

The wire messages live in `data/schema/fit_request.proto` (package `fit`).
The fit hash is `lowercase_hex(sha256(canonical FitState bytes))`; the
canonical form sorts every repeated collection (see `src/hash.rs`).

Oversized free-text fields are rejected with 400 `bad_request` before
canonicalization (limits in Unicode code points): `fit_name` ≤ 100,
`description` ≤ 4000.

When the requested `(server_id, snapshot_hash)` has no completed registry row,
the submit either fails or — with explicit uploader consent
(`FitUploadRequest.allow_latest_snapshot_fallback`) — reproduces the fit with
the server's latest completed snapshot for the same `server_id`. The error
envelope then carries `latest_snapshot_hash` so clients can ask for that
consent; `FitStoreResponse.snapshot_hash` / `snapshot_fallback` report which
snapshot actually computed the result. Fits are stored per
`(fit_hash, snapshot_hash)` variant (`requested_snapshot_hash` records the
fallback provenance), so a re-upload under the originally requested snapshot —
once ingested — recomputes into its own variant instead of short-circuiting on
the fallback entry; reads addressed by bare fit hash serve the newest variant.

Error responses are JSON `{ "error": <code>, "message": <string> }` (+ an
`issues` array for `validation_failed`, + `latest_snapshot_hash` for
`snapshot_incomplete` when a fallback candidate exists):

| Status | Code | Condition |
| --- | --- | --- |
| 400 | `bad_request` | Malformed protobuf, constraint violations |
| 404 | `not_found` | Unknown fit hash |
| 409 | `snapshot_incomplete` | `(server_id, snapshot_hash)` has no completed row in the `snapshots` registry; carries `latest_snapshot_hash` when a same-server fallback candidate exists |
| 422 | `unknown_type` | A referenced type ID has no row in the snapshot |
| 422 | `validation_failed` | Engine `validate_fit` returned Error-level issues |

## How it works

- Engine data comes from the `efa-snapshot-registry` D1 database
  (populated by `worker/efa-platform-data-sync`), addressed by the
  client-supplied `(server_id, snapshot_hash)`. The selector is resolved to
  the registry's `snapshot_id` (requiring `completed_at IS NOT NULL`, cached
  per isolate), and rows are read from `snapshot_entries` ⋈ `entries` by
  `(snapshot_id, family)`. A 3-round transitive-closure prefetch
  (`src/prefetch.rs`) loads exactly the reachable rows; a `thread_local!`
  isolate cache makes warm requests zero-query.
- `eve-fit-os` is used with `default-features = false`; the worker decodes
  `efos.*` rows itself and implements `InfoProvider` (`src/provider.rs`).
  Getter misses degrade to zero-value placeholders and are counted/logged,
  never a wasm trap.
- Fits that pass `calculate` + `validate_fit` are stored in the `efa-platform`
  D1 database (`migrations/0001_init.sql`, `0002_snapshot_variants.sql`): one
  `fits` row per `(canonical hash, computation snapshot)` variant (idempotent
  re-submits of the same variant skip computation). The `posts` table in the
  same database is owned by `efa-platform-api`.
- At submit time only, each used type's icon is resolved through the EFA
  storage catalog chain (`src/icons.rs`:
  `channels/heads/channels.json` → head `metadata.json` → generation
  `resources.pb2` → the server's `ResourceIndex`) and baked into the snapshot
  as `SnapshotType.icon_url` — an absolute, immutable, content-addressed blob
  URL under `STORAGE_ORIGIN` (`efa/v2/assets/blobs/...`, `identHash =
  SHA-256(resource_id)`; graphic IDs preferred over icon IDs, matching the
  app). Resolution is best-effort and cached (Cloudflare Cache API plus
  in-isolate memoization of the immutable, content-addressed bodies): any
  failure — including a missing `STORAGE_ORIGIN` var — leaves `icon_url`
  unset and consumers fall back to the public EVE image server keyed by
  `type_id`. There is no rebake-on-read; pre-existing fits rely on the
  fallback until re-submitted.
- Statistics are a field-for-field port of the app's
  `lib/features/fit_io/snapshot_export.dart::_statistics` (`src/statistics.rs`).

## Local development

```sh
cargo build -p efa-platform-fit-storage   # host build
cargo test -p efa-platform-fit-storage    # host unit tests
worker-build --release                    # wasm build (output: build/)
wrangler dev                              # local smoke (miniflare D1)
```

The engine's `build.rs` requires `packages/eve-fit-os/.env` even with
default-features off. On developer machines `./x dev env write-backend` has
already written a real one and nothing else is needed. Otherwise
`gen_engine_json.py` (stdlib + PyYAML) regenerates the negative-only patch
JSONs from the submodule's tracked `data/patches/*.yaml` into the gitignored
`engine-json/` directory, and `install-build.sh` writes a minimal `.env`
pointing at it (never overwriting an existing one).

## Preview environment

`wrangler deploy --env preview` targets the `[env.preview]` preview chain:
`FIT_DB` points at the disposable
`efa-platform-test` database; `PLATFORM_DB` stays on `efa-snapshot-registry`
(engine data is read-only and shared).

## Deployment (one-time setup)

1. `wrangler d1 create efa-platform` / `efa-platform-test` → paste the real
   `database_id`s into `wrangler.toml`.
2. `wrangler d1 migrations apply efa-platform --remote` (and `--env preview`
   for the test database). Migration filenames must never collide with those
   of `efa-platform-api` — wrangler records applied filenames per database.
3. Cloudflare Git integration: build command runs `./install-build.sh` then
   `wrangler deploy` (same pattern as `worker/release`; no GitHub Actions
   changes). The `FIT_STORAGE_TOKEN` secret lives on `efa-platform-api`, not
   here.
