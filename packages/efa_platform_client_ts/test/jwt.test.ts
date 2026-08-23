import { describe, expect, it } from "vitest";
import { decodeJwtSubject } from "../src/lib/jwt";
import { fakeJwt } from "./helpers";

describe("decodeJwtSubject", () => {
    it("decodes the sub claim", () => {
        expect(decodeJwtSubject(fakeJwt("user-123"))).toBe("user-123");
    });

    it("returns null for a payload without sub", () => {
        expect(decodeJwtSubject(fakeJwt(null))).toBeNull();
    });

    it("returns null for malformed tokens", () => {
        expect(decodeJwtSubject("not-a-jwt")).toBeNull();
        expect(decodeJwtSubject("a.b")).toBeNull();
        expect(decodeJwtSubject("a.!!!.c")).toBeNull();
    });

    it("decodes unicode payloads", () => {
        expect(decodeJwtSubject(fakeJwt("用户-1"))).toBe("用户-1");
    });
});
