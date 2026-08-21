// Rate-limit Durable Object: one instance per (bucket, key), resolved by
// idFromName in ratelimit.ts. Per-instance serialization plus a single storage
// transaction per hit make the counter read-check-increment atomic — the
// property KV's non-atomic read-modify-write could not provide.
//
// SQLite-backed (new_sqlite_classes migration in wrangler.toml); an idle
// instance hibernates and incurs no duration charges. Stale windows are
// overwritten by the next hit, so no TTL or alarm cleanup is needed.
//
// This class is imported only by the worker entrypoint (index.ts); the
// transactional logic lives in rate-core.ts so tests can exercise it without
// the cloudflare:workers runtime module.

import { DurableObject } from "cloudflare:workers";
import { type RateLimitOutcome, rateWindowHit, rateWindowRefund } from "./rate-core.ts";

export class RateLimitWindow extends DurableObject {
    hit(limit: number, windowSec: number, nowMs: number): Promise<RateLimitOutcome> {
        // The callback txn object is obsolete in the SQLite storage API; call
        // get/put on ctx.storage directly — transaction() still provides the
        // atomicity.
        return this.ctx.storage.transaction(() =>
            rateWindowHit(this.ctx.storage, limit, windowSec, nowMs),
        );
    }

    refund(windowSec: number, nowMs: number): Promise<void> {
        return this.ctx.storage.transaction(() =>
            rateWindowRefund(this.ctx.storage, windowSec, nowMs),
        );
    }
}
