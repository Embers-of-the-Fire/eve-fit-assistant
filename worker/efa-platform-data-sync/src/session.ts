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
// Storage (folded per-family segments, see migrations/0003_folded.sql): each
// family is folded into self-contained, content-addressed <=512 KiB segments
// stored in folded_blobs; per-snapshot links live in snapshot_family_segments.
// Hashes cross the wire as lowercase hex but are stored as raw 32-byte BLOBs,
// and link rows reference dense database-local integer ids (snapshot_id,
// blob_id) instead of repeating both hashes per row.
//
// Segment format (self-contained, entries sorted by entry id):
//   u32 count
//   count x { i32 entry_id, u32 offset, u32 length }  -- offset from segment
//   payload bytes (concatenated per-entry protobufs)
//
// Client frames:
//   {type: "content",  id, family, content_hash, entry_count,
//    first_entry_id, last_entry_id, content_b64}
//       -> {id, ok: true, inserted, blob_id} — one folded segment (<=512 KiB
//          raw, ~700 KiB base64 cap), SHA-256-verified, INSERT OR IGNORE
//          into folded_blobs; the reply resolves the database-local blob id.
//   {type: "lookup",   id, family, content_hashes: [hex]}
//       -> {id, ok: true, missing: [hex], ids: {content_hash: blob_id}} —
//          segment hashes not yet present in the family, plus the blob ids
//          of the present ones (resume support).
//   {type: "register", id, server_id, snapshot_hash,
//    segments: [{family, seq, blob_id}]}
//       -> {id, ok: true, inserted} — per-snapshot segment links, conditional
//          on the snapshot not being frozen by a `complete` marker yet. A
//          frame linking the same blob id more than once per family is
//          rejected (the freeze SUM counts entry_count once per link row).
//   {type: "complete", id, server_id, snapshot_hash, entry_count}
//       -> {id, ok: true} — freezes the snapshot after verifying
//          SUM(folded_blobs.entry_count) over the segment-link join inside
//          the single conditional UPDATE. Register and complete frames for
//          the same snapshot are serialized in instance memory
//          (runSerialized), so the SUM is settled whenever complete
//          evaluates it; the per-statement freeze guards remain as the
//          SQL-level backstop. A retry of the same frame after a lost reply
//          succeeds.
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
// below the limit and give the uploader fast acks. One segment per content
// frame, <=512 KiB raw; the base64 cap (~700 KiB) keeps the JSON frame well
// under the 1 MiB WebSocket message limit. Register frames carry one family's
// segment links (the largest family folds to ~25 segments at 512 KiB); 1000 is
// generous headroom, not an expected size. The lookup cap also keeps the reply
// (hash -> id map) well under the 1 MiB WebSocket message limit.
const SEGMENT_CONTENT_B64_MAX = 700 * 1024;
const SEGMENT_LINKS_PER_FRAME = 1000;
const SEGMENT_LOOKUP_HASHES_PER_FRAME = 5000;

// Engine-internal pseudo attributes/effects carry negative int32 IDs.
const EntryIdSchema = z.number().int().gte(-2147483648).lte(2147483647);

const SegmentLinkSchema = z.object({
    family: FamilySchema,
    seq: z.number().int().nonnegative(),
    blob_id: z.number().int().positive(),
});

const SnapshotSelectorSchema = z.object({
    server_id: z.string().min(1),
    snapshot_hash: z.string().regex(HASH_RE),
});

