// Auth router tests against the real local bindings (D1, KV, Durable
// Objects) provided by the Workers Vitest integration; only the outbound
// email sender is substituted (the production sender hits the Resend API).
// Endpoints read the wall clock via Date.now(), so tests that need to move
// past OTP cooldowns run under vitest's fake timers restricted to Date.

import { env } from "cloudflare:workers";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { OTP_DAILY_SEND_LIMIT, OTP_VERIFY_RESEND_COOLDOWN_SEC } from "../../src/auth/otp.ts";
import { RESET_EMAIL_WINDOW_SEC } from "../../src/auth/router.ts";
import { type CapturedEmail, clearAuthState, setupAuthApp, type TestEnv } from "./helpers.ts";

const PASSWORD = "password-1234";
const NEW_PASSWORD = "new-password-5678";
const DEFAULT_IP = "203.0.113.10";

// Moves the wall clock seen by the router and its Durable Objects forward.
const advance = (ms: number): void => {
    vi.advanceTimersByTime(ms);
};

beforeEach(async () => {
    await clearAuthState();
    vi.useFakeTimers({ toFake: ["Date"] });
});

afterEach(() => {
    vi.useRealTimers();
});

interface TokenPair {
    accessToken: string;
    refreshToken: string;
    expiresIn: number;
}

interface PostOptions {
    ip?: string;
    headers?: Record<string, string>;
}

function makePost(testEnv: TestEnv, app: ReturnType<typeof setupAuthApp>["app"]) {
    return (path: string, body: unknown, options?: PostOptions): Promise<Response> =>
        Promise.resolve(
            app.fetch(
                new Request(`https://example.com${path}`, {
                    method: "POST",
                    headers: {
                        "content-type": "application/json",
                        "CF-Connecting-IP": options?.ip ?? DEFAULT_IP,
                        ...(options?.headers ?? {}),
                    },
                    body: JSON.stringify(body),
                }),
                testEnv,
            ),
        );
}

function setup(wrapDb?: (db: D1Database) => D1Database) {
    const { app, testEnv, emails } = setupAuthApp();
    const finalEnv = wrapDb ? { ...testEnv, FIT_DB: wrapDb(testEnv.FIT_DB) } : testEnv;
    const post = makePost(finalEnv, app);
    const lastEmail = (to: string, purpose: string): CapturedEmail => {
        const mail = emails.findLast((m) => m.to === to && m.purpose === purpose);
        if (!mail) {
            throw new Error(`expected a ${purpose} email to ${to}`);
        }
        return mail;
    };
    const wrongCode = (code: string): string => (code === "000000" ? "000001" : "000000");
    const signup = (email: string, options?: PostOptions): Promise<Response> =>
        post("/signup", { email, password: PASSWORD }, options);
    const verify = (email: string): Promise<Response> =>
        post("/verify-email", { email, code: lastEmail(email, "verify").code });
    const login = (email: string, password: string, options?: PostOptions): Promise<Response> =>
        post("/login", { email, password }, options);
    const refresh = (refreshToken: string): Promise<Response> => post("/refresh", { refreshToken });
    /** Signup + verify; resolves to the issued token pair. */
    const register = async (email: string, options?: PostOptions): Promise<TokenPair> => {
        expect((await signup(email, options)).status).toBe(201);
        const res = await verify(email);
        expect(res.status).toBe(200);
        return (await res.json()) as TokenPair;
    };
    return { emails, post, lastEmail, wrongCode, signup, verify, login, refresh, register };
}

// D1 wrapper that hides the users row from the first email lookup, simulating
// a signup that passes the existence check but then loses the insert race
// against a concurrent request for the same address. Every operation
// delegates to the real binding; only the first matching SELECT is
// redirected.
function hideFirstEmailLookup(db: D1Database): D1Database {
    let hidden = false;
    return new Proxy(db, {
        get(target, prop, receiver) {
            if (prop !== "prepare") {
                return Reflect.get(target, prop, receiver);
            }
            return (sql: string): D1PreparedStatement => {
                if (!hidden && sql.startsWith("SELECT * FROM users WHERE email")) {
                    hidden = true;
                    return target
                        .prepare("SELECT * FROM users WHERE email = ?")
                        .bind("missing@example.com");
                }
                return target.prepare(sql);
            };
        },
    });
}

