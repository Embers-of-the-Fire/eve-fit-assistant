-- Bind each post to the exact fit variant computed at creation. Fits gained
-- per-snapshot variants in efa-platform-fit-storage's
-- 0002_snapshot_variants.sql (PRIMARY KEY (fit_hash, snapshot_hash)); without
-- this column the post→fit join on fit_hash alone could fan out or drift to a
-- newer variant, breaking the immutability of post content.
--
-- NULL rows (legacy posts whose fit row is gone, or mid-deploy rows) fall
-- back to the newest variant at read time.
--
-- Migration filenames must never collide with the other workers sharing this
-- database (`0001_init.sql`, `0002_snapshot_variants.sql` in
-- efa-platform-fit-storage) — wrangler records applied filenames per database.

ALTER TABLE posts ADD COLUMN snapshot_hash TEXT;

-- Backfill from the fits table: pre-variant fits are 1:1 with fit_hash, so
-- this resolves to the single computation snapshot of each post's fit.
UPDATE posts SET snapshot_hash = (
    SELECT f.snapshot_hash FROM fits f
    WHERE f.fit_hash = posts.fit_hash
    ORDER BY f.created_at DESC, f.rowid DESC
    LIMIT 1
);
