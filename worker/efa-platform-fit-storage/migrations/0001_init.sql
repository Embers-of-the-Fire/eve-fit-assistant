-- Pure content-addressed fit store: fits keyed by canonical fit-state hash.
-- The legacy `requests` submission log is abolished; post identity lives in
-- the `posts` table owned by `efa-platform-api` (see its own migrations).
-- See docs/temp/api-unit/spec.md §4.1.

CREATE TABLE fits (
    fit_hash TEXT PRIMARY KEY,             -- canonical fit hash
    server_id TEXT NOT NULL,               -- snapshot used for computation
    snapshot_hash TEXT NOT NULL,
    fit_state BLOB NOT NULL,               -- canonical FitState protobuf bytes
    snapshot BLOB NOT NULL,                -- full FitSnapshot protobuf bytes
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);