describe("error handling", () => {
    it("wraps unexpected failures in the platform error envelope", async () => {
        const brokenDb = {
            prepare: () => {
                throw new Error("d1 is down");
            },
        } as unknown as D1Database;
        const { app, testEnv } = setupAuthApp({ env: { FIT_DB: brokenDb } });
        const res = await Promise.resolve(
            app.fetch(
                new Request("https://example.com/signup", {
                    method: "POST",
                    headers: { "content-type": "application/json" },
                    body: JSON.stringify({ email: "user@example.com", password: PASSWORD }),
                }),
                testEnv,
            ),
        );
        expect(res.status).toBe(500);
        expect(await res.json()).toEqual({ error: "internal", message: "internal server error" });
    });

    it("answers 500 when AUTH_TOKEN_SECRET is not set", async () => {
        const { app, testEnv } = setupAuthApp({ env: { AUTH_TOKEN_SECRET: undefined } });
        const res = await Promise.resolve(
            app.fetch(
                new Request("https://example.com/login", {
                    method: "POST",
                    headers: { "content-type": "application/json" },
                    body: JSON.stringify({ email: "user@example.com", password: PASSWORD }),
                }),
                testEnv,
            ),
        );
        expect(res.status).toBe(500);
        expect(await res.json()).toEqual({ error: "internal", message: "internal server error" });
    });
});

