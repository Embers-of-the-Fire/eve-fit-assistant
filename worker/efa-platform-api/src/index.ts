import { fromBinary, toJson } from "@bufbuild/protobuf";
import { FitStoreResponseSchema } from "efa-proto-ts/fit_request_pb";
import { type FitSnapshot, FitSnapshotSchema } from "efa-proto-ts/fit_snapshot_pb";
import { Hono } from "hono";

import {
    decodeCursor,
    encodeCursor,
    normalizeBlob,
    resolveShipName,
    timingSafeEqual,
    truncateCodePoints,
    UUID_PATTERN,
} from "./util";

// Public front of the platform (docs/temp/api-unit/spec.md §6). Owns the
// `posts` table, orchestrates submissions through the FIT_STORAGE service
// binding, and holds the platform's Bearer credential.

interface Env {
    FIT_DB: D1Database;
    FIT_STORAGE: Fetcher;
    FIT_STORAGE_TOKEN?: string;
}

const MOUNT_PATH = "/platform/internal";
const FIT_STORAGE_ORIGIN = "https://efa-platform-fit-storage.internal";

const DEFAULT_LIST_LIMIT = 20;
const MAX_LIST_LIMIT = 50;
// §4.2: posts.description is a preview of the snapshot's description.
const DESCRIPTION_PREVIEW_CODE_POINTS = 280;

const PROTOBUF_CONTENT_TYPE = "application/x-protobuf";
const IMMUTABLE_CACHE_CONTROL = "public, max-age=31536000, immutable";
const LIST_CACHE_CONTROL = "public, max-age=30";

function errorJson(status: 400 | 401 | 404 | 500, code: string, message: string): Response {
    return Response.json({ error: code, message }, { status });
}

// §6.2: raw protobuf responses. D1 hands BLOB columns back as plain number
// arrays, which are not a valid Response body — always normalize first. A
// missing/empty blob is a store-side bug, not a client error.
function blobResponse(value: unknown): Response {
    const bytes = normalizeBlob(value);
    if (!bytes || bytes.length === 0) {
        console.error("stored fit snapshot is missing or unreadable");
        return errorJson(500, "internal", "internal server error");
    }
    return new Response(bytes, {
        headers: {
            "Content-Type": PROTOBUF_CONTENT_TYPE,
            "Cache-Control": IMMUTABLE_CACHE_CONTROL,
        },
    });
}

const app = new Hono<{ Bindings: Env }>();

app.use("*", async (c, next) => {
    try {
        await next();
    } catch (err) {
        console.error("Unhandled error", err);
        c.res = errorJson(500, "internal", "internal server error");
    }
    c.res.headers.set("Access-Control-Allow-Origin", "*");
});

app.options("*", () => {
    return new Response(null, {
        status: 204,
        headers: {
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
            "Access-Control-Allow-Headers": "Content-Type, Authorization",
        },
    });
});

