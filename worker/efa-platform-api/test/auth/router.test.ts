import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { describe, it } from "node:test";
import { OTP_DAILY_SEND_LIMIT } from "../../src/auth/otp.ts";
import { createAuthApp } from "../../src/auth/router.ts";
import {
    loadAuthDatabase,
    TestD1Database,
    TestKV,
    TestOtpStateNamespace,
    TestRateLimitNamespace,
    type TestStatement,
} from "./helpers.ts";

const SECRET = "test-secret";
const PASSWORD = "password-1234";
const NEW_PASSWORD = "new-password-5678";
const DEFAULT_IP = "203.0.113.10";

interface CapturedEmail {
    to: string;
    code: string;
    purpose: string;
    locale: string;
}

interface TokenPair {
    accessToken: string;
    refreshToken: string;
    expiresIn: number;
}

interface PostOptions {
    ip?: string;
    headers?: Record<string, string>;
}

function setup(wrapDb?: (db: TestD1Database) => TestD1Database) {
    const db = loadAuthDatabase();
    const kv = new TestKV();
    const otp = new TestOtpStateNamespace();
    const rl = new TestRateLimitNamespace();
    const emails: CapturedEmail[] = [];
    const app = createAuthApp({
        sendEmail: (_env, input) => {
            emails.push({ ...input });
            return Promise.resolve(true);
        },
    });
    const d1 = new TestD1Database(db);
    const env = {
        FIT_DB: wrapDb ? wrapDb(d1) : d1,
        AUTH_KV: kv,
        AUTH_OTP: otp,
        AUTH_RATE_LIMIT: rl,
        AUTH_TOKEN_SECRET: SECRET,
    };
    const post = (path: string, body: unknown, options?: PostOptions): Promise<Response> =>
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
                env as never,
            ),
        );
    const lastEmail = (to: string, purpose: string): CapturedEmail => {
        const mail = emails.findLast((m) => m.to === to && m.purpose === purpose);
        assert.ok(mail, `expected a ${purpose} email to ${to}`);
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
        assert.equal((await signup(email, options)).status, 201);
        const res = await verify(email);
        assert.equal(res.status, 200);
        return (await res.json()) as TokenPair;
    };
    return {
        db,
        kv,
        otp,
        rl,
        emails,
        post,
        lastEmail,
        wrongCode,
        signup,
        verify,
        login,
        refresh,
        register,
    };
}

// D1 shim that hides the users row from the first email lookup, simulating a
// signup that passes the existence check but then loses the insert race
// against a concurrent request for the same address.
function hideFirstEmailLookup(db: TestD1Database): TestD1Database {
    let hidden = false;
    return {
        prepare: (sql: string): TestStatement => {
            if (!hidden && sql.startsWith("SELECT * FROM users WHERE email")) {
                hidden = true;
                return db
                    .prepare("SELECT * FROM users WHERE email = ?")
                    .bind("missing@example.com");
            }
            return db.prepare(sql);
        },
    } as TestD1Database;
}

