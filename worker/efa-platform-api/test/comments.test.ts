// Discussion comment tests against the real local bindings (D1, KV, Durable
// Objects) provided by the Workers Vitest integration. The public app is
// composed with an auth sub-app whose email sender is captured (like
// production, minus Resend). Posts and comments are seeded directly into D1
// — the fit-storage orchestration behind POST /posts is covered by
// posts.test.ts.

import { env } from "cloudflare:workers";
import { beforeEach, describe, expect, it } from "vitest";
import { setUserAclRoles } from "../src/auth/acl.ts";
import { createAuthApp } from "../src/auth/router.ts";
import { createPublicApp } from "../src/index.ts";
import { AUTH_MOUNT_PATH, createRootApp, MOUNT_PATH } from "../src/root.ts";
import { type CapturedEmail, clearAuthState } from "./auth/helpers.ts";

const PASSWORD = "password-1234";
const POST_ID = "11111111-1111-4111-8111-111111111111";
const FIT_HASH = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";

interface TokenPair {
    accessToken: string;
    refreshToken: string;
    expiresIn: number;
}

interface CommentView {
    commentId: string;
    authorId: string | null;
    authorDeleted: boolean;
    body: string;
    createdAt: string;
}

function setup() {
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
    const testEnv = { ...env };

    const post = (path: string, body: unknown, headers?: Record<string, string>) =>
        root.fetch(
            new Request(`https://api.efa-tech.dev${path}`, {
                method: "POST",
                headers: { "Content-Type": "application/json", ...headers },
                body: JSON.stringify(body),
            }),
            testEnv,
        );
    const get = (path: string) =>
        root.fetch(new Request(`https://api.efa-tech.dev${path}`), testEnv);
    const del = (path: string, accessToken?: string) =>
        root.fetch(
            new Request(`https://api.efa-tech.dev${path}`, {
                method: "DELETE",
                headers: accessToken ? { Authorization: `Bearer ${accessToken}` } : {},
            }),
            testEnv,
        );
    const createComment = (postId: string, body: unknown, accessToken?: string) =>
        root.fetch(
            new Request(`https://api.efa-tech.dev${MOUNT_PATH}/posts/${postId}/comments`, {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                    ...(accessToken ? { Authorization: `Bearer ${accessToken}` } : {}),
                },
                body: typeof body === "string" ? body : JSON.stringify(body),
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

    return { post, get, del, createComment, register };
}

async function userIdByEmail(email: string): Promise<string> {
    const row = await env.FIT_DB.prepare("SELECT user_id FROM users WHERE email = ?")
        .bind(email)
        .first<{ user_id: string }>();
    expect(row).not.toBeNull();
    return row!.user_id;
}

async function seedPost(postId: string, authorId?: string): Promise<void> {
    await env.FIT_DB.prepare(
        "INSERT INTO posts (post_id, author_id, fit_hash, fit_name, description, ship_names, " +
            "ship_type_id, last_modified_ms) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
    )
        .bind(postId, authorId ?? null, FIT_HASH, "Test Fit", "", '{"en":"Merlin"}', 12017, 42)
        .run();
}

async function seedComment(
    commentId: string,
    overrides?: { postId?: string; authorId?: string | null; body?: string; createdAt?: string },
): Promise<void> {
    await env.FIT_DB.prepare(
        "INSERT INTO comments (comment_id, post_id, author_id, body, created_at) " +
            "VALUES (?, ?, ?, ?, ?)",
    )
        .bind(
            commentId,
            overrides?.postId ?? POST_ID,
            overrides?.authorId ?? null,
            overrides?.body ?? "seeded",
            overrides?.createdAt ?? "2025-01-01T00:00:00.000Z",
        )
        .run();
}

beforeEach(async () => {
    await clearAuthState();
});

describe("GET /posts/:id/comments", () => {
    it("reports unknown and malformed post ids", async () => {
        const { get } = setup();

        const missing = await get(`${MOUNT_PATH}/posts/${POST_ID}/comments`);
        expect(missing.status).toBe(404);
        expect(await missing.json()).toMatchObject({ error: "not_found" });

        const malformed = await get(`${MOUNT_PATH}/posts/not-a-uuid/comments`);
        expect(malformed.status).toBe(400);
        expect(await malformed.json()).toMatchObject({ error: "bad_request" });
    });

    it("lists comments oldest-first with a short public cache", async () => {
        await seedPost(POST_ID);
        await seedComment("00000000-0000-4000-8000-000000000001", {
            body: "first",
            createdAt: "2025-01-01T00:00:00.000Z",
        });
        await seedComment("00000000-0000-4000-8000-000000000002", {
            body: "second",
            createdAt: "2025-01-01T00:01:00.000Z",
        });
        const { get } = setup();

        const res = await get(`${MOUNT_PATH}/posts/${POST_ID}/comments`);
        expect(res.status).toBe(200);
        expect(res.headers.get("Cache-Control")).toBe("public, max-age=10");
        const body = (await res.json()) as { comments: CommentView[]; nextCursor: string | null };
        expect(body.comments.map((c) => c.body)).toEqual(["first", "second"]);
        expect(body.comments[0]).toMatchObject({ authorId: null, authorDeleted: true });
        expect(body.nextCursor).toBeNull();
    });

    it("paginates with a keyset cursor", async () => {
        await seedPost(POST_ID);
        for (let i = 0; i < 3; i++) {
            await seedComment(`00000000-0000-4000-8000-00000000000${i}`, {
                body: `c${i}`,
                createdAt: `2025-01-01T00:00:0${i}.000Z`,
            });
        }
        const { get } = setup();

        const first = await get(`${MOUNT_PATH}/posts/${POST_ID}/comments?limit=2`);
        expect(first.status).toBe(200);
        const firstPage = (await first.json()) as {
            comments: CommentView[];
            nextCursor: string | null;
        };
        expect(firstPage.comments.map((c) => c.body)).toEqual(["c0", "c1"]);
        expect(firstPage.nextCursor).not.toBeNull();

        const second = await get(
            `${MOUNT_PATH}/posts/${POST_ID}/comments?limit=2&cursor=${firstPage.nextCursor}`,
        );
        expect(second.status).toBe(200);
        const secondPage = (await second.json()) as {
            comments: CommentView[];
            nextCursor: string | null;
        };
        expect(secondPage.comments.map((c) => c.body)).toEqual(["c2"]);
        expect(secondPage.nextCursor).toBeNull();
    });

    it("rejects malformed limit and cursor parameters", async () => {
        await seedPost(POST_ID);
        const { get } = setup();

        const limit = await get(`${MOUNT_PATH}/posts/${POST_ID}/comments?limit=1x`);
        expect(limit.status).toBe(400);
        const cursor = await get(`${MOUNT_PATH}/posts/${POST_ID}/comments?cursor=garbage`);
        expect(cursor.status).toBe(400);
    });
});

describe("POST /posts/:id/comments", () => {
    it("rejects requests without a token", async () => {
        await seedPost(POST_ID);
        const { createComment } = setup();

        const res = await createComment(POST_ID, { body: "hello" });
        expect(res.status).toBe(401);
        expect(await res.json()).toMatchObject({ error: "invalid_token" });
    });

    it("rejects an account without the comment:create permission", async () => {
        await seedPost(POST_ID);
        const { createComment, register } = setup();
        const pair = await register("no-create@example.com");
        await setUserAclRoles(env, await userIdByEmail("no-create@example.com"), []);

        const res = await createComment(POST_ID, { body: "hello" }, pair.accessToken);
        expect(res.status).toBe(403);
        expect(await res.json()).toMatchObject({ error: "forbidden" });
    });

    it("creates a comment owned by the active account", async () => {
        await seedPost(POST_ID);
        const { createComment, register } = setup();
        const email = "commenter@example.com";
        const pair = await register(email);

        const res = await createComment(POST_ID, { body: "**markdown** _body_" }, pair.accessToken);
        expect(res.status).toBe(201);
        const created = (await res.json()) as CommentView & { postId: string };
        expect(created).toMatchObject({
            postId: POST_ID,
            authorId: await userIdByEmail(email),
            authorDeleted: false,
            body: "**markdown** _body_",
        });

        const row = await env.FIT_DB.prepare(
            "SELECT author_id, body FROM comments WHERE comment_id = ?",
        )
            .bind(created.commentId)
            .first<{ author_id: string; body: string }>();
        expect(row?.author_id).toBe(await userIdByEmail(email));
        expect(row?.body).toBe("**markdown** _body_");
    });

    it("trims surrounding whitespace from the body", async () => {
        await seedPost(POST_ID);
        const { createComment, register } = setup();
        const pair = await register("trim@example.com");

        const res = await createComment(POST_ID, { body: "  hello  " }, pair.accessToken);
        expect(res.status).toBe(201);
        const created = (await res.json()) as CommentView;
        expect(created.body).toBe("hello");
    });

    it("rejects unknown posts and malformed bodies", async () => {
        await seedPost(POST_ID);
        const { createComment, register } = setup();
        const pair = await register("invalid@example.com");

        const missing = await createComment(
            "22222222-2222-4222-8222-222222222222",
            { body: "hello" },
            pair.accessToken,
        );
        expect(missing.status).toBe(404);

        const badId = await createComment("not-a-uuid", { body: "hello" }, pair.accessToken);
        expect(badId.status).toBe(400);

        const notJson = await createComment(POST_ID, "{", pair.accessToken);
        expect(notJson.status).toBe(400);

        const wrongType = await createComment(POST_ID, { body: 42 }, pair.accessToken);
        expect(wrongType.status).toBe(400);

        const nullPayload = await createComment(POST_ID, null, pair.accessToken);
        expect(nullPayload.status).toBe(400);

        const empty = await createComment(POST_ID, { body: "   " }, pair.accessToken);
        expect(empty.status).toBe(400);

        const oversized = await createComment(
            POST_ID,
            { body: "x".repeat(10_001) },
            pair.accessToken,
        );
        expect(oversized.status).toBe(400);
    });
});

describe("DELETE /comments/:id", () => {
    it("rejects requests without a token", async () => {
        const { del } = setup();
        const res = await del(`${MOUNT_PATH}/comments/33333333-3333-4333-8333-333333333333`);
        expect(res.status).toBe(401);
        expect(await res.json()).toMatchObject({ error: "invalid_token" });
    });

    it("lets the author delete their own comment", async () => {
        await seedPost(POST_ID);
        const { createComment, register, del } = setup();
        const pair = await register("owner@example.com");
        const created = await createComment(POST_ID, { body: "mine" }, pair.accessToken);
        expect(created.status).toBe(201);
        const { commentId } = (await created.json()) as { commentId: string };

        const res = await del(`${MOUNT_PATH}/comments/${commentId}`, pair.accessToken);
        expect(res.status).toBe(200);
        expect(await res.json()).toMatchObject({ commentId });

        const row = await env.FIT_DB.prepare("SELECT comment_id FROM comments WHERE comment_id = ?")
            .bind(commentId)
            .first();
        expect(row).toBeNull();
    });

    it("rejects a non-author holding only comment:delete:own", async () => {
        await seedPost(POST_ID);
        const { createComment, register, del } = setup();
        const owner = await register("real-owner@example.com");
        const created = await createComment(POST_ID, { body: "not yours" }, owner.accessToken);
        const { commentId } = (await created.json()) as { commentId: string };
        const stranger = await register("stranger@example.com");

        const res = await del(`${MOUNT_PATH}/comments/${commentId}`, stranger.accessToken);
        expect(res.status).toBe(403);
        expect(await res.json()).toMatchObject({ error: "forbidden" });
    });

    it("lets a comment:delete:all holder delete another account's comment", async () => {
        await seedPost(POST_ID);
        const { createComment, register, del } = setup();
        const owner = await register("victim@example.com");
        const created = await createComment(POST_ID, { body: "flagged" }, owner.accessToken);
        const { commentId } = (await created.json()) as { commentId: string };
        const moderator = await register("moderator@example.com");
        await setUserAclRoles(env, await userIdByEmail("moderator@example.com"), ["moderator"]);

        const res = await del(`${MOUNT_PATH}/comments/${commentId}`, moderator.accessToken);
        expect(res.status).toBe(200);
    });

    it("rejects deleting a NULL-author tombstone with comment:delete:own only", async () => {
        await seedPost(POST_ID);
        await seedComment("44444444-4444-4444-8444-444444444444", { authorId: null });
        const { register, del } = setup();
        const pair = await register("tombstone@example.com");

        const res = await del(
            `${MOUNT_PATH}/comments/44444444-4444-4444-8444-444444444444`,
            pair.accessToken,
        );
        expect(res.status).toBe(403);
        expect(await res.json()).toMatchObject({ error: "forbidden" });
    });

    it("rejects an account without any comment:delete qualifier", async () => {
        await seedPost(POST_ID);
        const { createComment, register, del } = setup();
        const owner = await register("perm-owner@example.com");
        const created = await createComment(POST_ID, { body: "protected" }, owner.accessToken);
        const { commentId } = (await created.json()) as { commentId: string };
        const stripped = await register("stripped@example.com");
        await setUserAclRoles(env, await userIdByEmail("stripped@example.com"), []);

        const res = await del(`${MOUNT_PATH}/comments/${commentId}`, stripped.accessToken);
        expect(res.status).toBe(403);
        expect(await res.json()).toMatchObject({ error: "forbidden" });
    });

    it("reports unknown and malformed comment ids", async () => {
        const { register, del } = setup();
        const pair = await register("ids@example.com");

        const missing = await del(
            `${MOUNT_PATH}/comments/55555555-5555-4555-8555-555555555555`,
            pair.accessToken,
        );
        expect(missing.status).toBe(404);
        expect(await missing.json()).toMatchObject({ error: "not_found" });

        const malformed = await del(`${MOUNT_PATH}/comments/not-a-uuid`, pair.accessToken);
        expect(malformed.status).toBe(400);
        expect(await malformed.json()).toMatchObject({ error: "bad_request" });
    });
});

describe("comment lifecycle with posts and users", () => {
    it("marks comments of a deregistered author as deleted", async () => {
        await seedPost(POST_ID);
        const { post, get, createComment, register } = setup();
        const email = "deregistered@example.com";
        const pair = await register(email);
        const userId = await userIdByEmail(email);
        const created = await createComment(POST_ID, { body: "bye" }, pair.accessToken);
        expect(created.status).toBe(201);
        const { commentId } = (await created.json()) as { commentId: string };

        const deregister = await post(
            `${AUTH_MOUNT_PATH}/deregister`,
            { password: PASSWORD },
            { Authorization: `Bearer ${pair.accessToken}` },
        );
        expect(deregister.status).toBe(200);

        const list = await get(`${MOUNT_PATH}/posts/${POST_ID}/comments`);
        expect(list.status).toBe(200);
        const { comments } = (await list.json()) as { comments: CommentView[] };
        expect(comments).toHaveLength(1);
        expect(comments[0]).toMatchObject({
            commentId,
            authorId: userId,
            authorDeleted: true,
        });
    });

    it("sets author_id to NULL when the author row is hard-deleted", async () => {
        const userId = crypto.randomUUID();
        await env.FIT_DB.prepare(
            "INSERT INTO users (user_id, email, password_hash, status) VALUES (?, ?, '', 'active')",
        )
            .bind(userId, "hard-delete@example.com")
            .run();
        await seedPost(POST_ID);
        await seedComment("66666666-6666-4666-8666-666666666666", { authorId: userId });

        await env.FIT_DB.prepare("DELETE FROM users WHERE user_id = ?").bind(userId).run();

        const row = await env.FIT_DB.prepare("SELECT author_id FROM comments WHERE comment_id = ?")
            .bind("66666666-6666-4666-8666-666666666666")
            .first<{ author_id: string | null }>();
        expect(row?.author_id).toBeNull();
    });

    it("cascades comment deletion when the post is deleted", async () => {
        await seedPost(POST_ID);
        await seedComment("77777777-7777-4777-8777-777777777777");

        await env.FIT_DB.prepare("DELETE FROM posts WHERE post_id = ?").bind(POST_ID).run();

        const row = await env.FIT_DB.prepare("SELECT comment_id FROM comments WHERE comment_id = ?")
            .bind("77777777-7777-4777-8777-777777777777")
            .first();
        expect(row).toBeNull();
    });

    it("reports the comment count on the post record", async () => {
        await seedPost(POST_ID);
        await seedComment("88888888-8888-4888-8888-888888888888", {
            createdAt: "2025-01-01T00:00:00.000Z",
        });
        await seedComment("88888888-8888-4888-8888-888888888889", {
            createdAt: "2025-01-01T00:01:00.000Z",
        });
        const { get } = setup();

        const res = await get(`${MOUNT_PATH}/posts/${POST_ID}`);
        expect(res.status).toBe(200);
        expect(await res.json()).toMatchObject({ postId: POST_ID, commentCount: 2 });
    });
});
