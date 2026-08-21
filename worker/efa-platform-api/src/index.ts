import { fromBinary, toJson } from "@bufbuild/protobuf";
import { FitStoreResponseSchema } from "efa-proto-ts/fit_request_pb";
import { type FitSnapshot, FitSnapshotSchema } from "efa-proto-ts/fit_snapshot_pb";
import { Hono } from "hono";

import {
    decodeCursor,
    decodeShipCursor,
    encodeCursor,
    encodeShipCursor,
    escapeLikePattern,
    FIT_HASH_PATTERN,
    normalizeBlob,
    parseLimit,
    parseTimeWindow,
    resolveShipName,
    timingSafeEqual,
    truncateCodePoints,
    UUID_PATTERN,
} from "./util";

// Public front of the platform. Owns the `posts` table, orchestrates
// submissions through the FIT_STORAGE service binding, and holds the
// platform's Bearer credential.

interface Env {
    FIT_DB: D1Database;
    FIT_STORAGE: Fetcher;
    FIT_STORAGE_TOKEN?: string;
}

const MOUNT_PATH = "/platform/internal";
const FIT_STORAGE_ORIGIN = "https://efa-platform-fit-storage.internal";

const DEFAULT_LIST_LIMIT = 20;
const MAX_LIST_LIMIT = 50;
const STATS_TOP_SHIPS_LIMIT = 10;
// posts.description is a preview of the snapshot's description.
const DESCRIPTION_PREVIEW_CODE_POINTS = 280;
// Free-text ship search is capped like the other free-text fields.
const MAX_SHIP_QUERY_CODE_POINTS = 100;

const PROTOBUF_CONTENT_TYPE = "application/x-protobuf";
const IMMUTABLE_CACHE_CONTROL = "public, max-age=31536000, immutable";
const LIST_CACHE_CONTROL = "public, max-age=30";
const STATS_CACHE_CONTROL = "public, max-age=60";

function errorJson(status: 400 | 401 | 404 | 500, code: string, message: string): Response {
    return Response.json({ error: code, message }, { status });
}

// Raw protobuf responses. D1 hands BLOB columns back as plain number
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

// Create post.
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

