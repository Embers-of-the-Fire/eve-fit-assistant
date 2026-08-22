// Transactional core of the OTP Durable Object (otp-state.ts), kept free of
// worker-only imports so the unit tests can run it under Node's strip-types
// mode against an in-memory store. Every function operates inside a single
// storage transaction, so the read-modify-write of code consumption and
// attempt counting cannot race (the failure mode of the old KV backend).
//
// The plaintext code never reaches this layer: the worker computes the keyed
// HMAC and only digests are stored and compared here.

import { timingSafeEqual } from "../util.ts";

export type OtpVerifyResult = "ok" | "invalid" | "expired";

export const OTP_MAX_ATTEMPTS = 5;

export interface OtpEntry {
    codeHmac: string;
    attempts: number;
    expiresAtMs: number; // ms epoch; DO storage has no TTL, so expiry is lazy
    // (the Durable Object in otp-state.ts schedules an alarm to reclaim the
    // instance once both the entry and the cooldown have lapsed)
}

// The resend cooldown is deliberately separate from the code entry: consuming
// (or burning) the code must not lift the cooldown, while clearOtp drops both.
const ENTRY_KEY = "entry";
const COOLDOWN_KEY = "cooldown";

// Minimal transactional-storage surface shared by DurableObjectTransaction
// and the in-memory test double.
export interface OtpTxn {
    get<T>(key: string): Promise<T | undefined>;
    put(key: string, value: unknown): Promise<unknown>;
    delete(key: string): Promise<unknown>;
}

export async function otpStateStore(
    tx: OtpTxn,
    entry: OtpEntry,
    cooldownUntilMs: number,
): Promise<void> {
    await tx.put(ENTRY_KEY, entry);
    await tx.put(COOLDOWN_KEY, cooldownUntilMs);
}

export async function otpStateVerify(
    tx: OtpTxn,
    candidateHmac: string,
    nowMs: number,
): Promise<OtpVerifyResult> {
    const entry = await tx.get<OtpEntry>(ENTRY_KEY);
    if (!entry || entry.expiresAtMs <= nowMs) {
        await tx.delete(ENTRY_KEY);
        return "expired";
    }
    if (entry.attempts >= OTP_MAX_ATTEMPTS) {
        // Burned by too many wrong guesses; the caller must resend a fresh code.
        await tx.delete(ENTRY_KEY);
        return "expired";
    }
    if (timingSafeEqual(candidateHmac, entry.codeHmac)) {
        // Only this request can consume the code: the transaction serializes
        // against any concurrent verify of the same (purpose, email).
        await tx.delete(ENTRY_KEY);
        return "ok";
    }
    entry.attempts += 1;
    if (entry.attempts >= OTP_MAX_ATTEMPTS) {
        await tx.delete(ENTRY_KEY);
    } else {
        await tx.put(ENTRY_KEY, entry);
    }
    return "invalid";
}

export async function otpStateHasCooldown(tx: OtpTxn, nowMs: number): Promise<boolean> {
    const cooldownUntilMs = await tx.get<number>(COOLDOWN_KEY);
    return cooldownUntilMs !== undefined && cooldownUntilMs > nowMs;
}

export async function otpStateClear(tx: OtpTxn): Promise<void> {
    await tx.delete(ENTRY_KEY);
    await tx.delete(COOLDOWN_KEY);
}
