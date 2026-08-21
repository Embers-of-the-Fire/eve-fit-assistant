import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { fixedWindowLimit } from "../../src/auth/ratelimit.ts";
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
