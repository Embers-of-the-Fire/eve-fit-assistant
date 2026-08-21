// KV-backed fixed-window rate limiting. Counters are approximate (KV is
// eventually consistent and the read-modify-write is not atomic), which is
// acceptable for abuse throttling.

export interface RateLimitOutcome {
    allowed: boolean;
    retryAfterSec: number;
}

// Cloudflare KV expirationTtl has a 60 s floor.
const MIN_KV_TTL_SEC = 60;

export async function fixedWindowLimit(
    kv: KVNamespace,
    bucket: string,
    key: string,
    limit: number,
    windowSec: number,
    nowMs: number = Date.now(),
): Promise<RateLimitOutcome> {
    const nowSec = Math.floor(nowMs / 1000);
    const windowIndex = Math.floor(nowSec / windowSec);
    const kvKey = `rl:${bucket}:${key}:${windowIndex}`;
    const elapsedSec = nowSec - windowIndex * windowSec;
    const remainingSec = windowSec - elapsedSec;

    const raw = await kv.get(kvKey);
    const count = raw === null ? 0 : Number.parseInt(raw, 10);
    if (count >= limit) {
        return { allowed: false, retryAfterSec: remainingSec };
    }
    await kv.put(kvKey, String(count + 1), {
        expirationTtl: Math.max(MIN_KV_TTL_SEC, remainingSec),
    });
    return { allowed: true, retryAfterSec: 0 };
}