// §6.1: create post.
app.post("/posts", async (c) => {
    const token = c.env.FIT_STORAGE_TOKEN;
    if (!token) {
        console.error("FIT_STORAGE_TOKEN is not set");
        return errorJson(500, "internal", "internal server error");
    }
    const header = c.req.header("Authorization") ?? "";
    if (!timingSafeEqual(header, `Bearer ${token}`)) {
        return errorJson(401, "unauthorized", "missing or invalid bearer token");
    }

    const body = await c.req.arrayBuffer();
    let stored: Response;
    try {
        stored = await c.env.FIT_STORAGE.fetch(
            `${FIT_STORAGE_ORIGIN}/platform/storage/fit/submit`,
            {
                method: "POST",
                headers: { "Content-Type": PROTOBUF_CONTENT_TYPE },
                body,
            },
        );
    } catch (err) {
        console.error("FIT_STORAGE binding call failed", err);
        return errorJson(500, "internal", "internal server error");
    }

    // Pass the fit-storage error envelope and status through unchanged.
    if (!stored.ok) {
        return new Response(stored.body, {
            status: stored.status,
            headers: { "Content-Type": stored.headers.get("Content-Type") ?? "application/json" },
        });
    }

    const storeResult = fromBinary(
        FitStoreResponseSchema,
        new Uint8Array(await stored.arrayBuffer()),
    );

    const row = await c.env.FIT_DB.prepare("SELECT snapshot FROM fits WHERE fit_hash = ?")
        .bind(storeResult.fitHash)
        .first<{ snapshot: unknown }>();
    if (!row) {
        console.error(`fit ${storeResult.fitHash} stored but not readable`);
        return errorJson(500, "internal", "internal server error");
    }
    let snapshot: FitSnapshot;
    try {
        const bytes = normalizeBlob(row.snapshot);
        if (!bytes || bytes.length === 0) throw new Error("stored blob is empty");
        snapshot = fromBinary(FitSnapshotSchema, bytes);
        // fromBinary does not enforce proto2 required fields; toJson does.
        toJson(FitSnapshotSchema, snapshot);
    } catch (err) {
        // A snapshot that fails to decode right after a trusted write indicates
        // a fit-storage write bug: fail, leave the (harmless) fit row, and let
        // the client retry.
        console.error(`stored snapshot of fit ${storeResult.fitHash} failed to decode`, err);
        return errorJson(500, "internal", "internal server error");
    }

    const fitName = snapshot.header?.fitName ?? "";
    const description = truncateCodePoints(
        snapshot.header?.description ?? "",
        DESCRIPTION_PREVIEW_CODE_POINTS,
    );
    const shipNames = snapshot.ship?.type?.names ?? {};
    const shipTypeId = snapshot.ship?.type?.typeId ?? 0;
    const lastModifiedMs = Number(snapshot.header?.lastModifiedMs ?? 0);
    const generator = snapshot.header?.generator ?? null;

    const postId = crypto.randomUUID();
    await c.env.FIT_DB.prepare(
        "INSERT INTO posts (post_id, fit_hash, fit_name, description, ship_names, ship_type_id, last_modified_ms, generator) " +
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
    )
        .bind(
            postId,
            storeResult.fitHash,
            fitName,
            description,
            JSON.stringify(shipNames),
            shipTypeId,
            lastModifiedMs,
            generator,
        )
        .run();

    return c.json(
        { postId, fitHash: storeResult.fitHash, alreadyExisted: storeResult.alreadyExisted },
        201,
    );
});

interface PostRow {
    post_id: string;
    fit_hash: string;
    fit_name: string;
    description: string;
    ship_names: string;
    ship_type_id: number;
    last_modified_ms: number;
    generator: string | null;
    created_at: string;
}

// §6.3: list posts (keyset pagination over posts_created_at, pure SQL).
app.get("/posts", async (c) => {
    let limit = DEFAULT_LIST_LIMIT;
    const limitRaw = c.req.query("limit");
    if (limitRaw !== undefined) {
        const parsed = Number.parseInt(limitRaw, 10);
        if (Number.isNaN(parsed)) {
            return errorJson(400, "bad_request", "malformed limit");
        }
        limit = Math.min(Math.max(parsed, 1), MAX_LIST_LIMIT);
    }
    const locale = c.req.query("locale") ?? "en";

    const cursorRaw = c.req.query("cursor");
    let cursor: { createdAt: string; postId: string } | null = null;
    if (cursorRaw !== undefined) {
        cursor = decodeCursor(cursorRaw);
        if (!cursor) {
            return errorJson(400, "bad_request", "malformed cursor");
        }
    }

    const columns =
        "post_id, fit_hash, fit_name, description, ship_names, ship_type_id, last_modified_ms, generator, created_at";
    const statement = cursor
        ? c.env.FIT_DB.prepare(
              `SELECT ${columns} FROM posts WHERE (created_at, post_id) < (?, ?) ` +
                  "ORDER BY created_at DESC, post_id DESC LIMIT ?",
          ).bind(cursor.createdAt, cursor.postId, limit + 1)
        : c.env.FIT_DB.prepare(
              `SELECT ${columns} FROM posts ORDER BY created_at DESC, post_id DESC LIMIT ?`,
          ).bind(limit + 1);
    const { results } = await statement.all<PostRow>();

    const page = results.slice(0, limit);
    let nextCursor: string | null = null;
    if (results.length > limit && page.length > 0) {
        const last = page[page.length - 1];
        nextCursor = encodeCursor(last.created_at, last.post_id);
    }

    return c.json(
        {
            posts: page.map((row) => ({
                postId: row.post_id,
                fitHash: row.fit_hash,
                fitName: row.fit_name,
                description: row.description,
                shipName: resolveShipName(row.ship_names, locale),
                shipTypeId: row.ship_type_id,
                createdAt: row.created_at,
                lastModifiedMs: row.last_modified_ms,
                generator: row.generator,
            })),
            nextCursor,
        },
        200,
        { "Cache-Control": LIST_CACHE_CONTROL },
    );
});

