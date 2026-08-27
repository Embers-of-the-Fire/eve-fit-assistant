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

Error responses are JSON `{ "error": <code>, "message": <string> }` (+ an
`issues` array for `validation_failed`):

| Status | Code | Condition |
| --- | --- | --- |
| 400 | `bad_request` | Malformed protobuf, constraint violations |
| 404 | `not_found` | Unknown fit hash |
| 409 | `snapshot_incomplete` | `(server_id, snapshot_hash)` not in the `snapshots` registry |
| 422 | `unknown_type` | A referenced type ID has no row in the snapshot |
| 422 | `validation_failed` | Engine `validate_fit` returned Error-level issues |

## How it works

- Engine data comes from the `efa-platform-snapshots` D1 database (populated
  by `worker/efa-platform-data-sync`), addressed by the client-supplied
  `(server_id, snapshot_hash)`. A 3-round transitive-closure prefetch
  (`src/prefetch.rs`) loads exactly the reachable rows; a `thread_local!`
  isolate cache makes warm requests zero-query.
- `eve-fit-os` is used with `default-features = false`; the worker decodes
  `efos.*` rows itself and implements `InfoProvider` (`src/provider.rs`).
  Getter misses degrade to zero-value placeholders and are counted/logged,
  never a wasm trap.
- Fits that pass `calculate` + `validate_fit` are stored in the `efa-platform`
  D1 database (`migrations/0001_init.sql`): one `fits` row per canonical hash
  (idempotent re-submits skip computation). The `posts` table in the same
  database is owned by `efa-platform-api`.
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
`efa-platform-test` database; `PLATFORM_DB` stays on `efa-platform-snapshots`
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