describe("signup and verify-email", () => {
    it("runs the full flow with resend semantics", async () => {
        const ctx = setup();
        const email = "user@example.com";

        const res = await ctx.signup(email);
        expect(res.status).toBe(201);
        const { userId } = (await res.json()) as { userId: string };
        expect(userId).toMatch(/^[0-9a-f-]{36}$/);
        expect(ctx.emails.length).toBe(1);
        expect(ctx.lastEmail(email, "verify").purpose).toBe("verify");
        expect(ctx.lastEmail(email, "verify").code).toMatch(/^\d{6}$/);

        // Pending + cooldown: 200 without a new email; normalization applies.
        expect((await ctx.signup("  User@Example.COM ")).status).toBe(200);
        expect(ctx.emails.length).toBe(1);

        // Pending after the verification resend cooldown: resends.
        advance((OTP_VERIFY_RESEND_COOLDOWN_SEC + 1) * 1000);
        expect((await ctx.signup(email)).status).toBe(200);
        expect(ctx.emails.length).toBe(2);

        const code = ctx.lastEmail(email, "verify").code;
        const wrong = await ctx.post("/verify-email", { email, code: ctx.wrongCode(code) });
        expect(wrong.status).toBe(401);
        expect(((await wrong.json()) as { error: string }).error).toBe("otp_invalid");

        const verified = await ctx.verify(email);
        expect(verified.status).toBe(200);
        const pair = (await verified.json()) as TokenPair;
        expect(pair.accessToken.length).toBeGreaterThan(0);
        expect(pair.refreshToken.length).toBeGreaterThan(0);
        expect(pair.expiresIn).toBe(900);

        expect((await ctx.verify(email)).status).toBe(409);
        expect(((await (await ctx.signup(email)).json()) as { error: string }).error).toBe(
            "email_taken",
        );
    });

    it("keeps the initial password when a pending signup is repeated", async () => {
        const ctx = setup();
        const email = "user@example.com";

        expect((await ctx.signup(email)).status).toBe(201);
        advance((OTP_VERIFY_RESEND_COOLDOWN_SEC + 1) * 1000);
        // Repeat signup with a different password: accepted as a resend, but
        // the submitted password is ignored.
        expect((await ctx.post("/signup", { email, password: NEW_PASSWORD })).status).toBe(200);

        expect((await ctx.verify(email)).status).toBe(200);
        expect((await ctx.login(email, PASSWORD)).status).toBe(200);
        expect((await ctx.login(email, NEW_PASSWORD)).status).toBe(401);
    });

    it("treats a lost insert race against a pending row as a resend", async () => {
        const ctx = setup(hideFirstEmailLookup);
        const email = "user@example.com";
        // The concurrent winner's row lands between the existence check and
        // the insert, which then fails on UNIQUE(email).
        await env.FIT_DB.prepare(
            "INSERT INTO users (user_id, email, password_hash, status) " +
                "VALUES (?, ?, ?, 'pending')",
        )
            .bind(crypto.randomUUID(), email, "hash-from-concurrent-winner")
            .run();

        const res = await ctx.signup(email);
        expect(res.status).toBe(200);
        expect(await res.json()).toEqual({ ok: true });
        expect(ctx.emails.length).toBe(1);
    });

    it("treats a lost insert race against an active row as email_taken", async () => {
        const ctx = setup(hideFirstEmailLookup);
        const email = "user@example.com";
        await env.FIT_DB.prepare(
            "INSERT INTO users (user_id, email, password_hash, status) " +
                "VALUES (?, ?, ?, 'active')",
        )
            .bind(crypto.randomUUID(), email, "hash-from-concurrent-winner")
            .run();

        const res = await ctx.signup(email);
        expect(res.status).toBe(409);
        expect(((await res.json()) as { error: string }).error).toBe("email_taken");
        expect(ctx.emails.length).toBe(0);
    });

    it("rejects malformed bodies", async () => {
        const ctx = setup();
        expect((await ctx.post("/signup", { email: "a@b.c", password: "short" })).status).toBe(400);
        expect(
            (await ctx.post("/signup", { email: "not-an-email", password: PASSWORD })).status,
        ).toBe(400);
        expect((await ctx.post("/signup", { password: PASSWORD })).status).toBe(400);
        expect((await ctx.post("/signup", "junk")).status).toBe(400);
        expect((await ctx.post("/verify-email", { email: "a@b.c", code: "12345" })).status).toBe(
            400,
        );
    });

    it("answers otp_expired for unknown emails", async () => {
        const ctx = setup();
        const res = await ctx.post("/verify-email", {
            email: "ghost@example.com",
            code: "123456",
        });
        expect(res.status).toBe(401);
        expect(((await res.json()) as { error: string }).error).toBe("otp_expired");
    });

    it("rate limits signups per IP", async () => {
        const ctx = setup();
        for (let i = 0; i < 5; i++) {
            expect((await ctx.signup(`user${i}@example.com`)).status).toBe(201);
        }
        const denied = await ctx.signup("user6@example.com");
        expect(denied.status).toBe(429);
        expect(((await denied.json()) as { error: string }).error).toBe("rate_limited");
        expect(Number(denied.headers.get("retry-after"))).toBeGreaterThan(0);
        // A different IP is unaffected.
        expect((await ctx.signup("user6@example.com", { ip: "198.51.100.7" })).status).toBe(201);
    });

    it("does not burn the daily send quota when the email send fails", async () => {
        let deliver = false;
        const sent: CapturedEmail[] = [];
        const { app, testEnv } = setupAuthApp({
            sendEmail: (_env, input) => {
                if (!deliver) {
                    return Promise.resolve(false);
                }
                sent.push({ ...input });
                return Promise.resolve(true);
            },
        });
        const email = "user@example.com";
        // Each attempt uses a fresh IP so the per-IP signup cap does not mask
        // the per-address daily send quota under test.
        const signup = (ip: string): Promise<Response> =>
            Promise.resolve(
                app.fetch(
                    new Request("https://example.com/signup", {
                        method: "POST",
                        headers: { "content-type": "application/json", "CF-Connecting-IP": ip },
                        body: JSON.stringify({ email, password: PASSWORD }),
                    }),
                    testEnv,
                ),
            );

        // A provider outage: every attempt fails, so the address stays
        // pending and each retry follows the resend path.
        for (let i = 0; i < OTP_DAILY_SEND_LIMIT; i++) {
            expect((await signup(`203.0.113.${i}`)).status).toBe(500);
        }
        expect(sent.length).toBe(0);

        // The provider recovers: no slot was consumed, so the resend goes out.
        deliver = true;
        expect((await signup(DEFAULT_IP)).status).toBe(200);
        expect(sent.length).toBe(1);
    });
});

