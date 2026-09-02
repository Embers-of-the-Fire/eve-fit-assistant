import { applyD1Migrations } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { ensureFitsTable } from "./fits-table.ts";

// Setup files run outside the per-test-file storage isolation, and may be run
// multiple times. `applyD1Migrations()` only applies migrations that haven't
// already been applied, therefore it is safe to call this function here. The
// fits table (owned by efa-platform-fit-storage) must exist first: the 0007
// migration backfills posts.snapshot_hash from it.
await ensureFitsTable();
await applyD1Migrations(env.FIT_DB, env.TEST_MIGRATIONS);
