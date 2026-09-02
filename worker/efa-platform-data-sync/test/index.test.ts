// Endpoint tests against the real local bindings provided by the Workers
// Vitest integration: PLATFORM_DB is a genuine D1 database (migrated from
// migrations/ by the test setup file) and SYNC_SESSION a real Durable Object,
// not re-implemented shims. Uploads go through the WebSocket protocol
// terminated by the SyncSession object; completeness probes additionally
// exercise the public HTTP GET routes.

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

async function connect(): Promise<WebSocket> {
    const res = await worker.fetch(
        new Request(`https://example.com${MOUNT}/sync`, {
            headers: { Upgrade: "websocket", Authorization: `Bearer ${TOKEN}` },
        }),
        env,
    );
    expect(res.status).toBe(101);
    const ws = res.webSocket;
    if (!ws) {
        throw new Error("Expected a WebSocket on the upgrade response");
    }
    ws.accept();
    return ws;
}

// Synchronous request/reply helper: tests never pipeline frames on one
// socket, so the next message event after send() is this frame's reply.
function call(ws: WebSocket, message: Record<string, unknown>): Promise<Record<string, unknown>> {
    return new Promise((resolve, reject) => {
        const onMessage = (event: MessageEvent) => {
            ws.removeEventListener("message", onMessage);
            ws.removeEventListener("close", onClose);
            resolve(JSON.parse(event.data as string) as Record<string, unknown>);
        };
        const onClose = () => {
            ws.removeEventListener("message", onMessage);
            reject(new Error("WebSocket closed before reply"));
        };
        ws.addEventListener("message", onMessage);
        ws.addEventListener("close", onClose);
        ws.send(JSON.stringify(message));
    });
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

function hexToBlob(hex: string): ArrayBuffer {
    const bytes = new Uint8Array(hex.length / 2);
    for (let i = 0; i < bytes.length; i++) {
        bytes[i] = Number.parseInt(hex.slice(i * 2, i * 2 + 2), 16);
    }
    return bytes.buffer as ArrayBuffer;
}

describe("sync route access", () => {
    it("rejects unauthenticated upgrade requests", async () => {
        const res = await worker.fetch(
            new Request(`https://example.com${MOUNT}/sync`, {
                headers: { Upgrade: "websocket" },
            }),
            env,
        );
        expect(res.status).toBe(401);
    });

    it("rejects authenticated non-upgrade requests", async () => {
        const res = await worker.fetch(
            new Request(`https://example.com${MOUNT}/sync`, {
                headers: { Authorization: `Bearer ${TOKEN}` },
            }),
            env,
        );
        expect(res.status).toBe(426);
    });
});

describe("frame validation", () => {
    it("replies with an error for malformed and invalid frames", async () => {
        const ws = await connect();

        const malformed = await new Promise<Record<string, unknown>>((resolve) => {
            ws.addEventListener("message", function onMessage(event) {
                ws.removeEventListener("message", onMessage);
                resolve(JSON.parse(event.data as string) as Record<string, unknown>);
            });
            ws.send("not json");
        });
        expect(malformed.ok).toBe(false);
        expect(malformed.error).toBe("Invalid JSON message");

        const invalid = await call(ws, { id: 1, type: "unknown-type" });
        expect(invalid.id).toBe(1);
        expect(invalid.ok).toBe(false);
        expect(invalid.error).toBe("Validation failed");

        ws.close();
    });
});

describe("lookup", () => {
    it("reports missing hashes and resolves ids for present rows", async () => {
        const ws = await connect();
        const content = new TextEncoder().encode("type-entry-1");
        const contentHash = await sha256Hex(content);

        const before = await call(ws, {
            id: 1,
            type: "lookup",
            family: "types",
            content_hashes: [contentHash],
        });
        expect(before).toEqual({ id: 1, ok: true, missing: [contentHash], ids: {} });

        const upload = await call(ws, {
            id: 2,
            type: "content",
            entries: [
                { family: "types", content_hash: contentHash, content_b64: toBase64(content) },
            ],
        });
        const ids = upload.ids as Record<string, number>;
        expect(ids[contentHash]).toBeGreaterThan(0);

        const after = await call(ws, {
            id: 3,
            type: "lookup",
            family: "types",
            content_hashes: [contentHash, "00".repeat(32)],
        });
        expect(after).toEqual({
            id: 3,
            ok: true,
            missing: ["00".repeat(32)],
            ids: { [contentHash]: ids[contentHash] },
        });

        ws.close();
    });
});

describe("snapshot freeze", () => {
    it("rejects register after complete and keeps the registration set frozen", async () => {
        const ws = await connect();
        const serverId = "tranquility";
        const snapshotHash = "ab".repeat(32);

        const content = new TextEncoder().encode("type-entry-1");
        const contentHash = await sha256Hex(content);

        let reply = await call(ws, {
            id: 1,
            type: "content",
            entries: [
                { family: "types", content_hash: contentHash, content_b64: toBase64(content) },
            ],
        });
        expect(reply.id).toBe(1);
        expect(reply.ok).toBe(true);
        expect(reply.inserted).toBe(1);
        const contentId = (reply.ids as Record<string, number>)[contentHash];
        expect(contentId).toBeGreaterThan(0);

        reply = await call(ws, {
            id: 2,
            type: "register",
            server_id: serverId,
            snapshot_hash: snapshotHash,
            entries: [{ family: "types", entry_id: 1, content_id: contentId }],
        });
        expect(reply).toEqual({ id: 2, ok: true, inserted: 1 });

        reply = await call(ws, {
            id: 3,
            type: "complete",
            server_id: serverId,
            snapshot_hash: snapshotHash,
            entry_count: 1,
        });
        expect(reply).toEqual({ id: 3, ok: true });

        reply = await call(ws, {
            id: 4,
            type: "register",
            server_id: serverId,
            snapshot_hash: snapshotHash,
            entries: [{ family: "types", entry_id: 2, content_id: contentId }],
        });
        expect(reply.id).toBe(4);
        expect(reply.ok).toBe(false);
        expect(reply.error).toBe("Snapshot already complete");

        const regCount = await env.PLATFORM_DB.prepare(
            "SELECT COUNT(*) AS n FROM snapshot_entries se " +
                "JOIN snapshots s ON s.snapshot_id = se.snapshot_id " +
                "WHERE s.server_id = ? AND s.snapshot_hash = ?",
        )
            .bind(serverId, hexToBlob(snapshotHash))
            .first<{ n: number }>();
        expect(regCount?.n).toBe(1);

        // The snapshot probe agrees over both the WS frame and the public
        // HTTP GET route.
        reply = await call(ws, {
            id: 5,
            type: "snapshot",
            server_id: serverId,
            snapshot_hash: snapshotHash,
        });
        expect(reply.id).toBe(5);
        expect(reply.ok).toBe(true);
        expect(reply.complete).toBe(true);
        expect(reply.entry_count).toBe(1);

        const res = await get(`/snapshot?server_id=${serverId}&snapshot_hash=${snapshotHash}`);
        expect(res.status).toBe(200);
        const snapshot = (await res.json()) as {
            ok: boolean;
            complete: boolean;
            entry_count: number;
        };
        expect(snapshot.complete).toBe(true);
        expect(snapshot.entry_count).toBe(1);

        ws.close();
    });

    it("never freezes a snapshot whose entry_count disagrees with its rows", async () => {
        // Regression test for the register/complete race: Durable Object
        // input gates do not cover external D1 operations, so a complete
        // event can run between a register event's completed_at check and
        // its inserts. The register frame below spans multiple D1 batches
        // (2000 entries at 24 rows/statement over 50-statement batches) so
        // the concurrent complete has real windows to interleave. Whichever
        // side wins, the invariant must hold: a frozen snapshot's
        // entry_count equals its actual registration row count.
        const content = new TextEncoder().encode("type-entry-1");
        const contentHash = await sha256Hex(content);

        for (let round = 0; round < 5; round++) {
            const ws1 = await connect();
            const ws2 = await connect();
            const serverId = "tranquility";
            const snapshotHash = round.toString(16).padStart(2, "0").repeat(32);

            const upload = await call(ws1, {
                id: 1,
                type: "content",
                entries: [
                    { family: "types", content_hash: contentHash, content_b64: toBase64(content) },
                ],
            });
            const contentId = (upload.ids as Record<string, number>)[contentHash];

            const first = await call(ws1, {
                id: 2,
                type: "register",
                server_id: serverId,
                snapshot_hash: snapshotHash,
                entries: [{ family: "types", entry_id: 1, content_id: contentId }],
            });
            expect(first).toEqual({ id: 2, ok: true, inserted: 1 });

            // Fire both frames without awaiting so the two events interleave
            // at their D1 awaits.
            const [registerReply, completeReply] = await Promise.all([
                call(ws1, {
                    id: 3,
                    type: "register",
                    server_id: serverId,
                    snapshot_hash: snapshotHash,
                    entries: Array.from({ length: 2000 }, (_, i) => ({
                        family: "types",
                        entry_id: i + 2,
                        content_id: contentId,
                    })),
                }),
                call(ws2, {
                    id: 4,
                    type: "complete",
                    server_id: serverId,
                    snapshot_hash: snapshotHash,
                    entry_count: 1,
                }),
            ]);

            const regCount = await env.PLATFORM_DB.prepare(
                "SELECT COUNT(*) AS n FROM snapshot_entries se " +
                    "JOIN snapshots s ON s.snapshot_id = se.snapshot_id " +
                    "WHERE s.server_id = ? AND s.snapshot_hash = ?",
            )
                .bind(serverId, hexToBlob(snapshotHash))
                .first<{ n: number }>();

            const probe = await call(ws1, {
                id: 5,
                type: "snapshot",
                server_id: serverId,
                snapshot_hash: snapshotHash,
            });

            if (completeReply.ok) {
                // Completion won before any register batch committed: the
                // freeze guards must have rejected every later insert.
                expect(registerReply.ok).toBe(false);
                expect(registerReply.error).toBe("Snapshot already complete");
                expect(regCount?.n).toBe(1);
                expect(probe.complete).toBe(true);
                expect(probe.entry_count).toBe(1);
            } else {
                // The register committed rows the count check then saw, so
                // completion must have failed instead of freezing a lie.
                expect(completeReply.error).toBe("Snapshot incomplete");
                expect(registerReply.ok).toBe(true);
                expect(regCount?.n).toBe(2001);
                expect(probe.complete).toBe(false);
            }

            ws1.close();
            ws2.close();
        }
    });

    it("reports pending (registered but not completed) snapshots as incomplete", async () => {
        const ws = await connect();
        const serverId = "tranquility";
        const snapshotHash = "12".repeat(32);

        const content = new TextEncoder().encode("type-entry-1");
        const contentHash = await sha256Hex(content);
        const upload = await call(ws, {
            id: 1,
            type: "content",
            entries: [
                { family: "types", content_hash: contentHash, content_b64: toBase64(content) },
            ],
        });
        const contentId = (upload.ids as Record<string, number>)[contentHash];

        await call(ws, {
            id: 2,
            type: "register",
            server_id: serverId,
            snapshot_hash: snapshotHash,
            entries: [{ family: "types", entry_id: 1, content_id: contentId }],
        });

        const reply = await call(ws, {
            id: 3,
            type: "snapshot",
            server_id: serverId,
            snapshot_hash: snapshotHash,
        });
        expect(reply).toEqual({ id: 3, ok: true, complete: false });

        const res = await get(`/snapshot?server_id=${serverId}&snapshot_hash=${snapshotHash}`);
        const snapshot = (await res.json()) as { complete: boolean };
        expect(snapshot.complete).toBe(false);

        ws.close();
    });

    it("rejects registration of unknown content ids", async () => {
        const ws = await connect();
        const reply = await call(ws, {
            id: 1,
            type: "register",
            server_id: "tranquility",
            snapshot_hash: "cd".repeat(32),
            entries: [{ family: "types", entry_id: 1, content_id: 424242 }],
        });
        expect(reply.id).toBe(1);
        expect(reply.ok).toBe(false);
        expect(reply.error).toBe("Unknown content ids");
        ws.close();
    });
});

describe("entry_id validation", () => {
    it("accepts negative entry IDs used by engine-internal pseudo entries", async () => {
        const ws = await connect();
        const serverId = "tranquility";
        const snapshotHash = "cd".repeat(32);

        const content = new TextEncoder().encode("pseudo-effect");
        const contentHash = await sha256Hex(content);

        let reply = await call(ws, {
            id: 1,
            type: "content",
            entries: [
                {
                    family: "dogma_effects",
                    content_hash: contentHash,
                    content_b64: toBase64(content),
                },
            ],
        });
        expect(reply.id).toBe(1);
        expect(reply.ok).toBe(true);
        expect(reply.inserted).toBe(1);
        const contentId = (reply.ids as Record<string, number>)[contentHash];

        reply = await call(ws, {
            id: 2,
            type: "register",
            server_id: serverId,
            snapshot_hash: snapshotHash,
            entries: [{ family: "dogma_effects", entry_id: -64, content_id: contentId }],
        });
        expect(reply).toEqual({ id: 2, ok: true, inserted: 1 });

        ws.close();
    });

    it("rejects entry IDs outside the int32 range", async () => {
        const ws = await connect();
        for (const entryId of [-2147483649, 2147483648]) {
            const reply = await call(ws, {
                id: 1,
                type: "register",
                server_id: "tranquility",
                snapshot_hash: "ef".repeat(32),
                entries: [{ family: "types", entry_id: entryId, content_id: 1 }],
            });
            expect(reply.id).toBe(1);
            expect(reply.ok).toBe(false);
            expect(reply.error).toBe("Validation failed");
        }
        ws.close();
    });
});