describe("error handling", () => {
    it("wraps unexpected failures in the platform error envelope", async () => {
        const emails: CapturedEmail[] = [];
        const app = createAuthApp({
            sendEmail: (_env, input) => {
                emails.push({ ...input });
                return Promise.resolve(true);
            },
        });
        const brokenDb = {
            prepare: () => {
                throw new Error("d1 is down");
            },
        };
        const env = {
            FIT_DB: brokenDb,
            AUTH_KV: new TestKV(),
            AUTH_OTP: new TestOtpStateNamespace(),
            AUTH_RATE_LIMIT: new TestRateLimitNamespace(),
            AUTH_TOKEN_SECRET: SECRET,
        };
        const res = await Promise.resolve(
            app.fetch(
                new Request("https://example.com/signup", {
                    method: "POST",
                    headers: { "content-type": "application/json" },
                    body: JSON.stringify({ email: "user@example.com", password: PASSWORD }),
                }),
                env as never,
            ),
        );
        assert.equal(res.status, 500);
        assert.deepEqual(await res.json(), { error: "internal", message: "internal server error" });
    });

    it("answers 500 when AUTH_TOKEN_SECRET is not set", async () => {
        const app = createAuthApp({
            sendEmail: () => Promise.resolve(true),
        });
        const env = {
            FIT_DB: new TestD1Database(loadAuthDatabase()),
            AUTH_KV: new TestKV(),
            AUTH_OTP: new TestOtpStateNamespace(),
            AUTH_RATE_LIMIT: new TestRateLimitNamespace(),
        };
        const res = await Promise.resolve(
            app.fetch(
                new Request("https://example.com/login", {
                    method: "POST",
                    headers: { "content-type": "application/json" },
                    body: JSON.stringify({ email: "user@example.com", password: PASSWORD }),
                }),
                env as never,
            ),
        );
        assert.equal(res.status, 500);
        assert.deepEqual(await res.json(), { error: "internal", message: "internal server error" });
    });
});

