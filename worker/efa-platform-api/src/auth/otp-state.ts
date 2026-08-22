// OTP state Durable Object: one instance per (purpose, email), resolved by
// idFromName in otp.ts. Per-instance serialization plus a single storage
// transaction per operation make code consumption and attempt counting
// atomic — the property KV's non-atomic read-modify-write could not provide.
//
// SQLite-backed (new_sqlite_classes migration in wrangler.toml); an idle
// instance hibernates and incurs no duration charges. Expiry is lazy: entries
// carry absolute timestamps and are deleted on the next access (or
// overwritten by the next store). Reclamation is eager: store schedules the
// instance's single alarm at the later of the code expiry and the resend
// cooldown, and alarm() deleteAll()s the instance, so abandoned (purpose,
// email) instances do not accumulate billed SQLite storage without bound.
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
        return this.ctx.storage.transaction(async (tx) => {
            await otpStateStore(tx, entry, cooldownUntilMs);
            // Reclaim the instance once nothing in it is live. One alarm per
            // instance and setAlarm overrides the previous one, so a resend
            // simply pushes reclamation out to the new expiry. SQLite-backed
            // storage folds ctx.storage calls into the running transaction, so
            // the alarm commits atomically with the state it reclaims.
            await this.ctx.storage.setAlarm(Math.max(entry.expiresAtMs, cooldownUntilMs));
        });
    }

    verify(candidateHmac: string, nowMs: number): Promise<OtpVerifyResult> {
        return this.ctx.storage.transaction((tx) => otpStateVerify(tx, candidateHmac, nowMs));
    }

    hasCooldown(nowMs: number): Promise<boolean> {
        return this.ctx.storage.transaction((tx) => otpStateHasCooldown(tx, nowMs));
    }

    clear(): Promise<void> {
        return this.ctx.storage.transaction(async (tx) => {
            await otpStateClear(tx);
            // No state left to reclaim: drop the pending reclamation alarm too.
            await this.ctx.storage.deleteAlarm();
        });
    }

    // Fires at the later of the code expiry and the resend cooldown, when
    // every row in this instance is expired state (and clear() cancels the
    // alarm when the state went away early) — drop the whole instance.
    async alarm(): Promise<void> {
        await this.ctx.storage.deleteAll();
    }
}
