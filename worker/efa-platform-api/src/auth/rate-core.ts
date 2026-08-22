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
    // Wall-clock end of the window; lets the alarm handler decide expiry
    // without knowing windowSec. Rows written before this field existed
    // (windowEndMs undefined) always compare as expired and are swept.
    windowEndMs?: number;
}

const WINDOW_KEY = "window";

// Minimal transactional-storage surface shared by DurableObjectStorage (used
// directly inside storage.transaction(); the callback txn object is obsolete
// in the SQLite storage API) and the in-memory test double.
export interface RateTxn {
    get<T>(key: string): Promise<T | undefined>;
    put(key: string, value: unknown): Promise<unknown>;
}

// Sweep surface for the alarm handler: RateTxn plus row deletion.
export interface RateSweepTxn extends RateTxn {
    delete(key: string): Promise<unknown>;
}

// Wall-clock boundary (ms) of the window containing nowMs — the moment the
// stored row becomes stale and the cleanup alarm should fire.
export function rateWindowBoundaryMs(windowSec: number, nowMs: number): number {
    const windowIndex = Math.floor(Math.floor(nowMs / 1000) / windowSec);
    return (windowIndex + 1) * windowSec * 1000;
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
    const windowEndMs = (windowIndex + 1) * windowSec * 1000;

    const stored = await tx.get<RateWindow>(WINDOW_KEY);
    const count = stored?.windowIndex === windowIndex ? stored.count : 0;
    if (count >= limit) {
        return { allowed: false, retryAfterSec: remainingSec };
    }
    await tx.put(WINDOW_KEY, { windowIndex, count: count + 1, windowEndMs });
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
        await tx.put(WINDOW_KEY, { ...stored, count: stored.count - 1 });
    }
}

// Alarm cleanup for the Durable Object. Deletes the window row only if its
// window has actually passed (a hit in a later window re-arms the alarm, so
// the row can still be current when an older alarm fires). Returns the
// boundary to re-arm the alarm at when the row is still current, or null
// when the row was deleted (or absent) and the instance can be torn down.
export async function rateWindowSweep(tx: RateSweepTxn, nowMs: number): Promise<number | null> {
    const stored = await tx.get<RateWindow>(WINDOW_KEY);
    if (stored === undefined) {
        return null;
    }
    if (stored.windowEndMs !== undefined && nowMs < stored.windowEndMs) {
        return stored.windowEndMs;
    }
    await tx.delete(WINDOW_KEY);
    return null;
}
