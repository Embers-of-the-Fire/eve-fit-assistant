-- Registration counter for O(1) snapshot completion.
--
-- 0001's `complete` frame verified the registration set with
-- `(SELECT COUNT(*) FROM snapshot_entries WHERE snapshot_id = ?)` inside the
-- freezing UPDATE — an ~145k-row index-range scan per snapshot (run twice on
-- a count-mismatch retry). registered_count is maintained incrementally: each
-- register frame adds its actually-inserted row count (INSERT OR IGNORE
-- conflicts contribute 0, so idempotent re-sends never inflate it), and
-- `complete` compares the counter in its atomic conditional UPDATE instead.
--
-- The counter update is a separate transaction from the frame's inserts, so
-- a worker crash between them can leave the counter short; a pre-migration
-- pending snapshot (interrupted 0001-era sync) likewise starts at 0 with
-- partial rows. Both are self-healing: when the fast-path counter check
-- fails, `complete` falls back to one real COUNT(*), repairs the counter,
-- and retries the freeze. Completed snapshots never need a value — frozen
-- rows are never re-verified.

ALTER TABLE snapshots ADD COLUMN registered_count INTEGER NOT NULL DEFAULT 0;