describe("signup resend", () => {
    it("resends for a pending address and reports the cooldown as 429", async () => {
        const ctx = setup();
        const email = "user@example.com";
        expect((await ctx.signup(email)).status).toBe(201);

        // Inside the resend cooldown armed by the initial signup: 429 with
        // Retry-After instead of a silent 200, and no second email.
        const denied = await ctx.post("/signup/resend", { email });
        expect(denied.status).toBe(429);
        expect(((await denied.json()) as { error: string }).error).toBe("rate_limited");
        const retryAfter = Number(denied.headers.get("retry-after"));
        expect(retryAfter).toBeGreaterThan(0);
        expect(retryAfter).toBeLessThanOrEqual(OTP_VERIFY_RESEND_COOLDOWN_SEC);
        expect(ctx.emails.length).toBe(1);

        // After the cooldown the resend goes out and rearms it.
        advance((OTP_VERIFY_RESEND_COOLDOWN_SEC + 1) * 1000);
        const res = await ctx.post("/signup/resend", { email });
        expect(res.status).toBe(200);
        expect(await res.json()).toEqual({ ok: true });
        expect(ctx.emails.length).toBe(2);
        expect(ctx.lastEmail(email, "verify").purpose).toBe("verify");
        expect((await ctx.post("/signup/resend", { email })).status).toBe(429);
    });

    it("serializes parallel resends: exactly one sends, the rest get 429", async () => {
        const ctx = setup();
        const email = "user@example.com";
        expect((await ctx.signup(email)).status).toBe(201);
        // Move past the cooldown armed by the initial signup so every
        // parallel request races on the reservation.
        advance((OTP_VERIFY_RESEND_COOLDOWN_SEC + 1) * 1000);

        const responses = await Promise.all(
            Array.from({ length: 3 }, () => ctx.post("/signup/resend", { email })),
        );
        expect(responses.map((r) => r.status).sort()).toEqual([200, 429, 429]);
        // Exactly one new email went out, and the code in it is the one that
        // was stored — no losing request overwrote the winner's code.
        expect(ctx.emails.length).toBe(2);
        expect((await ctx.verify(email)).status).toBe(200);
    });

    it("is enumeration-safe for unknown and active addresses", async () => {
        const ctx = setup();
        const email = "user@example.com";

        const unknown = await ctx.post("/signup/resend", { email: "ghost@example.com" });
        expect(unknown.status).toBe(200);
        expect(await unknown.json()).toEqual({ ok: true });

        await ctx.register(email);
        const active = await ctx.post("/signup/resend", { email });
        expect(active.status).toBe(200);
        expect(await active.json()).toEqual({ ok: true });
        // Only the initial signup's verification email went out.
        expect(ctx.emails.filter((m) => m.purpose === "verify").length).toBe(1);
    });

    it("rejects malformed bodies", async () => {
        const ctx = setup();
        expect((await ctx.post("/signup/resend", { email: "not-an-email" })).status).toBe(400);
        expect((await ctx.post("/signup/resend", {})).status).toBe(400);
        expect((await ctx.post("/signup/resend", "junk")).status).toBe(400);
    });

    it("shares the per-IP signup budget", async () => {
        const ctx = setup();
        for (let i = 0; i < 5; i++) {
            expect(
                (await ctx.post("/signup/resend", { email: `user${i}@example.com` })).status,
            ).toBe(200);
        }
        const denied = await ctx.post("/signup/resend", { email: "user6@example.com" });
        expect(denied.status).toBe(429);
        expect(((await denied.json()) as { error: string }).error).toBe("rate_limited");
        // The budget is shared with /signup itself.
        expect((await ctx.signup("user6@example.com")).status).toBe(429);
        // A different IP is unaffected.
        expect((await ctx.signup("user6@example.com", { ip: "198.51.100.7" })).status).toBe(201);
    });
});