describe("signup and verify-email", () => {
    it("runs the full flow with resend semantics", async () => {
        const ctx = setup();
        const email = "user@example.com";

        const res = await ctx.signup(email);
        assert.equal(res.status, 201);
        const { userId } = (await res.json()) as { userId: string };
        assert.match(userId, /^[0-9a-f-]{36}$/);
        assert.equal(ctx.emails.length, 1);
        assert.equal(ctx.lastEmail(email, "verify").purpose, "verify");
        assert.match(ctx.lastEmail(email, "verify").code, /^\d{6}$/);

        // Pending + cooldown: 200 without a new email; normalization applies.
        assert.equal((await ctx.signup("  User@Example.COM ")).status, 200);
        assert.equal(ctx.emails.length, 1);

        // Pending after cooldown: resends.
        ctx.otp.advance(61 * 1000);
        assert.equal((await ctx.signup(email)).status, 200);
        assert.equal(ctx.emails.length, 2);

        const code = ctx.lastEmail(email, "verify").code;
        const wrong = await ctx.post("/verify-email", { email, code: ctx.wrongCode(code) });
        assert.equal(wrong.status, 401);
        assert.equal(((await wrong.json()) as { error: string }).error, "otp_invalid");

        const verified = await ctx.verify(email);
        assert.equal(verified.status, 200);
        const pair = (await verified.json()) as TokenPair;
        assert.ok(pair.accessToken.length > 0);
        assert.ok(pair.refreshToken.length > 0);
        assert.equal(pair.expiresIn, 900);

        assert.equal((await ctx.verify(email)).status, 409);
        assert.equal(
            ((await (await ctx.signup(email)).json()) as { error: string }).error,
            "email_taken",
        );
    });

    it("keeps the initial password when a pending signup is repeated", async () => {
        const ctx = setup();
        const email = "user@example.com";

        assert.equal((await ctx.signup(email)).status, 201);
        ctx.otp.advance(61 * 1000);
        // Repeat signup with a different password: accepted as a resend, but
        // the submitted password is ignored.
        assert.equal((await ctx.post("/signup", { email, password: NEW_PASSWORD })).status, 200);

        assert.equal((await ctx.verify(email)).status, 200);
        assert.equal((await ctx.login(email, PASSWORD)).status, 200);
        assert.equal((await ctx.login(email, NEW_PASSWORD)).status, 401);
    });

    it("treats a lost insert race against a pending row as a resend", async () => {
        const ctx = setup(hideFirstEmailLookup);
        const email = "user@example.com";
        // The concurrent winner's row lands between the existence check and
        // the insert, which then fails on UNIQUE(email).
        ctx.db
            .prepare(
                "INSERT INTO users (user_id, email, password_hash, status) " +
                    "VALUES (?, ?, ?, 'pending')",
            )
            .run(randomUUID(), email, "hash-from-concurrent-winner");

        const res = await ctx.signup(email);
        assert.equal(res.status, 200);
        assert.deepEqual(await res.json(), { ok: true });
        assert.equal(ctx.emails.length, 1);
    });

    it("treats a lost insert race against an active row as email_taken", async () => {
        const ctx = setup(hideFirstEmailLookup);
        const email = "user@example.com";
        ctx.db
            .prepare(
                "INSERT INTO users (user_id, email, password_hash, status) " +
                    "VALUES (?, ?, ?, 'active')",
            )
            .run(randomUUID(), email, "hash-from-concurrent-winner");

        const res = await ctx.signup(email);
        assert.equal(res.status, 409);
        assert.equal(((await res.json()) as { error: string }).error, "email_taken");
        assert.equal(ctx.emails.length, 0);
    });

    it("rejects malformed bodies", async () => {
        const ctx = setup();
        assert.equal(
            (await ctx.post("/signup", { email: "a@b.c", password: "short" })).status,
            400,
        );
        assert.equal(
            (await ctx.post("/signup", { email: "not-an-email", password: PASSWORD })).status,
            400,
        );
        assert.equal((await ctx.post("/signup", { password: PASSWORD })).status, 400);
        assert.equal((await ctx.post("/signup", "junk")).status, 400);
        assert.equal(
            (await ctx.post("/verify-email", { email: "a@b.c", code: "12345" })).status,
            400,
        );
    });

    it("answers otp_expired for unknown emails", async () => {
        const ctx = setup();
        const res = await ctx.post("/verify-email", { email: "ghost@example.com", code: "123456" });
        assert.equal(res.status, 401);
        assert.equal(((await res.json()) as { error: string }).error, "otp_expired");
    });

    it("rate limits signups per IP", async () => {
        const ctx = setup();
        for (let i = 0; i < 5; i++) {
            assert.equal((await ctx.signup(`user${i}@example.com`)).status, 201);
        }
        const denied = await ctx.signup("user6@example.com");
        assert.equal(denied.status, 429);
        assert.equal(((await denied.json()) as { error: string }).error, "rate_limited");
        assert.ok(Number(denied.headers.get("retry-after")) > 0);
        // A different IP is unaffected.
        assert.equal((await ctx.signup("user6@example.com", { ip: "198.51.100.7" })).status, 201);
    });

    it("does not burn the daily send quota when the email send fails", async () => {
        let deliver = false;
        const emails: CapturedEmail[] = [];
        const app = createAuthApp({
            sendEmail: (_env, input) => {
                if (!deliver) {
                    return Promise.resolve(false);
                }
                emails.push({ ...input });
                return Promise.resolve(true);
            },
        });
        const env = {
            FIT_DB: new TestD1Database(loadAuthDatabase()),
            AUTH_KV: new TestKV(),
            AUTH_OTP: new TestOtpStateNamespace(),
            AUTH_RATE_LIMIT: new TestRateLimitNamespace(),
            AUTH_TOKEN_SECRET: SECRET,
        };
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
                    env as never,
                ),
            );

        // A provider outage: every attempt fails, so the address stays
        // pending and each retry follows the resend path.
        for (let i = 0; i < OTP_DAILY_SEND_LIMIT; i++) {
            assert.equal((await signup(`203.0.113.${i}`)).status, 500);
        }
        assert.equal(emails.length, 0);

        // The provider recovers: no slot was consumed, so the resend goes out.
        deliver = true;
        assert.equal((await signup(DEFAULT_IP)).status, 200);
        assert.equal(emails.length, 1);
    });
});

