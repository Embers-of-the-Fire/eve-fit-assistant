# efa-platform-data-sync — Cloudflare Worker

Ingests per-entry engine data from resource snapshots into the
`efa-platform-snapshots` D1 database, keyed by `(server_id, snapshot_hash)` so any
historical snapshot stays addressable (checkout-ref semantics).

Mounted at `api.efa-tech.dev/platform/storage/data-sync`.

## Data model

Eight families: the five native engine collections (`types`, `type_dogma`,
`dogma_attributes`, `dogma_effects`, `buffs`) plus sync-built metadata
(`type_meta`, `dogma_attribute_meta`, `dogma_effect_meta`). Each family `<f>`
has two tables:

- `<f>` — `(content_hash TEXT PRIMARY KEY, content BLOB)`: content-addressed
  single-entry protobuf payloads (efos `efos.*` entry messages for the engine
  families, `efa.v2`-style `platform_data.*` messages for metadata).
- `<f>_reg` — `(server_id, snapshot_hash, entry_id, content_hash)`:
  registration rows mapping a snapshot's entries onto content rows.

Uploads span many requests (one transaction each), so a failed sync leaves
partial `<f>_reg` rows behind. The `snapshots` table —
`(server_id, snapshot_hash, entry_count, completed_at)` — is the completeness
registry: the uploader inserts a row only after every content and registration
batch for the snapshot succeeded, and the worker verifies the actual
registration row count before accepting the marker. **Readers must check
`snapshots` first and treat a `(server_id, snapshot_hash)` with no row as
incomplete.**

See `migrations/0001_init.sql` and `data/schema/platform_data.proto`.

## API

All mutating endpoints require `Authorization: Bearer <SYNC_TOKEN>`.

### `GET /platform/storage/data-sync/health`

Returns `{ "ok": true }` after a `SELECT 1` probe.

### `POST /platform/storage/data-sync/content`

```json
{
  "entries": [
    { "family": "types", "content_hash": "sha256-hex", "content_b64": "..." }
  ]
}
```

`INSERT OR IGNORE`s every row into the family content table (dedup by content
hash). At most 10000 entries per request. Responds `{ "ok": true, "inserted": n }`.

### `POST /platform/storage/data-sync/register`

```json
{
  "server_id": "tranquility",
  "snapshot_hash": "sha256-hex",
  "entries": [{ "family": "types", "entry_id": 587, "content_hash": "sha256-hex" }]
}
```

Verifies every referenced content hash exists (409 with a `missing` list
otherwise), then `INSERT OR IGNORE`s the registration rows (immutable per
primary key, so re-runs are free of write quota). Inserts are conditional on
the absence of the `snapshots` marker: once `/complete` has frozen a snapshot,
further registrations for it are skipped and the request fails with
409 `Snapshot already complete`. At most 10000
entries per request. Responds `{ "ok": true, "inserted": n }`.

### `POST /platform/storage/data-sync/complete`

```json
{ "server_id": "tranquility", "snapshot_hash": "sha256-hex", "entry_count": 8 }
```

Marks a snapshot complete. Verifies server-side that the registration rows
present for `(server_id, snapshot_hash)` across all `<f>_reg` tables equal
`entry_count` (409 otherwise), then upserts the `snapshots` registry row.
Responds `{ "ok": true }`.

### `GET /platform/storage/data-sync/snapshot?server_id=...&snapshot_hash=...`

Completeness check for readers. Responds `{ "ok": true, "complete": false }`
when the snapshot has no registry row, or
`{ "ok": true, "complete": true, "entry_count": n, "completed_at": "..." }`.

## Deployment

Deployed via the Cloudflare Git integration; the build phase runs dependency
install plus `pnpm check` (`tsc --noEmit`), the deploy command is
`wrangler deploy`.

One-time setup:

1. `wrangler d1 create efa-platform-snapshots` and paste the printed `database_id`
   into `wrangler.toml`.
2. `wrangler d1 migrations apply efa-platform-snapshots --remote`.
3. `wrangler secret put SYNC_TOKEN`; add the same value as the `D1_SYNC_TOKEN`
   secret of the `production-data` GitHub environment.

## Sync driver

The Python side lives in `bootstrap/data/d1/`; run via
`./x ci release-data d1-sync --hashes snapshot-hashes.json --schema-root cache/remote`
(token from `[d1].token` in `efa.dev.toml` or `--dev-env d1.token=...`).
