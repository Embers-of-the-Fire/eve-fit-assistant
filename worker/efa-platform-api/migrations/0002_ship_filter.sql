-- Ship-filtered listing (the `shipTypeId` filter on the post list) and the
-- per-ship aggregation behind the stats endpoint. Filenames must never collide
-- with efa-platform-fit-storage's migrations.

CREATE INDEX posts_ship_created ON posts (ship_type_id, created_at DESC, post_id DESC);