// §6.2: post record.
app.get("/posts/:id", async (c) => {
    const postId = c.req.param("id");
    if (!UUID_PATTERN.test(postId)) {
        return errorJson(400, "bad_request", "invalid post id");
    }
    const row = await c.env.FIT_DB.prepare(
        "SELECT post_id, fit_hash, created_at FROM posts WHERE post_id = ?",
    )
        .bind(postId)
        .first<{ post_id: string; fit_hash: string; created_at: string }>();
    if (!row) {
        return errorJson(404, "not_found", "unknown post id");
    }
    return c.json({ postId: row.post_id, fitHash: row.fit_hash, createdAt: row.created_at });
});

// §6.2: raw FitSnapshot protobuf bytes behind a post.
app.get("/posts/:id/snapshot", async (c) => {
    const postId = c.req.param("id");
    if (!UUID_PATTERN.test(postId)) {
        return errorJson(400, "bad_request", "invalid post id");
    }
    const row = await c.env.FIT_DB.prepare(
        "SELECT f.snapshot FROM posts p JOIN fits f ON f.fit_hash = p.fit_hash WHERE p.post_id = ?",
    )
        .bind(postId)
        .first<{ snapshot: unknown }>();
    if (!row) {
        return errorJson(404, "not_found", "unknown post id");
    }
    return blobResponse(row.snapshot);
});

// §6.2: raw FitSnapshot protobuf bytes addressed directly by fit hash.
app.get("/fits/:fitHash/snapshot", async (c) => {
    const fitHash = c.req.param("fitHash");
    const row = await c.env.FIT_DB.prepare("SELECT snapshot FROM fits WHERE fit_hash = ?")
        .bind(fitHash)
        .first<{ snapshot: unknown }>();
    if (!row) {
        return errorJson(404, "not_found", "unknown fit hash");
    }
    return blobResponse(row.snapshot);
});

// §6.4: threads (stub).
app.get("/posts/:id/threads", (c) => {
    return c.json({ threads: [] });
});

// §6.5: health; a valid Bearer token additionally pings D1 and the binding.
app.get("/health", async (c) => {
    const token = c.env.FIT_STORAGE_TOKEN;
    const header = c.req.header("Authorization") ?? "";
    if (token && timingSafeEqual(header, `Bearer ${token}`)) {
        await c.env.FIT_DB.prepare("SELECT 1").first();
        const storageHealth = await c.env.FIT_STORAGE.fetch(
            `${FIT_STORAGE_ORIGIN}/platform/storage/fit/health`,
        );
        if (!storageHealth.ok) {
            console.error(`fit-storage health check failed: ${storageHealth.status}`);
            return errorJson(500, "internal", "internal server error");
        }
    }
    return c.json({ ok: true });
});

app.onError((err, _c) => {
    console.error("Unhandled error", err);
    return errorJson(500, "internal", "internal server error");
});

const root = new Hono<{ Bindings: Env }>();
root.route(MOUNT_PATH, app);
export default root;
