// SyncSession Durable Object: WebSocket endpoint for snapshot uploads.
//
// The old HTTP API uploaded thousands of rows per request, so a single Worker
// invocation carried the whole base64 decode + hash-verify + D1 batch chain
// and regularly died with 503s. Here the uploader holds one WebSocket to a
// single named instance ("sync") and streams small JSON frames; every frame
// is its own event with its own CPU budget, and the SQLite-backed instance
// hibernates between frames (no duration charges while idle).
//
// Protocol: every client frame is a JSON object with a `type` discriminator
// and a client-chosen integer `id`; the server replies with one JSON object
// carrying the same `id`. All operations are idempotent (INSERT OR IGNORE /
// INSERT OR REPLACE), so a client that loses the connection may reconnect and
// resend the unacknowledged frame — or rerun the whole sync, which converges
// via the `lookup`/`snapshot` frames.
//
// Client frames:
//   {type: "content",  id, entries: [{family, content_hash, content_b64}]}
//       -> {id, ok: true, inserted} — INSERT OR IGNORE per-entry payloads,
//          each verified against its SHA-256 content hash.
//   {type: "lookup",   id, family, content_hashes: [hex]}
//       -> {id, ok: true, missing: [hex]} — subset of the given hashes not
//          yet present in the family content table (resume support).
//   {type: "register", id, server_id, snapshot_hash, entries: [{family, entry_id, content_hash}]}
//       -> {id, ok: true, inserted} — registration rows, conditional on the
//          snapshot not being frozen by a `complete` marker yet.
//   {type: "complete", id, server_id, snapshot_hash, entry_count}
//       -> {id, ok: true} — writes the `snapshots` completeness marker after
//          verifying the actual registration row count server-side.
//   {type: "snapshot", id, server_id, snapshot_hash}
//       -> {id, ok: true, complete: bool, entry_count?, completed_at?} —
//          completeness probe so reruns can skip finished snapshots.
//
// Error replies carry {id, ok: false, error, ...details}.

import { DurableObject } from "cloudflare:workers";
import { z } from "zod";
import type { Env } from "./index.ts";

const FAMILIES = {
    types: { content: "types", reg: "types_reg" },
    type_dogma: { content: "type_dogma", reg: "type_dogma_reg" },
    dogma_attributes: { content: "dogma_attributes", reg: "dogma_attributes_reg" },
    dogma_effects: { content: "dogma_effects", reg: "dogma_effects_reg" },
    buffs: { content: "buffs", reg: "buffs_reg" },
    type_meta: { content: "type_meta", reg: "type_meta_reg" },
    dogma_attribute_meta: {
        content: "dogma_attribute_meta",
        reg: "dogma_attribute_meta_reg",
    },
    dogma_effect_meta: { content: "dogma_effect_meta", reg: "dogma_effect_meta_reg" },
} as const;

type Family = keyof typeof FAMILIES;

const HASH_RE = /^[0-9a-f]{64}$/;
const FamilySchema = z.enum(Object.keys(FAMILIES) as [Family, ...Family[]]);
const IdSchema = z.number().int().nonnegative();

// Per-frame caps. Frames are deliberately small: each one is a separate Durable
// Object event with its own CPU budget, so modest frames keep every event far
// below the limit and give the uploader fast acks.
const CONTENT_ENTRIES_PER_FRAME = 2000;
const REGISTER_ENTRIES_PER_FRAME = 2000;
const LOOKUP_HASHES_PER_FRAME = 10000;

const ContentEntrySchema = z.object({
    family: FamilySchema,
    content_hash: z.string().regex(HASH_RE),
    content_b64: z.base64().min(1),
});

const RegisterEntrySchema = z.object({
    family: FamilySchema,
    // Engine-internal pseudo attributes/effects carry negative int32 IDs.
    entry_id: z.number().int().gte(-2147483648).lte(2147483647),
    content_hash: z.string().regex(HASH_RE),
});

const SnapshotSelectorSchema = z.object({
    server_id: z.string().min(1),
    snapshot_hash: z.string().regex(HASH_RE),
});

