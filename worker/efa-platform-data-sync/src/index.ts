import { Hono } from "hono";
import { z } from "zod";

interface Env {
    PLATFORM_DB: D1Database;
    SYNC_TOKEN?: string;
}

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

const ContentEntrySchema = z.object({
    family: z.enum(Object.keys(FAMILIES) as [Family, ...Family[]]),
    content_hash: z.string().regex(HASH_RE),
    content_b64: z.base64().min(1),
});

const ContentRequestSchema = z.object({
    entries: z.array(ContentEntrySchema).min(1).max(10000),
});

const RegisterEntrySchema = z.object({
    family: z.enum(Object.keys(FAMILIES) as [Family, ...Family[]]),
    entry_id: z.number().int().nonnegative(),
    content_hash: z.string().regex(HASH_RE),
});

const RegisterRequestSchema = z.object({
    server_id: z.string().min(1),
    snapshot_hash: z.string().regex(HASH_RE),
    entries: z.array(RegisterEntrySchema).min(1).max(10000),
});

const CompleteRequestSchema = z.object({
    server_id: z.string().min(1),
    snapshot_hash: z.string().regex(HASH_RE),
    entry_count: z.number().int().nonnegative(),
});

// D1 allows at most 100 bound parameters per statement.
const CONTENT_ROWS_PER_STATEMENT = 50; // 2 params per row
const REGISTER_ROWS_PER_STATEMENT = 25; // 4 params per row
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

const app = new Hono<{ Bindings: Env }>();

const MOUNT_PATH = "/platform/storage/data-sync";
// Reader-facing probes; everything else (including any future route) requires
// the sync token by default.
const PUBLIC_GET_PATHS = new Set([`${MOUNT_PATH}/health`, `${MOUNT_PATH}/snapshot`]);

function timingSafeEqual(a: string, b: string): boolean {
    const encoder = new TextEncoder();
    const aBytes = encoder.encode(a);
    const bBytes = encoder.encode(b);
    if (aBytes.length !== bBytes.length) {
        return false;
    }
    let diff = 0;
    for (let i = 0; i < aBytes.length; i++) {
        diff |= aBytes[i] ^ bBytes[i];
    }
    return diff === 0;
}

app.use("*", async (c, next) => {
    if (c.req.method === "GET" && PUBLIC_GET_PATHS.has(new URL(c.req.url).pathname)) {
        return next();
    }
    const token = c.env.SYNC_TOKEN;
    if (!token) {
        return c.json({ ok: false, error: "Server misconfigured: SYNC_TOKEN is not set" }, 500);
    }
    const header = c.req.header("Authorization") ?? "";
    if (!timingSafeEqual(header, `Bearer ${token}`)) {
        return c.json({ ok: false, error: "Unauthorized" }, 401);
    }
    return next();
});

app.get("/health", async (c) => {
    await c.env.PLATFORM_DB.prepare("SELECT 1").first();
    return c.json({ ok: true });
});

app.post("/content", async (c) => {
    const parsed = ContentRequestSchema.safeParse(await c.req.json().catch(() => null));
    if (!parsed.success) {
        return c.json({ ok: false, error: "Validation failed", details: parsed.error.issues }, 400);
    }

    const byFamily = new Map<Family, { hash: string; content: Uint8Array }[]>();
    const rejected: { family: Family; content_hash: string; reason: string }[] = [];
    for (const entry of parsed.data.entries) {
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
        return c.json(
            { ok: false, error: "Content verification failed", rejected: rejected.slice(0, 100) },
            400,
        );
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
                c.env.PLATFORM_DB.prepare(
                    `INSERT OR IGNORE INTO ${table} (content_hash, content) VALUES ${placeholders}`,
                ).bind(...binds),
            );
        }
        for (const batch of chunked(statements, STATEMENTS_PER_BATCH)) {
            const results = await c.env.PLATFORM_DB.batch(batch);
            for (const result of results) {
                inserted += result.meta.changes ?? 0;
            }
        }
    }

    return c.json({ ok: true, inserted });
});

