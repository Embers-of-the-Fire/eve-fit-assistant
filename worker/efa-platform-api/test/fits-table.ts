import { env } from "cloudflare:workers";

// The fits table is owned by efa-platform-fit-storage (its migrations are not
// part of this worker's set), but 0007_post_snapshot_variant.sql backfills
// posts.snapshot_hash from it, so the table must exist before that migration
// applies. This only guarantees the post-0002 variant schema; seeding rows
// stays with each test file.
export const FITS_TABLE_DDL =
    "CREATE TABLE IF NOT EXISTS fits (" +
    "fit_hash TEXT NOT NULL, server_id TEXT NOT NULL, snapshot_hash TEXT NOT NULL, " +
    "requested_snapshot_hash TEXT, fit_state BLOB NOT NULL, snapshot BLOB NOT NULL, " +
    "created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')), " +
    "PRIMARY KEY (fit_hash, snapshot_hash))";

export async function ensureFitsTable(): Promise<void> {
    await env.FIT_DB.exec(FITS_TABLE_DDL);
}
