import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { rateWindowHit, rateWindowSweep } from "../../src/auth/rate-core.ts";
import { fixedWindowLimit, fixedWindowRefund } from "../../src/auth/ratelimit.ts";
import { TestRateLimitNamespace } from "./helpers.ts";

describe("fixedWindowLimit", () => {
    it("allows up to the limit, then denies with a Retry-After", async () => {
        const ns = new TestRateLimitNamespace();
        for (let i = 0; i < 3; i++) {
            const outcome = await fixedWindowLimit(ns as never, "bucket", "key", 3, 3600);
            assert.equal(outcome.allowed, true);
        }
        const denied = await fixedWindowLimit(ns as never, "bucket", "key", 3, 3600);
        assert.equal(denied.allowed, false);
        assert.ok(denied.retryAfterSec > 0 && denied.retryAfterSec <= 3600);
    });

    it("tracks keys and buckets independently", async () => {
        const ns = new TestRateLimitNamespace();
        await fixedWindowLimit(ns as never, "bucket", "a", 1, 3600);
        assert.equal((await fixedWindowLimit(ns as never, "bucket", "a", 1, 3600)).allowed, false);
        assert.equal((await fixedWindowLimit(ns as never, "bucket", "b", 1, 3600)).allowed, true);
        assert.equal((await fixedWindowLimit(ns as never, "other", "a", 1, 3600)).allowed, true);
    });

    it("resets when the window rolls over", async () => {
        const ns = new TestRateLimitNamespace();
        // Aligned to a 300 s window boundary so +301 s crosses into the next window.
        const startMs = 1_200_000;
        await fixedWindowLimit(ns as never, "bucket", "key", 1, 300, startMs);
        assert.equal(
            (await fixedWindowLimit(ns as never, "bucket", "key", 1, 300, startMs)).allowed,
            false,
        );
        const afterMs = startMs + 301 * 1000;
        assert.equal(
            (await fixedWindowLimit(ns as never, "bucket", "key", 1, 300, afterMs)).allowed,
            true,
        );
    });

    it("handles short windows", async () => {
        const ns = new TestRateLimitNamespace();
        const outcome = await fixedWindowLimit(ns as never, "bucket", "key", 5, 30);
        assert.equal(outcome.allowed, true);
    });

    it("admits exactly the limit under concurrent bursts", async () => {
        const ns = new TestRateLimitNamespace();
        const outcomes = await Promise.all(
            Array.from({ length: 10 }, () =>
                fixedWindowLimit(ns as never, "bucket", "key", 3, 3600),
            ),
        );
        assert.equal(outcomes.filter((o) => o.allowed).length, 3);
        assert.equal(outcomes.filter((o) => !o.allowed).length, 7);
    });
});

describe("fixedWindowRefund", () => {
    it("frees a slot so a previously denied hit passes again", async () => {
        const ns = new TestRateLimitNamespace();
        assert.equal((await fixedWindowLimit(ns as never, "bucket", "key", 1, 3600)).allowed, true);
        assert.equal(
            (await fixedWindowLimit(ns as never, "bucket", "key", 1, 3600)).allowed,
            false,
        );
        await fixedWindowRefund(ns as never, "bucket", "key", 3600);
        assert.equal((await fixedWindowLimit(ns as never, "bucket", "key", 1, 3600)).allowed, true);
        assert.equal(
            (await fixedWindowLimit(ns as never, "bucket", "key", 1, 3600)).allowed,
            false,
        );
    });

    it("never drives the count below zero", async () => {
        const ns = new TestRateLimitNamespace();
        await fixedWindowRefund(ns as never, "bucket", "key", 3600);
        await fixedWindowRefund(ns as never, "bucket", "key", 3600);
        assert.equal((await fixedWindowLimit(ns as never, "bucket", "key", 1, 3600)).allowed, true);
        assert.equal(
            (await fixedWindowLimit(ns as never, "bucket", "key", 1, 3600)).allowed,
            false,
        );
    });

    it("does not touch a window that has rolled over", async () => {
        const ns = new TestRateLimitNamespace();
        // Aligned to a 300 s window boundary so +301 s crosses into the next window.
        const startMs = 1_200_000;
        await fixedWindowLimit(ns as never, "bucket", "key", 1, 300, startMs);
        const afterMs = startMs + 301 * 1000;
        // The new window starts empty; refunding must not drive it negative.
        await fixedWindowRefund(ns as never, "bucket", "key", 300, afterMs);
        assert.equal(
            (await fixedWindowLimit(ns as never, "bucket", "key", 1, 300, afterMs)).allowed,
            true,
        );
        assert.equal(
            (await fixedWindowLimit(ns as never, "bucket", "key", 1, 300, afterMs)).allowed,
            false,
        );
    });
});

describe("rateWindowSweep", () => {
    // Minimal sweep-capable txn over a plain map (mirrors TestDurableStorage).
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
        assert.equal(await rateWindowSweep(tx, startMs + 300 * 1000), null);
        assert.equal(tx.map.size, 0);
    });

    it("keeps a current row and reports its boundary for re-arming", async () => {
        const tx = makeTxn();
        const startMs = 1_200_000;
        await rateWindowHit(tx, 1, 300, startMs);
        assert.equal(await rateWindowSweep(tx, startMs + 1000), 1_500_000);
        assert.equal(tx.map.size, 1);
    });

    it("treats a missing row as already cleared", async () => {
        const tx = makeTxn();
        assert.equal(await rateWindowSweep(tx, Date.now()), null);
    });

    it("sweeps legacy rows without a recorded boundary", async () => {
        const tx = makeTxn();
        tx.map.set("window", { windowIndex: 1, count: 1 });
        assert.equal(await rateWindowSweep(tx, Date.now()), null);
        assert.equal(tx.map.size, 0);
    });
});
