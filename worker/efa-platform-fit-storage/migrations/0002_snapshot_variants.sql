-- Snapshot-aware fit variants: the same canonical fit may be computed under
-- different engine data snapshots — a consented fallback to the server's
-- latest snapshot, or a re-upload after the originally requested snapshot was
-- ingested. The storage key becomes (fit_hash, snapshot_hash) so a re-upload
-- under a refreshed snapshot recomputes instead of short-circuiting on
-- another snapshot's entry.
--
-- `requested_snapshot_hash` records fallback provenance: NULL when the fit
-- was computed with the snapshot the uploader requested, otherwise the
-- originally requested (unregistered) snapshot hash.

CREATE TABLE fits_new (
    fit_hash TEXT NOT NULL,                -- canonical fit hash
    server_id TEXT NOT NULL,               -- server of the computation snapshot
    snapshot_hash TEXT NOT NULL,           -- snapshot actually used for computation
    requested_snapshot_hash TEXT,          -- non-NULL iff a consented fallback was used
    fit_state BLOB NOT NULL,               -- canonical FitState protobuf bytes
    snapshot BLOB NOT NULL,                -- full FitSnapshot protobuf bytes
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    PRIMARY KEY (fit_hash, snapshot_hash)
);

INSERT INTO fits_new (fit_hash, server_id, snapshot_hash, requested_snapshot_hash, fit_state, snapshot, created_at)
    SELECT fit_hash, server_id, snapshot_hash, NULL, fit_state, snapshot, created_at FROM fits;

DROP TABLE fits;

ALTER TABLE fits_new RENAME TO fits;
