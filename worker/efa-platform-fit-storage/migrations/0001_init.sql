-- Remote fit storage: fits keyed by canonical fit-state hash, plus a
-- per-submission request log pointing at the fit hash.
-- See docs/temp/remote-fit/spec.md §8.

CREATE TABLE fits (
    fit_hash TEXT PRIMARY KEY,             -- canonical fit hash
    server_id TEXT NOT NULL,               -- snapshot used for computation
    snapshot_hash TEXT NOT NULL,
    fit_state BLOB NOT NULL,               -- canonical FitState protobuf bytes
    snapshot BLOB NOT NULL,                -- full FitSnapshot protobuf bytes
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE TABLE requests (
    request_id TEXT PRIMARY KEY,           -- UUID v4
    fit_hash TEXT NOT NULL REFERENCES fits (fit_hash),
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);
CREATE INDEX requests_fit_hash ON requests (fit_hash);
