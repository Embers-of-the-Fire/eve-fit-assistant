// Post ownership tests against the real local bindings (D1, KV, Durable
// Objects) provided by the Workers Vitest integration. The public app is
// composed with an auth sub-app whose email sender is captured (like
// production, minus Resend); the FIT_STORAGE service binding is replaced by
// a per-test fake answering the store RPC, and the fits table (owned by
// efa-platform-fit-storage, so absent from this worker's migrations) is
// created inline.

import { applyD1Migrations, reset } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { beforeEach, describe, expect, it } from "vitest";
import { setUserAclRoles } from "../src/auth/acl.ts";
import { createAuthApp } from "../src/auth/router.ts";
import { createPublicApp } from "../src/index.ts";
import { AUTH_MOUNT_PATH, createRootApp, MOUNT_PATH } from "../src/root.ts";
import { type CapturedEmail, clearAuthState } from "./auth/helpers.ts";

const PASSWORD = "password-1234";
const FIT_HASH = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";

// Pre-encoded protobuf fixtures (generated once from the schemas in
// data/schema/ via efa-proto-ts; kept as constants so tests do not depend on
// the protobuf runtime's behavior inside workerd).
// FitStoreResponse { fit_hash: FIT_HASH, already_existed: false }.
const STORE_RESPONSE_B64 =
    "CkAwMTIzNDU2Nzg5YWJjZGVmMDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWYwMTIzNDU2Nzg5YWJjZGVmEAA=";
// Minimal but fully-valid FitSnapshot (proto2 required fields only): the
// worker decodes it after the store write and denormalizes the post row
// from it. fit_name "Test Fit", ship type 12017 "Merlin", ALL_5 character.
const SNAPSHOT_B64 =
    "CAESFgoIVGVzdCBGaXQY0oXYzAQg0oXYzAQaJwoRCPFdEgwKAmVuEgZNZXJsaW4SEggDEAMYASADKAAwADgCQAFIAHoCEAKCASQJAAAAAAAA0D8RAAAAAAAA0D8ZAAAAAAAA0D8hAAAAAAAA0D8=";

function b64ToBytes(b64: string): Uint8Array {
    return Uint8Array.from(atob(b64), (ch) => ch.charCodeAt(0));
}

interface TokenPair {
    accessToken: string;
    refreshToken: string;
    expiresIn: number;
}

// The fits table is owned by efa-platform-fit-storage (its 0001_init.sql is
// not part of this worker's migration set), so tests create and seed it
// themselves.
async function seedFit(fitHash: string): Promise<void> {
    await env.FIT_DB.exec(
        "CREATE TABLE fits (" +
            "fit_hash TEXT PRIMARY KEY, server_id TEXT NOT NULL, snapshot_hash TEXT NOT NULL, " +
            "fit_state BLOB NOT NULL, snapshot BLOB NOT NULL, " +
            "created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')))",
    );
    await env.FIT_DB.prepare(
        "INSERT INTO fits (fit_hash, server_id, snapshot_hash, fit_state, snapshot) " +
            "VALUES (?, ?, ?, ?, ?)",
    )
        .bind(fitHash, "Tranquility", "snapshot-hash", new Uint8Array([1]), b64ToBytes(SNAPSHOT_B64))
        .run();
}

