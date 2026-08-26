// Middleware tests for requirePermission/getAuthPermissions against a
// minimal Hono app on the real local D1/KV bindings; the token codec and
// requireAccessToken itself are covered by tokens.test.ts and
// middleware.test.ts.

import { env } from "cloudflare:workers";
import { Hono } from "hono";
import { beforeEach, describe, expect, it } from "vitest";
import { setUserAclRoles } from "../../src/auth/acl.ts";
import { requireAccessToken, requireActiveAccount } from "../../src/auth/middleware.ts";
import { getAuthPermissions, requirePermission } from "../../src/auth/permission.ts";
import { signAccessToken } from "../../src/auth/tokens.ts";
import { clearAuthState } from "./helpers.ts";

interface TestEnv {
    Bindings: {
        FIT_DB: D1Database;
        AUTH_KV: KVNamespace;
        AUTH_TOKEN_SECRET?: string;
    };
}

function setup(action: "post:create" | "post:delete") {
    const app = new Hono<TestEnv>();
    app.get(
        "/protected",
        requireAccessToken<TestEnv>({
            secret: (c) => c.env.AUTH_TOKEN_SECRET,
            validateClaims: requireActiveAccount,
        }),
        requirePermission<TestEnv>(action),
        (c) => c.json({ permissions: getAuthPermissions(c) }, 200),
    );
    return app;
}

async function seedUser(roles?: string[]): Promise<{ userId: string; token: string }> {
    const userId = crypto.randomUUID();
    await env.FIT_DB.prepare(
        "INSERT INTO users (user_id, email, password_hash, status) VALUES (?, ?, '', 'active')",
    )
        .bind(userId, `${userId}@example.com`)
        .run();
    if (roles !== undefined) {
        await setUserAclRoles(env, userId, roles);
    }
    const token = await signAccessToken(env.AUTH_TOKEN_SECRET, userId, 0);
    return { userId, token };
}

function get(app: Hono<TestEnv>, token?: string): Promise<Response> {
    return Promise.resolve(
        app.fetch(
            new Request("https://example.com/protected", {
                headers: token === undefined ? {} : { Authorization: `Bearer ${token}` },
            }),
            env as unknown as TestEnv["Bindings"],
        ),
    );
}

beforeEach(async () => {
    await clearAuthState();
});

describe("requirePermission", () => {
    it("rejects requests without a token as 401 before any ACL check", async () => {
        const res = await get(setup("post:create"));
        expect(res.status).toBe(401);
        expect(await res.json()).toMatchObject({ error: "invalid_token" });
    });

    it("passes an unqualified action when the exact token is present", async () => {
        const { token } = await seedUser();
        const res = await get(setup("post:create"), token);
        expect(res.status).toBe(200);
        const body = (await res.json()) as { permissions: string[] };
        expect(body.permissions).toContain("post:create");
    });

    it("rejects an unqualified action when the token is absent", async () => {
        const { token } = await seedUser([]);
        const res = await get(setup("post:create"), token);
        expect(res.status).toBe(403);
        expect(await res.json()).toMatchObject({ error: "forbidden" });
    });

    it("passes a qualified action when any qualifier token is present", async () => {
        // The default "user" role holds post:delete:own only; the
        // action-level gate does not distinguish qualifiers.
        const { token } = await seedUser();
        const res = await get(setup("post:delete"), token);
        expect(res.status).toBe(200);
        const body = (await res.json()) as { permissions: string[] };
        expect(body.permissions).toContain("post:delete:own");
        expect(body.permissions).not.toContain("post:delete:all");
    });

    it("rejects a qualified action when no qualifier token is present", async () => {
        const { token } = await seedUser([]);
        const res = await get(setup("post:delete"), token);
        expect(res.status).toBe(403);
        expect(await res.json()).toMatchObject({ error: "forbidden" });
    });
});