const ClientMessageSchema = z.discriminatedUnion("type", [
    z.object({
        type: z.literal("content"),
        id: IdSchema,
        entries: z.array(ContentEntrySchema).min(1).max(CONTENT_ENTRIES_PER_FRAME),
    }),
    z.object({
        type: z.literal("lookup"),
        id: IdSchema,
        family: FamilySchema,
        content_hashes: z.array(z.string().regex(HASH_RE)).min(1).max(LOOKUP_HASHES_PER_FRAME),
    }),
    z.object({
        type: z.literal("register"),
        id: IdSchema,
        ...SnapshotSelectorSchema.shape,
        entries: z.array(RegisterEntrySchema).min(1).max(REGISTER_ENTRIES_PER_FRAME),
    }),
    z.object({
        type: z.literal("complete"),
        id: IdSchema,
        ...SnapshotSelectorSchema.shape,
        entry_count: z.number().int().nonnegative(),
    }),
    z.object({
        type: z.literal("snapshot"),
        id: IdSchema,
        ...SnapshotSelectorSchema.shape,
    }),
]);

// D1 allows at most 100 bound parameters per statement.
const CONTENT_ROWS_PER_STATEMENT = 50; // 2 params per row
const REGISTER_ROWS_PER_STATEMENT = 24; // 4 params per row + 2 freeze-guard params
const HASHES_PER_LOOKUP = 100;
const STATEMENTS_PER_BATCH = 50;

function base64ToBytes(value: string): Uint8Array {
    const binary = atob(value);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) {
        bytes[i] = binary.charCodeAt(i);
    }
    return bytes;
}

function bytesToHex(bytes: Uint8Array): string {
    let hex = "";
    for (const b of bytes) {
        hex += b.toString(16).padStart(2, "0");
    }
    return hex;
}

// Matches bootstrap/remote/hash.py content_hash(): plain SHA-256 of the raw
// bytes, lowercase hex, no prefix or envelope.
async function sha256Hex(data: Uint8Array): Promise<string> {
    const digest = await crypto.subtle.digest("SHA-256", data.buffer as ArrayBuffer);
    return bytesToHex(new Uint8Array(digest));
}

function chunked<T>(items: T[], size: number): T[][] {
    const chunks: T[][] = [];
    for (let offset = 0; offset < items.length; offset += size) {
        chunks.push(items.slice(offset, offset + size));
    }
    return chunks;
}

// Expected, client-visible failures (bad hashes, frozen snapshots, incomplete
// counts). Anything else bubbles up as a generic internal error.
class SyncFailure extends Error {
    constructor(public body: Record<string, unknown>) {
        super(String(body.error ?? "Sync failure"));
    }
}

type ContentEntry = z.infer<typeof ContentEntrySchema>;
type RegisterEntry = z.infer<typeof RegisterEntrySchema>;

async function handleContent(
    db: D1Database,
    entries: ContentEntry[],
): Promise<{ inserted: number }> {
    const byFamily = new Map<Family, { hash: string; content: Uint8Array }[]>();
    const rejected: { family: Family; content_hash: string; reason: string }[] = [];
    for (const entry of entries) {
        let content: Uint8Array;
        try {
            content = base64ToBytes(entry.content_b64);
        } catch {
            rejected.push({
                family: entry.family,
                content_hash: entry.content_hash,
                reason: "invalid base64",
            });
            continue;
        }
        const actual = await sha256Hex(content);
        if (actual !== entry.content_hash) {
            rejected.push({
                family: entry.family,
                content_hash: entry.content_hash,
                reason: `hash mismatch: content hashes to ${actual}`,
            });
            continue;
        }
        const rows = byFamily.get(entry.family) ?? [];
        rows.push({ hash: entry.content_hash, content });
        byFamily.set(entry.family, rows);
    }
    if (rejected.length > 0) {
        throw new SyncFailure({
            error: "Content verification failed",
            rejected: rejected.slice(0, 100),
        });
    }

    let inserted = 0;
    for (const [family, rows] of byFamily) {
        const table = FAMILIES[family].content;
        const statements: D1PreparedStatement[] = [];
        for (const chunk of chunked(rows, CONTENT_ROWS_PER_STATEMENT)) {
            const placeholders = chunk.map(() => "(?, ?)").join(", ");
            const binds: (string | ArrayBuffer)[] = chunk.flatMap((row) => [
                row.hash,
                row.content.buffer as ArrayBuffer,
            ]);
            statements.push(
                db
                    .prepare(
                        `INSERT OR IGNORE INTO ${table} (content_hash, content) VALUES ${placeholders}`,
                    )
                    .bind(...binds),
            );
        }
        for (const batch of chunked(statements, STATEMENTS_PER_BATCH)) {
            const results = await db.batch(batch);
            for (const result of results) {
                inserted += result.meta.changes ?? 0;
            }
        }
    }
    return { inserted };
}

