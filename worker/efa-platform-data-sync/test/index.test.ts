// Endpoint tests against the real local bindings provided by the Workers
// Vitest integration: PLATFORM_DB is a genuine D1 database (migrated from
// migrations/ by the test setup file), not a re-implemented shim.

import { applyD1Migrations, reset } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { beforeEach, describe, expect, it } from "vitest";
import worker from "../src/index.ts";

const MOUNT = "/platform/storage/data-sync";
const TOKEN = env.SYNC_TOKEN;

// Storage isolation is per test file. reset() clears the whole isolated
// storage including the D1 schema, so re-apply the migrations to start each
// test from an empty database like the old per-test in-memory shim did.
beforeEach(async () => {
    await reset();
    await applyD1Migrations(env.PLATFORM_DB, env.TEST_MIGRATIONS);
});

function post(path: string, body: unknown): Promise<Response> {
    return Promise.resolve(
        worker.fetch(
            new Request(`https://example.com${MOUNT}${path}`, {
                method: "POST",
                headers: {
                    "content-type": "application/json",
                    authorization: `Bearer ${TOKEN}`,
                },
                body: JSON.stringify(body),
            }),
            env,
        ),
    );
}

function get(path: string): Promise<Response> {
    return Promise.resolve(worker.fetch(new Request(`https://example.com${MOUNT}${path}`), env));
}

async function sha256Hex(data: Uint8Array): Promise<string> {
    const digest = await crypto.subtle.digest("SHA-256", data.buffer as ArrayBuffer);
    return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function toBase64(data: Uint8Array): string {
    return btoa(String.fromCharCode(...data));
}

describe("snapshot freeze", () => {
    it("rejects /register after /complete and keeps the registration set frozen", async () => {
        const serverId = "tranquility";
        const snapshotHash = "ab".repeat(32);

        const content = new TextEncoder().encode("type-entry-1");
        const contentHash = await sha256Hex(content);

        let res = await post("/content", {
            entries: [
                { family: "types", content_hash: contentHash, content_b64: toBase64(content) },
            ],
        });
        expect(res.status).toBe(200);

        res = await post("/register", {
            server_id: serverId,
            snapshot_hash: snapshotHash,
            entries: [{ family: "types", entry_id: 1, content_hash: contentHash }],
        });
        expect(res.status).toBe(200);
        expect(await res.json()).toEqual({ ok: true, inserted: 1 });

        res = await post("/complete", {
            server_id: serverId,
            snapshot_hash: snapshotHash,
            entry_count: 1,
        });
        expect(res.status).toBe(200);

        res = await post("/register", {
            server_id: serverId,
            snapshot_hash: snapshotHash,
            entries: [{ family: "types", entry_id: 2, content_hash: contentHash }],
        });
        expect(res.status).toBe(409);
        const conflict = (await res.json()) as { ok: boolean; error: string };
        expect(conflict.ok).toBe(false);
        expect(conflict.error).toBe("Snapshot already complete");

        const regCount = await env.PLATFORM_DB.prepare(
            "SELECT COUNT(*) AS n FROM types_reg WHERE server_id = ? AND snapshot_hash = ?",
        )
            .bind(serverId, snapshotHash)
            .first<{ n: number }>();
        expect(regCount?.n).toBe(1);

        res = await get(`/snapshot?server_id=${serverId}&snapshot_hash=${snapshotHash}`);
        expect(res.status).toBe(200);
        const snapshot = (await res.json()) as {
            ok: boolean;
            complete: boolean;
            entry_count: number;
        };
        expect(snapshot.complete).toBe(true);
        expect(snapshot.entry_count).toBe(1);
    });
});

describe("entry_id validation", () => {
    it("accepts negative entry IDs used by engine-internal pseudo entries", async () => {
        const serverId = "tranquility";
        const snapshotHash = "cd".repeat(32);

        const content = new TextEncoder().encode("pseudo-effect");
        const contentHash = await sha256Hex(content);

        let res = await post("/content", {
            entries: [
                {
                    family: "dogma_effects",
                    content_hash: contentHash,
                    content_b64: toBase64(content),
                },
            ],
        });
        expect(res.status).toBe(200);

        res = await post("/register", {
            server_id: serverId,
            snapshot_hash: snapshotHash,
            entries: [{ family: "dogma_effects", entry_id: -64, content_hash: contentHash }],
        });
        expect(res.status).toBe(200);
        expect(await res.json()).toEqual({ ok: true, inserted: 1 });
    });

    it("rejects entry IDs outside the int32 range", async () => {
        const snapshotHash = "ef".repeat(32);
        const contentHash = "ab".repeat(32);

        for (const entryId of [-2147483649, 2147483648]) {
            const res = await post("/register", {
                server_id: "tranquility",
                snapshot_hash: snapshotHash,
                entries: [{ family: "types", entry_id: entryId, content_hash: contentHash }],
            });
            expect(res.status).toBe(400);
        }
    });
});
