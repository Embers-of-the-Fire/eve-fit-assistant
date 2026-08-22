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
                        // Test-only stand-in for the deployed sync secret.
                        SYNC_TOKEN: "test-token",
                        // Applied to the test D1 database in test/apply-migrations.ts.
                        TEST_MIGRATIONS: migrations,
                    },
                },
            }),
        ],
        test: {
            setupFiles: ["./test/apply-migrations.ts"],
        },
    };
});
