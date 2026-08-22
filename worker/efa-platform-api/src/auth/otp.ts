// One-time passcodes: 6-digit codes stored only as keyed HMACs, never in
// plaintext. Codes are single-use, TTL-bound, and self-limiting on failed
// attempts. State lives in the OtpState Durable Object (one instance per
// purpose+email), whose per-instance serialization makes consumption and
// attempt counting atomic; see otp-state.ts / otp-core.ts.

import { OTP_MAX_ATTEMPTS, type OtpVerifyResult } from "./otp-core.ts";
import type { OtpState } from "./otp-state.ts";

export type OtpPurpose = "verify" | "reset";
export { OTP_MAX_ATTEMPTS, type OtpVerifyResult };

export const OTP_TTL_SEC = 10 * 60;
export const OTP_RESEND_COOLDOWN_SEC = 60;
// Verification codes stay valid for the full TTL, so resending one sooner
// than that only spams the inbox: verification sends for the same address
// are spaced by the code TTL instead of the generic cooldown.
export const OTP_VERIFY_RESEND_COOLDOWN_SEC = OTP_TTL_SEC;
// Per purpose+email daily send cap, enforced by the caller through the
// rate-limit helper.
export const OTP_DAILY_SEND_LIMIT = 10;
export const OTP_DAILY_SEND_WINDOW_SEC = 24 * 60 * 60;

function resendCooldownSec(purpose: OtpPurpose): number {
    return purpose === "verify" ? OTP_VERIFY_RESEND_COOLDOWN_SEC : OTP_RESEND_COOLDOWN_SEC;
}

const OTP_MODULUS = 1_000_000;

function otpKey(purpose: OtpPurpose, email: string): string {
    return `otp:${purpose}:${email}`;
}

function otpStub(ns: DurableObjectNamespace<OtpState>, purpose: OtpPurpose, email: string) {
    return ns.get(ns.idFromName(otpKey(purpose, email)));
}

// Rejection-sampled uniform 6-digit code (Math.random is not a CSPRNG).
export function generateOtpCode(): string {
    const limit = Math.floor(0x1_0000_0000 / OTP_MODULUS) * OTP_MODULUS;
    const draw = new Uint32Array(1);
    for (;;) {
        crypto.getRandomValues(draw);
        if (draw[0] < limit) {
            return String(draw[0] % OTP_MODULUS).padStart(6, "0");
        }
    }
}

async function hmacHex(secret: string, message: string): Promise<string> {
    const key = await crypto.subtle.importKey(
        "raw",
        new TextEncoder().encode(secret),
        { name: "HMAC", hash: "SHA-256" },
        false,
        ["sign"],
    );
    const signature = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(message));
    let hex = "";
    for (const b of new Uint8Array(signature)) {
        hex += b.toString(16).padStart(2, "0");
    }
    return hex;
}

function codeHmac(
    secret: string,
    purpose: OtpPurpose,
    email: string,
    code: string,
): Promise<string> {
    return hmacHex(secret, `${purpose}|${email}|${code}`);
}

export async function storeOtp(
    ns: DurableObjectNamespace<OtpState>,
    secret: string,
    purpose: OtpPurpose,
    email: string,
    code: string,
    nowMs: number = Date.now(),
): Promise<void> {
    await otpStub(ns, purpose, email).store(
        {
            codeHmac: await codeHmac(secret, purpose, email, code),
            attempts: 0,
            expiresAtMs: nowMs + OTP_TTL_SEC * 1000,
        },
        nowMs + resendCooldownSec(purpose) * 1000,
    );
}

export async function hasOtpCooldown(
    ns: DurableObjectNamespace<OtpState>,
    purpose: OtpPurpose,
    email: string,
    nowMs: number = Date.now(),
): Promise<boolean> {
    return otpStub(ns, purpose, email).hasCooldown(nowMs);
}

// Milliseconds until the resend cooldown lapses (0 when no cooldown is
// active), so callers can report a Retry-After instead of swallowing the
// resend silently.
export async function otpCooldownRemainingMs(
    ns: DurableObjectNamespace<OtpState>,
    purpose: OtpPurpose,
    email: string,
    nowMs: number = Date.now(),
): Promise<number> {
    return otpStub(ns, purpose, email).cooldownRemainingMs(nowMs);
}

// Drop the stored code and its resend cooldown, e.g. when the send itself
// failed and the user should be able to retry immediately.
export async function clearOtp(
    ns: DurableObjectNamespace<OtpState>,
    purpose: OtpPurpose,
    email: string,
): Promise<void> {
    await otpStub(ns, purpose, email).clear();
}

export async function verifyOtp(
    ns: DurableObjectNamespace<OtpState>,
    secret: string,
    purpose: OtpPurpose,
    email: string,
    code: string,
    nowMs: number = Date.now(),
): Promise<OtpVerifyResult> {
    const candidate = await codeHmac(secret, purpose, email, code);
    return otpStub(ns, purpose, email).verify(candidate, nowMs);
}
