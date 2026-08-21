// OTP state Durable Object: one instance per (purpose, email), resolved by
// idFromName in otp.ts. Per-instance serialization plus a single storage
// transaction per operation make code consumption and attempt counting
// atomic — the property KV's non-atomic read-modify-write could not provide.
//
// SQLite-backed (new_sqlite_classes migration in wrangler.toml); an idle
// instance hibernates and incurs no duration charges. Expiry is lazy: entries
// carry absolute timestamps and are deleted on the next access (or
// overwritten by the next store), so no alarms are scheduled.
//
// This class is imported only by the worker entrypoint (index.ts); the
// transactional logic lives in otp-core.ts so tests can exercise it without
// the cloudflare:workers runtime module.

import { DurableObject } from "cloudflare:workers";
import {
    type OtpEntry,
    type OtpVerifyResult,
    otpStateClear,
    otpStateHasCooldown,
    otpStateStore,
    otpStateVerify,
} from "./otp-core.ts";

export class OtpState extends DurableObject {
    store(entry: OtpEntry, cooldownUntilMs: number): Promise<void> {
        return this.ctx.storage.transaction((tx) => otpStateStore(tx, entry, cooldownUntilMs));
    }

    verify(candidateHmac: string, nowMs: number): Promise<OtpVerifyResult> {
        return this.ctx.storage.transaction((tx) => otpStateVerify(tx, candidateHmac, nowMs));
    }

    hasCooldown(nowMs: number): Promise<boolean> {
        return this.ctx.storage.transaction((tx) => otpStateHasCooldown(tx, nowMs));
    }

    clear(): Promise<void> {
        return this.ctx.storage.transaction((tx) => otpStateClear(tx));
    }
}
