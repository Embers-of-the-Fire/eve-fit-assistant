// Transactional core of the rate-limit Durable Object (rate-window.ts), kept
// free of worker-only imports so the unit tests can run it under Node's
// strip-types mode. Fixed-window counters are wall-clock-aligned (same
// semantics as the old KV backend), but the read-check-increment now happens
// inside one storage transaction, so concurrent requests for the same
// (bucket, key) cannot all pass a saturated limit.

export interface RateLimitOutcome {
    allowed: boolean;
    retryAfterSec: number;
}

interface RateWindow {
    windowIndex: number;
    count: number;
}

const WINDOW_KEY = "window";

// Minimal transactional-storage surface shared by DurableObjectStorage (used
// directly inside storage.transaction(); the callback txn object is obsolete
// in the SQLite storage API) and the in-memory test double.
export interface RateTxn {
    get<T>(key: string): Promise<T | undefined>;
    put(key: string, value: unknown): Promise<unknown>;
}

export async function rateWindowHit(
    tx: RateTxn,
    limit: number,
    windowSec: number,
    nowMs: number,
): Promise<RateLimitOutcome> {
    const nowSec = Math.floor(nowMs / 1000);
    const windowIndex = Math.floor(nowSec / windowSec);
    const elapsedSec = nowSec - windowIndex * windowSec;
    const remainingSec = windowSec - elapsedSec;

    const stored = await tx.get<RateWindow>(WINDOW_KEY);
    const count = stored?.windowIndex === windowIndex ? stored.count : 0;
    if (count >= limit) {
        return { allowed: false, retryAfterSec: remainingSec };
    }
    await tx.put(WINDOW_KEY, { windowIndex, count: count + 1 });
    return { allowed: true, retryAfterSec: 0 };
}

// Give back one previously counted hit, e.g. when an email send failed after
// the quota check and the attempt should not consume the user's allowance.
// Only meaningful inside the window the hit was counted in: a rolled-over or
// empty window is left untouched, and the count never drops below zero.
export async function rateWindowRefund(
    tx: RateTxn,
    windowSec: number,
    nowMs: number,
): Promise<void> {
    const nowSec = Math.floor(nowMs / 1000);
    const windowIndex = Math.floor(nowSec / windowSec);

    const stored = await tx.get<RateWindow>(WINDOW_KEY);
    if (stored?.windowIndex === windowIndex && stored.count > 0) {
        await tx.put(WINDOW_KEY, { windowIndex, count: stored.count - 1 });
    }
}
