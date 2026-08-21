// Fixed-window rate limiting backed by the RateLimitWindow Durable Object
// (one instance per bucket+key), whose per-instance serialization makes the
// counter read-check-increment atomic; see rate-window.ts / rate-core.ts.

import type { RateLimitOutcome } from "./rate-core.ts";
import type { RateLimitWindow } from "./rate-window.ts";

export type { RateLimitOutcome };

export async function fixedWindowLimit(
    ns: DurableObjectNamespace<RateLimitWindow>,
    bucket: string,
    key: string,
    limit: number,
    windowSec: number,
    nowMs: number = Date.now(),
): Promise<RateLimitOutcome> {
    return ns.get(ns.idFromName(`rl:${bucket}:${key}`)).hit(limit, windowSec, nowMs);
}

// Decrement the counter by one, refunding a hit whose guarded action failed
// (see rate-core.ts). Only used where the quota must count successful
// actions, not attempts.
export async function fixedWindowRefund(
    ns: DurableObjectNamespace<RateLimitWindow>,
    bucket: string,
    key: string,
    windowSec: number,
    nowMs: number = Date.now(),
): Promise<void> {
    return ns.get(ns.idFromName(`rl:${bucket}:${key}`)).refund(windowSec, nowMs);
}
