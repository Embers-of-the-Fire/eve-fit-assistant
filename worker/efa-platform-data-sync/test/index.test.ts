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

// ---------------------------------------------------------------------------
// Folded per-family segments (migrations/0003_folded.sql).
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
        type: "content",
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

describe("segment content", () => {
    it("verifies hashes, resolves blob ids, and converges on rerun", async () => {
        const ws = await connect();
        const [segment] = await foldSegments([
            { id: 587, content: new TextEncoder().encode("type-entry-587") },
            { id: -64, content: new TextEncoder().encode("pseudo-entry") },
        ]);

        const before = await call(ws, {
            id: 1,
            type: "lookup",
            family: "types",
            content_hashes: [segment.hash],
        });
        expect(before).toEqual({ id: 1, ok: true, missing: [segment.hash], ids: {} });

        const { blobId, inserted } = await uploadSegment(ws, 2, "types", segment);
        expect(inserted).toBe(1);
        expect(blobId).toBeGreaterThan(0);

        const after = await call(ws, {
            id: 3,
            type: "lookup",
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
            type: "content",
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

    it("rejects segment metadata that disagrees with the verified content", async () => {
        const ws = await connect();
        const [segment] = await foldSegments([
            { id: 587, content: new TextEncoder().encode("type-entry-587") },
            { id: 600, content: new TextEncoder().encode("type-entry-600") },
        ]);
        // entry_count, first/last_entry_id are not covered by the content
        // hash; each mismatch must be rejected against the parsed index.
        for (const metadata of [
            { entry_count: 1, first_entry_id: 587, last_entry_id: 600 },
            { entry_count: 3, first_entry_id: 587, last_entry_id: 600 },
            { entry_count: 2, first_entry_id: 588, last_entry_id: 600 },
            { entry_count: 2, first_entry_id: 587, last_entry_id: 599 },
        ]) {
            const reply = await call(ws, {
                id: 1,
                type: "content",
                family: "types",
                content_hash: segment.hash,
                ...metadata,
                content_b64: toBase64(segment.bytes),
            });
            expect(reply.id).toBe(1);
            expect(reply.ok).toBe(false);
            expect(reply.error).toBe("Content verification failed");
        }
        // Nothing was stored: the same content with correct metadata still
        // inserts (a retry repairs what INSERT OR IGNORE would otherwise
        // have frozen in).
        const { inserted } = await uploadSegment(ws, 2, "types", segment);
        expect(inserted).toBe(1);
        ws.close();
    });

    it("rejects segments whose index overruns the content", async () => {
        const ws = await connect();
        // Hash-valid content whose header declares more index entries than
        // the buffer holds.
        const bytes = new Uint8Array(4);
        new DataView(bytes.buffer).setUint32(0, 2, true);
        const reply = await call(ws, {
            id: 1,
            type: "content",
            family: "types",
            content_hash: await sha256Hex(bytes),
            entry_count: 2,
            first_entry_id: 1,
            last_entry_id: 2,
            content_b64: toBase64(bytes),
        });
        expect(reply.id).toBe(1);
        expect(reply.ok).toBe(false);
        expect(reply.error).toBe("Content verification failed");
        ws.close();
    });

    it("rejects segments whose index entry ids are not strictly increasing", async () => {
        const ws = await connect();
        // Hash-valid content whose metadata (count, first/last) matches the
        // parsed index, but the ids are unsorted or duplicated. Readers
        // binary-search this index, and the stored blob is immutable
        // (INSERT OR IGNORE keeps the first row), so accepting it would
        // poison the family permanently.
        const build = (ids: number[]): Uint8Array => {
            const payload = new TextEncoder().encode("x");
            const bytes = new Uint8Array(4 + ids.length * 12 + ids.length * payload.length);
            const view = new DataView(bytes.buffer);
            view.setUint32(0, ids.length, true);
            let indexOffset = 4;
            let dataOffset = 4 + ids.length * 12;
            for (const id of ids) {
                view.setInt32(indexOffset, id, true);
                view.setUint32(indexOffset + 4, dataOffset, true);
                view.setUint32(indexOffset + 8, payload.length, true);
                bytes.set(payload, dataOffset);
                indexOffset += 12;
                dataOffset += payload.length;
            }
            return bytes;
        };
        for (const ids of [
            [2, 1],
            [1, 1],
        ]) {
            const bytes = build(ids);
            const hash = await sha256Hex(bytes);
            const reply = await call(ws, {
                id: 1,
                type: "content",
                family: "types",
                content_hash: hash,
                entry_count: ids.length,
                first_entry_id: ids[0],
                last_entry_id: ids[ids.length - 1],
                content_b64: toBase64(bytes),
            });
            expect(reply.id).toBe(1);
            expect(reply.ok).toBe(false);
            expect(reply.error).toBe("Content verification failed");
            expect(reply.rejected).toEqual([
                { family: "types", content_hash: hash, reason: "malformed segment index" },
            ]);
            // Nothing was stored for the crafted hash.
            const stored = await env.PLATFORM_DB.prepare(
                "SELECT COUNT(*) AS n FROM folded_blobs WHERE content_hash = ?",
            )
                .bind(hexToBlob(hash))
                .first<{ n: number }>();
            expect(stored?.n).toBe(0);
        }
        ws.close();
    });

    it("rejects oversize segments", async () => {
        const ws = await connect();
        const reply = await call(ws, {
            id: 1,
            type: "content",
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
                type: "content",
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

describe("snapshot freeze", () => {
    it("rejects register after complete and keeps the links frozen", async () => {
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
            type: "register",
            server_id: serverId,
            snapshot_hash: snapshotHash,
            segments: [{ family: "types", seq: 0, blob_id: blobId }],
        });
        expect(reply).toEqual({ id: 2, ok: true, inserted: 1 });

        reply = await call(ws, {
            id: 3,
            type: "complete",
            server_id: serverId,
            snapshot_hash: snapshotHash,
            entry_count: 3,
        });
        expect(reply).toEqual({ id: 3, ok: true });

        // Idempotent retry of the same complete frame (lost reply).
        reply = await call(ws, {
            id: 4,
            type: "complete",
            server_id: serverId,
            snapshot_hash: snapshotHash,
            entry_count: 3,
        });
        expect(reply).toEqual({ id: 4, ok: true });

        reply = await call(ws, {
            id: 5,
            type: "register",
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
            type: "register",
            server_id: serverId,
            snapshot_hash: snapshotHash,
            segments: [{ family: "types", seq: 0, blob_id: blobId }],
        });

        // The link SUM is 2; claiming 3 fails with the real count reported,
        // and the snapshot stays pending.
        const failed = await call(ws, {
            id: 3,
            type: "complete",
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
            type: "complete",
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
            type: "register",
            server_id: "tranquility",
            snapshot_hash: "ef".repeat(32),
            segments: [{ family: "types", seq: 0, blob_id: 424242 }],
        });
        expect(reply.id).toBe(1);
        expect(reply.ok).toBe(false);
        expect(reply.error).toBe("Unknown blob ids");
        ws.close();
    });

    it("rejects frames linking the same blob id more than once per family", async () => {
        const ws = await connect();
        const serverId = "tranquility";
        const snapshotHash = "fa".repeat(32);

        const [segment] = await foldSegments([
            { id: 1, content: new TextEncoder().encode("type-entry-1") },
            { id: 2, content: new TextEncoder().encode("type-entry-2") },
        ]);
        const { blobId } = await uploadSegment(ws, 1, "types", segment);

        // The same blob at two seq values would double-count entry_count in
        // the freeze SUM and enumerate the segment twice in readers'
        // catalogs; the frame is rejected before writing anything.
        let reply = await call(ws, {
            id: 2,
            type: "register",
            server_id: serverId,
            snapshot_hash: snapshotHash,
            segments: [
                { family: "types", seq: 0, blob_id: blobId },
                { family: "types", seq: 1, blob_id: blobId },
            ],
        });
        expect(reply.id).toBe(2);
        expect(reply.ok).toBe(false);
        expect(reply.error).toBe("Duplicate segment links");
        expect(reply.duplicates).toEqual([{ family: "types", blob_id: blobId }]);
        expect(await linkStats(serverId, snapshotHash)).toEqual({ links: 0, entries: 0 });

        // The same link registered once is fine, and a retry of the
        // identical frame stays idempotent (primary-key dedup).
        reply = await call(ws, {
            id: 3,
            type: "register",
            server_id: serverId,
            snapshot_hash: snapshotHash,
            segments: [{ family: "types", seq: 0, blob_id: blobId }],
        });
        expect(reply).toEqual({ id: 3, ok: true, inserted: 1 });
        reply = await call(ws, {
            id: 4,
            type: "register",
            server_id: serverId,
            snapshot_hash: snapshotHash,
            segments: [{ family: "types", seq: 0, blob_id: blobId }],
        });
        expect(reply).toEqual({ id: 4, ok: true, inserted: 0 });

        // The happy path still freezes at the real entry count.
        reply = await call(ws, {
            id: 5,
            type: "complete",
            server_id: serverId,
            snapshot_hash: snapshotHash,
            entry_count: 2,
        });
        expect(reply).toEqual({ id: 5, ok: true });
        expect(await linkStats(serverId, snapshotHash)).toEqual({ links: 1, entries: 2 });
        ws.close();
    });

    it("never freezes mid-registration even when register and complete race", async () => {
        // Register/complete race regression test: register and complete
        // frames for the same snapshot are serialized in the Durable Object
        // (runSerialized), and the per-statement freeze guards plus the SUM
        // check are the SQL-level backstop. Whichever side runs first, a
        // frozen snapshot's entry_count must equal its actual segment-link
        // SUM.
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
                type: "register",
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
                    type: "register",
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
                    type: "complete",
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
