import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { fixedWindowLimit } from "../../src/auth/ratelimit.ts";
import { TestKV } from "./helpers.ts";

describe("fixedWindowLimit", () => {
    it("allows up to the limit, then denies with a Retry-After", async () => {
        const kv = new TestKV();
        for (let i = 0; i < 3; i++) {
            const outcome = await fixedWindowLimit(kv as never, "bucket", "key", 3, 3600);
            assert.equal(outcome.allowed, true);
        }
        const denied = await fixedWindowLimit(kv as never, "bucket", "key", 3, 3600);
        assert.equal(denied.allowed, false);
        assert.ok(denied.retryAfterSec > 0 && denied.retryAfterSec <= 3600);
    });

    it("tracks keys and buckets independently", async () => {
        const kv = new TestKV();
        await fixedWindowLimit(kv as never, "bucket", "a", 1, 3600);
        assert.equal((await fixedWindowLimit(kv as never, "bucket", "a", 1, 3600)).allowed, false);
        assert.equal((await fixedWindowLimit(kv as never, "bucket", "b", 1, 3600)).allowed, true);
        assert.equal((await fixedWindowLimit(kv as never, "other", "a", 1, 3600)).allowed, true);
    });

    it("resets when the window rolls over", async () => {
        const kv = new TestKV();
        await fixedWindowLimit(kv as never, "bucket", "key", 1, 300);
        assert.equal((await fixedWindowLimit(kv as never, "bucket", "key", 1, 300)).allowed, false);
        kv.advance(301 * 1000);
        assert.equal((await fixedWindowLimit(kv as never, "bucket", "key", 1, 300)).allowed, true);
    });

    it("handles windows shorter than the KV TTL floor", async () => {
        const kv = new TestKV();
        const outcome = await fixedWindowLimit(kv as never, "bucket", "key", 5, 30);
        assert.equal(outcome.allowed, true);
    });
});
