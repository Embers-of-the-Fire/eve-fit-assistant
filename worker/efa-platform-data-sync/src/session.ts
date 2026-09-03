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
//       -> {id, ok: true} — freezes the snapshot after verifying the
//          registration count server-side. The check compares the
//          register-maintained registered_count counter in one atomic
//          conditional UPDATE (a real COUNT(*) scan only runs to repair a
//          counter diverged by a crash), and a retry of the same frame
//          after a lost reply succeeds. Register and complete frames for
//          the same snapshot are serialized in instance memory
//          (runSerialized), so the counter is settled whenever complete
//          evaluates it; the per-statement freeze guards remain as the
//          SQL-level backstop.
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
    registered_count: number;
}

// Resolve (server_id, snapshot_hash) to its registry row, if any.
async function findSnapshot(
    db: D1Database,
    serverId: string,
    snapshotHash: string,
): Promise<SnapshotRow | null> {
    return await db
        .prepare(
            "SELECT snapshot_id, entry_count, completed_at, registered_count FROM snapshots " +
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
    // insert plus the completed_at probe in the final batch below. Register
    // and complete handlers for the same snapshot are serialized in the
    // Durable Object (runSerialized), but that is instance memory — these
    // SQL guards are the backstop for any writer that bypasses it.
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
    // so a concurrent complete that bypassed the instance-level
    // serialization either committed before it (the guards above inserted
    // nothing and the probe observes the freeze, rejecting this frame) or
    // runs after it (and counts these rows in its own atomic
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
    // Maintain the O(1) completion counter: add only the rows this frame
    // actually inserted (INSERT OR IGNORE conflicts contribute 0, so re-sent
    // frames never inflate it). The UPDATE commits separately from the
    // insert batches above; a crash in between leaves the counter short,
    // which the complete frame's fallback detects and repairs with one real
    // COUNT(*). Incrementing an already-frozen snapshot is harmless: frozen
    // rows are never re-verified.
    if (inserted > 0) {
        await db
            .prepare(
                "UPDATE snapshots SET registered_count = registered_count + ? " +
                    "WHERE snapshot_id = ?",
            )
            .bind(inserted, snapshot.snapshot_id)
            .run();
    }
    return { inserted };
}

// The freezing UPDATE: the count verification, the not-yet-frozen check, and
// the marker write are a single statement, so a concurrent register frame
// that bypassed the instance-level serialization can never slip rows in
// between the verification and the freeze. The count check compares
// registered_count — maintained incrementally by register frames — instead
// of scanning snapshot_entries: a COUNT(*) here costs a full index-range
// scan of the snapshot's registration rows.
async function freezeSnapshot(
    db: D1Database,
    snapshotId: number,
    entryCount: number,
): Promise<boolean> {
    const result = await db
        .prepare(
            "UPDATE snapshots SET entry_count = ?, " +
                "completed_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now') " +
                "WHERE snapshot_id = ? AND completed_at IS NULL AND registered_count = ?",
        )
        .bind(entryCount, snapshotId, entryCount)
        .run();
    return (result.meta.changes ?? 0) > 0;
}

async function countRegistrations(db: D1Database, snapshotId: number): Promise<number> {
    const row = await db
        .prepare("SELECT COUNT(*) AS n FROM snapshot_entries WHERE snapshot_id = ?")
        .bind(snapshotId)
        .first<{ n: number }>();
    return row?.n ?? 0;
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

    if (await freezeSnapshot(db, snapshot.snapshot_id, entryCount)) {
        return {};
    }

    // The conditional update matched no row: a concurrent complete won the
    // race, the registration count genuinely differs, or the counter
    // diverged from the rows (a crash between a register frame's inserts and
    // its counter update, or a pre-0002 pending snapshot). Re-read the
    // registry row, then fall back to one real COUNT(*) to disambiguate.
    const state = await findSnapshot(db, serverId, snapshotHash);
    if (state?.completed_at != null) {
        if (state.entry_count === entryCount) {
            return {};
        }
        throw new SyncFailure({ error: "Snapshot already complete" });
    }
    const registered = await countRegistrations(db, snapshot.snapshot_id);
    if (registered !== entryCount) {
        throw new SyncFailure({
            error: "Snapshot incomplete",
            expected: entryCount,
            registered,
        });
    }

    // Complete row set behind a diverged counter: repair it (CAS on the
    // value read above, so a concurrent register frame's increment is kept)
    // and retry the freeze once.
    await db
        .prepare(
            "UPDATE snapshots SET registered_count = ? " +
                "WHERE snapshot_id = ? AND registered_count = ?",
        )
        .bind(registered, snapshot.snapshot_id, state?.registered_count ?? 0)
        .run();
    if (await freezeSnapshot(db, snapshot.snapshot_id, entryCount)) {
        return {};
    }
    // The retry matched no row: a concurrent complete or register won the
    // race in between. Report from a fresh read.
    const final = await findSnapshot(db, serverId, snapshotHash);
    if (final?.completed_at != null) {
        if (final.entry_count === entryCount) {
            return {};
        }
        throw new SyncFailure({ error: "Snapshot already complete" });
    }
    throw new SyncFailure({
        error: "Snapshot incomplete",
        expected: entryCount,
        registered: final?.registered_count ?? registered,
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
    // Per-snapshot mutual exclusion between register and complete handlers.
    // The freeze fast path trusts registered_count, which a register frame
    // updates only after its insert batches commit; serializing the two
    // handlers per snapshot guarantees no register frame is mid-flight when
    // complete evaluates the counter. This is instance memory, so a
    // restarted instance starts empty — safe, because an instance is never
    // evicted while it is still processing a frame, and a crashed register
    // frame's divergence is repaired by the complete fallback's COUNT(*).
    // The per-statement freeze guards remain the SQL-level backstop.
    private readonly snapshotLocks = new Map<string, Promise<unknown>>();

    // Run `task` after every previously queued register/complete handler for
    // the same snapshot settles; settled chains remove themselves so the map
    // does not grow without bound.
    private async runSerialized<T>(key: string, task: () => Promise<T>): Promise<T> {
        const previous = this.snapshotLocks.get(key) ?? Promise.resolve();
        const current = (async () => {
            // A failed predecessor must not block the chain.
            await previous.catch(() => {});
            return await task();
        })();
        const tail = current
            .catch(() => {})
            .finally(() => {
                if (this.snapshotLocks.get(key) === tail) {
                    this.snapshotLocks.delete(key);
                }
            });
        this.snapshotLocks.set(key, tail);
        return await current;
    }

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
                        await this.runSerialized(`${msg.server_id}:${msg.snapshot_hash}`, () =>
                            handleRegister(
                                this.env.PLATFORM_DB,
                                msg.server_id,
                                msg.snapshot_hash,
                                msg.entries,
                            ),
                        ),
                    );
                    break;
                case "complete":
                    await this.runSerialized(`${msg.server_id}:${msg.snapshot_hash}`, () =>
                        handleComplete(
                            this.env.PLATFORM_DB,
                            msg.server_id,
                            msg.snapshot_hash,
                            msg.entry_count,
                        ),
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
