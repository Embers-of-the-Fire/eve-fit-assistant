# efa-platform-fit-storage

Remote fit storage & computation service: a Cloudflare Worker (worker-rs) that
accepts an authorized fit-state upload, computes the fit's statistics with the
`eve-fit-os` fitting engine, and stores the result as a self-contained
`FitSnapshot` for later retrieval.

Spec: `docs/temp/remote-fit/spec.md`; implementation plan:
`docs/temp/remote-fit/plan.md`.

## API

Routes are mounted at `api.efa-tech.dev/platform/storage/fit/*`. Permissive
CORS on all endpoints.

| Endpoint | Auth | Request | Response |
| --- | --- | --- | --- |
| `POST /platform/storage/fit/submit` | Bearer | `FitUploadRequest` protobuf body (`Content-Type: application/x-protobuf`) | `FitUploadResponse` protobuf |
| `GET /platform/storage/fit/by-hash/:fit_hash` | public | — | `FitSnapshot` protobuf bytes; 404 if unknown |
| `GET /platform/storage/fit/request/:request_id` | public | — | `FitRequestRecord` protobuf; 404 if unknown |
| `GET /platform/storage/fit/health` | public | — | 200 JSON `{ "ok": true }`; with a valid Bearer token it additionally runs `SELECT 1` on both databases and reports failures |

The wire messages live in `data/schema/fit_request.proto` (package `fit`).
The fit hash is `lowercase_hex(sha256(canonical FitState bytes))`; the
canonical form sorts every repeated collection (see `src/hash.rs`).

Error responses are JSON `{ "error": <code>, "message": <string> }` (+ an
`issues` array for `validation_failed`):

| Status | Code | Condition |
| --- | --- | --- |
| 400 | `bad_request` | Malformed protobuf, constraint violations |
| 401 | `unauthorized` | Missing/invalid Bearer token |
| 404 | `not_found` | Unknown hash / request ID |
| 409 | `snapshot_incomplete` | `(server_id, snapshot_hash)` not in the `snapshots` registry |
| 422 | `unknown_type` | A referenced type ID has no row in the snapshot |
| 422 | `validation_failed` | Engine `validate_fit` returned Error-level issues |

## How it works

- Engine data comes from the `efa-platform-prod` D1 database (populated by
  `worker/efa-platform-data-sync`), addressed by the client-supplied
  `(server_id, snapshot_hash)`. A 3-round transitive-closure prefetch
  (`src/prefetch.rs`) loads exactly the reachable rows; a `thread_local!`
  isolate cache makes warm requests zero-query.
- `eve-fit-os` is used with `default-features = false`; the worker decodes
  `efos.*` rows itself and implements `InfoProvider` (`src/provider.rs`).
  Getter misses degrade to zero-value placeholders and are counted/logged,
  never a wasm trap.
- Fits that pass `calculate` + `validate_fit` are stored in the `efa-platform`
  D1 database (`migrations/0001_init.sql`): one `fits` row per canonical hash
  (idempotent re-submits skip computation) plus one `requests` row per
  submission.
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

Local secrets: copy `.dev.vars.example` to `.dev.vars` and set a token.

## Deployment (one-time setup)

1. `wrangler d1 create efa-platform` → paste the real `database_id` into
   `wrangler.toml` (the committed value is a placeholder).
2. `wrangler d1 migrations apply efa-platform --remote`.
3. `wrangler secret put FIT_STORAGE_TOKEN`.
4. Cloudflare Git integration: build command runs `./install-build.sh` then
   `wrangler deploy` (same pattern as `worker/release`; no GitHub Actions
   changes).
