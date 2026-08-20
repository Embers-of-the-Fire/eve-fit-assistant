-- Ship-filtered listing (§6.3 `shipTypeId`) and the per-ship aggregation behind
-- the stats endpoint (§6.5). Filenames must never collide with
-- efa-platform-fit-storage's migrations.

CREATE INDEX posts_ship_created ON posts (ship_type_id, created_at DESC, post_id DESC);
