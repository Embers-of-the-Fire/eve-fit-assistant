import { Hono } from "hono";
import type { SyncSession } from "./session.ts";

export { SyncSession } from "./session.ts";

export interface Env {
    PLATFORM_DB: D1Database;
    SYNC_SESSION: DurableObjectNamespace<SyncSession>;
    SYNC_TOKEN?: string;
}

const HASH_RE = /^[0-9a-f]{64}$/;

function hexToBlob(hex: string): ArrayBuffer {
    const bytes = new Uint8Array(hex.length / 2);
    for (let i = 0; i < bytes.length; i++) {
        bytes[i] = Number.parseInt(hex.slice(i * 2, i * 2 + 2), 16);
    }
    return bytes.buffer as ArrayBuffer;
}

const app = new Hono<{ Bindings: Env }>();

const MOUNT_PATH = "/platform/storage/data-sync";
// Reader-facing probes; everything else (including the WebSocket sync route)
// requires the sync token.
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

// Uploader entry point: a single long-lived WebSocket to the SyncSession
// Durable Object replaces the old multi-request HTTP upload (see session.ts
// for the frame protocol).
app.get("/sync", async (c) => {
    const upgrade = c.req.header("Upgrade");
    if (upgrade?.toLowerCase() !== "websocket") {
        return c.json({ ok: false, error: "Expected a WebSocket upgrade request" }, 426);
    }
    const id = c.env.SYNC_SESSION.idFromName("sync");
    return c.env.SYNC_SESSION.get(id).fetch(c.req.raw);
});

app.get("/snapshot", async (c) => {
    const serverId = c.req.query("server_id");
    const snapshotHash = c.req.query("snapshot_hash");
    if (!serverId || !snapshotHash || !HASH_RE.test(snapshotHash)) {
        return c.json({ ok: false, error: "Invalid server_id or snapshot_hash" }, 400);
    }
    // A snapshot is complete only once the uploader's `complete` frame has
    // frozen it; pending rows (completed_at IS NULL) are incomplete.
    const row = await c.env.PLATFORM_DB.prepare(
        "SELECT entry_count, completed_at FROM snapshots " +
            "WHERE server_id = ? AND snapshot_hash = ? AND completed_at IS NOT NULL",
    )
        .bind(serverId, hexToBlob(snapshotHash))
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
