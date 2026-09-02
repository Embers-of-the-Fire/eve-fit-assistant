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
// carrying the same `id`. All operations are idempotent (INSERT OR IGNORE),
// so a client that loses the connection may reconnect and resend the
// unacknowledged frame — or rerun the whole sync, which converges via the
// `lookup`/`snapshot` frames.
//
// Storage v2 (see migrations/0001_init.sql): hashes cross the wire as
// lowercase hex but are stored as raw 32-byte BLOBs, and registration rows
// reference dense database-local integer ids (snapshot_id, content_id)
// instead of repeating both hashes per row.
//
// Client frames:
//   {type: "content",  id, entries: [{family, content_hash, content_b64}]}
//       -> {id, ok: true, inserted, ids: {content_hash: content_id}} —
//          INSERT OR IGNORE per-entry payloads, each verified against its
//          SHA-256 content hash, then the content ids of the frame's entries
//          (present and freshly inserted alike) are resolved for the client.
//          `ids` is keyed by hash alone: ids are only unique per
//          (family, hash), so a frame must not carry identical content bytes
//          under two families (the uploader sends one family per frame).
//   {type: "lookup",   id, family, content_hashes: [hex]}
//       -> {id, ok: true, missing: [hex], ids: {content_hash: content_id}} —
//          hashes not yet present in the family, plus the content ids of the
//          present ones (resume support).
//   {type: "register", id, server_id, snapshot_hash, entries: [{family, entry_id, content_id}]}
//       -> {id, ok: true, inserted} — registration rows, conditional on the
//          snapshot not being frozen by a `complete` marker yet.
//   {type: "complete", id, server_id, snapshot_hash, entry_count}
//       -> {id, ok: true} — freezes the snapshot after verifying the actual
//          registration row count server-side; the count check and the
//          freeze are one atomic UPDATE, and a retry of the same frame after
//          a lost reply succeeds.
//   {type: "snapshot", id, server_id, snapshot_hash}
//       -> {id, ok: true, complete: bool, entry_count?, completed_at?} —
//          completeness probe so reruns can skip finished snapshots.
//
// Error replies carry {id, ok: false, error, ...details}.

import { DurableObject } from "cloudflare:workers";
import { z } from "zod";
import type { Env } from "./index.ts";

// Family codes, mirrored in bootstrap/data/d1/sync.py and
// worker/efa-platform-fit-storage/src/prefetch.rs.
const FAMILY_CODES = {
    types: 0,
    type_dogma: 1,
    dogma_attributes: 2,
    dogma_effects: 3,
    buffs: 4,
    type_meta: 5,
    dogma_attribute_meta: 6,
    dogma_effect_meta: 7,
} as const;

type Family = keyof typeof FAMILY_CODES;

const HASH_RE = /^[0-9a-f]{64}$/;
const FamilySchema = z.enum(Object.keys(FAMILY_CODES) as [Family, ...Family[]]);
const IdSchema = z.number().int().nonnegative();

// Per-frame caps. Frames are deliberately small: each one is a separate Durable
// Object event with its own CPU budget, so modest frames keep every event far
// below the limit and give the uploader fast acks. The lookup cap also keeps
// the reply (hash -> id map) well under the 1 MiB WebSocket message limit.
const CONTENT_ENTRIES_PER_FRAME = 2000;
const REGISTER_ENTRIES_PER_FRAME = 2000;
const LOOKUP_HASHES_PER_FRAME = 5000;

const ContentEntrySchema = z.object({
    family: FamilySchema,
    content_hash: z.string().regex(HASH_RE),
    content_b64: z.base64().min(1),
});