describe("login", () => {
    it("handles pending, bad, and good credentials", async () => {
        const ctx = setup();
        const email = "user@example.com";
        await ctx.signup(email);

        // Pending: 403, cooldown suppresses the resend.
        const pending = await ctx.login(email, PASSWORD);
        expect(pending.status).toBe(403);
        expect(((await pending.json()) as { error: string }).error).toBe("email_unverified");
        expect(ctx.emails.length).toBe(1);
        // After the cooldown the nudge resends.
        advance((OTP_VERIFY_RESEND_COOLDOWN_SEC + 1) * 1000);
        expect((await ctx.login(email, PASSWORD)).status).toBe(403);
        expect(ctx.emails.length).toBe(2);

        await ctx.verify(email);

        const wrong = await ctx.login(email, "wrong-password");
        expect(wrong.status).toBe(401);
        expect(((await wrong.json()) as { error: string }).error).toBe("invalid_credentials");

        const unknown = await ctx.login("ghost@example.com", PASSWORD);
        expect(unknown.status).toBe(401);
        expect(((await unknown.json()) as { error: string }).error).toBe("invalid_credentials");

        const ok = await ctx.login(email, PASSWORD);
        expect(ok.status).toBe(200);
        const pair = (await ok.json()) as TokenPair;
        expect(pair.refreshToken.length).toBeGreaterThan(0);
    });

    it("rate limits failed login attempts per account and IP", async () => {
        const ctx = setup();
        const email = "user@example.com";
        await ctx.register(email);

        for (let i = 0; i < 5; i++) {
            expect((await ctx.login(email, "wrong-password")).status).toBe(401);
        }
        // The sixth attempt from the same IP is blocked, even with the right
        // password.
        const denied = await ctx.login(email, PASSWORD);
        expect(denied.status).toBe(429);
        expect(Number(denied.headers.get("retry-after"))).toBeGreaterThan(0);

        // The block is scoped to the source IP: the account still logs in
        // from anywhere else.
        expect((await ctx.login(email, PASSWORD, { ip: "203.0.113.99" })).status).toBe(200);
    });

    it("does not count successful logins against the failure limit", async () => {
        const ctx = setup();
        const email = "user@example.com";
        await ctx.register(email);

        // Repeated successful logins never exhaust the budget.
        for (let i = 0; i < 10; i++) {
            expect((await ctx.login(email, PASSWORD)).status).toBe(200);
        }
        // A success just below saturation still goes through and frees its
        // slot, so it cannot tip the counter over the limit.
        for (let i = 0; i < 4; i++) {
            expect((await ctx.login(email, "wrong-password")).status).toBe(401);
        }
        expect((await ctx.login(email, PASSWORD)).status).toBe(200);
        expect((await ctx.login(email, "wrong-password")).status).toBe(401);
        expect((await ctx.login(email, PASSWORD)).status).toBe(429);
    });
});

describe("refresh", () => {
    it("rotates and replays the same pair within the grace window", async () => {
        const ctx = setup();
        const pair1 = await ctx.register("user@example.com");

        const rotated = await ctx.refresh(pair1.refreshToken);
        expect(rotated.status).toBe(200);
        const pair2 = (await rotated.json()) as TokenPair;
        expect(pair2.refreshToken).not.toBe(pair1.refreshToken);

        // Idempotent replay of the rotated-out token returns the same pair.
        const replay = await ctx.refresh(pair1.refreshToken);
        expect(replay.status).toBe(200);
        expect((await replay.json()) as TokenPair).toEqual(pair2);

        // The successor rotates normally.
        const next = await ctx.refresh(pair2.refreshToken);
        expect(next.status).toBe(200);
        const pair3 = (await next.json()) as TokenPair;
        expect(pair3.refreshToken).not.toBe(pair2.refreshToken);
    });

    it("revokes the whole chain when an old token is reused past the grace window", async () => {
        const ctx = setup();
        const pair1 = await ctx.register("user@example.com");
        const pair2 = (await (await ctx.refresh(pair1.refreshToken)).json()) as TokenPair;

        // Let the grace window lapse.
        await env.FIT_DB.prepare(
            "UPDATE auth_sessions SET rotation_grace_until = '2000-01-01T00:00:00.000Z'",
        ).run();

        expect((await ctx.refresh(pair1.refreshToken)).status).toBe(401);
        // The reuse signal killed the whole chain, including the successor.
        expect((await ctx.refresh(pair2.refreshToken)).status).toBe(401);
        // Access tokens issued before the detection fail their version check.
        expect(
            (
                await ctx.post(
                    "/deregister",
                    {},
                    { headers: { authorization: `Bearer ${pair1.accessToken}` } },
                )
            ).status,
        ).toBe(401);
        expect(
            (
                await ctx.post(
                    "/deregister",
                    {},
                    { headers: { authorization: `Bearer ${pair2.accessToken}` } },
                )
            ).status,
        ).toBe(401);
    });

    it("rejects unknown, expired, and revoked tokens", async () => {
        const ctx = setup();
        const pair = await ctx.register("user@example.com");

        expect((await ctx.refresh("not-a-real-token")).status).toBe(401);

        expect((await ctx.post("/logout", { refreshToken: pair.refreshToken })).status).toBe(200);
        expect((await ctx.refresh(pair.refreshToken)).status).toBe(401);

        const pair2 = await ctx.login("user@example.com", PASSWORD).then(async (res) => {
            expect(res.status).toBe(200);
            return (await res.json()) as TokenPair;
        });
        await env.FIT_DB.prepare(
            "UPDATE auth_sessions SET expires_at = '2000-01-01T00:00:00.000Z'",
        ).run();
        expect((await ctx.refresh(pair2.refreshToken)).status).toBe(401);
    });
});

