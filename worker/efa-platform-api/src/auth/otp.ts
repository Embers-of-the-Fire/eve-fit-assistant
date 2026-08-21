// One-time passcodes: 6-digit codes stored in KV only as keyed HMACs, never
// in plaintext. Codes are single-use, TTL-bound, and self-limiting on failed
// attempts. KV eventual consistency is acceptable here: a verify request that
// lands before propagation simply reads as "no code issued".

import { timingSafeEqual } from "../util.ts";

export type OtpPurpose = "verify" | "reset";
export type OtpVerifyResult = "ok" | "invalid" | "expired";

export const OTP_TTL_SEC = 10 * 60;
export const OTP_MAX_ATTEMPTS = 5;
export const OTP_RESEND_COOLDOWN_SEC = 60;
// Per purpose+email daily send cap, enforced by the caller through the
// rate-limit helper.
export const OTP_DAILY_SEND_LIMIT = 10;
export const OTP_DAILY_SEND_WINDOW_SEC = 24 * 60 * 60;

const OTP_MODULUS = 1_000_000;

interface OtpEntry {
    codeHmac: string;
    attempts: number;
    sentAt: number; // ms epoch; used to preserve the remaining TTL on updates
}

function otpKey(purpose: OtpPurpose, email: string): string {
    return `otp:${purpose}:${email}`;
}

function cooldownKey(purpose: OtpPurpose, email: string): string {
    return `otp-cd:${purpose}:${email}`;
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
    kv: KVNamespace,
    secret: string,
    purpose: OtpPurpose,
    email: string,
    code: string,
    nowMs: number = Date.now(),
): Promise<void> {
    const entry: OtpEntry = {
        codeHmac: await codeHmac(secret, purpose, email, code),
        attempts: 0,
        sentAt: nowMs,
    };
    await kv.put(otpKey(purpose, email), JSON.stringify(entry), { expirationTtl: OTP_TTL_SEC });
    await kv.put(cooldownKey(purpose, email), "1", { expirationTtl: OTP_RESEND_COOLDOWN_SEC });
}

export async function hasOtpCooldown(
    kv: KVNamespace,
    purpose: OtpPurpose,
    email: string,
): Promise<boolean> {
    return (await kv.get(cooldownKey(purpose, email))) !== null;
}

// Drop the stored code and its resend cooldown, e.g. when the send itself
// failed and the user should be able to retry immediately.
export async function clearOtp(kv: KVNamespace, purpose: OtpPurpose, email: string): Promise<void> {
    await kv.delete(otpKey(purpose, email));
    await kv.delete(cooldownKey(purpose, email));
}

function parseEntry(raw: string | null): OtpEntry | null {
    if (raw === null) {
        return null;
    }
    try {
        const entry = JSON.parse(raw) as OtpEntry;
        if (
            typeof entry.codeHmac !== "string" ||
            typeof entry.attempts !== "number" ||
            typeof entry.sentAt !== "number"
        ) {
            return null;
        }
        return entry;
    } catch {
        return null;
    }
}

export async function verifyOtp(
    kv: KVNamespace,
    secret: string,
    purpose: OtpPurpose,
    email: string,
    code: string,
    nowMs: number = Date.now(),
): Promise<OtpVerifyResult> {
    const key = otpKey(purpose, email);
    const entry = parseEntry(await kv.get(key));
    if (!entry) {
        return "expired";
    }
    const remainingTtlSec = Math.floor((entry.sentAt + OTP_TTL_SEC * 1000 - nowMs) / 1000);
    if (remainingTtlSec <= 0) {
        await kv.delete(key);
        return "expired";
    }
    if (entry.attempts >= OTP_MAX_ATTEMPTS) {
        // Burned by too many wrong guesses; the caller must resend a fresh code.
        await kv.delete(key);
        return "expired";
    }
    const candidate = await codeHmac(secret, purpose, email, code);
    if (timingSafeEqual(candidate, entry.codeHmac)) {
        await kv.delete(key);
        return "ok";
    }
    entry.attempts += 1;
    if (entry.attempts >= OTP_MAX_ATTEMPTS) {
        await kv.delete(key);
    } else {
        // KV expirationTtl has a 60 s floor; the sentAt check above stays
        // authoritative for the real expiry.
        await kv.put(key, JSON.stringify(entry), {
            expirationTtl: Math.max(60, remainingTtlSec),
        });
    }
    return "invalid";
}
