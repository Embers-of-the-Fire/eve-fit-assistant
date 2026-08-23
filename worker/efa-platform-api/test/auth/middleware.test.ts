// Middleware tests for requireAccessToken/getAuthClaims against a minimal
// Hono app; the token codec itself is covered by tokens.test.ts.

import { Hono } from "hono";
import type { Context } from "hono";
import { describe, expect, it } from "vitest";
import { getAuthClaims, requireAccessToken } from "../../src/auth/middleware.ts";
import { type AccessTokenClaims, signAccessToken } from "../../src/auth/tokens.ts";

const SECRET = "test-secret";

interface TestEnv {
    Bindings: { AUTH_TOKEN_SECRET?: string };
}

function setup(options?: {
    validateClaims?: (c: Context<TestEnv>, claims: AccessTokenClaims) => Promise<Response | undefined>;
    secret?: string | undefined;
}) {
    const app = new Hono<TestEnv>();
    app.get(
        "/protected",
        requireAccessToken<TestEnv>({
            secret: (c) => options?.secret ?? c.env.AUTH_TOKEN_SECRET,
            validateClaims: options?.validateClaims,
        }),
        (c) => {
            const claims = getAuthClaims(c);
            return c.json({ sub: claims.sub, tv: claims.tv }, 200);
        },
    );
    return app;
}

function get(app: Hono<TestEnv>, authorization?: string): Promise<Response> {
    return Promise.resolve(
        app.fetch(
            new Request("https://example.com/protected", {
                headers: authorization === undefined ? {} : { authorization },
            }),
            { AUTH_TOKEN_SECRET: SECRET },
        ),
    );
}

describe("requireAccessToken", () => {
    it("rejects a missing Authorization header with the invalid_token envelope", async () => {
        const res = await get(setup());
        expect(res.status).toBe(401);
        expect(await res.json()).toEqual({
            error: "invalid_token",
            message: "missing or invalid access token",
        });
    });

    it("rejects malformed headers and garbage tokens", async () => {
        const app = setup();
        for (const header of ["Bearer", "Token abc", "Bearer garbage"]) {
            const res = await get(app, header);
            expect(res.status).toBe(401);
            expect(((await res.json()) as { error: string }).error).toBe("invalid_token");
        }
    });

    it("rejects tokens signed with a different secret", async () => {
        const token = await signAccessToken("other-secret", "user-1", 0);
        const res = await get(setup(), `Bearer ${token}`);
        expect(res.status).toBe(401);
    });

    it("rejects expired tokens", async () => {
        const token = await signAccessToken(SECRET, "user-1", 0, Date.now() - 20 * 60 * 1000);
        const res = await get(setup(), `Bearer ${token}`);
        expect(res.status).toBe(401);
    });

    it("exposes verified claims to the handler via getAuthClaims", async () => {
        const token = await signAccessToken(SECRET, "user-1", 3);
        const res = await get(setup(), `Bearer ${token}`);
        expect(res.status).toBe(200);
        expect(await res.json()).toEqual({ sub: "user-1", tv: 3 });
    });

    it("short-circuits with the validateClaims rejection response", async () => {
        const rejection = Response.json(
            { error: "invalid_token", message: "stale token version" },
            { status: 401 },
        );
        const app = setup({ validateClaims: () => Promise.resolve(rejection) });
        const token = await signAccessToken(SECRET, "user-1", 3);
        const res = await get(app, `Bearer ${token}`);
        expect(res.status).toBe(401);
        expect(((await res.json()) as { message: string }).message).toBe("stale token version");
    });

    it("reports a missing secret as a 500 internal error", async () => {
        const app = setup({ secret: "" });
        const token = await signAccessToken(SECRET, "user-1", 0);
        const res = await get(app, `Bearer ${token}`);
        expect(res.status).toBe(500);
        expect(((await res.json()) as { error: string }).error).toBe("internal");
    });
});
