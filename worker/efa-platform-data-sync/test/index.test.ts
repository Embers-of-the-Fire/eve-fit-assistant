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
    // Chunked: spreading a whole segment into fromCharCode overflows the
    // call stack at ~512 KiB payloads.
    let binary = "";
    for (let i = 0; i < data.length; i += 0x8000) {
        binary += String.fromCharCode(...data.subarray(i, i + 0x8000));
    }
    return btoa(binary);
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
        // Regression test for the register/complete race: register and
        // complete frames for the same snapshot are serialized in the
        // Durable Object (runSerialized), and the per-statement freeze
        // guards plus the counter check are the SQL-level backstop. The
        // register frame below spans multiple D1 batches (2000 entries at
        // 24 rows/statement over 50-statement batches), so without the
        // serialization a complete event would have real windows to
        // interleave. Whichever side runs first, the invariant must hold:
        // a frozen snapshot's entry_count equals its actual registration
        // row count.
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

describe("registration counter", () => {
    async function snapshotRow(
        serverId: string,
        snapshotHash: string,
    ): Promise<{
        snapshot_id: number;
        entry_count: number | null;
        completed_at: string | null;
        registered_count: number;
    } | null> {
        return await env.PLATFORM_DB.prepare(
            "SELECT snapshot_id, entry_count, completed_at, registered_count FROM snapshots " +
                "WHERE server_id = ? AND snapshot_hash = ?",
        )
            .bind(serverId, hexToBlob(snapshotHash))
            .first<{
                snapshot_id: number;
                entry_count: number | null;
                completed_at: string | null;
                registered_count: number;
            }>();
    }

    async function uploadType(ws: WebSocket, id: number, label: string): Promise<number> {
        const content = new TextEncoder().encode(label);
        const contentHash = await sha256Hex(content);
        const reply = await call(ws, {
            id,
            type: "content",
            entries: [
                { family: "types", content_hash: contentHash, content_b64: toBase64(content) },
            ],
        });
        expect(reply.ok).toBe(true);
        return (reply.ids as Record<string, number>)[contentHash];
    }

    it("tracks registrations across frames and freezes via the counter", async () => {
        const ws = await connect();
        const serverId = "tranquility";
        const snapshotHash = "aa".repeat(32);
        const contentId = await uploadType(ws, 1, "type-entry-1");

        for (let frame = 0; frame < 3; frame++) {
            const reply = await call(ws, {
                id: 10 + frame,
                type: "register",
                server_id: serverId,
                snapshot_hash: snapshotHash,
                entries: [{ family: "types", entry_id: frame + 1, content_id: contentId }],
            });
            expect(reply).toEqual({ id: 10 + frame, ok: true, inserted: 1 });
        }
        expect((await snapshotRow(serverId, snapshotHash))?.registered_count).toBe(3);

        const complete = await call(ws, {
            id: 20,
            type: "complete",
            server_id: serverId,
            snapshot_hash: snapshotHash,
            entry_count: 3,
        });
        expect(complete).toEqual({ id: 20, ok: true });

        const row = await snapshotRow(serverId, snapshotHash);
        expect(row?.completed_at).not.toBeNull();
        expect(row?.entry_count).toBe(3);
        ws.close();
    });

    it("does not inflate the counter on re-sent register frames", async () => {
        const ws = await connect();
        const serverId = "tranquility";
        const snapshotHash = "bb".repeat(32);
        const contentId = await uploadType(ws, 1, "type-entry-1");

        const frame = {
            type: "register",
            server_id: serverId,
            snapshot_hash: snapshotHash,
            entries: [{ family: "types", entry_id: 1, content_id: contentId }],
        };
        expect(await call(ws, { id: 2, ...frame })).toEqual({ id: 2, ok: true, inserted: 1 });
        // Idempotent re-send (lost reply): all rows conflict, so the counter
        // must stay at 1.
        expect(await call(ws, { id: 3, ...frame })).toEqual({ id: 3, ok: true, inserted: 0 });
        expect((await snapshotRow(serverId, snapshotHash))?.registered_count).toBe(1);

        const complete = await call(ws, {
            id: 4,
            type: "complete",
            server_id: serverId,
            snapshot_hash: snapshotHash,
            entry_count: 1,
        });
        expect(complete).toEqual({ id: 4, ok: true });
        ws.close();
    });

    it("repairs a diverged counter before freezing", async () => {
        const ws = await connect();
        const serverId = "tranquility";
        const snapshotHash = "cc".repeat(32);
        const contentId = await uploadType(ws, 1, "type-entry-1");

        const register = await call(ws, {
            id: 2,
            type: "register",
            server_id: serverId,
            snapshot_hash: snapshotHash,
            entries: [{ family: "types", entry_id: 1, content_id: contentId }],
        });
        expect(register).toEqual({ id: 2, ok: true, inserted: 1 });

        // Simulate a crash between a register frame's inserts and its
        // counter update: the row exists but registered_count does not
        // reflect it (also the state of a pre-0002 pending snapshot).
        const row = await snapshotRow(serverId, snapshotHash);
        await env.PLATFORM_DB.prepare(
            "INSERT INTO snapshot_entries (snapshot_id, family, entry_id, content_id) " +
                "VALUES (?, 0, 2, ?)",
        )
            .bind(row?.snapshot_id, contentId)
            .run();
        expect((await snapshotRow(serverId, snapshotHash))?.registered_count).toBe(1);

        const complete = await call(ws, {
            id: 3,
            type: "complete",
            server_id: serverId,
            snapshot_hash: snapshotHash,
            entry_count: 2,
        });
        expect(complete).toEqual({ id: 3, ok: true });

        const repaired = await snapshotRow(serverId, snapshotHash);
        expect(repaired?.completed_at).not.toBeNull();
        expect(repaired?.entry_count).toBe(2);
        expect(repaired?.registered_count).toBe(2);
        ws.close();
    });

    it("reports a genuinely incomplete snapshot with the real row count", async () => {
        const ws = await connect();
        const serverId = "tranquility";
        const snapshotHash = "dd".repeat(32);
        const contentId = await uploadType(ws, 1, "type-entry-1");

        await call(ws, {
            id: 2,
            type: "register",
            server_id: serverId,
            snapshot_hash: snapshotHash,
            entries: [{ family: "types", entry_id: 1, content_id: contentId }],
        });
        const row = await snapshotRow(serverId, snapshotHash);
        await env.PLATFORM_DB.prepare(
            "INSERT INTO snapshot_entries (snapshot_id, family, entry_id, content_id) " +
                "VALUES (?, 0, 2, ?)",
        )
            .bind(row?.snapshot_id, contentId)
            .run();

        // Counter says 1, the uploader claims 3, the truth is 2: the error
        // must report the real row count, and the snapshot stays pending.
        const reply = await call(ws, {
            id: 3,
            type: "complete",
            server_id: serverId,
            snapshot_hash: snapshotHash,
            entry_count: 3,
        });
        expect(reply.id).toBe(3);
        expect(reply.ok).toBe(false);
        expect(reply.error).toBe("Snapshot incomplete");
        expect(reply.registered).toBe(2);
        expect((await snapshotRow(serverId, snapshotHash))?.completed_at).toBeNull();
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

// ---------------------------------------------------------------------------
// Storage v3: folded per-family segments (migrations/0003_folded.sql).
// ---------------------------------------------------------------------------

const SEGMENT_MAX = 512 * 1024;

interface SegmentDef {
    entries: { id: number; content: Uint8Array }[];
    bytes: Uint8Array;
    hash: string;
}

// Mirrors bootstrap/data/d1/sync.py::fold_family: sort by entry id, greedy
// pack <=512 KiB at entry boundaries, u32 count + (i32 id, u32 off, u32 len)
// index + concatenated payloads.
async function foldSegments(entries: { id: number; content: Uint8Array }[]): Promise<SegmentDef[]> {
    const sorted = [...entries].sort((a, b) => a.id - b.id);
    const groups: { id: number; content: Uint8Array }[][] = [];
    let current: { id: number; content: Uint8Array }[] = [];
    let size = 4;
    for (const entry of sorted) {
        const entrySize = 12 + entry.content.length;
        if (current.length > 0 && size + entrySize > SEGMENT_MAX) {
            groups.push(current);
            current = [];
            size = 4;
        }
        current.push(entry);
        size += entrySize;
    }
    if (current.length > 0) {
        groups.push(current);
    }
    const segments: SegmentDef[] = [];
    for (const group of groups) {
        const bytes = new Uint8Array(
            4 + group.length * 12 + group.reduce((n, e) => n + e.content.length, 0),
        );
        const view = new DataView(bytes.buffer);
        view.setUint32(0, group.length, true);
        let indexOffset = 4;
        let dataOffset = 4 + group.length * 12;
        for (const entry of group) {
            view.setInt32(indexOffset, entry.id, true);
            view.setUint32(indexOffset + 4, dataOffset, true);
            view.setUint32(indexOffset + 8, entry.content.length, true);
            bytes.set(entry.content, dataOffset);
            indexOffset += 12;
            dataOffset += entry.content.length;
        }
        segments.push({ entries: group, bytes, hash: await sha256Hex(bytes) });
    }
    return segments;
}

async function uploadSegment(
    ws: WebSocket,
    id: number,
    family: string,
    segment: SegmentDef,
): Promise<{ blobId: number; inserted: number }> {
    const reply = await call(ws, {
        id,
        type: "segment",
        family,
        content_hash: segment.hash,
        entry_count: segment.entries.length,
        first_entry_id: segment.entries[0].id,
        last_entry_id: segment.entries[segment.entries.length - 1].id,
        content_b64: toBase64(segment.bytes),
    });
    expect(reply.id).toBe(id);
    expect(reply.ok).toBe(true);
    return { blobId: reply.blob_id as number, inserted: reply.inserted as number };
}

async function linkStats(
    serverId: string,
    snapshotHash: string,
): Promise<{ links: number; entries: number } | null> {
    return await env.PLATFORM_DB.prepare(
        "SELECT COUNT(*) AS links, COALESCE(SUM(b.entry_count), 0) AS entries " +
            "FROM snapshot_family_segments s " +
            "JOIN folded_blobs b ON b.blob_id = s.blob_id " +
            "JOIN snapshots sn ON sn.snapshot_id = s.snapshot_id " +
            "WHERE sn.server_id = ? AND sn.snapshot_hash = ?",
    )
        .bind(serverId, hexToBlob(snapshotHash))
        .first<{ links: number; entries: number }>();
}

describe("v3 segment content", () => {
    it("verifies hashes, resolves blob ids, and converges on rerun", async () => {
        const ws = await connect();
        const [segment] = await foldSegments([
            { id: 587, content: new TextEncoder().encode("type-entry-587") },
            { id: -64, content: new TextEncoder().encode("pseudo-entry") },
        ]);

        const before = await call(ws, {
            id: 1,
            type: "segment_lookup",
            family: "types",
            content_hashes: [segment.hash],
        });
        expect(before).toEqual({ id: 1, ok: true, missing: [segment.hash], ids: {} });

        const { blobId, inserted } = await uploadSegment(ws, 2, "types", segment);
        expect(inserted).toBe(1);
        expect(blobId).toBeGreaterThan(0);

        const after = await call(ws, {
            id: 3,
            type: "segment_lookup",
            family: "types",
            content_hashes: [segment.hash, "00".repeat(32)],
        });
        expect(after).toEqual({
            id: 3,
            ok: true,
            missing: ["00".repeat(32)],
            ids: { [segment.hash]: blobId },
        });

        // Rerun convergence: re-uploading the same segment inserts nothing
        // and resolves the same blob id.
        const rerun = await uploadSegment(ws, 4, "types", segment);
        expect(rerun).toEqual({ blobId, inserted: 0 });

        ws.close();
    });

    it("rejects segments whose content hashes differently", async () => {
        const ws = await connect();
        const [segment] = await foldSegments([
            { id: 1, content: new TextEncoder().encode("type-entry-1") },
        ]);
        const reply = await call(ws, {
            id: 1,
            type: "segment",
            family: "types",
            content_hash: "00".repeat(32),
            entry_count: 1,
            first_entry_id: 1,
            last_entry_id: 1,
            content_b64: toBase64(segment.bytes),
        });
        expect(reply.id).toBe(1);
        expect(reply.ok).toBe(false);
        expect(reply.error).toBe("Content verification failed");
        ws.close();
    });

    it("rejects oversize segments", async () => {
        const ws = await connect();
        const reply = await call(ws, {
            id: 1,
            type: "segment",
            family: "types",
            content_hash: "00".repeat(32),
            entry_count: 1,
            first_entry_id: 1,
            last_entry_id: 1,
            // Over the ~700 KiB base64 cap (512 KiB raw segments).
            content_b64: "AAAA".repeat(200 * 1024),
        });
        expect(reply.id).toBe(1);
        expect(reply.ok).toBe(false);
        expect(reply.error).toBe("Validation failed");
        ws.close();
    });

    it("rejects segment entry ids outside the int32 range", async () => {
        const ws = await connect();
        for (const entryId of [-2147483649, 2147483648]) {
            const reply = await call(ws, {
                id: 1,
                type: "segment",
                family: "types",
                content_hash: "00".repeat(32),
                entry_count: 1,
                first_entry_id: entryId,
                last_entry_id: entryId,
                content_b64: toBase64(new Uint8Array([0])),
            });
            expect(reply.id).toBe(1);
            expect(reply.ok).toBe(false);
            expect(reply.error).toBe("Validation failed");
        }
        ws.close();
    });
});

describe("v3 snapshot freeze", () => {
    it("rejects segment_register after segment_complete and keeps the links frozen", async () => {
        const ws = await connect();
        const serverId = "tranquility";
        const snapshotHash = "ab".repeat(32);

        const segments = await foldSegments([
            { id: 1, content: new TextEncoder().encode("type-entry-1") },
            { id: 2, content: new TextEncoder().encode("type-entry-2") },
            { id: 3, content: new TextEncoder().encode("type-entry-3") },
        ]);
        expect(segments).toHaveLength(1);
        const { blobId } = await uploadSegment(ws, 1, "types", segments[0]);

        let reply = await call(ws, {
            id: 2,
            type: "segment_register",
            server_id: serverId,
            snapshot_hash: snapshotHash,
            segments: [{ family: "types", seq: 0, blob_id: blobId }],
        });
        expect(reply).toEqual({ id: 2, ok: true, inserted: 1 });

        reply = await call(ws, {
            id: 3,
            type: "segment_complete",
            server_id: serverId,
            snapshot_hash: snapshotHash,
            entry_count: 3,
        });
        expect(reply).toEqual({ id: 3, ok: true });

        // Idempotent retry of the same complete frame (lost reply).
        reply = await call(ws, {
            id: 4,
            type: "segment_complete",
            server_id: serverId,
            snapshot_hash: snapshotHash,
            entry_count: 3,
        });
        expect(reply).toEqual({ id: 4, ok: true });

        reply = await call(ws, {
            id: 5,
            type: "segment_register",
            server_id: serverId,
            snapshot_hash: snapshotHash,
            segments: [{ family: "types", seq: 1, blob_id: blobId }],
        });
        expect(reply.id).toBe(5);
        expect(reply.ok).toBe(false);
        expect(reply.error).toBe("Snapshot already complete");

        const stats = await linkStats(serverId, snapshotHash);
        expect(stats).toEqual({ links: 1, entries: 3 });

        reply = await call(ws, {
            id: 6,
            type: "snapshot",
            server_id: serverId,
            snapshot_hash: snapshotHash,
        });
        expect(reply.complete).toBe(true);
        expect(reply.entry_count).toBe(3);

        ws.close();
    });

    it("never freezes a snapshot whose entry_count disagrees with the segment SUM", async () => {
        const ws = await connect();
        const serverId = "tranquility";
        const snapshotHash = "cd".repeat(32);

        const [segment] = await foldSegments([
            { id: 1, content: new TextEncoder().encode("type-entry-1") },
            { id: 2, content: new TextEncoder().encode("type-entry-2") },
        ]);
        const { blobId } = await uploadSegment(ws, 1, "types", segment);
        await call(ws, {
            id: 2,
            type: "segment_register",
            server_id: serverId,
            snapshot_hash: snapshotHash,
            segments: [{ family: "types", seq: 0, blob_id: blobId }],
        });

        // The link SUM is 2; claiming 3 fails with the real count reported,
        // and the snapshot stays pending.
        const failed = await call(ws, {
            id: 3,
            type: "segment_complete",
            server_id: serverId,
            snapshot_hash: snapshotHash,
            entry_count: 3,
        });
        expect(failed.id).toBe(3);
        expect(failed.ok).toBe(false);
        expect(failed.error).toBe("Snapshot incomplete");
        expect(failed.registered).toBe(2);

        const probe = await call(ws, {
            id: 4,
            type: "snapshot",
            server_id: serverId,
            snapshot_hash: snapshotHash,
        });
        expect(probe.complete).toBe(false);

        // The corrected claim freezes.
        const complete = await call(ws, {
            id: 5,
            type: "segment_complete",
            server_id: serverId,
            snapshot_hash: snapshotHash,
            entry_count: 2,
        });
        expect(complete).toEqual({ id: 5, ok: true });
        ws.close();
    });

    it("rejects registration of unknown blob ids", async () => {
        const ws = await connect();
        const reply = await call(ws, {
            id: 1,
            type: "segment_register",
            server_id: "tranquility",
            snapshot_hash: "ef".repeat(32),
            segments: [{ family: "types", seq: 0, blob_id: 424242 }],
        });
        expect(reply.id).toBe(1);
        expect(reply.ok).toBe(false);
        expect(reply.error).toBe("Unknown blob ids");
        ws.close();
    });

    it("never freezes mid-registration even when register and complete race", async () => {
        // Port of the v2 register/complete race regression test to the v3
        // frames: whichever side runs first, a frozen snapshot's entry_count
        // must equal its actual segment-link SUM.
        for (let round = 0; round < 5; round++) {
            const ws1 = await connect();
            const ws2 = await connect();
            const serverId = "tranquility";
            const snapshotHash = round.toString(16).padStart(2, "0").repeat(32);

            // 16 KiB payloads: 48 entries fold into 2 segments (>512 KiB
            // total), so registration spans multiple links.
            const segments = await foldSegments(
                Array.from({ length: 48 }, (_, i) => ({
                    id: i + 1,
                    content: new Uint8Array(16 * 1024).fill(i % 251),
                })),
            );
            expect(segments.length).toBeGreaterThan(1);
            const blobIds: number[] = [];
            for (const [i, segment] of segments.entries()) {
                blobIds.push((await uploadSegment(ws1, 100 + i, "types", segment)).blobId);
            }
            const firstCount = segments[0].entries.length;
            const restCount = segments.slice(1).reduce((n, s) => n + s.entries.length, 0);

            const first = await call(ws1, {
                id: 1,
                type: "segment_register",
                server_id: serverId,
                snapshot_hash: snapshotHash,
                segments: [{ family: "types", seq: 0, blob_id: blobIds[0] }],
            });
            expect(first).toEqual({ id: 1, ok: true, inserted: 1 });

            // Fire both frames without awaiting so the two events interleave
            // at their D1 awaits.
            const [registerReply, completeReply] = await Promise.all([
                call(ws1, {
                    id: 2,
                    type: "segment_register",
                    server_id: serverId,
                    snapshot_hash: snapshotHash,
                    segments: segments.slice(1).map((_, i) => ({
                        family: "types",
                        seq: i + 1,
                        blob_id: blobIds[i + 1],
                    })),
                }),
                call(ws2, {
                    id: 3,
                    type: "segment_complete",
                    server_id: serverId,
                    snapshot_hash: snapshotHash,
                    entry_count: firstCount,
                }),
            ]);

            const stats = await linkStats(serverId, snapshotHash);
            const probe = await call(ws1, {
                id: 4,
                type: "snapshot",
                server_id: serverId,
                snapshot_hash: snapshotHash,
            });

            if (completeReply.ok) {
                // Completion won before the register committed: the freeze
                // guards must have rejected every later link insert.
                expect(registerReply.ok).toBe(false);
                expect(registerReply.error).toBe("Snapshot already complete");
                expect(stats).toEqual({ links: 1, entries: firstCount });
                expect(probe.complete).toBe(true);
                expect(probe.entry_count).toBe(firstCount);
            } else {
                // The register committed links the SUM check then saw, so
                // completion must have failed instead of freezing a lie.
                expect(completeReply.error).toBe("Snapshot incomplete");
                expect(registerReply.ok).toBe(true);
                expect(stats).toEqual({
                    links: segments.length,
                    entries: firstCount + restCount,
                });
                expect(probe.complete).toBe(false);
            }

            ws1.close();
            ws2.close();
        }
    });
});