const RegisterEntrySchema = z.object({
    family: FamilySchema,
    // Engine-internal pseudo attributes/effects carry negative int32 IDs.
    entry_id: z.number().int().gte(-2147483648).lte(2147483647),
    content_id: z.number().int().positive(),
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
const CONTENT_ROWS_PER_STATEMENT = 32; // 3 params per row
const REGISTER_ROWS_PER_STATEMENT = 24; // 4 params per row + 1 freeze-guard param
const HASHES_PER_LOOKUP = 49; // 2 params per hash (family + hash)
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

function hexToBytes(hex: string): Uint8Array {
    const bytes = new Uint8Array(hex.length / 2);
    for (let i = 0; i < bytes.length; i++) {
        bytes[i] = Number.parseInt(hex.slice(i * 2, i * 2 + 2), 16);
    }
    return bytes;
}

function hexToBlob(hex: string): ArrayBuffer {
    return hexToBytes(hex).buffer as ArrayBuffer;
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

interface SnapshotRow {
    snapshot_id: number;
    entry_count: number | null;
    completed_at: string | null;
}

// Resolve (server_id, snapshot_hash) to its registry row, if any.
async function findSnapshot(
    db: D1Database,
    serverId: string,
    snapshotHash: string,
): Promise<SnapshotRow | null> {
    return await db
        .prepare(
            "SELECT snapshot_id, entry_count, completed_at FROM snapshots " +
                "WHERE server_id = ? AND snapshot_hash = ?",
        )
        .bind(serverId, hexToBlob(snapshotHash))
        .first<SnapshotRow>();
}

// Resolve-or-create the pending registry row for a snapshot. Registration
// rows reference snapshot_id, so the row must exist before the first
// register frame; `complete` later fills entry_count/completed_at.
async function ensureSnapshot(
    db: D1Database,
    serverId: string,
    snapshotHash: string,
): Promise<SnapshotRow> {
    await db
        .prepare("INSERT OR IGNORE INTO snapshots (server_id, snapshot_hash) VALUES (?, ?)")
        .bind(serverId, hexToBlob(snapshotHash))
        .run();
    const row = await findSnapshot(db, serverId, snapshotHash);
    if (!row) {
        throw new Error("snapshots row missing after insert");
    }
    return row;
}

// Resolve the content ids of the given hashes in one family. Returns the
// hash -> id map for present rows and the list of missing hashes.
async function resolveContentIds(
    db: D1Database,
    family: Family,
    contentHashes: string[],
): Promise<{ ids: Record<string, number>; missing: string[] }> {
    const familyCode = FAMILY_CODES[family];
    const ids: Record<string, number> = {};
    const missing: string[] = [];
    for (const chunk of chunked([...new Set(contentHashes)], HASHES_PER_LOOKUP)) {
        const placeholders = chunk.map(() => "?").join(", ");
        const found = await db
            .prepare(
                "SELECT content_id, content_hash FROM entries " +
                    `WHERE family = ? AND content_hash IN (${placeholders})`,
            )
            .bind(familyCode, ...chunk.map(hexToBlob))
            .all<{ content_id: number; content_hash: ArrayBuffer }>();
        const foundSet = new Set<string>();
        for (const row of found.results) {
            const hex = bytesToHex(new Uint8Array(row.content_hash));
            ids[hex] = row.content_id;
            foundSet.add(hex);
        }
        for (const hash of chunk) {
            if (!foundSet.has(hash)) {
                missing.push(hash);
            }
        }
    }
    return { ids, missing };
}

async function handleContent(
    db: D1Database,
    entries: ContentEntry[],
): Promise<{ inserted: number; ids: Record<string, number> }> {
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
    const ids: Record<string, number> = {};
    for (const [family, rows] of byFamily) {
        const statements: D1PreparedStatement[] = [];
        for (const chunk of chunked(rows, CONTENT_ROWS_PER_STATEMENT)) {
            const placeholders = chunk.map(() => "(?, ?, ?)").join(", ");
            const binds: (number | ArrayBuffer)[] = chunk.flatMap((row) => [
                FAMILY_CODES[family],
                hexToBlob(row.hash),
                row.content.buffer as ArrayBuffer,
            ]);
            statements.push(
                db
                    .prepare(
                        "INSERT OR IGNORE INTO entries (family, content_hash, content) " +
                            `VALUES ${placeholders}`,
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
        // Resolve the ids of every row in the frame, freshly inserted and
        // pre-existing alike (INSERT OR IGNORE does not report which).
        const resolved = await resolveContentIds(
            db,
            family,
            rows.map((row) => row.hash),
        );
        Object.assign(ids, resolved.ids);
    }
    return { inserted, ids };
}

async function handleLookup(
    db: D1Database,
    family: Family,
    contentHashes: string[],
): Promise<{ missing: string[]; ids: Record<string, number> }> {
    return await resolveContentIds(db, family, contentHashes);
}

async function handleRegister(
    db: D1Database,
    serverId: string,
    snapshotHash: string,
    entries: RegisterEntry[],
): Promise<{ inserted: number }> {
    const snapshot = await ensureSnapshot(db, serverId, snapshotHash);
    // Fast path only. The authoritative freeze check is the guard on every
    // insert plus the completed_at probe in the final batch below: the
    // Durable Object input gate does not cover external D1 operations, so a
    // concurrent complete event can commit between this read and the inserts.
    if (snapshot.completed_at !== null) {
        throw new SyncFailure({ error: "Snapshot already complete" });
    }

    // Referential integrity: every referenced content id must exist and
    // belong to the entry's stated family.
    const missing: { family: Family; content_id: number }[] = [];
    const byFamily = new Map<Family, number[]>();
    for (const entry of entries) {
        const ids = byFamily.get(entry.family) ?? [];
        ids.push(entry.content_id);
        byFamily.set(entry.family, ids);
    }
    for (const [family, contentIds] of byFamily) {
        const familyCode = FAMILY_CODES[family];
        for (const chunk of chunked([...new Set(contentIds)], HASHES_PER_LOOKUP)) {
            const placeholders = chunk.map(() => "?").join(", ");
            const found = await db
                .prepare(
                    "SELECT content_id FROM entries " +
                        `WHERE family = ? AND content_id IN (${placeholders})`,
                )
                .bind(familyCode, ...chunk)
                .all<{ content_id: number }>();
            const foundSet = new Set(found.results.map((row) => row.content_id));
            for (const contentId of chunk) {
                if (!foundSet.has(contentId)) {
                    missing.push({ family, content_id: contentId });
                }
            }
        }
    }
    if (missing.length > 0) {
        throw new SyncFailure({ error: "Unknown content ids", missing: missing.slice(0, 100) });
    }

    const byFamilyEntries = new Map<Family, { id: number; contentId: number }[]>();
    for (const entry of entries) {
        const rows = byFamilyEntries.get(entry.family) ?? [];
        rows.push({ id: entry.entry_id, contentId: entry.content_id });
        byFamilyEntries.set(entry.family, rows);
    }

    let inserted = 0;
    const statements: D1PreparedStatement[] = [];
    for (const [family, rows] of byFamilyEntries) {
        const familyCode = FAMILY_CODES[family];
        for (const chunk of chunked(rows, REGISTER_ROWS_PER_STATEMENT)) {
            const placeholders = chunk.map(() => "(?, ?, ?, ?)").join(", ");
            const binds = [
                ...chunk.flatMap((row) => [
                    snapshot.snapshot_id,
                    familyCode,
                    row.id,
                    row.contentId,
                ]),
                snapshot.snapshot_id,
            ];
            // Every insert is conditional on the snapshot not being frozen:
            // INSERT OR IGNORE alone would silently add rows to an already
            // completed snapshot if a complete event won the race after the
            // fast-path check above. (SQLite names the columns of a VALUES
            // subquery column1..column4.)
            statements.push(
                db
                    .prepare(
                        "INSERT OR IGNORE INTO snapshot_entries " +
                            "(snapshot_id, family, entry_id, content_id) " +
                            "SELECT column1, column2, column3, column4 " +
                            `FROM (VALUES ${placeholders}) ` +
                            "WHERE EXISTS (SELECT 1 FROM snapshots " +
                            "WHERE snapshot_id = ? AND completed_at IS NULL)",
                    )
                    .bind(...binds),
            );
        }
    }
    // The final batch also probes completed_at. A batch commits atomically,
    // so a concurrent complete either committed before it (the guards above
    // inserted nothing and the probe observes the freeze, rejecting this
    // frame) or runs after it (and counts these rows in its own atomic
    // count-and-freeze update). Registration and completion therefore cannot
    // interleave into a frozen snapshot whose entry_count disagrees with its
    // registration set.
    const batches = chunked(statements, STATEMENTS_PER_BATCH);
    for (const [index, batch] of batches.entries()) {
        const isLast = index === batches.length - 1;
        if (isLast) {
            batch.push(
                db
                    .prepare("SELECT completed_at FROM snapshots WHERE snapshot_id = ?")
                    .bind(snapshot.snapshot_id),
            );
        }
        const results = await db.batch(batch);
        for (const result of isLast ? results.slice(0, -1) : results) {
            inserted += result.meta.changes ?? 0;
        }
        if (isLast) {
            const probe = results.at(-1)?.results[0] as { completed_at: string | null } | undefined;
            if (probe?.completed_at != null) {
                throw new SyncFailure({ error: "Snapshot already complete" });
            }
        }
    }
    return { inserted };
}

async function handleComplete(
    db: D1Database,
    serverId: string,
    snapshotHash: string,
    entryCount: number,
): Promise<Record<string, never>> {
    const snapshot = await findSnapshot(db, serverId, snapshotHash);
    if (!snapshot) {
        throw new SyncFailure({
            error: "Snapshot incomplete",
            expected: entryCount,
            registered: 0,
        });
    }

    // Idempotent retry of a complete frame whose reply was lost.
    if (snapshot.completed_at !== null) {
        if (snapshot.entry_count === entryCount) {
            return {};
        }
        throw new SyncFailure({ error: "Snapshot already complete" });
    }

    // Atomic completion: the count verification, the not-yet-frozen check,
    // and the marker write are a single UPDATE statement. A concurrent
    // register frame can therefore never slip rows in between the
    // verification and the freeze (the Durable Object input gate does not
    // cover external D1 operations).
    const result = await db
        .prepare(
            "UPDATE snapshots SET entry_count = ?, " +
                "completed_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now') " +
                "WHERE snapshot_id = ? AND completed_at IS NULL AND " +
                "(SELECT COUNT(*) FROM snapshot_entries WHERE snapshot_id = ?) = ?",
        )
        .bind(entryCount, snapshot.snapshot_id, snapshot.snapshot_id, entryCount)
        .run();
    if ((result.meta.changes ?? 0) > 0) {
        return {};
    }

    // The conditional update matched no row: a concurrent complete won the
    // race, or the registration count moved under us. Re-read to report
    // which one happened.
    const state = await db
        .prepare(
            "SELECT entry_count, completed_at, " +
                "(SELECT COUNT(*) FROM snapshot_entries WHERE snapshot_id = ?) AS registered " +
                "FROM snapshots WHERE snapshot_id = ?",
        )
        .bind(snapshot.snapshot_id, snapshot.snapshot_id)
        .first<{ entry_count: number | null; completed_at: string | null; registered: number }>();
    if (state?.completed_at != null) {
        if (state.entry_count === entryCount) {
            return {};
        }
        throw new SyncFailure({ error: "Snapshot already complete" });
    }
    throw new SyncFailure({
        error: "Snapshot incomplete",
        expected: entryCount,
        registered: state?.registered ?? 0,
    });
}

async function handleSnapshot(
    db: D1Database,
    serverId: string,
    snapshotHash: string,
): Promise<{ complete: boolean; entry_count?: number; completed_at?: string }> {
    const row = await db
        .prepare(
            "SELECT entry_count, completed_at FROM snapshots " +
                "WHERE server_id = ? AND snapshot_hash = ?",
        )
        .bind(serverId, hexToBlob(snapshotHash))
        .first<{ entry_count: number | null; completed_at: string | null }>();
    if (!row || row.completed_at === null) {
        return { complete: false };
    }
    return {
        complete: true,
        entry_count: row.entry_count ?? undefined,
        completed_at: row.completed_at,
    };
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
