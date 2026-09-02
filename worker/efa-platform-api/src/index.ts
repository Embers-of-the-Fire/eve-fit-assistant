import { fromBinary, toJson } from "@bufbuild/protobuf";
import { FitStoreResponseSchema } from "efa-proto-ts/fit_request_pb";
import { type FitSnapshot, FitSnapshotSchema } from "efa-proto-ts/fit_snapshot_pb";
import { Hono } from "hono";

import { getAuthClaims, requireAccessToken, requireActiveAccount } from "./auth/middleware.ts";
import { getAuthPermissions, requirePermission } from "./auth/permission.ts";
import { type AuthEnv, authApp } from "./auth/router.ts";
import { createRootApp } from "./root.ts";

// Durable Object classes must be exported from the worker entrypoint.
export { OtpState } from "./auth/otp-state.ts";
export { RateLimitWindow } from "./auth/rate-window.ts";

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
} from "./util.ts";

// Public front of the platform. Owns the `posts` table and orchestrates
// submissions through the FIT_STORAGE service binding. Post creation and
// deletion are gated by ACL permissions (post:create, post:delete:{own,all})
// on top of an account access token; the platform's Bearer credential
// (FIT_STORAGE_TOKEN) only unlocks the privileged /health probes.

interface Env extends AuthEnv {
    FIT_STORAGE: Fetcher;
    FIT_STORAGE_TOKEN?: string;
    // Origin of the platform site; used to build the post page URL handed
    // back to uploaders so clients can redirect straight to the post page
    // instead of the raw protobuf endpoints.
    PLATFORM_SITE_ORIGIN: string;
}

const FIT_STORAGE_ORIGIN = "https://efa-platform-fit-storage.internal";

const DEFAULT_LIST_LIMIT = 20;
const MAX_LIST_LIMIT = 50;
const STATS_TOP_SHIPS_LIMIT = 10;
// posts.description is a preview of the snapshot's description.
const DESCRIPTION_PREVIEW_CODE_POINTS = 280;
// Free-text ship search is capped like the other free-text fields.
const MAX_SHIP_QUERY_CODE_POINTS = 100;

// Comment lists are chat-like (ascending) and longer than post lists.
const DEFAULT_COMMENT_LIST_LIMIT = 50;
const MAX_COMMENT_LIST_LIMIT = 100;
// Raw markdown bodies are stored verbatim; the cap keeps rows bounded.
const MAX_COMMENT_BODY_CODE_POINTS = 10_000;

const PROTOBUF_CONTENT_TYPE = "application/x-protobuf";
const IMMUTABLE_CACHE_CONTROL = "public, max-age=31536000, immutable";
const LIST_CACHE_CONTROL = "public, max-age=30";
const STATS_CACHE_CONTROL = "public, max-age=60";
// Comment lists change more often than post lists; keep the edge copy short.
const COMMENT_LIST_CACHE_CONTROL = "public, max-age=10";

