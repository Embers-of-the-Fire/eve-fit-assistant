// Rate-limit Durable Object: one instance per (bucket, key), resolved by
// idFromName in ratelimit.ts. Per-instance serialization plus a single storage
// transaction per hit make the counter read-check-increment atomic — the
// property KV's non-atomic read-modify-write could not provide.
//
// SQLite-backed (new_sqlite_classes migration in wrangler.toml); an idle
// instance hibernates and incurs no duration charges. Each hit re-arms an
// alarm at the window boundary; the alarm handler sweeps the stale row and
// wipes the now-empty instance, so one-shot bucket/key pairs (every seen IP
// and login account) do not accumulate rows forever.
//
// This class is imported only by the worker entrypoint (index.ts); the
// transactional logic lives in rate-core.ts so tests can exercise it without
// the cloudflare:workers runtime module.

import { DurableObject } from "cloudflare:workers";
import {
    type RateLimitOutcome,
    rateWindowBoundaryMs,
    rateWindowHit,
    rateWindowRefund,
    rateWindowSweep,
} from "./rate-core.ts";

export class RateLimitWindow extends DurableObject {
    async hit(limit: number, windowSec: number, nowMs: number): Promise<RateLimitOutcome> {
        // The callback txn object is obsolete in the SQLite storage API; call
        // get/put on ctx.storage directly — transaction() still provides the
        // atomicity.
        const outcome = await this.ctx.storage.transaction(() =>
            rateWindowHit(this.ctx.storage, limit, windowSec, nowMs),
        );
        // Re-arm the cleanup alarm at the window boundary. setAlarm replaces
        // any pending alarm, so a hit in a later window simply moves it.
        await this.ctx.storage.setAlarm(rateWindowBoundaryMs(windowSec, nowMs));
        return outcome;
    }

    refund(windowSec: number, nowMs: number): Promise<void> {
        return this.ctx.storage.transaction(() =>
            rateWindowRefund(this.ctx.storage, windowSec, nowMs),
        );
    }

    async alarm(): Promise<void> {
        const rearmAtMs = await this.ctx.storage.transaction(() =>
            rateWindowSweep(this.ctx.storage, Date.now()),
        );
        if (rearmAtMs !== null) {
            // The stored window is still current (a hit re-armed after this
            // alarm was scheduled); wait for its boundary instead.
            await this.ctx.storage.setAlarm(rearmAtMs);
            return;
        }
        // The window row is the only state an instance holds; if nothing else
        // remains, wipe the instance outright (deleteAll also clears alarms).
        const remaining = await this.ctx.storage.list({ limit: 1 });
        if (remaining.size === 0) {
            await this.ctx.storage.deleteAll();
        }
    }
}
