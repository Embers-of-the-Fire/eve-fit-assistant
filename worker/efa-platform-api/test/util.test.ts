import { describe, expect, it } from "vitest";
import {
    decodeCursor,
    decodeShipCursor,
    encodeCursor,
    encodeShipCursor,
    escapeLikePattern,
    normalizeBlob,
    parseLimit,
    parseTimeWindow,
    resolveShipName,
    timingSafeEqual,
    truncateCodePoints,
} from "../src/util.ts";

describe("normalizeBlob", () => {
    const bytes = [8, 1, 255];

    it("accepts ArrayBuffer and ArrayBufferView shapes", () => {
        const view = new Uint8Array(bytes);
        expect(normalizeBlob(view.buffer)).toEqual(new Uint8Array(bytes));
        expect(normalizeBlob(view)).toEqual(new Uint8Array(bytes));
        expect(normalizeBlob(new DataView(view.buffer))).toEqual(new Uint8Array(bytes));
        const slice = new Uint8Array([0, ...bytes, 0]).subarray(1, 4);
        expect(normalizeBlob(slice)).toEqual(new Uint8Array(bytes));
    });

    it("converts D1's plain number arrays", () => {
        expect(normalizeBlob(bytes)).toEqual(new Uint8Array(bytes));
        expect(normalizeBlob([])).toEqual(new Uint8Array([]));
    });

    it("rejects non-blob shapes", () => {
        expect(normalizeBlob(null)).toBe(null);
        expect(normalizeBlob(undefined)).toBe(null);
        expect(normalizeBlob("8,1,255")).toBe(null);
        expect(normalizeBlob(42)).toBe(null);
        expect(normalizeBlob({})).toBe(null);
    });
});

describe("timingSafeEqual", () => {
    it("compares without early exit on length or content mismatch", () => {
        expect(timingSafeEqual("Bearer abc", "Bearer abc")).toBe(true);
        expect(timingSafeEqual("Bearer abc", "Bearer abd")).toBe(false);
        expect(timingSafeEqual("Bearer abc", "Bearer abcd")).toBe(false);
        expect(timingSafeEqual("", "")).toBe(true);
        expect(timingSafeEqual("", "x")).toBe(false);
    });
});

describe("truncateCodePoints", () => {
    it("counts Unicode code points, not UTF-16 units", () => {
        const emoji = "🚀".repeat(300);
        expect(truncateCodePoints(emoji, 280).length).toBe(560); // 280 surrogate pairs
        expect([...truncateCodePoints(emoji, 280)].length).toBe(280);
    });

    it("leaves short text unchanged", () => {
        expect(truncateCodePoints("hello", 280)).toBe("hello");
        expect(truncateCodePoints("", 280)).toBe("");
    });
});

describe("cursor tokens", () => {
    const createdAt = "2026-08-19T12:34:56.789Z";
    const postId = "7c9e6679-7425-40de-944b-e07fc1f90ae7";

    it("round-trips", () => {
        const token = encodeCursor(createdAt, postId);
        expect(decodeCursor(token)).toEqual({ createdAt, postId });
    });

    it("produces unpadded base64url", () => {
        const token = encodeCursor(createdAt, postId);
        expect(token).toMatch(/^[A-Za-z0-9_-]+$/);
    });

    it("rejects malformed tokens", () => {
        expect(decodeCursor("")).toBe(null);
        expect(decodeCursor("!!!not-base64!!!")).toBe(null);
        expect(decodeCursor(btoa("no-separator"))).toBe(null);
        expect(decodeCursor(btoa("|post"))).toBe(null);
        expect(decodeCursor(btoa(`${createdAt}|not-a-uuid`))).toBe(null);
        expect(decodeCursor(btoa(`${createdAt}|${postId}|extra`))).toBe(null);
    });
});

describe("resolveShipName", () => {
    const names = JSON.stringify({ en: "Heron", zh: "苍鹭" });

    it("prefers the requested locale, then en, then any", () => {
        expect(resolveShipName(names, "zh")).toBe("苍鹭");
        expect(resolveShipName(names, "en")).toBe("Heron");
        expect(resolveShipName(names, "fr")).toBe("Heron");
        expect(resolveShipName(JSON.stringify({ zh: "苍鹭" }), "en")).toBe("苍鹭");
    });

    it("degrades to empty on malformed JSON", () => {
        expect(resolveShipName("not json", "en")).toBe("");
        expect(resolveShipName("{}", "en")).toBe("");
    });
});