describe("logout", () => {
    it("is idempotent and revokes the session", async () => {
        const ctx = setup();
        const pair = await ctx.register("user@example.com");

        expect((await ctx.post("/logout", { refreshToken: "unknown-token" })).status).toBe(200);
        expect((await ctx.post("/logout", { refreshToken: pair.refreshToken })).status).toBe(200);
        expect((await ctx.post("/logout", { refreshToken: pair.refreshToken })).status).toBe(200);
        expect((await ctx.refresh(pair.refreshToken)).status).toBe(401);
    });
});

describe("deregister", () => {
    it("anonymizes the account and frees the address", async () => {
        const ctx = setup();
        const email = "user@example.com";
        const pair = await ctx.register(email);

        expect((await ctx.post("/deregister", {})).status).toBe(401);
        const garbage = await ctx.post(
            "/deregister",
            {},
            { headers: { authorization: "Bearer garbage" } },
        );
        expect(garbage.status).toBe(401);

        const res = await ctx.post(
            "/deregister",
            { password: PASSWORD },
            { headers: { authorization: `Bearer ${pair.accessToken}` } },
        );
        expect(res.status).toBe(200);

        const user = await env.FIT_DB.prepare(
            "SELECT email, password_hash, status FROM users",
        ).first<{ email: string; password_hash: string; status: string }>();
        expect(user?.status).toBe("deregistered");
        expect(user?.password_hash).toBe("");
        expect(user?.email).toMatch(/^deleted-[0-9a-f-]{36}@deregistered\.invalid$/);

        // Sessions are revoked and their retained PII is cleared.
        const sessions = (
            await env.FIT_DB.prepare("SELECT revoked_at, user_agent, ip FROM auth_sessions").all<{
                revoked_at: string | null;
                user_agent: string | null;
                ip: string | null;
            }>()
        ).results;
        expect(sessions.length).toBeGreaterThan(0);
        for (const session of sessions) {
            expect(session.revoked_at).not.toBe(null);
            expect(session.user_agent).toBe(null);
            expect(session.ip).toBe(null);
        }

        // The old access token fails its token-version check; the session is gone.
        expect(
            (
                await ctx.post(
                    "/deregister",
                    {},
                    { headers: { authorization: `Bearer ${pair.accessToken}` } },
                )
            ).status,
        ).toBe(401);
        expect((await ctx.refresh(pair.refreshToken)).status).toBe(401);
        expect((await ctx.login(email, PASSWORD)).status).toBe(401);

        // The address is free for re-signup.
        expect((await ctx.signup(email)).status).toBe(201);
    });

    it("requires the current password in addition to the access token", async () => {
        const ctx = setup();
        const email = "user@example.com";
        const pair = await ctx.register(email);
        const headers = { authorization: `Bearer ${pair.accessToken}` };

        // A valid access token alone is not enough.
        const noPassword = await ctx.post("/deregister", {}, { headers });
        expect(noPassword.status).toBe(400);

        const wrong = await ctx.post("/deregister", { password: "wrong-password" }, { headers });
        expect(wrong.status).toBe(401);
        expect(((await wrong.json()) as { error: string }).error).toBe("invalid_credentials");

        // The account is untouched and still usable.
        expect((await ctx.login(email, PASSWORD)).status).toBe(200);

        expect((await ctx.post("/deregister", { password: PASSWORD }, { headers })).status).toBe(
            200,
        );
        expect((await ctx.login(email, PASSWORD)).status).toBe(401);
    });

    it("rate limits failed deregister attempts per account and IP", async () => {
        const ctx = setup();
        const email = "user@example.com";
        const pair = await ctx.register(email);
        const headers = { authorization: `Bearer ${pair.accessToken}` };
        const deregister = (password: string, options?: PostOptions): Promise<Response> =>
            ctx.post("/deregister", { password }, { ...options, headers });

        for (let i = 0; i < 5; i++) {
            expect((await deregister("wrong-password")).status).toBe(401);
        }
        // The sixth attempt from the same IP is blocked, even with the right
        // password.
        const denied = await deregister(PASSWORD);
        expect(denied.status).toBe(429);
        expect(Number(denied.headers.get("retry-after"))).toBeGreaterThan(0);

        // The block is scoped to the source IP: the correct password still
        // deregisters from anywhere else.
        expect((await deregister(PASSWORD, { ip: "203.0.113.99" })).status).toBe(200);
    });
});

