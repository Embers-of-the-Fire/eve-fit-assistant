import path from "node:path";
import { cloudflareTest, readD1Migrations } from "@cloudflare/vitest-plugin";
import { defineConfig } from "vitest/config";

export default defineConfig(async () => {
    const migrations = await readD1Migrations(path.join(import.meta.dirname, "migrations"));

    return {
        plugins: [
            cloudflareTest({
                wrangler: { configPath: "./wrangler.toml" },
                miniflare: {
                    bindings: {
                        // Test-only stand-in for the deployed auth secret.
                        AUTH_TOKEN_SECRET: "test-secret",
                        // Applied to the test D1 database in test/apply-migrations.ts.
                        TEST_MIGRATIONS: migrations,
                    },
                    // The deployed service binding points at the separate
                    // fit-storage worker, which no test exercises; stub it so
                    // the test environment stays self-contained.
                    serviceBindings: {
                        FIT_STORAGE: () => new Response("not implemented", { status: 501 }),
                    },
                },
            }),
        ],
        test: {
            setupFiles: ["./test/apply-migrations.ts"],
        },
    };
});