app.post("/register", async (c) => {
    const parsed = RegisterRequestSchema.safeParse(await c.req.json().catch(() => null));
    if (!parsed.success) {
        return c.json({ ok: false, error: "Validation failed", details: parsed.error.issues }, 400);
    }

    const { server_id: serverId, snapshot_hash: snapshotHash, entries } = parsed.data;

    const byFamily = new Map<Family, { id: number; hash: string }[]>();
    for (const entry of entries) {
        const rows = byFamily.get(entry.family) ?? [];
        rows.push({ id: entry.entry_id, hash: entry.content_hash });
        byFamily.set(entry.family, rows);
    }

    // Referential integrity: every registered content hash must already exist.
    const missing: { family: Family; content_hash: string }[] = [];
    for (const [family, rows] of byFamily) {
        const table = FAMILIES[family].content;
        const uniqueHashes = [...new Set(rows.map((row) => row.hash))];
        for (const chunk of chunked(uniqueHashes, HASHES_PER_LOOKUP)) {
            const placeholders = chunk.map(() => "?").join(", ");
            const found = await c.env.PLATFORM_DB.prepare(
                `SELECT content_hash FROM ${table} WHERE content_hash IN (${placeholders})`,
            )
                .bind(...chunk)
                .all<{ content_hash: string }>();
            const foundSet = new Set(found.results.map((row) => row.content_hash));
            for (const hash of chunk) {
                if (!foundSet.has(hash)) {
                    missing.push({ family, content_hash: hash });
                }
            }
        }
    }
    if (missing.length > 0) {
        return c.json(
            { ok: false, error: "Unknown content hashes", missing: missing.slice(0, 100) },
            409,
        );
    }

    let inserted = 0;
    for (const [family, rows] of byFamily) {
        const table = FAMILIES[family].reg;
        const statements: D1PreparedStatement[] = [];
        for (const chunk of chunked(rows, REGISTER_ROWS_PER_STATEMENT)) {
            const placeholders = chunk.map(() => "(?, ?, ?, ?)").join(", ");
            const binds = chunk.flatMap((row) => [serverId, snapshotHash, row.id, row.hash]);
            statements.push(
                c.env.PLATFORM_DB.prepare(
                    `INSERT OR IGNORE INTO ${table} ` +
                        `(server_id, snapshot_hash, entry_id, content_hash) VALUES ${placeholders}`,
                ).bind(...binds),
            );
        }
        for (const batch of chunked(statements, STATEMENTS_PER_BATCH)) {
            const results = await c.env.PLATFORM_DB.batch(batch);
            for (const result of results) {
                inserted += result.meta.changes ?? 0;
            }
        }
    }

    return c.json({ ok: true, inserted });
});

app.post("/complete", async (c) => {
    const parsed = CompleteRequestSchema.safeParse(await c.req.json().catch(() => null));
    if (!parsed.success) {
        return c.json({ ok: false, error: "Validation failed", details: parsed.error.issues }, 400);
    }

    const {
        server_id: serverId,
        snapshot_hash: snapshotHash,
        entry_count: entryCount,
    } = parsed.data;

    // Verify completeness server-side: the marker is only written when the
    // registration rows actually present match the uploader's entry count.
    let registered = 0;
    for (const family of Object.keys(FAMILIES) as Family[]) {
        const table = FAMILIES[family].reg;
        const row = await c.env.PLATFORM_DB.prepare(
            `SELECT COUNT(*) AS n FROM ${table} WHERE server_id = ? AND snapshot_hash = ?`,
        )
            .bind(serverId, snapshotHash)
            .first<{ n: number }>();
        registered += row?.n ?? 0;
    }
    if (registered !== entryCount) {
        return c.json(
            { ok: false, error: "Snapshot incomplete", expected: entryCount, registered },
            409,
        );
    }

    await c.env.PLATFORM_DB.prepare(
        "INSERT OR REPLACE INTO snapshots (server_id, snapshot_hash, entry_count) VALUES (?, ?, ?)",
    )
        .bind(serverId, snapshotHash, entryCount)
        .run();

    return c.json({ ok: true });
});

app.get("/snapshot", async (c) => {
    const serverId = c.req.query("server_id");
    const snapshotHash = c.req.query("snapshot_hash");
    if (!serverId || !snapshotHash || !HASH_RE.test(snapshotHash)) {
        return c.json({ ok: false, error: "Invalid server_id or snapshot_hash" }, 400);
    }
    const row = await c.env.PLATFORM_DB.prepare(
        "SELECT entry_count, completed_at FROM snapshots WHERE server_id = ? AND snapshot_hash = ?",
    )
        .bind(serverId, snapshotHash)
        .first<{ entry_count: number; completed_at: string }>();
    if (!row) {
        return c.json({ ok: true, complete: false });
    }
    return c.json({
        ok: true,
        complete: true,
        entry_count: row.entry_count,
        completed_at: row.completed_at,
    });
});

app.onError((err, c) => {
    console.error("Unhandled error", err);
    return c.json({ ok: false, error: "Internal server error" }, 500);
});

const root = new Hono<{ Bindings: Env }>();
root.route(MOUNT_PATH, app);
export default root;
