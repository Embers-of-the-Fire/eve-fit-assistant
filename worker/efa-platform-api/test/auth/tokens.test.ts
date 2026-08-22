import { describe, expect, it } from "vitest";
import {
    ACCESS_TOKEN_TTL_SEC,
    generateRefreshToken,
    hashRefreshToken,
    signAccessToken,
    verifyAccessToken,
} from "../../src/auth/tokens.ts";

const SECRET = "test-secret";

describe("access tokens", () => {
    it("round-trips claims", async () => {
        const now = Date.now();
        const token = await signAccessToken(SECRET, "user-1", 3, now);
        const claims = await verifyAccessToken(SECRET, token, now);
        expect(claims).not.toBe(null);
        expect(claims?.sub).toBe("user-1");
        expect(claims?.tv).toBe(3);
        expect(claims && claims.exp - claims.iat).toBe(ACCESS_TOKEN_TTL_SEC);
        expect(claims?.jti.length).toBeGreaterThan(0);
    });

    it("rejects a tampered payload", async () => {
        const token = await signAccessToken(SECRET, "user-1", 0);
        const [header, payload, signature] = token.split(".");
        const replacement = payload.startsWith("A") ? "B" : "A";
        const tampered = `${header}.${replacement}${payload.slice(1)}.${signature}`;
        expect(await verifyAccessToken(SECRET, tampered)).toBe(null);
    });

    it("rejects a wrong secret", async () => {
        const token = await signAccessToken(SECRET, "user-1", 0);
        expect(await verifyAccessToken("other-secret", token)).toBe(null);
    });

    it("rejects malformed tokens", async () => {
        for (const malformed of ["", "a", "a.b", "a.b.c.d", "a.b.!!!"]) {
            expect(await verifyAccessToken(SECRET, malformed)).toBe(null);
        }
    });

    it("honours expiry with the clock-skew leeway", async () => {
        const now = Date.now();
        const token = await signAccessToken(SECRET, "user-1", 0, now);
        const expiredAt = now + ACCESS_TOKEN_TTL_SEC * 1000;
        expect(await verifyAccessToken(SECRET, token, expiredAt + 20 * 1000)).not.toBe(null);
        expect(await verifyAccessToken(SECRET, token, expiredAt + 31 * 1000)).toBe(null);
    });

    it("rejects tokens issued too far in the future", async () => {
        const now = Date.now();
        const token = await signAccessToken(SECRET, "user-1", 0, now + 60 * 1000);
        expect(await verifyAccessToken(SECRET, token, now)).toBe(null);
        expect(await verifyAccessToken(SECRET, token, now + 31 * 1000)).not.toBe(null);
    });
});

describe("refresh tokens", () => {
    it("generates 43-char base64url tokens", () => {
        const token = generateRefreshToken();
        expect(token).toMatch(/^[A-Za-z0-9_-]{43}$/);
        expect(generateRefreshToken()).not.toBe(generateRefreshToken());
    });

    it("hashes to a deterministic 64-char hex digest", async () => {
        const token = generateRefreshToken();
        const hash = await hashRefreshToken(token);
        expect(hash).toMatch(/^[0-9a-f]{64}$/);
        expect(await hashRefreshToken(token)).toBe(hash);
        expect(await hashRefreshToken(generateRefreshToken())).not.toBe(hash);
    });
});
