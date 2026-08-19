import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
    decodeCursor,
    encodeCursor,
    resolveShipName,
    timingSafeEqual,
    truncateCodePoints,
} from "../src/util.ts";

describe("timingSafeEqual", () => {
    it("compares without early exit on length or content mismatch", () => {
        assert.ok(timingSafeEqual("Bearer abc", "Bearer abc"));
        assert.ok(!timingSafeEqual("Bearer abc", "Bearer abd"));
        assert.ok(!timingSafeEqual("Bearer abc", "Bearer abcd"));
        assert.ok(timingSafeEqual("", ""));
        assert.ok(!timingSafeEqual("", "x"));
    });
});

describe("truncateCodePoints", () => {
    it("counts Unicode code points, not UTF-16 units", () => {
        const emoji = "🚀".repeat(300);
        assert.equal(truncateCodePoints(emoji, 280).length, 560); // 280 surrogate pairs
        assert.equal([...truncateCodePoints(emoji, 280)].length, 280);
    });

    it("leaves short text unchanged", () => {
        assert.equal(truncateCodePoints("hello", 280), "hello");
        assert.equal(truncateCodePoints("", 280), "");
    });
});

describe("cursor tokens", () => {
    const createdAt = "2026-08-19T12:34:56.789Z";
    const postId = "7c9e6679-7425-40de-944b-e07fc1f90ae7";

    it("round-trips", () => {
        const token = encodeCursor(createdAt, postId);
        assert.deepEqual(decodeCursor(token), { createdAt, postId });
    });

    it("produces unpadded base64url", () => {
        const token = encodeCursor(createdAt, postId);
        assert.match(token, /^[A-Za-z0-9_-]+$/);
    });

    it("rejects malformed tokens", () => {
        assert.equal(decodeCursor(""), null);
        assert.equal(decodeCursor("!!!not-base64!!!"), null);
        assert.equal(decodeCursor(btoa("no-separator")), null);
        assert.equal(decodeCursor(btoa("|post")), null);
        assert.equal(decodeCursor(btoa(`${createdAt}|not-a-uuid`)), null);
        assert.equal(decodeCursor(btoa(`${createdAt}|${postId}|extra`)), null);
    });
});

describe("resolveShipName", () => {
    const names = JSON.stringify({ en: "Heron", zh: "苍鹭" });

    it("prefers the requested locale, then en, then any", () => {
        assert.equal(resolveShipName(names, "zh"), "苍鹭");
        assert.equal(resolveShipName(names, "en"), "Heron");
        assert.equal(resolveShipName(names, "fr"), "Heron");
        assert.equal(resolveShipName(JSON.stringify({ zh: "苍鹭" }), "en"), "苍鹭");
    });

    it("degrades to empty on malformed JSON", () => {
        assert.equal(resolveShipName("not json", "en"), "");
        assert.equal(resolveShipName("{}", "en"), "");
    });
});