describe("login", () => {
    it("handles pending, bad, and good credentials", async () => {
        const ctx = setup();
        const email = "user@example.com";
        await ctx.signup(email);

        // Pending: 403, cooldown suppresses the resend.
        const pending = await ctx.login(email, PASSWORD);
        assert.equal(pending.status, 403);
        assert.equal(((await pending.json()) as { error: string }).error, "email_unverified");
        assert.equal(ctx.emails.length, 1);
        // After the cooldown the nudge resends.
        ctx.otp.advance(61 * 1000);
        assert.equal((await ctx.login(email, PASSWORD)).status, 403);
        assert.equal(ctx.emails.length, 2);

        await ctx.verify(email);

        const wrong = await ctx.login(email, "wrong-password");
        assert.equal(wrong.status, 401);
        assert.equal(((await wrong.json()) as { error: string }).error, "invalid_credentials");

        const unknown = await ctx.login("ghost@example.com", PASSWORD);
        assert.equal(unknown.status, 401);
        assert.equal(((await unknown.json()) as { error: string }).error, "invalid_credentials");

        const ok = await ctx.login(email, PASSWORD);
        assert.equal(ok.status, 200);
        const pair = (await ok.json()) as TokenPair;
        assert.ok(pair.refreshToken.length > 0);
    });

    it("rate limits failed login attempts per account and IP", async () => {
        const ctx = setup();
        const email = "user@example.com";
        await ctx.register(email);

        for (let i = 0; i < 5; i++) {
            assert.equal((await ctx.login(email, "wrong-password")).status, 401);
        }
        // The sixth attempt from the same IP is blocked, even with the right
        // password.
        const denied = await ctx.login(email, PASSWORD);
        assert.equal(denied.status, 429);
        assert.ok(Number(denied.headers.get("retry-after")) > 0);

        // The block is scoped to the source IP: the account still logs in
        // from anywhere else.
        assert.equal((await ctx.login(email, PASSWORD, { ip: "203.0.113.99" })).status, 200);
    });

    it("does not count successful logins against the failure limit", async () => {
        const ctx = setup();
        const email = "user@example.com";
        await ctx.register(email);

        // Repeated successful logins never exhaust the budget.
        for (let i = 0; i < 10; i++) {
            assert.equal((await ctx.login(email, PASSWORD)).status, 200);
        }
        // A success just below saturation still goes through and frees its
        // slot, so it cannot tip the counter over the limit.
        for (let i = 0; i < 4; i++) {
            assert.equal((await ctx.login(email, "wrong-password")).status, 401);
        }
        assert.equal((await ctx.login(email, PASSWORD)).status, 200);
        assert.equal((await ctx.login(email, "wrong-password")).status, 401);
        assert.equal((await ctx.login(email, PASSWORD)).status, 429);
    });
});

