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
