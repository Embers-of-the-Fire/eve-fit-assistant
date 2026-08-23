// Rate-limit tests against the real RateLimitWindow Durable Object (via the
// AUTH_RATE_LIMIT namespace binding). Window rollover cases pass explicit
// nowMs values, which ratelimit.ts already accepts, instead of shifting a
// fake clock inside a double.

import { reset } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { beforeEach, describe, expect, it } from "vitest";
import { rateWindowHit, rateWindowSweep } from "../../src/auth/rate-core.ts";
import { fixedWindowLimit, fixedWindowRefund } from "../../src/auth/ratelimit.ts";

const NS = env.AUTH_RATE_LIMIT;

// Rate-limit state persists per test file; wipe the Durable Object instances
// so each test starts from a clean namespace.
beforeEach(async () => {
    await reset();
});

describe("fixedWindowLimit", () => {
    it("allows up to the limit, then denies with a Retry-After", async () => {
        for (let i = 0; i < 3; i++) {
            const outcome = await fixedWindowLimit(NS, "bucket", "key", 3, 3600);
            expect(outcome.allowed).toBe(true);
        }
        const denied = await fixedWindowLimit(NS, "bucket", "key", 3, 3600);
        expect(denied.allowed).toBe(false);
        expect(denied.retryAfterSec).toBeGreaterThan(0);
        expect(denied.retryAfterSec).toBeLessThanOrEqual(3600);
    });

    it("tracks keys and buckets independently", async () => {
        await fixedWindowLimit(NS, "bucket", "a", 1, 3600);
        expect((await fixedWindowLimit(NS, "bucket", "a", 1, 3600)).allowed).toBe(false);
        expect((await fixedWindowLimit(NS, "bucket", "b", 1, 3600)).allowed).toBe(true);
        expect((await fixedWindowLimit(NS, "other", "a", 1, 3600)).allowed).toBe(true);
    });

    it("resets when the window rolls over", async () => {
        // Aligned to a 300 s window boundary so +301 s crosses into the next window.
        const startMs = 1_200_000;
        await fixedWindowLimit(NS, "bucket", "key", 1, 300, startMs);
        expect((await fixedWindowLimit(NS, "bucket", "key", 1, 300, startMs)).allowed).toBe(false);
        const afterMs = startMs + 301 * 1000;
        expect((await fixedWindowLimit(NS, "bucket", "key", 1, 300, afterMs)).allowed).toBe(true);
    });

    it("handles short windows", async () => {
        const outcome = await fixedWindowLimit(NS, "bucket", "key", 5, 30);
        expect(outcome.allowed).toBe(true);
    });

    it("admits exactly the limit under concurrent bursts", async () => {
        const outcomes = await Promise.all(
            Array.from({ length: 10 }, () => fixedWindowLimit(NS, "bucket", "key", 3, 3600)),
        );
        expect(outcomes.filter((o) => o.allowed).length).toBe(3);
        expect(outcomes.filter((o) => !o.allowed).length).toBe(7);
    });
});

describe("fixedWindowRefund", () => {
    it("frees a slot so a previously denied hit passes again", async () => {
        expect((await fixedWindowLimit(NS, "bucket", "key", 1, 3600)).allowed).toBe(true);
        expect((await fixedWindowLimit(NS, "bucket", "key", 1, 3600)).allowed).toBe(false);
        await fixedWindowRefund(NS, "bucket", "key", 3600);
        expect((await fixedWindowLimit(NS, "bucket", "key", 1, 3600)).allowed).toBe(true);
        expect((await fixedWindowLimit(NS, "bucket", "key", 1, 3600)).allowed).toBe(false);
    });

    it("never drives the count below zero", async () => {
        await fixedWindowRefund(NS, "bucket", "key", 3600);
        await fixedWindowRefund(NS, "bucket", "key", 3600);
        expect((await fixedWindowLimit(NS, "bucket", "key", 1, 3600)).allowed).toBe(true);
        expect((await fixedWindowLimit(NS, "bucket", "key", 1, 3600)).allowed).toBe(false);
    });

    it("does not touch a window that has rolled over", async () => {
        // Aligned to a 300 s window boundary so +301 s crosses into the next window.
        const startMs = 1_200_000;
        await fixedWindowLimit(NS, "bucket", "key", 1, 300, startMs);
        const afterMs = startMs + 301 * 1000;
        // The new window starts empty; refunding must not drive it negative.
        await fixedWindowRefund(NS, "bucket", "key", 300, afterMs);
        expect((await fixedWindowLimit(NS, "bucket", "key", 1, 300, afterMs)).allowed).toBe(true);
        expect((await fixedWindowLimit(NS, "bucket", "key", 1, 300, afterMs)).allowed).toBe(false);
    });
});

describe("rateWindowSweep", () => {
    // Minimal sweep-capable txn over a plain map: rateWindowSweep is a pure
    // function of the storage interface, so no Durable Object is needed here.
    function makeTxn() {
        const map = new Map<string, unknown>();
        return {
            map,
            get: <T>(key: string): Promise<T | undefined> =>
                Promise.resolve(map.get(key) as T | undefined),
            put: (key: string, value: unknown): Promise<void> => {
                map.set(key, value);
                return Promise.resolve();
            },
            delete: (key: string): Promise<boolean> => Promise.resolve(map.delete(key)),
        };
    }

    it("deletes the row once its window boundary passes", async () => {
        const tx = makeTxn();
        // Aligned to a 300 s window boundary; the window ends at 1_500_000 ms.
        const startMs = 1_200_000;
        await rateWindowHit(tx, 1, 300, startMs);
        expect(await rateWindowSweep(tx, startMs + 300 * 1000)).toBe(null);
        expect(tx.map.size).toBe(0);
    });

    it("keeps a current row and reports its boundary for re-arming", async () => {
        const tx = makeTxn();
        const startMs = 1_200_000;
        await rateWindowHit(tx, 1, 300, startMs);
        expect(await rateWindowSweep(tx, startMs + 1000)).toBe(1_500_000);
        expect(tx.map.size).toBe(1);
    });

    it("treats a missing row as already cleared", async () => {
        const tx = makeTxn();
        expect(await rateWindowSweep(tx, Date.now())).toBe(null);
    });

    it("sweeps legacy rows without a recorded boundary", async () => {
        const tx = makeTxn();
        tx.map.set("window", { windowIndex: 1, count: 1 });
        expect(await rateWindowSweep(tx, Date.now())).toBe(null);
        expect(tx.map.size).toBe(0);
    });
});