describe("refresh", () => {
    it("rotates and replays the same pair within the grace window", async () => {
        const ctx = setup();
        const pair1 = await ctx.register("user@example.com");

        const rotated = await ctx.refresh(pair1.refreshToken);
        assert.equal(rotated.status, 200);
        const pair2 = (await rotated.json()) as TokenPair;
        assert.notEqual(pair2.refreshToken, pair1.refreshToken);

        // Idempotent replay of the rotated-out token returns the same pair.
        const replay = await ctx.refresh(pair1.refreshToken);
        assert.equal(replay.status, 200);
        assert.deepEqual((await replay.json()) as TokenPair, pair2);

        // The successor rotates normally.
        const next = await ctx.refresh(pair2.refreshToken);
        assert.equal(next.status, 200);
        const pair3 = (await next.json()) as TokenPair;
        assert.notEqual(pair3.refreshToken, pair2.refreshToken);
    });

    it("revokes the whole chain when an old token is reused past the grace window", async () => {
        const ctx = setup();
        const pair1 = await ctx.register("user@example.com");
        const pair2 = (await (await ctx.refresh(pair1.refreshToken)).json()) as TokenPair;

        // Let the grace window lapse.
        ctx.db.exec("UPDATE auth_sessions SET rotation_grace_until = '2000-01-01T00:00:00.000Z'");

        assert.equal((await ctx.refresh(pair1.refreshToken)).status, 401);
        // The reuse signal killed the whole chain, including the successor.
        assert.equal((await ctx.refresh(pair2.refreshToken)).status, 401);
        // Access tokens issued before the detection fail their version check.
        assert.equal(
            (
                await ctx.post(
                    "/deregister",
                    {},
                    { headers: { authorization: `Bearer ${pair1.accessToken}` } },
                )
            ).status,
            401,
        );
        assert.equal(
            (
                await ctx.post(
                    "/deregister",
                    {},
                    { headers: { authorization: `Bearer ${pair2.accessToken}` } },
                )
            ).status,
            401,
        );
    });

    it("rejects unknown, expired, and revoked tokens", async () => {
        const ctx = setup();
        const pair = await ctx.register("user@example.com");

        assert.equal((await ctx.refresh("not-a-real-token")).status, 401);

        assert.equal((await ctx.post("/logout", { refreshToken: pair.refreshToken })).status, 200);
        assert.equal((await ctx.refresh(pair.refreshToken)).status, 401);

        const pair2 = await ctx.login("user@example.com", PASSWORD).then(async (res) => {
            assert.equal(res.status, 200);
            return (await res.json()) as TokenPair;
        });
        ctx.db.exec("UPDATE auth_sessions SET expires_at = '2000-01-01T00:00:00.000Z'");
        assert.equal((await ctx.refresh(pair2.refreshToken)).status, 401);
    });
});

describe("logout", () => {
    it("is idempotent and revokes the session", async () => {
        const ctx = setup();
        const pair = await ctx.register("user@example.com");

        assert.equal((await ctx.post("/logout", { refreshToken: "unknown-token" })).status, 200);
        assert.equal((await ctx.post("/logout", { refreshToken: pair.refreshToken })).status, 200);
        assert.equal((await ctx.post("/logout", { refreshToken: pair.refreshToken })).status, 200);
        assert.equal((await ctx.refresh(pair.refreshToken)).status, 401);
    });
});

describe("deregister", () => {
    it("anonymizes the account and frees the address", async () => {
        const ctx = setup();
        const email = "user@example.com";
        const pair = await ctx.register(email);

        assert.equal((await ctx.post("/deregister", {})).status, 401);
        const garbage = await ctx.post(
            "/deregister",
            {},
            { headers: { authorization: "Bearer garbage" } },
        );
        assert.equal(garbage.status, 401);

        const res = await ctx.post(
            "/deregister",
            {},
            { headers: { authorization: `Bearer ${pair.accessToken}` } },
        );
        assert.equal(res.status, 200);

        const user = ctx.db.prepare("SELECT email, password_hash, status FROM users").get() as {
            email: string;
            password_hash: string;
            status: string;
        };
        assert.equal(user.status, "deregistered");
        assert.equal(user.password_hash, "");
        assert.match(user.email, /^deleted-[0-9a-f-]{36}@deregistered\.invalid$/);

        // Sessions are revoked and their retained PII is cleared.
        const sessions = ctx.db
            .prepare("SELECT revoked_at, user_agent, ip FROM auth_sessions")
            .all() as { revoked_at: string | null; user_agent: string | null; ip: string | null }[];
        assert.ok(sessions.length > 0);
        for (const session of sessions) {
            assert.ok(session.revoked_at !== null);
            assert.equal(session.user_agent, null);
            assert.equal(session.ip, null);
        }

        // The old access token fails its token-version check; the session is gone.
        assert.equal(
            (
                await ctx.post(
                    "/deregister",
                    {},
                    { headers: { authorization: `Bearer ${pair.accessToken}` } },
                )
            ).status,
            401,
        );
        assert.equal((await ctx.refresh(pair.refreshToken)).status, 401);
        assert.equal((await ctx.login(email, PASSWORD)).status, 401);

        // The address is free for re-signup.
        assert.equal((await ctx.signup(email)).status, 201);
    });
});

