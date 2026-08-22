import assert from "node:assert/strict";
import { describe, it } from "node:test";
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
        assert.ok(claims);
        assert.equal(claims.sub, "user-1");
        assert.equal(claims.tv, 3);
        assert.equal(claims.exp - claims.iat, ACCESS_TOKEN_TTL_SEC);
        assert.ok(claims.jti.length > 0);
    });

    it("rejects a tampered payload", async () => {
        const token = await signAccessToken(SECRET, "user-1", 0);
        const [header, payload, signature] = token.split(".");
        const replacement = payload.startsWith("A") ? "B" : "A";
        const tampered = `${header}.${replacement}${payload.slice(1)}.${signature}`;
        assert.equal(await verifyAccessToken(SECRET, tampered), null);
    });

    it("rejects a wrong secret", async () => {
        const token = await signAccessToken(SECRET, "user-1", 0);
        assert.equal(await verifyAccessToken("other-secret", token), null);
    });

    it("rejects malformed tokens", async () => {
        for (const malformed of ["", "a", "a.b", "a.b.c.d", "a.b.!!!"]) {
            assert.equal(await verifyAccessToken(SECRET, malformed), null, malformed);
        }
    });

    it("honours expiry with the clock-skew leeway", async () => {
        const now = Date.now();
        const token = await signAccessToken(SECRET, "user-1", 0, now);
        const expiredAt = now + ACCESS_TOKEN_TTL_SEC * 1000;
        assert.ok(await verifyAccessToken(SECRET, token, expiredAt + 20 * 1000));
        assert.equal(await verifyAccessToken(SECRET, token, expiredAt + 31 * 1000), null);
    });

    it("rejects tokens issued too far in the future", async () => {
        const now = Date.now();
        const token = await signAccessToken(SECRET, "user-1", 0, now + 60 * 1000);
        assert.equal(await verifyAccessToken(SECRET, token, now), null);
        assert.ok(await verifyAccessToken(SECRET, token, now + 31 * 1000));
    });
});

describe("refresh tokens", () => {
    it("generates 43-char base64url tokens", () => {
        const token = generateRefreshToken();
        assert.match(token, /^[A-Za-z0-9_-]{43}$/);
        assert.notEqual(generateRefreshToken(), generateRefreshToken());
    });

    it("hashes to a deterministic 64-char hex digest", async () => {
        const token = generateRefreshToken();
        const hash = await hashRefreshToken(token);
        assert.match(hash, /^[0-9a-f]{64}$/);
        assert.equal(await hashRefreshToken(token), hash);
        assert.notEqual(await hashRefreshToken(generateRefreshToken()), hash);
    });
});
