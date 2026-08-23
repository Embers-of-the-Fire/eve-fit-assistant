// Shared test scaffolding on top of the real local bindings (D1, KV, Durable
// Objects) provided by the Workers Vitest integration. Storage isolation is
// per test file, so clearAuthState() restores a pristine state before each
// test like the old per-test in-memory doubles did.

import { applyD1Migrations, reset } from "cloudflare:test";
import { env } from "cloudflare:workers";
import type { OtpEmailEnv, OtpEmailInput } from "../../src/auth/email.ts";
import { createAuthApp } from "../../src/auth/router.ts";

export interface CapturedEmail {
    to: string;
    code: string;
    purpose: string;
    locale: string;
}

export type TestEnv = typeof env;

export type SendEmail = (env: OtpEmailEnv, input: OtpEmailInput) => Promise<boolean>;

// Wipes all auth state: Durable Object instances (OTP codes and rate-limit
// counters), the refresh-rotation KV stash, and the D1 auth tables. reset()
// clears the whole per-file isolated storage including the D1 schema, so the
// migrations are re-applied to restore an empty database.
export async function clearAuthState(): Promise<void> {
    await reset();
    await applyD1Migrations(env.FIT_DB, env.TEST_MIGRATIONS);
}

// Builds the auth app against the real local bindings with the outbound email
// sender captured (the production sender hits the Resend API). Tests that
// need a failing sender pass their own sendEmail.
export function setupAuthApp(options?: { sendEmail?: SendEmail; env?: Partial<TestEnv> }): {
    app: ReturnType<typeof createAuthApp>;
    testEnv: TestEnv;
    emails: CapturedEmail[];
} {
    const emails: CapturedEmail[] = [];
    const sendEmail: SendEmail =
        options?.sendEmail ??
        ((_env, input) => {
            emails.push({ ...input });
            return Promise.resolve(true);
        });
    const app = createAuthApp({ sendEmail });
    return { app, testEnv: { ...env, ...options?.env }, emails };
}