async function handleLookup(
    db: D1Database,
    family: Family,
    contentHashes: string[],
): Promise<{ missing: string[] }> {
    const table = FAMILIES[family].content;
    const missing: string[] = [];
    for (const chunk of chunked([...new Set(contentHashes)], HASHES_PER_LOOKUP)) {
        const placeholders = chunk.map(() => "?").join(", ");
        const found = await db
            .prepare(`SELECT content_hash FROM ${table} WHERE content_hash IN (${placeholders})`)
            .bind(...chunk)
            .all<{ content_hash: string }>();
        const foundSet = new Set(found.results.map((row) => row.content_hash));
        for (const hash of chunk) {
            if (!foundSet.has(hash)) {
                missing.push(hash);
            }
        }
    }
    return { missing };
}

async function handleRegister(
    db: D1Database,
    serverId: string,
    snapshotHash: string,
    entries: RegisterEntry[],
): Promise<{ inserted: number }> {
    const byFamily = new Map<Family, { id: number; hash: string }[]>();
    for (const entry of entries) {
        const rows = byFamily.get(entry.family) ?? [];
        rows.push({ id: entry.entry_id, hash: entry.content_hash });
        byFamily.set(entry.family, rows);
    }

    // Referential integrity: every registered content hash must already exist.
    const missing: { family: Family; content_hash: string }[] = [];
    for (const [family, rows] of byFamily) {
        const result = await handleLookup(
            db,
            family,
            rows.map((row) => row.hash),
        );
        for (const hash of result.missing) {
            missing.push({ family, content_hash: hash });
        }
    }
    if (missing.length > 0) {
        throw new SyncFailure({ error: "Unknown content hashes", missing: missing.slice(0, 100) });
    }

    let inserted = 0;
    for (const [family, rows] of byFamily) {
        const table = FAMILIES[family].reg;
        const statements: D1PreparedStatement[] = [];
        for (const chunk of chunked(rows, REGISTER_ROWS_PER_STATEMENT)) {
            const placeholders = chunk.map(() => "(?, ?, ?, ?)").join(", ");
            const binds = chunk.flatMap((row) => [serverId, snapshotHash, row.id, row.hash]);
            binds.push(serverId, snapshotHash);
            statements.push(
                db
                    .prepare(
                        `INSERT OR IGNORE INTO ${table} ` +
                            "(server_id, snapshot_hash, entry_id, content_hash) " +
                            `SELECT column1, column2, column3, column4 FROM (VALUES ${placeholders}) ` +
                            "WHERE NOT EXISTS (" +
                            "SELECT 1 FROM snapshots WHERE server_id = ? AND snapshot_hash = ?" +
                            ")",
                    )
                    .bind(...binds),
            );
        }
        for (const batch of chunked(statements, STATEMENTS_PER_BATCH)) {
            const results = await db.batch(batch);
            for (const result of results) {
                inserted += result.meta.changes ?? 0;
            }
        }
    }

    const snapshot = await db
        .prepare("SELECT entry_count FROM snapshots WHERE server_id = ? AND snapshot_hash = ?")
        .bind(serverId, snapshotHash)
        .first();
    if (snapshot) {
        throw new SyncFailure({ error: "Snapshot already complete" });
    }
    return { inserted };
}

async function handleComplete(
    db: D1Database,
    serverId: string,
    snapshotHash: string,
    entryCount: number,
): Promise<Record<string, never>> {
    // Verify completeness server-side: the marker is only written when the
    // registration rows actually present match the uploader's entry count.
    let registered = 0;
    for (const family of Object.keys(FAMILIES) as Family[]) {
        const table = FAMILIES[family].reg;
        const row = await db
            .prepare(`SELECT COUNT(*) AS n FROM ${table} WHERE server_id = ? AND snapshot_hash = ?`)
            .bind(serverId, snapshotHash)
            .first<{ n: number }>();
        registered += row?.n ?? 0;
    }
    if (registered !== entryCount) {
        throw new SyncFailure({
            error: "Snapshot incomplete",
            expected: entryCount,
            registered,
        });
    }

    await db
        .prepare(
            "INSERT OR REPLACE INTO snapshots (server_id, snapshot_hash, entry_count) VALUES (?, ?, ?)",
        )
        .bind(serverId, snapshotHash, entryCount)
        .run();
    return {};
}