function setup(options?: { storageResponse?: Response }) {
    const emails: CapturedEmail[] = [];
    const root = createRootApp(
        createPublicApp(),
        createAuthApp({
            sendEmail: (_env, input) => {
                emails.push({ ...input });
                return Promise.resolve(true);
            },
        }),
    );
    const storage =
        options?.storageResponse ??
        new Response(b64ToBytes(STORE_RESPONSE_B64), {
            status: 200,
            headers: { "Content-Type": "application/x-protobuf" },
        });
    const testEnv = {
        ...env,
        FIT_STORAGE: { fetch: () => Promise.resolve(storage.clone()) } as unknown as Fetcher,
    };

    const post = (path: string, body: unknown, headers?: Record<string, string>) =>
        root.fetch(
            new Request(`https://api.efa-tech.dev${path}`, {
                method: "POST",
                headers: { "Content-Type": "application/json", ...headers },
                body: JSON.stringify(body),
            }),
            testEnv,
        );
    const get = (path: string, accessToken?: string) =>
        root.fetch(
            new Request(`https://api.efa-tech.dev${path}`, {
                headers: accessToken ? { Authorization: `Bearer ${accessToken}` } : {},
            }),
            testEnv,
        );
    const del = (path: string, accessToken?: string) =>
        root.fetch(
            new Request(`https://api.efa-tech.dev${path}`, {
                method: "DELETE",
                headers: accessToken ? { Authorization: `Bearer ${accessToken}` } : {},
            }),
            testEnv,
        );
    const upload = (accessToken?: string) =>
        root.fetch(
            new Request(`https://api.efa-tech.dev${MOUNT_PATH}/posts`, {
                method: "POST",
                headers: {
                    "Content-Type": "application/x-protobuf",
                    ...(accessToken ? { Authorization: `Bearer ${accessToken}` } : {}),
                },
                body: new Uint8Array([1, 2, 3]),
            }),
            testEnv,
        );

    // Signup + verify-email through the real auth mount; resolves to the
    // issued token pair.
    const register = async (email: string): Promise<TokenPair> => {
        const signup = await post(`${AUTH_MOUNT_PATH}/signup`, { email, password: PASSWORD });
        expect(signup.status).toBe(201);
        const mail = emails.findLast((m) => m.to === email && m.purpose === "verify");
        expect(mail).toBeDefined();
        const verify = await post(`${AUTH_MOUNT_PATH}/verify-email`, {
            email,
            code: mail!.code,
        });
        expect(verify.status).toBe(200);
        return (await verify.json()) as TokenPair;
    };

    return { post, get, del, upload, register };
}

async function userIdByEmail(email: string): Promise<string> {
    const row = await env.FIT_DB.prepare("SELECT user_id FROM users WHERE email = ?")
        .bind(email)
        .first<{ user_id: string }>();
    expect(row).not.toBeNull();
    return row!.user_id;
}

beforeEach(async () => {
    await clearAuthState();
    await seedFit(FIT_HASH);
});

