-- Platform data store v2: per-entry, content-addressed engine data rows.
--
-- Two design changes over v1 (which stored every hash as 64-char hex TEXT and
-- repeated the full snapshot hash in each of ~145k registration rows per
-- snapshot, costing ~50 MiB/snapshot):
--   1. All hashes are raw 32-byte BLOBs.
--   2. Registration rows reference dense integer ids (snapshot_id, content_id)
--      instead of hashes, ~25 B/row including the primary-key index.
--
-- The v1 tables were abandoned with the legacy database; this file is the
-- initial migration of the v2 database (efa-snapshot-registry).

-- Snapshot registry, doubling as the pending/completion marker: a row is
-- created by the first `register` frame for (server_id, snapshot_hash) and
-- `completed_at` stays NULL until the uploader's `complete` frame verifies
-- the registration row count and freezes the snapshot. Readers MUST treat a
-- snapshot with completed_at IS NULL as incomplete and reject it.
CREATE TABLE snapshots (
    snapshot_id INTEGER PRIMARY KEY,
    server_id TEXT NOT NULL,
    snapshot_hash BLOB NOT NULL,               -- raw 32-byte SHA-256
    entry_count INTEGER,                       -- set at completion
    completed_at TEXT,                         -- NULL = incomplete
    UNIQUE (server_id, snapshot_hash)
);

-- Content-addressed single-entry protobuf payloads for every family
-- (efos.* entry messages for the engine families, platform_data.* messages
-- for metadata). family codes: types=0, type_dogma=1, dogma_attributes=2,
-- dogma_effects=3, buffs=4, type_meta=5, dogma_attribute_meta=6,
-- dogma_effect_meta=7. content_id is database-local and must never leak
-- outside the sync protocol.
CREATE TABLE entries (
    content_id INTEGER PRIMARY KEY,
    family INTEGER NOT NULL,
    content_hash BLOB NOT NULL,                -- raw 32-byte SHA-256
    content BLOB NOT NULL,
    UNIQUE (family, content_hash)
);

-- Registration rows mapping a snapshot's entries onto content rows.
CREATE TABLE snapshot_entries (
    snapshot_id INTEGER NOT NULL REFERENCES snapshots (snapshot_id),
    family INTEGER NOT NULL,
    entry_id INTEGER NOT NULL,
    content_id INTEGER NOT NULL REFERENCES entries (content_id),
    PRIMARY KEY (snapshot_id, family, entry_id)
);