describe("parseTimeWindow", () => {
    it("maps preset tokens to SQLite datetime modifiers", () => {
        expect(parseTimeWindow("24h")).toBe("-1 day");
        expect(parseTimeWindow("7d")).toBe("-7 days");
        expect(parseTimeWindow("30d")).toBe("-30 days");
    });

    it("treats an absent parameter and 'all' as no condition", () => {
        expect(parseTimeWindow(undefined)).toBe(null);
        expect(parseTimeWindow("all")).toBe(null);
    });

    it("rejects unknown tokens", () => {
        expect(parseTimeWindow("1h")).toBe("invalid");
        expect(parseTimeWindow("")).toBe("invalid");
        expect(parseTimeWindow("-7 days")).toBe("invalid");
    });

    it("rejects inherited Object.prototype property names", () => {
        expect(parseTimeWindow("__proto__")).toBe("invalid");
        expect(parseTimeWindow("constructor")).toBe("invalid");
        expect(parseTimeWindow("toString")).toBe("invalid");
        expect(parseTimeWindow("hasOwnProperty")).toBe("invalid");
        expect(parseTimeWindow("valueOf")).toBe("invalid");
    });
});

describe("ship cursor tokens", () => {
    it("round-trips", () => {
        const token = encodeShipCursor(42, 24692);
        expect(decodeShipCursor(token)).toEqual({ postCount: 42, shipTypeId: 24692 });
    });

    it("produces unpadded base64url", () => {
        expect(encodeShipCursor(42, 24692)).toMatch(/^[A-Za-z0-9_-]+$/);
    });

    it("rejects malformed tokens", () => {
        expect(decodeShipCursor("")).toBe(null);
        expect(decodeShipCursor("!!!not-base64!!!")).toBe(null);
        expect(decodeShipCursor(btoa("no-separator"))).toBe(null);
        expect(decodeShipCursor(btoa("|24692"))).toBe(null);
        expect(decodeShipCursor(btoa("not-a-number|24692"))).toBe(null);
        expect(decodeShipCursor(btoa("42|0"))).toBe(null);
        expect(decodeShipCursor(btoa("42|-1"))).toBe(null);
        expect(decodeShipCursor(btoa("-1|24692"))).toBe(null);
        expect(decodeShipCursor(btoa("42|24692|extra"))).toBe(null);
    });
});

describe("parseLimit", () => {
    it("accepts plain decimal integers", () => {
        expect(parseLimit("1", 50)).toBe(1);
        expect(parseLimit("20", 50)).toBe(20);
        expect(parseLimit("007", 50)).toBe(7);
    });

    it("clamps to [1, maxLimit]", () => {
        expect(parseLimit("0", 50)).toBe(1);
        expect(parseLimit("999", 50)).toBe(50);
    });

    it("rejects numeric prefixes and non-decimal values", () => {
        expect(parseLimit("20junk", 50)).toBe(null);
        expect(parseLimit("20.5", 50)).toBe(null);
        expect(parseLimit("-1", 50)).toBe(null);
        expect(parseLimit("+1", 50)).toBe(null);
        expect(parseLimit(" 20", 50)).toBe(null);
        expect(parseLimit("20 ", 50)).toBe(null);
        expect(parseLimit("0x20", 50)).toBe(null);
        expect(parseLimit("", 50)).toBe(null);
        expect(parseLimit("junk", 50)).toBe(null);
    });
});

describe("escapeLikePattern", () => {
    it("escapes LIKE wildcards and the escape character itself", () => {
        expect(escapeLikePattern("Heron")).toBe("Heron");
        expect(escapeLikePattern("100%")).toBe("100\\%");
        expect(escapeLikePattern("a_b")).toBe("a\\_b");
        expect(escapeLikePattern("a\\b")).toBe("a\\\\b");
    });
});
