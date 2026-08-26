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

An upload spans many WebSocket frames (one D1 transaction each), so a failed
sync leaves partial `<f>_reg` rows behind. The `snapshots` table —
`(server_id, snapshot_hash, entry_count, completed_at)` — is the completeness
registry: the uploader marks a row only after every content and registration
frame for the snapshot succeeded, and the worker verifies the actual
registration row count before accepting the marker. **Readers must check
`snapshots` first and treat a `(server_id, snapshot_hash)` with no row as
incomplete.**

See `migrations/0001_init.sql` and `data/schema/platform_data.proto`.

## Transport

Uploads run over a single long-lived WebSocket (`GET
/platform/storage/data-sync/sync` with an upgrade request) terminated by the
`SyncSession` Durable Object (one named instance, `sync`). Each frame is its
own Durable Object event with its own CPU budget, so uploads no longer hit the
per-request resource limits that made the former HTTP batch API fail with
503s; the SQLite-backed instance hibernates between frames and incurs no
duration charges while idle.

Every client frame is a JSON object with a `type` discriminator and a
client-chosen integer `id`; the server answers each frame with one JSON object
carrying the same `id`. All operations are idempotent (`INSERT OR IGNORE` /
`INSERT OR REPLACE`): a client that loses the connection reconnects and
resends the unacknowledged frame, and a whole rerun converges via the `lookup`
and `snapshot` frames.

The WebSocket route requires `Authorization: Bearer <SYNC_TOKEN>`; the two
HTTP GET probes below are public.

### Frame: `content`

```json
{
  "type": "content",
  "id": 1,
  "entries": [
    { "family": "types", "content_hash": "sha256-hex", "content_b64": "..." }
  ]
}
```

`INSERT OR IGNORE`s every row into the family content table (dedup by content
hash); each payload is verified against its SHA-256 hash. At most 2000 entries
per frame. Replies `{ "id": 1, "ok": true, "inserted": n }`.

### Frame: `lookup`

```json
{ "type": "lookup", "id": 2, "family": "types", "content_hashes": ["sha256-hex"] }
```

Returns the subset of the given hashes not yet present in the family content
table (at most 10000 hashes per frame):
`{ "id": 2, "ok": true, "missing": ["sha256-hex"] }`. Uploaders use this to
skip already-synced content on reruns.

### Frame: `register`

```json
{
  "type": "register",
  "id": 3,
  "server_id": "tranquility",
  "snapshot_hash": "sha256-hex",
  "entries": [{ "family": "types", "entry_id": 587, "content_hash": "sha256-hex" }]
}
```

Verifies every referenced content hash exists (error reply with a `missing`
list otherwise), then `INSERT OR IGNORE`s the registration rows (immutable per
primary key, so re-runs are free of write quota). Inserts are conditional on
the absence of the `snapshots` marker: once `complete` has frozen a snapshot,
further registrations for it are skipped and the frame fails with
`Snapshot already complete`. At most 2000 entries per frame. Replies
`{ "id": 3, "ok": true, "inserted": n }`.

### Frame: `complete`

```json
{ "type": "complete", "id": 4, "server_id": "tranquility", "snapshot_hash": "sha256-hex", "entry_count": 8 }
```

Marks a snapshot complete. Verifies server-side that the registration rows
present for `(server_id, snapshot_hash)` across all `<f>_reg` tables equal
`entry_count` (error reply otherwise), then upserts the `snapshots` registry
row. Replies `{ "id": 4, "ok": true }`.

### Frame: `snapshot`

```json
{ "type": "snapshot", "id": 5, "server_id": "tranquility", "snapshot_hash": "sha256-hex" }
```

Completeness probe, same semantics as the HTTP GET below:
`{ "id": 5, "ok": true, "complete": false }` or
`{ "id": 5, "ok": true, "complete": true, "entry_count": n, "completed_at": "..." }`.

### `GET /platform/storage/data-sync/health`

Returns `{ "ok": true }` after a `SELECT 1` probe.

### `GET /platform/storage/data-sync/snapshot?server_id=...&snapshot_hash=...`

Completeness check for readers. Responds `{ "ok": true, "complete": false }`
when the snapshot has no registry row, or
`{ "ok": true, "complete": true, "entry_count": n, "completed_at": "..." }`.

## Deployment

Deployed via the Cloudflare Git integration; the build phase runs dependency
install plus `pnpm check` (`tsc --noEmit`), the deploy command is
`wrangler deploy`. Deploys also apply the Durable Object migration declared in
`wrangler.toml` (`new_sqlite_classes`), which provisions the `SYNC_SESSION`
class automatically.

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
