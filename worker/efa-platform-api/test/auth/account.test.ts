// Account endpoint tests (`POST /account`): identity plus ACL roles and
// resolved permissions, with the roles column in D1 as the source of truth
// and the AUTH_KV resolved-permission cache alongside. Expectations for the
// default roles derive from the efa-acl-ts bindings, so a divergence between
// the SQL column default and the schema's declared defaults fails here.

import { aclDefaultRoles, tokensForRoles } from "efa-acl-ts";
import { beforeEach, describe, expect, it } from "vitest";
import { getUserAcl, setUserAclRoles } from "../../src/auth/acl.ts";
import { getUserById, updateUserAclRoles } from "../../src/auth/store.ts";
import { clearAuthState, setupAuthApp, type TestEnv } from "./helpers.ts";

const PASSWORD = "password-1234";

interface TokenPair {
    accessToken: string;
    refreshToken: string;
    expiresIn: number;
}

interface AccountInfo {
    userId: string;
    email: string;
    roles: string[];
    permissions: string[];
}

beforeEach(async () => {
    await clearAuthState();
});

function setup() {
    const { app, testEnv, emails } = setupAuthApp();
    const post = (
        path: string,
        body: unknown,
        headers?: Record<string, string>,
    ): Promise<Response> =>
        Promise.resolve(
            app.fetch(
                new Request(`https://example.com${path}`, {
                    method: "POST",
                    headers: { "content-type": "application/json", ...(headers ?? {}) },
                    body: JSON.stringify(body),
                }),
                testEnv,
            ),
        );
    /** Signup + verify; resolves to the issued token pair. */
    const register = async (email: string): Promise<TokenPair> => {
        expect((await post("/signup", { email, password: PASSWORD })).status).toBe(201);
        const mail = emails.findLast((m) => m.to === email && m.purpose === "verify");
        if (!mail) {
            throw new Error(`expected a verify email to ${email}`);
        }
        const res = await post("/verify-email", { email, code: mail.code });
        expect(res.status).toBe(200);
        return (await res.json()) as TokenPair;
    };
    const account = (accessToken: string): Promise<Response> =>
        post("/account", {}, { Authorization: `Bearer ${accessToken}` });
    return { testEnv, register, account };
}

async function expectAccount(
    testEnv: TestEnv,
    accessToken: string,
    expected: { email: string; roles: string[]; permissions: string[] },
): Promise<void> {
    const res = await setup().account(accessToken);
    expect(res.status).toBe(200);
    const info = (await res.json()) as AccountInfo;
    expect(info.email).toBe(expected.email);
    expect(info.roles).toEqual(expected.roles);
    expect([...info.permissions].sort()).toEqual([...expected.permissions].sort());
    // The response's user id must match the stored account row.
    const user = await getUserById(testEnv.FIT_DB, info.userId);
    expect(user?.email).toBe(expected.email);
}

describe("account endpoint", () => {
    it("returns the default placeholder role and its resolved permissions", async () => {
        const { testEnv, register } = setup();
        const pair = await register("user@example.com");
        await expectAccount(testEnv, pair.accessToken, {
            email: "user@example.com",
            roles: [...aclDefaultRoles],
            permissions: tokensForRoles(aclDefaultRoles),
        });
        // The SQL column default must match the schema's declared defaults.
        const user = await getUserById(testEnv.FIT_DB, (
            await (await setup().account(pair.accessToken)).json() as AccountInfo
        ).userId);
        expect(user?.acl_roles).toBe(JSON.stringify(aclDefaultRoles));
    });

    it("rejects missing or invalid access tokens", async () => {
        const { account } = setup();
        expect((await account("not-a-token")).status).toBe(401);
        const res = await account("");
        expect(res.status).toBe(401);
        expect(await res.json()).toEqual({
            error: "invalid_token",
            message: "missing or invalid access token",
        });
    });

    it("reflects role writes through the cache-busting setter", async () => {
        const { testEnv, register, account } = setup();
        const pair = await register("mod@example.com");

        // Populate the cache with the default resolution.
        const first = await account(pair.accessToken);
        expect(((await first.json()) as AccountInfo).roles).toEqual([...aclDefaultRoles]);

        const userId = await userIdOf(testEnv, "mod@example.com");
        await setUserAclRoles(testEnv, userId, ["moderator"]);

        const res = await account(pair.accessToken);
        expect(res.status).toBe(200);
        const info = (await res.json()) as AccountInfo;
        expect(info.roles).toEqual(["moderator"]);
        expect([...info.permissions].sort()).toEqual(tokensForRoles(["moderator"]).sort());
    });

    it("self-heals a stale cache entry when the stored roles diverge", async () => {
        const { testEnv, register, account } = setup();
        const pair = await register("admin@example.com");

        // Populate the cache with the default resolution.
        await account(pair.accessToken);

        // Bypass the cache-busting setter (e.g. a manual D1 edit): the roles
        // JSON guard must detect the divergence and recompute.
        const userId = await userIdOf(testEnv, "admin@example.com");
        await updateUserAclRoles(testEnv.FIT_DB, userId, ["admin", "user"]);

        const res = await account(pair.accessToken);
        expect(res.status).toBe(200);
        const info = (await res.json()) as AccountInfo;
        expect(info.roles).toEqual(["admin", "user"]);
        expect([...info.permissions].sort()).toEqual(tokensForRoles(["admin", "user"]).sort());
    });

    it("serves the cached resolution while it matches the stored roles", async () => {
        const { testEnv, register, account } = setup();
        const pair = await register("cached@example.com");
        // Populate the cache via the endpoint, then read the resolution
        // directly: the cache entry matches the stored roles.
        await account(pair.accessToken);
        const userId = await userIdOf(testEnv, "cached@example.com");
        const user = await getUserById(testEnv.FIT_DB, userId);
        if (user === null) {
            throw new Error("expected the registered user row");
        }
        const acl = await getUserAcl(testEnv, user);
        expect(acl.roles).toEqual([...aclDefaultRoles]);
        expect([...acl.permissions].sort()).toEqual(tokensForRoles(aclDefaultRoles).sort());
    });
});

async function userIdOf(testEnv: TestEnv, email: string): Promise<string> {
    const row = await testEnv.FIT_DB.prepare("SELECT user_id FROM users WHERE email = ?")
        .bind(email)
        .first<{ user_id: string }>();
    if (row === null) {
        throw new Error(`expected a user row for ${email}`);
    }
    return row.user_id;
}