describe("migration 0004_post_author", () => {
    // Applies only the pre-author migrations so legacy-shaped rows can be
    // seeded before 0004 runs.
    async function applyPreAuthorMigrations(): Promise<void> {
        await reset();
        const preAuthor = env.TEST_MIGRATIONS.filter((m) => m.name < "0004");
        await applyD1Migrations(env.FIT_DB, preAuthor);
    }

    it("carries legacy anonymous posts over with a NULL author tombstone", async () => {
        await applyPreAuthorMigrations();
        await env.FIT_DB.prepare(
            "INSERT INTO posts (post_id, fit_hash, fit_name, description, ship_names, " +
                "ship_type_id, last_modified_ms, generator, created_at) " +
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
        )
            .bind(
                "11111111-1111-4111-8111-111111111111",
                FIT_HASH,
                "Legacy Fit",
                "legacy",
                '{"en":"Merlin"}',
                12017,
                42,
                "eve-fit-assistant/1.0.0",
                "2025-01-01T00:00:00.000Z",
            )
            .run();

        await applyD1Migrations(env.FIT_DB, env.TEST_MIGRATIONS);

        const row = await env.FIT_DB.prepare("SELECT * FROM posts WHERE post_id = ?")
            .bind("11111111-1111-4111-8111-111111111111")
            .first<Record<string, unknown>>();
        expect(row).toMatchObject({
            author_id: null,
            fit_hash: FIT_HASH,
            fit_name: "Legacy Fit",
            ship_type_id: 12017,
            last_modified_ms: 42,
            generator: "eve-fit-assistant/1.0.0",
            created_at: "2025-01-01T00:00:00.000Z",
        });
    });

    it("creates a nullable author_id with ON DELETE SET NULL and the posts_author index", async () => {
        // beforeEach already applied the full migration set.
        const { results: columns } = await env.FIT_DB.prepare(
            "PRAGMA table_info(posts)",
        ).all<{ name: string; notnull: number }>();
        const author = columns.find((c) => c.name === "author_id");
        expect(author).toBeDefined();
        expect(author!.notnull).toBe(0);

        const { results: fks } = await env.FIT_DB.prepare(
            "PRAGMA foreign_key_list(posts)",
        ).all<{ table: string; from: string; to: string; on_delete: string }>();
        expect(fks).toContainEqual(
            expect.objectContaining({ table: "users", from: "author_id", on_delete: "SET NULL" }),
        );

        const { results: indexes } = await env.FIT_DB.prepare("PRAGMA index_list(posts)").all<{
            name: string;
        }>();
        expect(indexes.map((i) => i.name)).toContain("posts_author");
    });

    it("sets author_id to NULL when the author row is hard-deleted", async () => {
        const userId = crypto.randomUUID();
        await env.FIT_DB.prepare(
            "INSERT INTO users (user_id, email, password_hash, status) VALUES (?, ?, '', 'active')",
        )
            .bind(userId, "hard-delete@example.com")
            .run();
        await env.FIT_DB.prepare(
            "INSERT INTO posts (post_id, author_id, fit_hash, fit_name, description, ship_names, " +
                "ship_type_id, last_modified_ms) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        )
            .bind(
                "22222222-2222-4222-8222-222222222222",
                userId,
                FIT_HASH,
                "Owned Fit",
                "",
                '{"en":"Merlin"}',
                12017,
                42,
            )
            .run();

        await env.FIT_DB.prepare("DELETE FROM users WHERE user_id = ?").bind(userId).run();

        const row = await env.FIT_DB.prepare(
            "SELECT author_id FROM posts WHERE post_id = ?",
        )
            .bind("22222222-2222-4222-8222-222222222222")
            .first<{ author_id: string | null }>();
        expect(row?.author_id).toBeNull();
    });
});

describe("POST /posts auth", () => {
    it("rejects requests without a token", async () => {
        const { upload } = setup();
        const res = await upload();
        expect(res.status).toBe(401);
        expect(await res.json()).toMatchObject({ error: "invalid_token" });
    });

    it("rejects a deregistered user's token", async () => {
        const { post, upload, register } = setup();
        const email = "deregistered@example.com";
        const pair = await register(email);
        const deregister = await post(
            `${AUTH_MOUNT_PATH}/deregister`,
            { password: PASSWORD },
            { Authorization: `Bearer ${pair.accessToken}` },
        );
        expect(deregister.status).toBe(200);

        const res = await upload(pair.accessToken);
        expect(res.status).toBe(401);
        expect(await res.json()).toMatchObject({ error: "invalid_token" });
    });

    it("creates a post owned by the active account", async () => {
        const { upload, register } = setup();
        const email = "author@example.com";
        const pair = await register(email);

        const res = await upload(pair.accessToken);
        expect(res.status).toBe(201);
        const body = (await res.json()) as { postId: string; fitHash: string; postUrl: string };
        expect(body.fitHash).toBe(FIT_HASH);
        expect(body.postUrl).toBe(`https://platform.efa-tech.dev/post/${body.postId}`);

        const row = await env.FIT_DB.prepare("SELECT author_id FROM posts WHERE post_id = ?")
            .bind(body.postId)
            .first<{ author_id: string }>();
        expect(row?.author_id).toBe(await userIdByEmail(email));
    });

    it("rejects an account without the post:create permission", async () => {
        const { upload, register } = setup();
        const pair = await register("no-create@example.com");
        await setUserAclRoles(env, await userIdByEmail("no-create@example.com"), []);

        const res = await upload(pair.accessToken);
        expect(res.status).toBe(403);
        expect(await res.json()).toMatchObject({ error: "forbidden" });
    });
});

describe("GET /my/posts", () => {
    it("rejects requests without a token", async () => {
        const { get } = setup();
        const res = await get(`${MOUNT_PATH}/my/posts`);
        expect(res.status).toBe(401);
        expect(await res.json()).toMatchObject({ error: "invalid_token" });
    });

    it("lists only the caller's own posts and is never cached", async () => {
        const { upload, register, get } = setup();
        const own = await register("mine@example.com");
        const other = await register("other@example.com");
        const ownUpload = await upload(own.accessToken);
        expect(ownUpload.status).toBe(201);
        const { postId } = (await ownUpload.json()) as { postId: string };
        expect((await upload(other.accessToken)).status).toBe(201);

        const res = await get(`${MOUNT_PATH}/my/posts`, own.accessToken);
        expect(res.status).toBe(200);
        expect(res.headers.get("Cache-Control")).toBe("no-store");
        const body = (await res.json()) as {
            posts: Record<string, unknown>[];
            nextCursor: string | null;
        };
        expect(body.posts).toHaveLength(1);
        expect(body.posts[0]).toMatchObject({
            postId,
            authorId: await userIdByEmail("mine@example.com"),
            authorDeleted: false,
        });
        expect(body.nextCursor).toBeNull();
    });

    it("rejects a malformed cursor", async () => {
        const { register, get } = setup();
        const pair = await register("cursor@example.com");
        const res = await get(`${MOUNT_PATH}/my/posts?cursor=garbage`, pair.accessToken);
        expect(res.status).toBe(400);
        expect(await res.json()).toMatchObject({ error: "bad_request" });
    });
});

describe("DELETE /posts/:id", () => {
    async function uploadAs(email: string): Promise<{ postId: string; pair: TokenPair }> {
        const { upload, register } = setup();
        const pair = await register(email);
        const res = await upload(pair.accessToken);
        expect(res.status).toBe(201);
        const { postId } = (await res.json()) as { postId: string };
        return { postId, pair };
    }

    it("rejects requests without a token", async () => {
        const { del } = setup();
        const res = await del(`${MOUNT_PATH}/posts/44444444-4444-4444-8444-444444444444`);
        expect(res.status).toBe(401);
        expect(await res.json()).toMatchObject({ error: "invalid_token" });
    });

    it("lets the owner delete their own post and keeps the shared fit row", async () => {
        const { postId, pair } = await uploadAs("owner@example.com");
        const { del } = setup();

        const res = await del(`${MOUNT_PATH}/posts/${postId}`, pair.accessToken);
        expect(res.status).toBe(200);
        expect(await res.json()).toMatchObject({ postId });

        const post = await env.FIT_DB.prepare("SELECT post_id FROM posts WHERE post_id = ?")
            .bind(postId)
            .first();
        expect(post).toBeNull();
        const fit = await env.FIT_DB.prepare("SELECT fit_hash FROM fits WHERE fit_hash = ?")
            .bind(FIT_HASH)
            .first();
        expect(fit).not.toBeNull();
    });

    it("rejects a non-owner holding only post:delete:own", async () => {
        const { postId } = await uploadAs("real-owner@example.com");
        const { register, del } = setup();
        const stranger = await register("stranger@example.com");

        const res = await del(`${MOUNT_PATH}/posts/${postId}`, stranger.accessToken);
        expect(res.status).toBe(403);
        expect(await res.json()).toMatchObject({ error: "forbidden" });
    });

    it("lets a post:delete:all holder delete another account's post", async () => {
        const { postId } = await uploadAs("victim@example.com");
        const { register, del } = setup();
        const moderator = await register("moderator@example.com");
        await setUserAclRoles(env, await userIdByEmail("moderator@example.com"), ["moderator"]);

        const res = await del(`${MOUNT_PATH}/posts/${postId}`, moderator.accessToken);
        expect(res.status).toBe(200);
    });

    it("rejects deleting a NULL-author tombstone with post:delete:own only", async () => {
        await env.FIT_DB.prepare(
            "INSERT INTO posts (post_id, author_id, fit_hash, fit_name, description, ship_names, " +
                "ship_type_id, last_modified_ms) VALUES (?, NULL, ?, ?, ?, ?, ?, ?)",
        )
            .bind(
                "55555555-5555-4555-8555-555555555555",
                FIT_HASH,
                "Legacy Fit",
                "",
                '{"en":"Merlin"}',
                12017,
                42,
            )
            .run();
        const { register, del } = setup();
        const pair = await register("tombstone@example.com");

        const res = await del(
            `${MOUNT_PATH}/posts/55555555-5555-4555-8555-555555555555`,
            pair.accessToken,
        );
        expect(res.status).toBe(403);
        expect(await res.json()).toMatchObject({ error: "forbidden" });
    });

    it("rejects an account without any post:delete qualifier", async () => {
        const { postId } = await uploadAs("perm-owner@example.com");
        const { register, del } = setup();
        const stripped = await register("stripped@example.com");
        await setUserAclRoles(env, await userIdByEmail("stripped@example.com"), []);

        const res = await del(`${MOUNT_PATH}/posts/${postId}`, stripped.accessToken);
        expect(res.status).toBe(403);
        expect(await res.json()).toMatchObject({ error: "forbidden" });
    });

    it("reports unknown and malformed post ids", async () => {
        const { register, del } = setup();
        const pair = await register("ids@example.com");

        const missing = await del(
            `${MOUNT_PATH}/posts/66666666-6666-4666-8666-666666666666`,
            pair.accessToken,
        );
        expect(missing.status).toBe(404);
        expect(await missing.json()).toMatchObject({ error: "not_found" });

        const malformed = await del(`${MOUNT_PATH}/posts/not-a-uuid`, pair.accessToken);
        expect(malformed.status).toBe(400);
        expect(await malformed.json()).toMatchObject({ error: "bad_request" });
    });
});

describe("post author reads", () => {
    async function uploadAsAuthor(): Promise<{ postId: string; userId: string; pair: TokenPair }> {
        const { upload, register } = setup();
        const email = "reader-author@example.com";
        const pair = await register(email);
        const res = await upload(pair.accessToken);
        expect(res.status).toBe(201);
        const { postId } = (await res.json()) as { postId: string };
        return { postId, userId: await userIdByEmail(email), pair };
    }

    it("reports the active author on the list and detail endpoints", async () => {
        const { postId, userId } = await uploadAsAuthor();
        const { get } = setup();

        const detail = await get(`${MOUNT_PATH}/posts/${postId}`);
        expect(detail.status).toBe(200);
        expect(await detail.json()).toMatchObject({
            postId,
            authorId: userId,
            authorDeleted: false,
        });

        const list = await get(`${MOUNT_PATH}/posts`);
        expect(list.status).toBe(200);
        const { posts } = (await list.json()) as { posts: Record<string, unknown>[] };
        expect(posts).toHaveLength(1);
        expect(posts[0]).toMatchObject({ postId, authorId: userId, authorDeleted: false });
    });

    it("keeps the post readable with authorDeleted after the real deregister flow", async () => {
        const { postId, userId, pair } = await uploadAsAuthor();
        const { post, get } = setup();
        const deregister = await post(
            `${AUTH_MOUNT_PATH}/deregister`,
            { password: PASSWORD },
            { Authorization: `Bearer ${pair.accessToken}` },
        );
        expect(deregister.status).toBe(200);

        const detail = await get(`${MOUNT_PATH}/posts/${postId}`);
        expect(detail.status).toBe(200);
        expect(await detail.json()).toMatchObject({ postId, authorDeleted: true });

        const list = await get(`${MOUNT_PATH}/posts`);
        const { posts } = (await list.json()) as { posts: Record<string, unknown>[] };
        expect(posts).toHaveLength(1);
        expect(posts[0]).toMatchObject({ postId, authorId: userId, authorDeleted: true });
    });

    it("reports legacy NULL-author posts as deleted", async () => {
        await env.FIT_DB.prepare(
            "INSERT INTO posts (post_id, author_id, fit_hash, fit_name, description, ship_names, " +
                "ship_type_id, last_modified_ms) VALUES (?, NULL, ?, ?, ?, ?, ?, ?)",
        )
            .bind(
                "33333333-3333-4333-8333-333333333333",
                FIT_HASH,
                "Legacy Fit",
                "",
                '{"en":"Merlin"}',
                12017,
                42,
            )
            .run();
        const { get } = setup();

        const detail = await get(`${MOUNT_PATH}/posts/33333333-3333-4333-8333-333333333333`);
        expect(detail.status).toBe(200);
        expect(await detail.json()).toMatchObject({ authorId: null, authorDeleted: true });

        const list = await get(`${MOUNT_PATH}/posts`);
        const { posts } = (await list.json()) as { posts: Record<string, unknown>[] };
        expect(posts).toHaveLength(1);
        expect(posts[0]).toMatchObject({ authorId: null, authorDeleted: true });
    });
});