const ClientMessageSchema = z.discriminatedUnion("type", [
    z.object({
        type: z.literal("content"),
        id: IdSchema,
        family: FamilySchema,
        content_hash: z.string().regex(HASH_RE),
        entry_count: z.number().int().positive(),
        first_entry_id: EntryIdSchema,
        last_entry_id: EntryIdSchema,
        content_b64: z.base64().min(1).max(SEGMENT_CONTENT_B64_MAX),
    }),
    z.object({
        type: z.literal("lookup"),
        id: IdSchema,
        family: FamilySchema,
        content_hashes: z
            .array(z.string().regex(HASH_RE))
            .min(1)
            .max(SEGMENT_LOOKUP_HASHES_PER_FRAME),
    }),
    z.object({
        type: z.literal("register"),
        id: IdSchema,
        ...SnapshotSelectorSchema.shape,
        segments: z.array(SegmentLinkSchema).min(1).max(SEGMENT_LINKS_PER_FRAME),
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

type SegmentLink = z.infer<typeof SegmentLinkSchema>;

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

// Resolve-or-create the pending registry row for a snapshot. Link rows
// reference snapshot_id, so the row must exist before the first register
// frame; `complete` later fills entry_count/completed_at.
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

// ---------------------------------------------------------------------------
// Folded per-family segments (migrations/0003_folded.sql).
// ---------------------------------------------------------------------------

// Folded segment layout (mirrors bootstrap/data/d1/sync.py::fold_family and
// the 0003_folded.sql comment): u32 count, then count x (i32 entry_id,
// u32 offset, u32 length) index, then the concatenated payloads.
const SEGMENT_HEADER_BYTES = 4;
const SEGMENT_INDEX_ENTRY_BYTES = 12;

// Parse a verified segment's own index. Returns null when the buffer is too
// small to hold the index its header declares, declares zero entries, or the
// entry ids are not strictly increasing. The ordering guarantee matters:
// readers binary-search this index (prefetch's segment_extract), and the
// stored blob is immutable (INSERT OR IGNORE keeps the first row), so an
// unsorted or duplicate index accepted here would be unrepairable.
function parseSegmentIndex(
    content: Uint8Array,
): { count: number; firstId: number; lastId: number } | null {
    if (content.length < SEGMENT_HEADER_BYTES) {
        return null;
    }
    const view = new DataView(content.buffer, content.byteOffset, content.byteLength);
    const count = view.getUint32(0, true);
    if (count < 1 || SEGMENT_HEADER_BYTES + count * SEGMENT_INDEX_ENTRY_BYTES > content.length) {
        return null;
    }
    const firstId = view.getInt32(SEGMENT_HEADER_BYTES, true);
    let lastId = firstId;
    for (let i = 1; i < count; i++) {
        const id = view.getInt32(SEGMENT_HEADER_BYTES + i * SEGMENT_INDEX_ENTRY_BYTES, true);
        if (id <= lastId) {
            return null;
        }
        lastId = id;
    }
    return { count, firstId, lastId };
}

interface SegmentFrame {
    family: Family;
    content_hash: string;
    entry_count: number;
    first_entry_id: number;
    last_entry_id: number;
    content_b64: string;
}

// One folded segment: base64-decode, verify against its SHA-256 content
// hash, INSERT OR IGNORE, then resolve the database-local blob id (the row
// may have pre-existed, so the id is read back rather than derived from the
// insert result).
async function handleContent(
    db: D1Database,
    frame: SegmentFrame,
): Promise<{ inserted: number; blob_id: number }> {
    let content: Uint8Array;
    try {
        content = base64ToBytes(frame.content_b64);
    } catch {
        throw new SyncFailure({
            error: "Content verification failed",
            rejected: [
                {
                    family: frame.family,
                    content_hash: frame.content_hash,
                    reason: "invalid base64",
                },
            ],
        });
    }
    const actual = await sha256Hex(content);
    if (actual !== frame.content_hash) {
        throw new SyncFailure({
            error: "Content verification failed",
            rejected: [
                {
                    family: frame.family,
                    content_hash: frame.content_hash,
                    reason: `hash mismatch: content hashes to ${actual}`,
                },
            ],
        });
    }
    const familyCode = FAMILY_CODES[frame.family];
    // The hash proves the content, not the metadata: the stored entry_count
    // and first/last id range are trusted verbatim by freezeSnapshot
    // (SUM over entry_count) and prefetch's subset routing (find_segment
    // binary-searches the stored ranges). Parse the verified content's own
    // index and reject a frame whose metadata disagrees — INSERT OR IGNORE
    // keeps the first row for (family, content_hash), so a stored mismatch
    // could never be repaired by a retry.
    const index = parseSegmentIndex(content);
    if (index === null) {
        throw new SyncFailure({
            error: "Content verification failed",
            rejected: [
                {
                    family: frame.family,
                    content_hash: frame.content_hash,
                    reason: "malformed segment index",
                },
            ],
        });
    }
    if (
        index.count !== frame.entry_count ||
        index.firstId !== frame.first_entry_id ||
        index.lastId !== frame.last_entry_id
    ) {
        throw new SyncFailure({
            error: "Content verification failed",
            rejected: [
                {
                    family: frame.family,
                    content_hash: frame.content_hash,
                    reason:
                        `metadata mismatch: index has count=${index.count} ` +
                        `ids=[${index.firstId}, ${index.lastId}], frame declares ` +
                        `count=${frame.entry_count} ` +
                        `ids=[${frame.first_entry_id}, ${frame.last_entry_id}]`,
                },
            ],
        });
    }
    const inserted = await db
        .prepare(
            "INSERT OR IGNORE INTO folded_blobs " +
                "(family, content_hash, entry_count, first_entry_id, last_entry_id, content) " +
                "VALUES (?, ?, ?, ?, ?, ?)",
        )
        .bind(
            familyCode,
            hexToBlob(frame.content_hash),
            frame.entry_count,
            frame.first_entry_id,
            frame.last_entry_id,
            content.buffer as ArrayBuffer,
        )
        .run();
    const row = await db
        .prepare("SELECT blob_id FROM folded_blobs WHERE family = ? AND content_hash = ?")
        .bind(familyCode, hexToBlob(frame.content_hash))
        .first<{ blob_id: number }>();
    if (!row) {
        throw new Error("folded_blobs row missing after insert");
    }
    return { inserted: inserted.meta.changes ?? 0, blob_id: row.blob_id };
}

// Segment hashes not yet present in the family, plus the blob ids of the
// present ones (resume support).
async function handleLookup(
    db: D1Database,
    family: Family,
    contentHashes: string[],
): Promise<{ missing: string[]; ids: Record<string, number> }> {
    const familyCode = FAMILY_CODES[family];
    const ids: Record<string, number> = {};
    const missing: string[] = [];
    for (const chunk of chunked([...new Set(contentHashes)], HASHES_PER_LOOKUP)) {
        const placeholders = chunk.map(() => "?").join(", ");
        const found = await db
            .prepare(
                "SELECT blob_id, content_hash FROM folded_blobs " +
                    `WHERE family = ? AND content_hash IN (${placeholders})`,
            )
            .bind(familyCode, ...chunk.map(hexToBlob))
            .all<{ blob_id: number; content_hash: ArrayBuffer }>();
        const foundSet = new Set<string>();
        for (const row of found.results) {
            const hex = bytesToHex(new Uint8Array(row.content_hash));
            ids[hex] = row.blob_id;
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

// Per-snapshot segment links. Freeze-guarded (fast-path check, per-statement
// EXISTS guard, completed_at probe in the final batch) and maintains no
// counter: completion verifies SUM(entry_count) over the link join instead.
async function handleRegister(
    db: D1Database,
    serverId: string,
    snapshotHash: string,
    segments: SegmentLink[],
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

    // Referential integrity: every referenced blob id must exist and belong
    // to the link's stated family. Within one frame, each blob id may be
    // linked at most once per family: freezeSnapshot sums entry_count once
    // per link row, so a duplicated blob id would be double-counted (and
    // enumerated twice by readers' catalogs). Reject before any insert so a
    // bad frame writes nothing. Cross-frame replays are unaffected — they
    // carry identical (family, seq, blob_id) rows, which the INSERT OR IGNORE
    // below dedupes by primary key.
    const duplicates: { family: Family; blob_id: number }[] = [];
    const frameLinks = new Set<string>();
    const missing: { family: Family; blob_id: number }[] = [];
    const byFamily = new Map<Family, number[]>();
    for (const link of segments) {
        const key = `${FAMILY_CODES[link.family]}:${link.blob_id}`;
        if (frameLinks.has(key)) {
            duplicates.push({ family: link.family, blob_id: link.blob_id });
            continue;
        }
        frameLinks.add(key);
        const ids = byFamily.get(link.family) ?? [];
        ids.push(link.blob_id);
        byFamily.set(link.family, ids);
    }
    if (duplicates.length > 0) {
        throw new SyncFailure({
            error: "Duplicate segment links",
            duplicates: duplicates.slice(0, 100),
        });
    }
    for (const [family, blobIds] of byFamily) {
        const familyCode = FAMILY_CODES[family];
        for (const chunk of chunked([...new Set(blobIds)], HASHES_PER_LOOKUP)) {
            const placeholders = chunk.map(() => "?").join(", ");
            const found = await db
                .prepare(
                    "SELECT blob_id FROM folded_blobs " +
                        `WHERE family = ? AND blob_id IN (${placeholders})`,
                )
                .bind(familyCode, ...chunk)
                .all<{ blob_id: number }>();
            const foundSet = new Set(found.results.map((row) => row.blob_id));
            for (const blobId of chunk) {
                if (!foundSet.has(blobId)) {
                    missing.push({ family, blob_id: blobId });
                }
            }
        }
    }
    if (missing.length > 0) {
        throw new SyncFailure({ error: "Unknown blob ids", missing: missing.slice(0, 100) });
    }

    let inserted = 0;
    const statements: D1PreparedStatement[] = [];
    for (const chunk of chunked(segments, REGISTER_ROWS_PER_STATEMENT)) {
        const placeholders = chunk.map(() => "(?, ?, ?, ?)").join(", ");
        const binds = [
            ...chunk.flatMap((link) => [
                snapshot.snapshot_id,
                FAMILY_CODES[link.family],
                link.seq,
                link.blob_id,
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
                    "INSERT OR IGNORE INTO snapshot_family_segments " +
                        "(snapshot_id, family, seq, blob_id) " +
                        "SELECT column1, column2, column3, column4 " +
                        `FROM (VALUES ${placeholders}) ` +
                        "WHERE EXISTS (SELECT 1 FROM snapshots " +
                        "WHERE snapshot_id = ? AND completed_at IS NULL)",
                )
                .bind(...binds),
        );
    }
    // The final batch also probes completed_at. A batch commits atomically,
    // so a concurrent complete that bypassed the instance-level
    // serialization either committed before it (the guards above inserted
    // nothing and the probe observes the freeze, rejecting this frame) or
    // runs after it (and counts these rows in its own atomic
    // sum-and-freeze update). Registration and completion therefore cannot
    // interleave into a frozen snapshot whose entry_count disagrees with its
    // link set.
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

// The freezing UPDATE: the count verification is SUM(folded_blobs.
// entry_count) over the snapshot's segment links — a ~64-row join, µs — not
// a maintained counter, so there is no divergence/repair path at all. The
// SUM, the not-yet-frozen check, and the marker write are one statement, so
// a concurrent register frame that bypassed the instance-level serialization
// can never slip links in between the verification and the freeze.
async function freezeSnapshot(
    db: D1Database,
    snapshotId: number,
    entryCount: number,
): Promise<boolean> {
    const result = await db
        .prepare(
            "UPDATE snapshots SET entry_count = ?, " +
                "completed_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now') " +
                "WHERE snapshot_id = ? AND completed_at IS NULL AND " +
                "(SELECT COALESCE(SUM(b.entry_count), 0) " +
                "FROM snapshot_family_segments s " +
                "JOIN folded_blobs b ON b.blob_id = s.blob_id " +
                "WHERE s.snapshot_id = ?) = ?",
        )
        .bind(entryCount, snapshotId, snapshotId, entryCount)
        .run();
    return (result.meta.changes ?? 0) > 0;
}

async function sumSegmentEntries(db: D1Database, snapshotId: number): Promise<number> {
    const row = await db
        .prepare(
            "SELECT COALESCE(SUM(b.entry_count), 0) AS n " +
                "FROM snapshot_family_segments s " +
                "JOIN folded_blobs b ON b.blob_id = s.blob_id " +
                "WHERE s.snapshot_id = ?",
        )
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
    // race, or the segment-link SUM genuinely differs. Re-read the registry
    // row, then report the real SUM — there is no counter to repair.
    const state = await findSnapshot(db, serverId, snapshotHash);
    if (state?.completed_at != null) {
        if (state.entry_count === entryCount) {
            return {};
        }
        throw new SyncFailure({ error: "Snapshot already complete" });
    }
    const registered = await sumSegmentEntries(db, snapshot.snapshot_id);
    throw new SyncFailure({
        error: "Snapshot incomplete",
        expected: entryCount,
        registered,
    });
}

export class SyncSession extends DurableObject<Env> {
    // Per-snapshot mutual exclusion between register and complete handlers:
    // serializing the two handlers per snapshot guarantees no register frame
    // is mid-flight when complete evaluates the link SUM. This is instance
    // memory, so a restarted instance starts empty — safe, because an
    // instance is never evicted while it is still processing a frame. The
    // per-statement freeze guards remain the SQL-level backstop.
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
                    Object.assign(reply, await handleContent(this.env.PLATFORM_DB, msg));
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
                                msg.segments,
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
