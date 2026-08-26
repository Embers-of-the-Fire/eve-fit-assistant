// Types for the test bindings (`env` from "cloudflare:workers"): the real
// worker bindings plus the test-only extras defined in vitest.config.ts.
declare namespace Cloudflare {
    interface Env {
        PLATFORM_DB: D1Database;
        SYNC_SESSION: DurableObjectNamespace<import("../src/session.ts").SyncSession>;
        SYNC_TOKEN: string;
        TEST_MIGRATIONS: import("cloudflare:test").D1Migration[];
    }
}
