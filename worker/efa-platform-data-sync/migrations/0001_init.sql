-- Platform data store: per-entry, content-addressed engine data rows.
-- Each family <f> has a content table and a registration table mapping
-- (server_id, snapshot_hash, entry_id) -> content_hash.

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