describe("reset-password", () => {
    it("is enumeration-safe on the request endpoint", async () => {
        const ctx = setup();
        const res = await ctx.post("/reset-password", { email: "ghost@example.com" });
        expect(res.status).toBe(200);
        expect(await res.json()).toEqual({ ok: true });
        expect(ctx.emails.length).toBe(0);
    });

    it("resets the password and invalidates prior credentials", async () => {
        const ctx = setup();
        const email = "user@example.com";
        const pair = await ctx.register(email);

        expect((await ctx.post("/reset-password", { email })).status).toBe(200);
        const mail = ctx.lastEmail(email, "reset");

        const wrong = await ctx.post("/reset-password/confirm", {
            email,
            code: ctx.wrongCode(mail.code),
            newPassword: NEW_PASSWORD,
        });
        expect(wrong.status).toBe(401);
        expect(((await wrong.json()) as { error: string }).error).toBe("otp_invalid");

        const confirmed = await ctx.post("/reset-password/confirm", {
            email,
            code: mail.code,
            newPassword: NEW_PASSWORD,
        });
        expect(confirmed.status).toBe(200);
        const fresh = (await confirmed.json()) as TokenPair;
        expect(fresh.refreshToken.length).toBeGreaterThan(0);

        expect((await ctx.login(email, PASSWORD)).status).toBe(401);
        expect((await ctx.login(email, NEW_PASSWORD)).status).toBe(200);
        expect((await ctx.refresh(pair.refreshToken)).status).toBe(401);
        expect(
            (
                await ctx.post(
                    "/deregister",
                    {},
                    { headers: { authorization: `Bearer ${pair.accessToken}` } },
                )
            ).status,
        ).toBe(401);
    });

    it("caps reset emails per address while staying enumeration-safe", async () => {
        const ctx = setup();
        const email = "user@example.com";
        await ctx.register(email);

        // Pin the clock just inside the current reset-email rate-limit
        // window so the 61 s advances below cannot roll over into a fresh
        // window (which would reset the cap) mid-test.
        const windowMs = RESET_EMAIL_WINDOW_SEC * 1000;
        vi.setSystemTime(Math.floor(Date.now() / windowMs) * windowMs + 1000);

        for (let i = 0; i < 3; i++) {
            advance(61 * 1000);
            expect((await ctx.post("/reset-password", { email })).status).toBe(200);
        }
        expect(ctx.emails.filter((m) => m.purpose === "reset").length).toBe(3);

        advance(61 * 1000);
        expect((await ctx.post("/reset-password", { email })).status).toBe(200);
        expect(ctx.emails.filter((m) => m.purpose === "reset").length).toBe(3);
    });

    it("validates the new password policy", async () => {
        const ctx = setup();
        const email = "user@example.com";
        await ctx.register(email);
        await ctx.post("/reset-password", { email });
        const mail = ctx.lastEmail(email, "reset");
        expect(
            (
                await ctx.post("/reset-password/confirm", {
                    email,
                    code: mail.code,
                    newPassword: "short",
                })
            ).status,
        ).toBe(400);
    });

    it("consumes the code on success so it cannot be replayed", async () => {
        const ctx = setup();
        const email = "user@example.com";

        // /verify-email: a second attempt with the consumed code never
        // reaches verification again (the account is already active).
        expect((await ctx.signup(email)).status).toBe(201);
        const verifyCode = ctx.lastEmail(email, "verify").code;
        expect((await ctx.post("/verify-email", { email, code: verifyCode })).status).toBe(200);
        expect((await ctx.post("/verify-email", { email, code: verifyCode })).status).toBe(409);

        // /reset-password/confirm: replaying the consumed code fails as expired.
        expect((await ctx.post("/reset-password", { email })).status).toBe(200);
        const resetCode = ctx.lastEmail(email, "reset").code;
        const confirm = (): Promise<Response> =>
            ctx.post("/reset-password/confirm", {
                email,
                code: resetCode,
                newPassword: NEW_PASSWORD,
            });
        expect((await confirm()).status).toBe(200);
        const replayed = await confirm();
        expect(replayed.status).toBe(401);
        expect(((await replayed.json()) as { error: string }).error).toBe("otp_expired");
    });
});
