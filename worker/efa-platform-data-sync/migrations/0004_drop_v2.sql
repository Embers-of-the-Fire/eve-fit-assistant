-- Storage v2 teardown (the drops deferred from 0003_folded.sql).
--
-- D1 enforces foreign-key constraints on every query and migration
-- (equivalent to PRAGMA foreign_keys = on), so child tables drop first.
DROP TABLE snapshot_entries; -- references entries + snapshots
DROP TABLE entries;
ALTER TABLE snapshots DROP COLUMN registered_count;
