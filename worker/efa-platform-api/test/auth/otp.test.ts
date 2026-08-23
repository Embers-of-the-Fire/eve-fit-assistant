// OTP tests against the real OtpState Durable Object (via the AUTH_OTP
// namespace binding). Time-dependent cases pass explicit nowMs values, which
// otp.ts already accepts, instead of shifting a fake clock inside a double.

import { reset } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { beforeEach, describe, expect, it } from "vitest";
import {
    clearOtp,
    generateOtpCode,
    hasOtpCooldown,
    OTP_MAX_ATTEMPTS,
    OTP_RESEND_COOLDOWN_SEC,
    OTP_TTL_SEC,
    OTP_VERIFY_RESEND_COOLDOWN_SEC,
    reserveOtp,
    storeOtp,
    verifyOtp,
} from "../../src/auth/otp.ts";

const SECRET = "test-secret";
const EMAIL = "user@example.com";
const NS = env.AUTH_OTP;

// OTP state persists per test file; wipe the Durable Object instances so each
// test starts from a clean namespace.
beforeEach(async () => {
    await reset();
});

describe("generateOtpCode", () => {
    it("produces zero-padded 6-digit codes", () => {
        for (let i = 0; i < 200; i++) {
            expect(generateOtpCode()).toMatch(/^\d{6}$/);
        }
    });
});

describe("otp store/verify", () => {
    it("verifies a stored code and consumes it", async () => {
        const code = generateOtpCode();
        await storeOtp(NS, SECRET, "verify", EMAIL, code);
        expect(await verifyOtp(NS, SECRET, "verify", EMAIL, code)).toBe("ok");
        // Single-use: the same code cannot be replayed.
        expect(await verifyOtp(NS, SECRET, "verify", EMAIL, code)).toBe("expired");
    });

    it("rejects a wrong code and burns the code after 5 attempts", async () => {
        await storeOtp(NS, SECRET, "verify", EMAIL, "123456");
        for (let i = 0; i < OTP_MAX_ATTEMPTS; i++) {
            expect(await verifyOtp(NS, SECRET, "verify", EMAIL, "654321")).toBe("invalid");
        }
        // Locked out: even the correct code no longer verifies.
        expect(await verifyOtp(NS, SECRET, "verify", EMAIL, "123456")).toBe("expired");
    });

    it("still accepts the correct code after a few wrong ones", async () => {
        await storeOtp(NS, SECRET, "verify", EMAIL, "123456");
        await verifyOtp(NS, SECRET, "verify", EMAIL, "000000");
        await verifyOtp(NS, SECRET, "verify", EMAIL, "000000");
        expect(await verifyOtp(NS, SECRET, "verify", EMAIL, "123456")).toBe("ok");
    });

    it("scopes codes by purpose and email", async () => {
        await storeOtp(NS, SECRET, "verify", EMAIL, "123456");
        expect(await verifyOtp(NS, SECRET, "reset", EMAIL, "123456")).toBe("expired");
        expect(await verifyOtp(NS, SECRET, "verify", "other@example.com", "123456")).toBe(
            "expired",
        );
        expect(await verifyOtp(NS, SECRET, "verify", EMAIL, "123456")).toBe("ok");
    });

    it("rejects codes signed with a different secret", async () => {
        await storeOtp(NS, "other-secret", "verify", EMAIL, "123456");
        expect(await verifyOtp(NS, SECRET, "verify", EMAIL, "123456")).toBe("invalid");
    });

    it("expires after the TTL", async () => {
        const startMs = Date.now();
        const code = generateOtpCode();
        await storeOtp(NS, SECRET, "verify", EMAIL, code, startMs);
        const afterTtlMs = startMs + (OTP_TTL_SEC + 1) * 1000;
        expect(await verifyOtp(NS, SECRET, "verify", EMAIL, code, afterTtlMs)).toBe("expired");
    });

    it("serializes concurrent verifications: only one consumes the code", async () => {
        const code = generateOtpCode();
        await storeOtp(NS, SECRET, "verify", EMAIL, code);
        const results = await Promise.all([
            verifyOtp(NS, SECRET, "verify", EMAIL, code),
            verifyOtp(NS, SECRET, "verify", EMAIL, code),
        ]);
        expect([...results].sort()).toEqual(["expired", "ok"]);
    });

    it("counts every failed attempt under concurrency", async () => {
        await storeOtp(NS, SECRET, "verify", EMAIL, "123456");
        const results = await Promise.all(
            Array.from({ length: OTP_MAX_ATTEMPTS }, () =>
                verifyOtp(NS, SECRET, "verify", EMAIL, "654321"),
            ),
        );
        expect(results.every((r) => r === "invalid")).toBe(true);
        // All five attempts landed: the correct code is now burned too.
        expect(await verifyOtp(NS, SECRET, "verify", EMAIL, "123456")).toBe("expired");
    });
});

