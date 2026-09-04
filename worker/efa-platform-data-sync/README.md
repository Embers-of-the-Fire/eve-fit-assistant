# efa-platform-data-sync — Cloudflare Worker

Ingests per-entry engine data from resource snapshots into the
`efa-snapshot-registry` D1 database, keyed by `(server_id, snapshot_hash)` so any
historical snapshot stays addressable (checkout-ref semantics).

Mounted at `api.efa-tech.dev/platform/storage/data-sync`.

## Data model

Eight families: the five native engine collections (`types`, `type_dogma`,
`dogma_attributes`, `dogma_effects`, `buffs`) plus sync-built metadata
(`type_meta`, `dogma_attribute_meta`, `dogma_effect_meta`), each with a fixed
integer code (`types=0` … `dogma_effect_meta=7`, see `src/session.ts`).

Folded per-family segments (`migrations/0003_folded.sql`; the v2 per-entry
tables and the `registered_count` counter were dropped by
`migrations/0004_drop_v2.sql`):

- `folded_blobs` — `(blob_id INTEGER PRIMARY KEY, family, content_hash BLOB,
  entry_count, first_entry_id, last_entry_id, content BLOB, UNIQUE (family,
  content_hash))`: the only content store. Each row is one self-contained,
  content-addressed ≤512 KiB segment of a family's folded stream (`u32
  count` + `count × (i32 entry_id, u32 offset, u32 length)` + concatenated
  per-entry protobuf payloads).
  `first_entry_id`/`last_entry_id` bound the segment's id range for subset
  routing; `blob_id` is a dense database-local integer that must never leak
  outside the sync protocol.
- `snapshot_family_segments` — `(snapshot_id, family, seq, blob_id)`:
  per-snapshot segment links, no content.
- `snapshots` — `(snapshot_id INTEGER PRIMARY KEY, server_id, snapshot_hash
  BLOB, entry_count, completed_at, UNIQUE (server_id, snapshot_hash))`: the
  completeness registry. The first `register` frame creates the row with
  `completed_at = NULL`, and the uploader's `complete` frame freezes the
  snapshot after verifying `SUM(entry_count)` over the segment-link join
  inside the freezing `UPDATE`. **Readers must check `completed_at IS NOT
  NULL` and treat any other `(server_id, snapshot_hash)` as incomplete.**

An upload spans many WebSocket frames (one D1 transaction each), so a failed
sync leaves partial `snapshot_family_segments` rows behind — always guarded
by the pending `snapshots` row above.

See `data/schema/platform_data.proto`.

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
  "family": "types",
  "content_hash": "sha256-hex",
  "entry_count": 137,
  "first_entry_id": 587,
  "last_entry_id": 42000,
  "content_b64": "..."
}
```

Uploads one folded segment: base64-decoded, verified against its SHA-256
content hash, `INSERT OR IGNORE`d into `folded_blobs`. One segment per frame,
≤512 KiB raw (base64 capped at ~700 KiB, keeping the frame under the 1 MiB
WebSocket message limit). Replies `{ "id": 1, "ok": true, "inserted": n,
"blob_id": 123 }` — the blob id of the freshly inserted or pre-existing row.

### Frame: `lookup`

```json
{ "type": "lookup", "id": 2, "family": "types", "content_hashes": ["sha256-hex"] }
```

Returns the segment hashes not yet present in the family (at most 5000 hashes
per frame) plus the blob ids of the present ones:
`{ "id": 2, "ok": true, "missing": ["sha256-hex"], "ids": { "<hash>": 123 } }`.
Uploaders use this to skip already-synced segments on reruns and to resolve
blob ids for registration.

### Frame: `register`

```json
{
  "type": "register",
  "id": 3,
  "server_id": "tranquility",
  "snapshot_hash": "sha256-hex",
  "segments": [{ "family": "types", "seq": 0, "blob_id": 123 }]
}
```

Links a snapshot's segments (one frame per family). Resolves-or-creates the
pending `snapshots` row, then verifies every referenced blob id exists in the
link's family (error reply with a `missing` list otherwise), and a frame may
link each blob id at most once per family — a duplicate fails with
`Duplicate segment links` and inserts nothing (the freeze `SUM(entry_count)`
counts once per link row, so a duplicated blob id would be double-counted).
Links are `INSERT OR IGNORE`d (immutable per primary key, so re-runs are free
of write quota) and freeze-guarded: once `complete` has frozen a snapshot,
further registrations fail with `Snapshot already complete`. Replies
`{ "id": 3, "ok": true, "inserted": n }`.

### Frame: `complete`

```json
{ "type": "complete", "id": 4, "server_id": "tranquility", "snapshot_hash": "sha256-hex", "entry_count": 8 }
```

Marks a snapshot complete. Verifies server-side that
`SUM(folded_blobs.entry_count)` over the snapshot's segment links equals
`entry_count` (error reply carrying the real sum otherwise); the SUM check
and the freeze are a single conditional `UPDATE`, and every link insert is
guarded by `completed_at IS NULL`, so a concurrent `register` frame can never
extend an already frozen link set. A retry of the same `complete` frame after
a lost reply succeeds. Replies `{ "id": 4, "ok": true }`.

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
when the snapshot is pending or unknown, or
`{ "ok": true, "complete": true, "entry_count": n, "completed_at": "..." }`.

## Deployment

Deployed via the Cloudflare Git integration; the build phase runs dependency
install plus `pnpm check` (`tsc --noEmit`), the deploy command is
`wrangler deploy`. Deploys also apply the Durable Object migration declared in
`wrangler.toml` (`new_sqlite_classes`), which provisions the `SYNC_SESSION`
class automatically.

One-time setup:

1. `wrangler d1 create efa-snapshot-registry` and paste the printed
   `database_id` into `wrangler.toml` (and into `efa-platform-fit-storage`'s
   `PLATFORM_DB` binding — readers and writer must move together).
2. `wrangler d1 migrations apply efa-snapshot-registry --remote`.
3. `wrangler secret put SYNC_TOKEN`; add the same value as the `D1_SYNC_TOKEN`
   secret of the `production-data` GitHub environment.
4. Resync every snapshot from source
   (`./x ci release-data d1-sync --hashes snapshot-hashes.json --schema-root cache/remote`);
   the store is fully derived from resource snapshots, so no data migration
   from the v1 database is needed.

## Sync driver

The Python side lives in `bootstrap/data/d1/`; run via
`./x ci release-data d1-sync --hashes snapshot-hashes.json --schema-root cache/remote`
(token from `[d1].token` in `efa.dev.toml` or `--dev-env d1.token=...`).
