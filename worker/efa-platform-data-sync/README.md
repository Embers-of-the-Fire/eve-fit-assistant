# efa-platform-data-sync — Cloudflare Worker

Ingests per-entry engine data from resource snapshots into the
`efa-platform-prod` D1 database, keyed by `(server_id, snapshot_hash)` so any
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
otherwise), then `INSERT OR REPLACE`s the registration rows. At most 10000
entries per request. Responds `{ "ok": true, "inserted": n }`.

## Deployment

Deployed via the Cloudflare Git integration; the build phase runs
`./build.sh` (dependency install + `tsc --noEmit`), the deploy command is
`wrangler deploy`.

One-time setup:

1. `wrangler d1 create efa-platform-prod` and paste the printed `database_id`
   into `wrangler.toml`.
2. `wrangler d1 migrations apply efa-platform-prod --remote`.
3. `wrangler secret put SYNC_TOKEN`; add the same value as the `D1_SYNC_TOKEN`
   secret of the `production-data` GitHub environment.

## Sync driver

The Python side lives in `bootstrap/data/d1/`; run via
`./x ci release-data d1-sync --hashes snapshot-hashes.json --schema-root cache/remote`
(token from `[d1].token` in `efa.dev.toml` or `--dev-env d1.token=...`).