describe("otp cooldown", () => {
    it("is set on store and clears after the purpose-specific window", async () => {
        const startMs = Date.now();
        expect(await hasOtpCooldown(NS, "verify", EMAIL, startMs)).toBe(false);
        await storeOtp(NS, SECRET, "verify", EMAIL, generateOtpCode(), startMs);
        expect(await hasOtpCooldown(NS, "verify", EMAIL, startMs)).toBe(true);
        // Verification resends hold a longer cooldown than the generic window.
        const afterGenericMs = startMs + (OTP_RESEND_COOLDOWN_SEC + 1) * 1000;
        expect(await hasOtpCooldown(NS, "verify", EMAIL, afterGenericMs)).toBe(true);
        const afterVerifyMs = startMs + (OTP_VERIFY_RESEND_COOLDOWN_SEC + 1) * 1000;
        expect(await hasOtpCooldown(NS, "verify", EMAIL, afterVerifyMs)).toBe(false);
    });

    it("applies the generic short cooldown to reset codes", async () => {
        const startMs = Date.now();
        await storeOtp(NS, SECRET, "reset", EMAIL, generateOtpCode(), startMs);
        expect(await hasOtpCooldown(NS, "reset", EMAIL, startMs)).toBe(true);
        const afterGenericMs = startMs + (OTP_RESEND_COOLDOWN_SEC + 1) * 1000;
        expect(await hasOtpCooldown(NS, "reset", EMAIL, afterGenericMs)).toBe(false);
    });

    it("clearOtp drops both the code and the cooldown", async () => {
        const code = generateOtpCode();
        await storeOtp(NS, SECRET, "verify", EMAIL, code);
        await clearOtp(NS, "verify", EMAIL);
        expect(await hasOtpCooldown(NS, "verify", EMAIL)).toBe(false);
        expect(await verifyOtp(NS, SECRET, "verify", EMAIL, code)).toBe("expired");
    });
});

describe("otp reserve", () => {
    it("stores the code and arms the cooldown when none is active", async () => {
        const code = generateOtpCode();
        expect(await reserveOtp(NS, SECRET, "verify", EMAIL, code)).toBe(0);
        expect(await hasOtpCooldown(NS, "verify", EMAIL)).toBe(true);
        expect(await verifyOtp(NS, SECRET, "verify", EMAIL, code)).toBe("ok");
    });

    it("reports the remaining cooldown without overwriting the stored code", async () => {
        const startMs = Date.now();
        const code = generateOtpCode();
        expect(await reserveOtp(NS, SECRET, "verify", EMAIL, code, startMs)).toBe(0);
        const remainingMs = await reserveOtp(
            NS,
            SECRET,
            "verify",
            EMAIL,
            generateOtpCode(),
            startMs,
        );
        expect(remainingMs).toBeGreaterThan(0);
        expect(remainingMs).toBeLessThanOrEqual(OTP_VERIFY_RESEND_COOLDOWN_SEC * 1000);
        // The rejected reservation left no trace: the original code still
        // verifies and the cooldown still lapses on its original schedule.
        expect(await verifyOtp(NS, SECRET, "verify", EMAIL, code, startMs)).toBe("ok");
        const afterVerifyMs = startMs + (OTP_VERIFY_RESEND_COOLDOWN_SEC + 1) * 1000;
        expect(await hasOtpCooldown(NS, "verify", EMAIL, afterVerifyMs)).toBe(false);
    });

    it("serializes parallel reservations: exactly one sender wins", async () => {
        const codes = [generateOtpCode(), generateOtpCode(), generateOtpCode()];
        const results = await Promise.all(
            codes.map((code) => reserveOtp(NS, SECRET, "verify", EMAIL, code)),
        );
        const winners = codes.filter((_, i) => results[i] === 0);
        expect(winners.length).toBe(1);
        expect(results.every((r) => r === 0 || r > 0)).toBe(true);
        // Only the winning code verifies; the losers' codes never landed.
        expect(await verifyOtp(NS, SECRET, "verify", EMAIL, winners[0])).toBe("ok");
    });
});