async function handleSnapshot(
    db: D1Database,
    serverId: string,
    snapshotHash: string,
): Promise<{ complete: boolean; entry_count?: number; completed_at?: string }> {
    const row = await db
        .prepare(
            "SELECT entry_count, completed_at FROM snapshots WHERE server_id = ? AND snapshot_hash = ?",
        )
        .bind(serverId, snapshotHash)
        .first<{ entry_count: number; completed_at: string }>();
    if (!row) {
        return { complete: false };
    }
    return { complete: true, entry_count: row.entry_count, completed_at: row.completed_at };
}

export class SyncSession extends DurableObject<Env> {
    fetch(_request: Request): Response {
        // Auth runs in the worker middleware before the request is forwarded
        // here; the worker route already rejected non-upgrade requests.
        const { 0: client, 1: server } = new WebSocketPair();
        this.ctx.acceptWebSocket(server);
        return new Response(null, { status: 101, webSocket: client });
    }

    async webSocketMessage(ws: WebSocket, message: string | ArrayBuffer): Promise<void> {
        let raw: unknown;
        try {
            const text = typeof message === "string" ? message : new TextDecoder().decode(message);
            raw = JSON.parse(text);
        } catch {
            ws.send(JSON.stringify({ ok: false, error: "Invalid JSON message" }));
            return;
        }
        const parsed = ClientMessageSchema.safeParse(raw);
        if (!parsed.success) {
            // Echo the client id when it is at least structurally present, so
            // the uploader can correlate the rejection with its request.
            const id = z.object({ id: IdSchema }).safeParse(raw);
            ws.send(
                JSON.stringify({
                    ...(id.success ? { id: id.data.id } : {}),
                    ok: false,
                    error: "Validation failed",
                    details: parsed.error.issues,
                }),
            );
            return;
        }

        const msg = parsed.data;
        try {
            const reply: Record<string, unknown> = { id: msg.id, ok: true };
            switch (msg.type) {
                case "content":
                    Object.assign(reply, await handleContent(this.env.PLATFORM_DB, msg.entries));
                    break;
                case "lookup":
                    Object.assign(
                        reply,
                        await handleLookup(this.env.PLATFORM_DB, msg.family, msg.content_hashes),
                    );
                    break;
                case "register":
                    Object.assign(
                        reply,
                        await handleRegister(
                            this.env.PLATFORM_DB,
                            msg.server_id,
                            msg.snapshot_hash,
                            msg.entries,
                        ),
                    );
                    break;
                case "complete":
                    await handleComplete(
                        this.env.PLATFORM_DB,
                        msg.server_id,
                        msg.snapshot_hash,
                        msg.entry_count,
                    );
                    break;
                case "snapshot":
                    Object.assign(
                        reply,
                        await handleSnapshot(
                            this.env.PLATFORM_DB,
                            msg.server_id,
                            msg.snapshot_hash,
                        ),
                    );
                    break;
            }
            ws.send(JSON.stringify(reply));
        } catch (err) {
            if (err instanceof SyncFailure) {
                ws.send(JSON.stringify({ id: msg.id, ok: false, ...err.body }));
                return;
            }
            console.error("Sync frame failed", err);
            ws.send(JSON.stringify({ id: msg.id, ok: false, error: "Internal server error" }));
        }
    }

    webSocketClose(ws: WebSocket, code: number, reason: string, _wasClean: boolean): void {
        // 1004/1005/1006/1015 are reserved pseudo-codes that must not be
        // echoed into a close frame.
        const echoable =
            (code >= 1000 && code <= 1014 && code !== 1004 && code !== 1005 && code !== 1006) ||
            (code >= 3000 && code <= 4999);
        ws.close(echoable ? code : 1000, echoable ? reason : "");
    }

    webSocketError(ws: WebSocket, _error: unknown): void {
        ws.close(1011, "Internal error");
    }
}
