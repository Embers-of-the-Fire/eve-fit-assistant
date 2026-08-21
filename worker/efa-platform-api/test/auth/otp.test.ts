import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
    clearOtp,
    generateOtpCode,
    hasOtpCooldown,
    OTP_MAX_ATTEMPTS,
    OTP_RESEND_COOLDOWN_SEC,
    OTP_TTL_SEC,
    storeOtp,
    verifyOtp,
} from "../../src/auth/otp.ts";
import { TestKV } from "./helpers.ts";

const SECRET = "test-secret";
const EMAIL = "user@example.com";

function kv(): TestKV {
    return new TestKV();
}

describe("generateOtpCode", () => {
    it("produces zero-padded 6-digit codes", () => {
        for (let i = 0; i < 200; i++) {
            assert.match(generateOtpCode(), /^\d{6}$/);
        }
    });
});

describe("otp store/verify", () => {
    it("verifies a stored code and consumes it", async () => {
        const store = kv();
        const code = generateOtpCode();
        await storeOtp(store as never, SECRET, "verify", EMAIL, code);
        assert.equal(await verifyOtp(store as never, SECRET, "verify", EMAIL, code), "ok");
        // Single-use: the same code cannot be replayed.
        assert.equal(await verifyOtp(store as never, SECRET, "verify", EMAIL, code), "expired");
    });

    it("rejects a wrong code and burns the code after 5 attempts", async () => {
        const store = kv();
        await storeOtp(store as never, SECRET, "verify", EMAIL, "123456");
        for (let i = 0; i < OTP_MAX_ATTEMPTS; i++) {
            assert.equal(
                await verifyOtp(store as never, SECRET, "verify", EMAIL, "654321"),
                "invalid",
            );
        }
        // Locked out: even the correct code no longer verifies.
        assert.equal(await verifyOtp(store as never, SECRET, "verify", EMAIL, "123456"), "expired");
    });

    it("still accepts the correct code after a few wrong ones", async () => {
        const store = kv();
        await storeOtp(store as never, SECRET, "verify", EMAIL, "123456");
        await verifyOtp(store as never, SECRET, "verify", EMAIL, "000000");
        await verifyOtp(store as never, SECRET, "verify", EMAIL, "000000");
        assert.equal(await verifyOtp(store as never, SECRET, "verify", EMAIL, "123456"), "ok");
    });

    it("scopes codes by purpose and email", async () => {
        const store = kv();
        await storeOtp(store as never, SECRET, "verify", EMAIL, "123456");
        assert.equal(await verifyOtp(store as never, SECRET, "reset", EMAIL, "123456"), "expired");
        assert.equal(
            await verifyOtp(store as never, SECRET, "verify", "other@example.com", "123456"),
            "expired",
        );
        assert.equal(await verifyOtp(store as never, SECRET, "verify", EMAIL, "123456"), "ok");
    });

    it("rejects codes signed with a different secret", async () => {
        const store = kv();
        await storeOtp(store as never, "other-secret", "verify", EMAIL, "123456");
        assert.equal(await verifyOtp(store as never, SECRET, "verify", EMAIL, "123456"), "invalid");
    });

    it("expires after the TTL", async () => {
        const store = kv();
        const code = generateOtpCode();
        await storeOtp(store as never, SECRET, "verify", EMAIL, code);
        store.advance((OTP_TTL_SEC + 1) * 1000);
        assert.equal(await verifyOtp(store as never, SECRET, "verify", EMAIL, code), "expired");
    });
});

describe("otp cooldown", () => {
    it("is set on store and clears after the window", async () => {
        const store = kv();
        assert.equal(await hasOtpCooldown(store as never, "verify", EMAIL), false);
        await storeOtp(store as never, SECRET, "verify", EMAIL, generateOtpCode());
        assert.equal(await hasOtpCooldown(store as never, "verify", EMAIL), true);
        store.advance((OTP_RESEND_COOLDOWN_SEC + 1) * 1000);
        assert.equal(await hasOtpCooldown(store as never, "verify", EMAIL), false);
    });

    it("clearOtp drops both the code and the cooldown", async () => {
        const store = kv();
        const code = generateOtpCode();
        await storeOtp(store as never, SECRET, "verify", EMAIL, code);
        await clearOtp(store as never, "verify", EMAIL);
        assert.equal(await hasOtpCooldown(store as never, "verify", EMAIL), false);
        assert.equal(await verifyOtp(store as never, SECRET, "verify", EMAIL, code), "expired");
    });
});