describe("reset-password", () => {
    it("is enumeration-safe on the request endpoint", async () => {
        const ctx = setup();
        const res = await ctx.post("/reset-password", { email: "ghost@example.com" });
        assert.equal(res.status, 200);
        assert.deepEqual(await res.json(), { ok: true });
        assert.equal(ctx.emails.length, 0);
    });

    it("resets the password and invalidates prior credentials", async () => {
        const ctx = setup();
        const email = "user@example.com";
        const pair = await ctx.register(email);

        assert.equal((await ctx.post("/reset-password", { email })).status, 200);
        const mail = ctx.lastEmail(email, "reset");

        const wrong = await ctx.post("/reset-password/confirm", {
            email,
            code: ctx.wrongCode(mail.code),
            newPassword: NEW_PASSWORD,
        });
        assert.equal(wrong.status, 401);
        assert.equal(((await wrong.json()) as { error: string }).error, "otp_invalid");

        const confirmed = await ctx.post("/reset-password/confirm", {
            email,
            code: mail.code,
            newPassword: NEW_PASSWORD,
        });
        assert.equal(confirmed.status, 200);
        const fresh = (await confirmed.json()) as TokenPair;
        assert.ok(fresh.refreshToken.length > 0);

        assert.equal((await ctx.login(email, PASSWORD)).status, 401);
        assert.equal((await ctx.login(email, NEW_PASSWORD)).status, 200);
        assert.equal((await ctx.refresh(pair.refreshToken)).status, 401);
        assert.equal(
            (
                await ctx.post(
                    "/deregister",
                    {},
                    { headers: { authorization: `Bearer ${pair.accessToken}` } },
                )
            ).status,
            401,
        );
    });

    it("caps reset emails per address while staying enumeration-safe", async () => {
        const ctx = setup();
        const email = "user@example.com";
        await ctx.register(email);

        for (let i = 0; i < 3; i++) {
            ctx.otp.advance(61 * 1000);
            assert.equal((await ctx.post("/reset-password", { email })).status, 200);
        }
        assert.equal(ctx.emails.filter((m) => m.purpose === "reset").length, 3);

        ctx.otp.advance(61 * 1000);
        assert.equal((await ctx.post("/reset-password", { email })).status, 200);
        assert.equal(ctx.emails.filter((m) => m.purpose === "reset").length, 3);
    });

    it("validates the new password policy", async () => {
        const ctx = setup();
        const email = "user@example.com";
        await ctx.register(email);
        await ctx.post("/reset-password", { email });
        const mail = ctx.lastEmail(email, "reset");
        assert.equal(
            (
                await ctx.post("/reset-password/confirm", {
                    email,
                    code: mail.code,
                    newPassword: "short",
                })
            ).status,
            400,
        );
    });

    it("consumes the code on success so it cannot be replayed", async () => {
        const ctx = setup();
        const email = "user@example.com";

        // /verify-email: a second attempt with the consumed code never
        // reaches verification again (the account is already active).
        assert.equal((await ctx.signup(email)).status, 201);
        const verifyCode = ctx.lastEmail(email, "verify").code;
        assert.equal((await ctx.post("/verify-email", { email, code: verifyCode })).status, 200);
        assert.equal((await ctx.post("/verify-email", { email, code: verifyCode })).status, 409);

        // /reset-password/confirm: replaying the consumed code fails as expired.
        assert.equal((await ctx.post("/reset-password", { email })).status, 200);
        const resetCode = ctx.lastEmail(email, "reset").code;
        const confirm = (): Promise<Response> =>
            ctx.post("/reset-password/confirm", {
                email,
                code: resetCode,
                newPassword: NEW_PASSWORD,
            });
        assert.equal((await confirm()).status, 200);
        const replayed = await confirm();
        assert.equal(replayed.status, 401);
        assert.equal(((await replayed.json()) as { error: string }).error, "otp_expired");
    });
});
