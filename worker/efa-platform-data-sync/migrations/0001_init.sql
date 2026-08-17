-- Platform data store: per-entry, content-addressed engine data rows.
-- Each family <f> has a content table and a registration table mapping
-- (server_id, snapshot_hash, entry_id) -> content_hash.

-- Snapshot completeness registry. Content and registration uploads span many
-- requests (one transaction each), so a failed run leaves partial <f>_reg rows
-- behind. The uploader inserts a row here only after every content and
-- registration batch for the snapshot succeeded; readers MUST treat any
-- (server_id, snapshot_hash) with no row here as incomplete and reject it.
CREATE TABLE snapshots (
    server_id TEXT NOT NULL,
    snapshot_hash TEXT NOT NULL,
    entry_count INTEGER NOT NULL,
    completed_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    PRIMARY KEY (server_id, snapshot_hash)
);

CREATE TABLE types (
    content_hash TEXT PRIMARY KEY,
    content BLOB NOT NULL
);
CREATE TABLE types_reg (
    server_id TEXT NOT NULL,
    snapshot_hash TEXT NOT NULL,
    entry_id INTEGER NOT NULL,
    content_hash TEXT NOT NULL REFERENCES types (content_hash),
    PRIMARY KEY (server_id, snapshot_hash, entry_id)
);
-- Reverse lookup for reference counting / orphan cleanup / FK checks on DELETE.
CREATE INDEX types_reg_content_hash ON types_reg (content_hash);

CREATE TABLE type_dogma (
    content_hash TEXT PRIMARY KEY,
    content BLOB NOT NULL
);
CREATE TABLE type_dogma_reg (
    server_id TEXT NOT NULL,
    snapshot_hash TEXT NOT NULL,
    entry_id INTEGER NOT NULL,
    content_hash TEXT NOT NULL REFERENCES type_dogma (content_hash),
    PRIMARY KEY (server_id, snapshot_hash, entry_id)
);
CREATE INDEX type_dogma_reg_content_hash ON type_dogma_reg (content_hash);

CREATE TABLE dogma_attributes (
    content_hash TEXT PRIMARY KEY,
    content BLOB NOT NULL
);
CREATE TABLE dogma_attributes_reg (
    server_id TEXT NOT NULL,
    snapshot_hash TEXT NOT NULL,
    entry_id INTEGER NOT NULL,
    content_hash TEXT NOT NULL REFERENCES dogma_attributes (content_hash),
    PRIMARY KEY (server_id, snapshot_hash, entry_id)
);
CREATE INDEX dogma_attributes_reg_content_hash ON dogma_attributes_reg (content_hash);

CREATE TABLE dogma_effects (
    content_hash TEXT PRIMARY KEY,
    content BLOB NOT NULL
);
CREATE TABLE dogma_effects_reg (
    server_id TEXT NOT NULL,
    snapshot_hash TEXT NOT NULL,
    entry_id INTEGER NOT NULL,
    content_hash TEXT NOT NULL REFERENCES dogma_effects (content_hash),
    PRIMARY KEY (server_id, snapshot_hash, entry_id)
);
CREATE INDEX dogma_effects_reg_content_hash ON dogma_effects_reg (content_hash);

CREATE TABLE buffs (
    content_hash TEXT PRIMARY KEY,
    content BLOB NOT NULL
);
CREATE TABLE buffs_reg (
    server_id TEXT NOT NULL,
    snapshot_hash TEXT NOT NULL,
    entry_id INTEGER NOT NULL,
    content_hash TEXT NOT NULL REFERENCES buffs (content_hash),
    PRIMARY KEY (server_id, snapshot_hash, entry_id)
);
CREATE INDEX buffs_reg_content_hash ON buffs_reg (content_hash);

CREATE TABLE type_meta (
    content_hash TEXT PRIMARY KEY,
    content BLOB NOT NULL
);
CREATE TABLE type_meta_reg (
    server_id TEXT NOT NULL,
    snapshot_hash TEXT NOT NULL,
    entry_id INTEGER NOT NULL,
    content_hash TEXT NOT NULL REFERENCES type_meta (content_hash),
    PRIMARY KEY (server_id, snapshot_hash, entry_id)
);
CREATE INDEX type_meta_reg_content_hash ON type_meta_reg (content_hash);

CREATE TABLE dogma_attribute_meta (
    content_hash TEXT PRIMARY KEY,
    content BLOB NOT NULL
);
CREATE TABLE dogma_attribute_meta_reg (
    server_id TEXT NOT NULL,
    snapshot_hash TEXT NOT NULL,
    entry_id INTEGER NOT NULL,
    content_hash TEXT NOT NULL REFERENCES dogma_attribute_meta (content_hash),
    PRIMARY KEY (server_id, snapshot_hash, entry_id)
);
CREATE INDEX dogma_attribute_meta_reg_content_hash ON dogma_attribute_meta_reg (content_hash);

CREATE TABLE dogma_effect_meta (
    content_hash TEXT PRIMARY KEY,
    content BLOB NOT NULL
);
CREATE TABLE dogma_effect_meta_reg (
    server_id TEXT NOT NULL,
    snapshot_hash TEXT NOT NULL,
    entry_id INTEGER NOT NULL,
    content_hash TEXT NOT NULL REFERENCES dogma_effect_meta (content_hash),
    PRIMARY KEY (server_id, snapshot_hash, entry_id)
);
CREATE INDEX dogma_effect_meta_reg_content_hash ON dogma_effect_meta_reg (content_hash);
