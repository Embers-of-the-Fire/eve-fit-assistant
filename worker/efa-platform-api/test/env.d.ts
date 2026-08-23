// Types for the test bindings (`env` from "cloudflare:workers"): the real
// worker bindings plus the test-only extras defined in vitest.config.ts.
// This file is intentionally a global script (no top-level imports) so the
// namespace declaration merges with the ambient one from workers-types.
declare namespace Cloudflare {
    interface Env {
        FIT_DB: D1Database;
        AUTH_KV: KVNamespace;
        AUTH_OTP: DurableObjectNamespace<import("../src/auth/otp-state.ts").OtpState>;
        AUTH_RATE_LIMIT: DurableObjectNamespace<
            import("../src/auth/rate-window.ts").RateLimitWindow
        >;
        AUTH_TOKEN_SECRET: string;
        TEST_MIGRATIONS: import("cloudflare:test").D1Migration[];
    }
}