function errorJson(status: 400 | 401 | 403 | 404 | 500, code: string, message: string): Response {
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

// Exported factory (not a module-level app) so tests can compose the public
// app with an auth sub-app whose email sender is captured.
export function createPublicApp(): Hono<{ Bindings: Env }> {
    const app = new Hono<{ Bindings: Env }>();

    // Create post. Requires an active account's access token plus the
    // post:create permission; the verified identity becomes the author.
    app.post(
        "/posts",
        requireAccessToken<{ Bindings: Env }>({
            secret: (c) => c.env.AUTH_TOKEN_SECRET,
            // Deregistered or absent users, and tokens issued before a
            // token_version bump, are rejected.
            validateClaims: requireActiveAccount,
        }),
        requirePermission<{ Bindings: Env }>("post:create"),
        async (c) => {
            const claims = getAuthClaims(c);

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
                    headers: {
                        "Content-Type": stored.headers.get("Content-Type") ?? "application/json",
                    },
                });
            }

            const storeResult = fromBinary(
                FitStoreResponseSchema,
                new Uint8Array(await stored.arrayBuffer()),
            );
            // Absent proto2 optional strings surface as the field default
            // ""; normalize to null for "store did not report a variant".
            const storedSnapshotHash = storeResult.snapshotHash || null;

            // Read back the exact variant the store computed; absent only
            // from a pre-variant fit-storage, which still serves the newest
            // variant.
            const row = storedSnapshotHash
                ? await c.env.FIT_DB.prepare(
                      "SELECT snapshot FROM fits WHERE fit_hash = ? AND snapshot_hash = ?",
                  )
                      .bind(storeResult.fitHash, storedSnapshotHash)
                      .first<{ snapshot: unknown }>()
                : await c.env.FIT_DB.prepare(
                      "SELECT snapshot FROM fits WHERE fit_hash = ? " +
                          "ORDER BY created_at DESC, rowid DESC LIMIT 1",
                  )
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
                console.error(
                    `stored snapshot of fit ${storeResult.fitHash} failed to decode`,
                    err,
                );
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
                "INSERT INTO posts (post_id, author_id, fit_hash, snapshot_hash, fit_name, description, ship_names, ship_type_id, last_modified_ms, generator) " +
                    "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            )
                .bind(
                    postId,
                    claims.sub,
                    storeResult.fitHash,
                    // Binds the post to the exact fit variant computed at
                    // creation; NULL only when a pre-variant fit-storage
                    // answered (the snapshot read above fell back the same
                    // way the /posts/:id/snapshot join does).
                    storedSnapshotHash,
                    fitName,
                    description,
                    JSON.stringify(shipNames),
                    shipTypeId,
                    lastModifiedMs,
                    generator,
                )
                .run();

            return c.json(
                {
                    postId,
                    fitHash: storeResult.fitHash,
                    alreadyExisted: storeResult.alreadyExisted,
                    snapshotHash: storedSnapshotHash,
                    snapshotFallback: storeResult.snapshotFallback ?? false,
                    postUrl: `${c.env.PLATFORM_SITE_ORIGIN}/post/${postId}`,
                },
                201,
            );
        },
    );

    interface PostRow {
        post_id: string;
        author_id: string | null;
        author_status: string | null;
        fit_hash: string;
        fit_name: string;
        description: string;
        ship_names: string;
        ship_type_id: number;
        last_modified_ms: number;
        generator: string | null;
        created_at: string;
    }

    const POST_LIST_COLUMNS =
        "posts.post_id, posts.author_id, posts.fit_hash, posts.fit_name, posts.description, " +
        "posts.ship_names, posts.ship_type_id, posts.last_modified_ms, posts.generator, " +
        "posts.created_at, users.status AS author_status";

    // Shared list projection; names are localized at projection time.
    function postSummary(row: PostRow, locale: string) {
        return {
            postId: row.post_id,
            authorId: row.author_id,
            // NULL author_id is the deleted-user (or pre-auth legacy)
            // tombstone; an anonymized deregistered row counts too.
            authorDeleted: row.author_id === null || row.author_status === "deregistered",
            fitHash: row.fit_hash,
            fitName: row.fit_name,
            description: row.description,
            shipName: resolveShipName(row.ship_names, locale),
            shipTypeId: row.ship_type_id,
            createdAt: row.created_at,
            lastModifiedMs: row.last_modified_ms,
            generator: row.generator,
        };
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

        const conditions: string[] = [];
        const binds: (string | number)[] = [];
        if (shipTypeId !== null) {
            conditions.push("posts.ship_type_id = ?");
            binds.push(shipTypeId);
        }
        if (windowModifier !== null) {
            conditions.push("posts.created_at >= strftime('%Y-%m-%dT%H:%M:%fZ', 'now', ?)");
            binds.push(windowModifier);
        }
        if (cursor) {
            conditions.push("(posts.created_at, posts.post_id) < (?, ?)");
            binds.push(cursor.createdAt, cursor.postId);
        }
        const where = conditions.length > 0 ? `WHERE ${conditions.join(" AND ")} ` : "";
        const statement = c.env.FIT_DB.prepare(
            `SELECT ${POST_LIST_COLUMNS} FROM posts LEFT JOIN users ON users.user_id = posts.author_id ` +
                `${where}ORDER BY posts.created_at DESC, posts.post_id DESC LIMIT ?`,
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
                posts: page.map((row) => postSummary(row, locale)),
                nextCursor,
            },
            200,
            { "Cache-Control": LIST_CACHE_CONTROL },
        );
    });

    // The caller's own posts. Auth-only: reading one's own posts needs no
    // ACL grant. Same keyset pagination contract as the public list, minus
    // the ship/window filters; private data is never cached.
    app.get(
        "/my/posts",
        requireAccessToken<{ Bindings: Env }>({
            secret: (c) => c.env.AUTH_TOKEN_SECRET,
            validateClaims: requireActiveAccount,
        }),
        async (c) => {
            const claims = getAuthClaims(c);
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

            const cursorRaw = c.req.query("cursor");
            let cursor: { createdAt: string; postId: string } | null = null;
            if (cursorRaw !== undefined) {
                cursor = decodeCursor(cursorRaw);
                if (!cursor) {
                    return errorJson(400, "bad_request", "malformed cursor");
                }
            }

            const conditions = ["posts.author_id = ?"];
            const binds: (string | number)[] = [claims.sub];
            if (cursor) {
                conditions.push("(posts.created_at, posts.post_id) < (?, ?)");
                binds.push(cursor.createdAt, cursor.postId);
            }
            const statement = c.env.FIT_DB.prepare(
                `SELECT ${POST_LIST_COLUMNS} FROM posts ` +
                    "LEFT JOIN users ON users.user_id = posts.author_id " +
                    `WHERE ${conditions.join(" AND ")} ` +
                    "ORDER BY posts.created_at DESC, posts.post_id DESC LIMIT ?",
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
                    posts: page.map((row) => postSummary(row, locale)),
                    nextCursor,
                },
                200,
                { "Cache-Control": "no-store" },
            );
        },
    );

    // Post record.
    app.get("/posts/:id", async (c) => {
        const postId = c.req.param("id");
        if (!UUID_PATTERN.test(postId)) {
            return errorJson(400, "bad_request", "invalid post id");
        }
        const row = await c.env.FIT_DB.prepare(
            "SELECT posts.post_id, posts.author_id, posts.fit_hash, posts.created_at, " +
                "users.status AS author_status, " +
                "(SELECT COUNT(*) FROM comments WHERE comments.post_id = posts.post_id) AS comment_count " +
                "FROM posts " +
                "LEFT JOIN users ON users.user_id = posts.author_id WHERE posts.post_id = ?",
        )
            .bind(postId)
            .first<{
                post_id: string;
                author_id: string | null;
                author_status: string | null;
                fit_hash: string;
                created_at: string;
                comment_count: number;
            }>();
        if (!row) {
            return errorJson(404, "not_found", "unknown post id");
        }
        return c.json({
            postId: row.post_id,
            fitHash: row.fit_hash,
            createdAt: row.created_at,
            authorId: row.author_id,
            authorDeleted: row.author_id === null || row.author_status === "deregistered",
            commentCount: row.comment_count,
        });
    });

    // Delete post. The requirePermission middleware performs the action-level
    // match (any post:delete qualifier); the qualifier itself is validated
    // here against the resource: `all` covers any post, `own` only the
    // caller's own (NULL-author tombstones are never "own"). Only the posts
    // row is deleted — the fits blob is shared by fit_hash and stays.
    app.delete(
        "/posts/:id",
        requireAccessToken<{ Bindings: Env }>({
            secret: (c) => c.env.AUTH_TOKEN_SECRET,
            validateClaims: requireActiveAccount,
        }),
        requirePermission<{ Bindings: Env }>("post:delete"),
        async (c) => {
            const postId = c.req.param("id");
            if (!UUID_PATTERN.test(postId)) {
                return errorJson(400, "bad_request", "invalid post id");
            }
            const row = await c.env.FIT_DB.prepare("SELECT author_id FROM posts WHERE post_id = ?")
                .bind(postId)
                .first<{ author_id: string | null }>();
            if (!row) {
                return errorJson(404, "not_found", "unknown post id");
            }
            const permissions = getAuthPermissions(c);
            const allowed =
                permissions.includes("post:delete:all") ||
                (permissions.includes("post:delete:own") && row.author_id === getAuthClaims(c).sub);
            if (!allowed) {
                return errorJson(403, "forbidden", "permission denied");
            }
            await c.env.FIT_DB.prepare("DELETE FROM posts WHERE post_id = ?").bind(postId).run();
            return c.json({ postId }, 200);
        },
    );

    // Raw FitSnapshot protobuf bytes behind a post. The post is bound to the
    // fit variant computed at its creation (posts.snapshot_hash); legacy NULL
    // bindings fall back to the newest variant.
    app.get("/posts/:id/snapshot", async (c) => {
        const postId = c.req.param("id");
        if (!UUID_PATTERN.test(postId)) {
            return errorJson(400, "bad_request", "invalid post id");
        }
        const row = await c.env.FIT_DB.prepare(
            "SELECT f.snapshot FROM posts p JOIN fits f ON f.fit_hash = p.fit_hash " +
                "WHERE p.post_id = ? AND (p.snapshot_hash IS NULL OR f.snapshot_hash = p.snapshot_hash) " +
                "ORDER BY f.created_at DESC, f.rowid DESC LIMIT 1",
        )
            .bind(postId)
            .first<{ snapshot: unknown }>();
        if (!row) {
            return errorJson(404, "not_found", "unknown post id");
        }
        return blobResponse(row.snapshot);
    });

    // Raw FitSnapshot protobuf bytes addressed directly by fit hash. A fit
    // hash may have several snapshot variants; serve the newest.
    app.get("/fits/:fitHash/snapshot", async (c) => {
        const fitHash = c.req.param("fitHash");
        if (!FIT_HASH_PATTERN.test(fitHash)) {
            return errorJson(400, "bad_request", "invalid fit hash");
        }
        const row = await c.env.FIT_DB.prepare(
            "SELECT snapshot FROM fits WHERE fit_hash = ? " +
                "ORDER BY created_at DESC, rowid DESC LIMIT 1",
        )
            .bind(fitHash)
            .first<{ snapshot: unknown }>();
        if (!row) {
            return errorJson(404, "not_found", "unknown fit hash");
        }
        return blobResponse(row.snapshot);
    });

    // Raw canonical FitState protobuf bytes addressed directly by fit hash.
    // Unlike the snapshot, the state is full-fidelity (dynamic items, custom
    // character skills) and is what registered fit links import from. The
    // state bytes are identical across snapshot variants of a fit hash.
    app.get("/fits/:fitHash/state", async (c) => {
        const fitHash = c.req.param("fitHash");
        if (!FIT_HASH_PATTERN.test(fitHash)) {
            return errorJson(400, "bad_request", "invalid fit hash");
        }
        const row = await c.env.FIT_DB.prepare(
            "SELECT fit_state FROM fits WHERE fit_hash = ? " +
                "ORDER BY created_at DESC, rowid DESC LIMIT 1",
        )
            .bind(fitHash)
            .first<{ fit_state: unknown }>();
        if (!row) {
            return errorJson(404, "not_found", "unknown fit hash");
        }
        return blobResponse(row.fit_state);
    });

    // Discussion comments. The post itself is the titled thread; comments are
    // a flat, chronological list of markdown messages under it. Bodies are
    // stored as raw markdown — rendering and sanitizing are the client's job.
    interface CommentRow {
        comment_id: string;
        author_id: string | null;
        author_status: string | null;
        body: string;
        created_at: string;
    }

    function commentView(row: CommentRow) {
        return {
            commentId: row.comment_id,
            authorId: row.author_id,
            // Same tombstone rule as posts: NULL author_id or a deregistered
            // account renders as a deleted author.
            authorDeleted: row.author_id === null || row.author_status === "deregistered",
            body: row.body,
            createdAt: row.created_at,
        };
    }

    // List a post's comments (keyset pagination over comments_post_created,
    // ascending like a chat log; the cursor carries the last seen row).
    app.get("/posts/:id/comments", async (c) => {
        const postId = c.req.param("id");
        if (!UUID_PATTERN.test(postId)) {
            return errorJson(400, "bad_request", "invalid post id");
        }
        const post = await c.env.FIT_DB.prepare("SELECT post_id FROM posts WHERE post_id = ?")
            .bind(postId)
            .first();
        if (!post) {
            return errorJson(404, "not_found", "unknown post id");
        }

        let limit = DEFAULT_COMMENT_LIST_LIMIT;
        const limitRaw = c.req.query("limit");
        if (limitRaw !== undefined) {
            const parsed = parseLimit(limitRaw, MAX_COMMENT_LIST_LIMIT);
            if (parsed === null) {
                return errorJson(400, "bad_request", "malformed limit");
            }
            limit = parsed;
        }

        const cursorRaw = c.req.query("cursor");
        let cursor: { createdAt: string; postId: string } | null = null;
        if (cursorRaw !== undefined) {
            cursor = decodeCursor(cursorRaw);
            if (!cursor) {
                return errorJson(400, "bad_request", "malformed cursor");
            }
        }

        const conditions = ["comments.post_id = ?"];
        const binds: (string | number)[] = [postId];
        if (cursor) {
            conditions.push("(comments.created_at, comments.comment_id) > (?, ?)");
            binds.push(cursor.createdAt, cursor.postId);
        }
        const statement = c.env.FIT_DB.prepare(
            "SELECT comments.comment_id, comments.author_id, comments.body, comments.created_at, " +
                "users.status AS author_status FROM comments " +
                "LEFT JOIN users ON users.user_id = comments.author_id " +
                `WHERE ${conditions.join(" AND ")} ` +
                "ORDER BY comments.created_at ASC, comments.comment_id ASC LIMIT ?",
        ).bind(...binds, limit + 1);
        const { results } = await statement.all<CommentRow>();

        const page = results.slice(0, limit);
        let nextCursor: string | null = null;
        if (results.length > limit && page.length > 0) {
            const last = page[page.length - 1];
            nextCursor = encodeCursor(last.created_at, last.comment_id);
        }

        return c.json(
            {
                comments: page.map(commentView),
                nextCursor,
            },
            200,
            { "Cache-Control": COMMENT_LIST_CACHE_CONTROL },
        );
    });

    // Create comment. The verified identity becomes the author; the body is
    // stored as raw markdown (empty and oversized bodies are rejected, never
    // silently truncated).
    app.post(
        "/posts/:id/comments",
        requireAccessToken<{ Bindings: Env }>({
            secret: (c) => c.env.AUTH_TOKEN_SECRET,
            validateClaims: requireActiveAccount,
        }),
        requirePermission<{ Bindings: Env }>("comment:create"),
        async (c) => {
            const claims = getAuthClaims(c);
            const postId = c.req.param("id");
            if (!UUID_PATTERN.test(postId)) {
                return errorJson(400, "bad_request", "invalid post id");
            }
            const post = await c.env.FIT_DB.prepare("SELECT post_id FROM posts WHERE post_id = ?")
                .bind(postId)
                .first();
            if (!post) {
                return errorJson(404, "not_found", "unknown post id");
            }

            let payload: unknown;
            try {
                payload = await c.req.json();
            } catch {
                return errorJson(400, "bad_request", "malformed JSON body");
            }
            if (typeof payload !== "object" || payload === null) {
                return errorJson(400, "bad_request", "malformed JSON body");
            }
            const bodyRaw = (payload as { body?: unknown }).body;
            if (typeof bodyRaw !== "string") {
                return errorJson(400, "bad_request", "body must be a string");
            }
            const body = bodyRaw.trim();
            if (body.length === 0) {
                return errorJson(400, "bad_request", "comment body must not be empty");
            }
            if ([...body].length > MAX_COMMENT_BODY_CODE_POINTS) {
                return errorJson(400, "bad_request", "comment body too long");
            }

            const commentId = crypto.randomUUID();
            const row = await c.env.FIT_DB.prepare(
                "INSERT INTO comments (comment_id, post_id, author_id, body) VALUES (?, ?, ?, ?) " +
                    "RETURNING created_at",
            )
                .bind(commentId, postId, claims.sub, body)
                .first<{ created_at: string }>();
            if (!row) {
                console.error(`comment ${commentId} inserted but not readable`);
                return errorJson(500, "internal", "internal server error");
            }

            return c.json(
                {
                    commentId,
                    postId,
                    authorId: claims.sub,
                    authorDeleted: false,
                    body,
                    createdAt: row.created_at,
                },
                201,
            );
        },
    );

    // Delete comment. Same qualifier contract as post deletion: the
    // middleware matches any comment:delete qualifier; `all` covers any
    // comment, `own` only the caller's own (NULL-author tombstones are never
    // "own").
    app.delete(
        "/comments/:id",
        requireAccessToken<{ Bindings: Env }>({
            secret: (c) => c.env.AUTH_TOKEN_SECRET,
            validateClaims: requireActiveAccount,
        }),
        requirePermission<{ Bindings: Env }>("comment:delete"),
        async (c) => {
            const commentId = c.req.param("id");
            if (!UUID_PATTERN.test(commentId)) {
                return errorJson(400, "bad_request", "invalid comment id");
            }
            const row = await c.env.FIT_DB.prepare(
                "SELECT author_id FROM comments WHERE comment_id = ?",
            )
                .bind(commentId)
                .first<{ author_id: string | null }>();
            if (!row) {
                return errorJson(404, "not_found", "unknown comment id");
            }
            const permissions = getAuthPermissions(c);
            const allowed =
                permissions.includes("comment:delete:all") ||
                (permissions.includes("comment:delete:own") &&
                    row.author_id === getAuthClaims(c).sub);
            if (!allowed) {
                return errorJson(403, "forbidden", "permission denied");
            }
            await c.env.FIT_DB.prepare("DELETE FROM comments WHERE comment_id = ?")
                .bind(commentId)
                .run();
            return c.json({ commentId }, 200);
        },
    );

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

    return app;
}

// Root composition and the CORS policy live in root.ts (kept free of
// cloudflare:workers imports so tests can exercise the wiring under Node).
export default createRootApp(createPublicApp(), authApp);
