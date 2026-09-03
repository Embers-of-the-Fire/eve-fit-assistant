-- Storage v3: folded per-family segments (additive).
--
-- Replaces the v2 per-entry content store (`entries` + `snapshot_entries`)
-- with folded per-family binary streams segmented into self-contained,
-- content-addressed <=512 KiB blobs. Motivation (benchmark-measured on the
-- real 2-snapshot dataset, ~300k entries / 31.3 MiB payload): the v2 layout
-- costs ~800k billable row-writes (index writes count) and ~830 WebSocket
-- frames per 2-snapshot sync; the folded layout needs ~300 writes and ~104
-- frames. Whole-family reads drop from a ~54k-row join to ~40 segment rows.
--
-- Segment size is bounded at 512 KiB because D1 caps a BLOB/row at 2 MB
-- (a mono-blob per family is impossible: type_dogma is ~10.4 MiB) and the
-- base64'd frame stays well under the 1 MiB WebSocket message limit.
-- Segments are deduplicated content-addressed per (family, content_hash);
-- cross-snapshot segment-level dedup is marginal (~1.3%) because
-- inter-snapshot churn is dense, so segmentation is a deterministic greedy
-- pack at entry boundaries, not CDC.
--
-- THIS MIGRATION IS ADDITIVE ONLY. It deliberately does NOT drop the v2
-- tables: `entries` and `snapshot_entries` stay in place for the rollback
-- window while the sync worker serves both the v2 and v3 frame protocols and
-- readers dual-read (v3 catalog probe first, v2 join fallback). The drops
-- happen in migration 0004, after cutover is complete and burned in.

-- The ONLY content store of v3. Each row is one self-contained segment of a
-- family's folded stream (entries sorted by entry id):
--   u32 count
--   count x { i32 entry_id, u32 offset, u32 length }  -- offset from segment start
--   payload bytes (concatenated per-entry protobufs, byte-identical to the
--   v2 entries.content payloads)
-- family codes are unchanged: types=0, type_dogma=1, dogma_attributes=2,
-- dogma_effects=3, buffs=4, type_meta=5, dogma_attribute_meta=6,
-- dogma_effect_meta=7. first_entry_id/last_entry_id bound the segment's id
-- range for subset routing; blob_id is database-local and must never leak
-- outside the sync protocol.
CREATE TABLE folded_blobs (
    blob_id INTEGER PRIMARY KEY,
    family INTEGER NOT NULL,
    content_hash BLOB NOT NULL,                -- raw 32-byte SHA-256 of the segment bytes
    entry_count INTEGER NOT NULL,
    first_entry_id INTEGER NOT NULL,           -- subset routing
    last_entry_id INTEGER NOT NULL,
    content BLOB NOT NULL,
    UNIQUE (family, content_hash)
);

-- Per-snapshot links onto segments; no content. (snapshot_id, family, seq)
-- orders a snapshot's segments within one family. Completion is verified by
-- SUM(folded_blobs.entry_count) over this join, replacing v2's
-- registered_count counter and its crash-repair path (v3 register frames do
-- not maintain registered_count).
CREATE TABLE snapshot_family_segments (
    snapshot_id INTEGER NOT NULL REFERENCES snapshots (snapshot_id),
    family INTEGER NOT NULL,
    seq INTEGER NOT NULL,
    blob_id INTEGER NOT NULL REFERENCES folded_blobs (blob_id),
    PRIMARY KEY (snapshot_id, family, seq)
);