// List posts (keyset pagination over posts_created_at, pure SQL).
app.get("/posts", async (c) => {
    let limit = DEFAULT_LIST_LIMIT;
    const limitRaw = c.req.query("limit");
    if (limitRaw !== undefined) {
        const parsed = parseLimit(limitRaw, MAX_LIST_LIMIT);
        if (parsed === null) {
            return errorJson(400, "bad_request", "malformed limit");
        }
        limit = parsed;
    }
    const locale = c.req.query("locale") ?? "en";

    let shipTypeId: number | null = null;
    const shipTypeIdRaw = c.req.query("shipTypeId");
    if (shipTypeIdRaw !== undefined) {
        const parsed = Number(shipTypeIdRaw);
        if (!Number.isSafeInteger(parsed) || parsed <= 0) {
            return errorJson(400, "bad_request", "malformed shipTypeId");
        }
        shipTypeId = parsed;
    }

    const windowModifier = parseTimeWindow(c.req.query("window"));
    if (windowModifier === "invalid") {
        return errorJson(400, "bad_request", "malformed window");
    }

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
    const conditions: string[] = [];
    const binds: (string | number)[] = [];
    if (shipTypeId !== null) {
        conditions.push("ship_type_id = ?");
        binds.push(shipTypeId);
    }
    if (windowModifier !== null) {
        conditions.push("created_at >= strftime('%Y-%m-%dT%H:%M:%fZ', 'now', ?)");
        binds.push(windowModifier);
    }
    if (cursor) {
        conditions.push("(created_at, post_id) < (?, ?)");
        binds.push(cursor.createdAt, cursor.postId);
    }
    const where = conditions.length > 0 ? `WHERE ${conditions.join(" AND ")} ` : "";
    const statement = c.env.FIT_DB.prepare(
        `SELECT ${columns} FROM posts ${where}ORDER BY created_at DESC, post_id DESC LIMIT ?`,
    ).bind(...binds, limit + 1);
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

// Post record.
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

// Raw FitSnapshot protobuf bytes behind a post.
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

// Raw FitSnapshot protobuf bytes addressed directly by fit hash.
app.get("/fits/:fitHash/snapshot", async (c) => {
    const fitHash = c.req.param("fitHash");
    if (!FIT_HASH_PATTERN.test(fitHash)) {
        return errorJson(400, "bad_request", "invalid fit hash");
    }
    const row = await c.env.FIT_DB.prepare("SELECT snapshot FROM fits WHERE fit_hash = ?")
        .bind(fitHash)
        .first<{ snapshot: unknown }>();
    if (!row) {
        return errorJson(404, "not_found", "unknown fit hash");
    }
    return blobResponse(row.snapshot);
});

// Raw canonical FitState protobuf bytes addressed directly by fit hash.
// Unlike the snapshot, the state is full-fidelity (dynamic items, custom
// character skills) and is what registered fit links import from.
app.get("/fits/:fitHash/state", async (c) => {
    const fitHash = c.req.param("fitHash");
    if (!FIT_HASH_PATTERN.test(fitHash)) {
        return errorJson(400, "bad_request", "invalid fit hash");
    }
    const row = await c.env.FIT_DB.prepare("SELECT fit_state FROM fits WHERE fit_hash = ?")
        .bind(fitHash)
        .first<{ fit_state: unknown }>();
    if (!row) {
        return errorJson(404, "not_found", "unknown fit hash");
    }
    return blobResponse(row.fit_state);
});

// Threads (stub).
app.get("/posts/:id/threads", (c) => {
    return c.json({ threads: [] });
});

interface StatsRow {
    total_posts: number;
    distinct_ships: number;
    posts_last_7d: number | null;
}

interface TopShipRow {
    ship_type_id: number;
    ship_names: string;
    post_count: number;
}

// Platform stats (pure SQL aggregation over posts; names localized at
// projection like the list endpoint).
app.get("/stats", async (c) => {
    const locale = c.req.query("locale") ?? "en";
    const totals = await c.env.FIT_DB.prepare(
        "SELECT COUNT(*) AS total_posts, COUNT(DISTINCT ship_type_id) AS distinct_ships, " +
            "SUM(created_at >= strftime('%Y-%m-%dT%H:%M:%fZ', 'now', '-7 days')) AS posts_last_7d " +
            "FROM posts",
    ).first<StatsRow>();
    const { results: topRows } = await c.env.FIT_DB.prepare(
        "SELECT ship_type_id, ship_names, COUNT(*) AS post_count FROM posts " +
            "GROUP BY ship_type_id ORDER BY post_count DESC, ship_type_id ASC LIMIT ?",
    )
        .bind(STATS_TOP_SHIPS_LIMIT)
        .all<TopShipRow>();

    return c.json(
        {
            totalPosts: totals?.total_posts ?? 0,
            distinctShips: totals?.distinct_ships ?? 0,
            postsLast7d: totals?.posts_last_7d ?? 0,
            topShips: topRows.map((row) => ({
                shipTypeId: row.ship_type_id,
                shipName: resolveShipName(row.ship_names, locale),
                postCount: row.post_count,
            })),
        },
        200,
        { "Cache-Control": STATS_CACHE_CONTROL },
    );
});

interface ShipRow {
    ship_type_id: number;
    ship_names: string;
    post_count: number;
    last_post_at: string;
}

// Ship directory (aggregation over posts; keyset pagination over
// (post_count, ship_type_id); names localized at projection like the list
// endpoint).
app.get("/ships", async (c) => {
    let limit = DEFAULT_LIST_LIMIT;
    const limitRaw = c.req.query("limit");
    if (limitRaw !== undefined) {
        const parsed = parseLimit(limitRaw, MAX_LIST_LIMIT);
        if (parsed === null) {
            return errorJson(400, "bad_request", "malformed limit");
        }
        limit = parsed;
    }
    const locale = c.req.query("locale") ?? "en";

    const windowModifier = parseTimeWindow(c.req.query("window"));
    if (windowModifier === "invalid") {
        return errorJson(400, "bad_request", "malformed window");
    }

    let query: string | null = null;
    const queryRaw = c.req.query("q");
    if (queryRaw !== undefined) {
        const trimmed = queryRaw.trim();
        if ([...trimmed].length > MAX_SHIP_QUERY_CODE_POINTS) {
            return errorJson(400, "bad_request", "ship query too long");
        }
        if (trimmed.length > 0) {
            query = trimmed.toLowerCase();
        }
    }

    const cursorRaw = c.req.query("cursor");
    let cursor: { postCount: number; shipTypeId: number } | null = null;
    if (cursorRaw !== undefined) {
        cursor = decodeShipCursor(cursorRaw);
        if (!cursor) {
            return errorJson(400, "bad_request", "malformed cursor");
        }
    }

    const conditions: string[] = [];
    const binds: (string | number)[] = [];
    if (windowModifier !== null) {
        conditions.push("created_at >= strftime('%Y-%m-%dT%H:%M:%fZ', 'now', ?)");
        binds.push(windowModifier);
    }
    if (query !== null) {
        conditions.push(
            "(LOWER(json_extract(ship_names, '$.en')) LIKE ? ESCAPE '\\' OR " +
                "LOWER(json_extract(ship_names, '$.zh')) LIKE ? ESCAPE '\\')",
        );
        const pattern = `%${escapeLikePattern(query)}%`;
        binds.push(pattern, pattern);
    }
    const where = conditions.length > 0 ? `WHERE ${conditions.join(" AND ")} ` : "";
    let having = "";
    if (cursor) {
        having = "HAVING (post_count < ?) OR (post_count = ? AND ship_type_id > ?) ";
        binds.push(cursor.postCount, cursor.postCount, cursor.shipTypeId);
    }
    const statement = c.env.FIT_DB.prepare(
        "SELECT ship_type_id, ship_names, COUNT(*) AS post_count, MAX(created_at) AS last_post_at " +
            `FROM posts ${where}GROUP BY ship_type_id ${having}` +
            "ORDER BY post_count DESC, ship_type_id ASC LIMIT ?",
    ).bind(...binds, limit + 1);
    const { results } = await statement.all<ShipRow>();

    const page = results.slice(0, limit);
    let nextCursor: string | null = null;
    if (results.length > limit && page.length > 0) {
        const last = page[page.length - 1];
        nextCursor = encodeShipCursor(last.post_count, last.ship_type_id);
    }

    return c.json(
        {
            ships: page.map((row) => ({
                shipTypeId: row.ship_type_id,
                shipName: resolveShipName(row.ship_names, locale),
                postCount: row.post_count,
                lastPostAt: row.last_post_at,
            })),
            nextCursor,
        },
        200,
        { "Cache-Control": LIST_CACHE_CONTROL },
    );
});

// Per-ship detail aggregate behind the ship directory's detail page.
app.get("/ships/:id", async (c) => {
    const shipTypeId = Number(c.req.param("id"));
    if (!Number.isSafeInteger(shipTypeId) || shipTypeId <= 0) {
        return errorJson(400, "bad_request", "invalid ship type id");
    }
    const locale = c.req.query("locale") ?? "en";
    const row = await c.env.FIT_DB.prepare(
        "SELECT ship_names, COUNT(*) AS post_count, MIN(created_at) AS first_post_at, " +
            "MAX(created_at) AS last_post_at FROM posts WHERE ship_type_id = ?",
    )
        .bind(shipTypeId)
        .first<{
            ship_names: string | null;
            post_count: number;
            first_post_at: string | null;
            last_post_at: string | null;
        }>();
    if (!row || row.post_count === 0) {
        return errorJson(404, "not_found", "unknown ship type id");
    }
    return c.json(
        {
            shipTypeId,
            shipName: resolveShipName(row.ship_names ?? "{}", locale),
            postCount: row.post_count,
            firstPostAt: row.first_post_at,
            lastPostAt: row.last_post_at,
        },
        200,
        { "Cache-Control": STATS_CACHE_CONTROL },
    );
});

// Health; a valid Bearer token additionally pings D1 and the binding.
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
