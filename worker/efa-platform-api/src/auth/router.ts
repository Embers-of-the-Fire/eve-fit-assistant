// Email+password authentication sub-app. All endpoints are POST with JSON
// bodies; errors follow the platform envelope { "error": code, "message" }.
// Persistent state lives in D1 (users, sessions); atomic OTP and rate-limit
// state lives in the AUTH_OTP / AUTH_RATE_LIMIT Durable Objects; AUTH_KV
// holds only the short-lived rotation stash.

import { Hono } from "hono";
import { z } from "zod";
import { type OtpEmailEnv, type OtpEmailInput, sendOtpEmail } from "./email.ts";
import {
    clearOtp,
    generateOtpCode,
    hasOtpCooldown,
    OTP_DAILY_SEND_LIMIT,
    OTP_DAILY_SEND_WINDOW_SEC,
    type OtpPurpose,
    storeOtp,
    verifyOtp,
} from "./otp.ts";
import type { OtpState } from "./otp-state.ts";
import { hashPassword, ITERATIONS, verifyPassword } from "./passwords.ts";
import type { RateLimitWindow } from "./rate-window.ts";
import { fixedWindowLimit, fixedWindowRefund } from "./ratelimit.ts";
import {
    activateUser,
    deregisterUser,
    getSessionByRefreshHash,
    getUserByEmail,
    getUserById,
    insertSession,
    insertUser,
    invalidateUserTokens,
    revokeAllUserSessions,
    revokeSession,
    rotateSession,
    type UserRow,
    updateUserPassword,
} from "./store.ts";
import {
    ACCESS_TOKEN_TTL_SEC,
    generateRefreshToken,
    hashRefreshToken,
    REFRESH_TOKEN_TTL_MS,
    ROTATION_GRACE_MS,
    signAccessToken,
    verifyAccessToken,
} from "./tokens.ts";

export interface AuthEnv extends OtpEmailEnv {
    FIT_DB: D1Database;
    AUTH_KV: KVNamespace;
    AUTH_OTP: DurableObjectNamespace<OtpState>;
    AUTH_RATE_LIMIT: DurableObjectNamespace<RateLimitWindow>;
    AUTH_TOKEN_SECRET?: string;
}

// Overridable seam for tests: the real sender hits the Resend API.
export interface AuthDeps {
    sendEmail?: (env: OtpEmailEnv, input: OtpEmailInput) => Promise<boolean>;
}

type ErrorStatus = 400 | 401 | 403 | 409 | 429 | 500;

function errorJson(
    status: ErrorStatus,
    code: string,
    message: string,
    headers?: Record<string, string>,
): Response {
    return Response.json({ error: code, message }, { status, headers });
}

// D1 (and node:sqlite in tests) reports key violations only in the message.
function isUniqueConstraintError(error: unknown): boolean {
    return error instanceof Error && error.message.includes("UNIQUE constraint failed");
}

const emailField = z
    .string()
    .max(254)
    .transform((value) => value.trim().toLowerCase())
    .pipe(z.email());
const passwordField = z.string().min(10).max(128);
const localeField = z.string().max(32).optional();
const codeField = z.string().regex(/^\d{6}$/);

const SignupSchema = z.object({
    email: emailField,
    password: passwordField,
    locale: localeField,
});
const VerifyEmailSchema = z.object({ email: emailField, code: codeField });
const LoginSchema = z.object({ email: emailField, password: z.string().min(1).max(128) });
const RefreshSchema = z.object({ refreshToken: z.string().min(1).max(128) });
const ResetRequestSchema = z.object({ email: emailField, locale: localeField });
const ResetConfirmSchema = z.object({
    email: emailField,
    code: codeField,
    newPassword: passwordField,
});

// Same shape as a real hash, used to keep the unknown-email path of /login
// on the same code path (and timing profile) as the known-email path.
const DUMMY_PASSWORD_HASH = `pbkdf2$${ITERATIONS}$AAAAAAAAAAAAAAAAAAAAAA==$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=`;

const SIGNUP_IP_LIMIT = 5;
const SIGNUP_IP_WINDOW_SEC = 60 * 60;
// Counts failed attempts only: a correct password refunds its hit, so a
// legitimate sign-in never consumes quota. Keyed on email+IP (see /login), so
// knowing a victim's address is not enough to lock the account out — one
// source can only exhaust its own pair's budget.
const LOGIN_ACCOUNT_LIMIT = 5;
const LOGIN_ACCOUNT_WINDOW_SEC = 30 * 60;
// Deliberately loose: mobile carriers use CGNAT, so many unrelated users
// share exit IPs. The per-account+IP failure limit carries the real weight.
const LOGIN_IP_LIMIT = 30;
const LOGIN_IP_WINDOW_SEC = 5 * 60;
const RESET_EMAIL_LIMIT = 3;
const RESET_EMAIL_WINDOW_SEC = 60 * 60;
// Loose per-IP cap on the unauthenticated token routes (/refresh, /logout):
// they accept any body and would otherwise give callers free D1 reads with
// random tokens. Kept as loose as login-ip for the same CGNAT reason.
const TOKEN_IP_LIMIT = 30;
const TOKEN_IP_WINDOW_SEC = 5 * 60;

// The rotation stash must outlive the grace window so a replay inside the
// window always finds it: 61 s is the smallest TTL KV accepts above the 60 s
// grace window (KV's minimum expirationTtl is 60 s).
// Exception to the hashes-only invariant (see tokens.ts): the stash holds the
// successor refresh and access tokens in plaintext so a replayed rotation can
// be answered with the same pair.
const ROTATION_STASH_TTL_SEC = 61;

interface TokenPair {
    accessToken: string;
    refreshToken: string;
    expiresIn: number;
}

function rotationStashKey(previousRefreshHash: string): string {
    return `rotate:${previousRefreshHash}`;
}

export function createAuthApp(deps: AuthDeps = {}): Hono<{ Bindings: AuthEnv }> {
    const sendEmail = deps.sendEmail ?? sendOtpEmail;
    const app = new Hono<{ Bindings: AuthEnv }>();

    function requireSecret(c: { env: AuthEnv }): string | null {
        const secret = c.env.AUTH_TOKEN_SECRET;
        if (!secret) {
            console.error("AUTH_TOKEN_SECRET is not set");
            return null;
        }
        return secret;
    }

    function clientIp(c: { req: { header: (name: string) => string | undefined } }): string {
        return c.req.header("CF-Connecting-IP") ?? "unknown";
    }

    async function rateLimited(
        c: { env: AuthEnv },
        bucket: string,
        key: string,
        limit: number,
        windowSec: number,
    ): Promise<Response | null> {
        const outcome = await fixedWindowLimit(
            c.env.AUTH_RATE_LIMIT,
            bucket,
            key,
            limit,
            windowSec,
        );
        if (outcome.allowed) {
            return null;
        }
        return errorJson(429, "rate_limited", "too many requests", {
            "Retry-After": String(outcome.retryAfterSec),
        });
    }

    type OtpSendOutcome = "sent" | "cooldown" | "limited" | "failed";

    // Cooldown is silent (callers still answer 200); the daily send cap and
    // send failures are reported so the caller can decide.
    async function sendOtp(
        c: { env: AuthEnv },
        secret: string,
        purpose: OtpPurpose,
        email: string,
        locale: string,
    ): Promise<{ outcome: OtpSendOutcome; retryAfterSec: number }> {
        if (await hasOtpCooldown(c.env.AUTH_OTP, purpose, email)) {
            return { outcome: "cooldown", retryAfterSec: 0 };
        }
        const daily = await fixedWindowLimit(
            c.env.AUTH_RATE_LIMIT,
            "otp-send",
            `${purpose}:${email}`,
            OTP_DAILY_SEND_LIMIT,
            OTP_DAILY_SEND_WINDOW_SEC,
        );
        if (!daily.allowed) {
            return { outcome: "limited", retryAfterSec: daily.retryAfterSec };
        }
        const code = generateOtpCode();
        await storeOtp(c.env.AUTH_OTP, secret, purpose, email, code);
        const sent = await sendEmail(c.env, { to: email, code, purpose, locale });
        if (!sent) {
            // Leave no state behind so an immediate retry can resend: clear
            // the OTP and refund the daily send quota, so a failed send does
            // not burn one of the user's OTP_DAILY_SEND_LIMIT slots.
            await clearOtp(c.env.AUTH_OTP, purpose, email);
            await fixedWindowRefund(
                c.env.AUTH_RATE_LIMIT,
                "otp-send",
                `${purpose}:${email}`,
                OTP_DAILY_SEND_WINDOW_SEC,
            );
            return { outcome: "failed", retryAfterSec: 0 };
        }
        return { outcome: "sent", retryAfterSec: 0 };
    }

    // Shared resend path for a signup that finds the address already pending:
    // the submitted password is ignored and the password hash from the
    // initial signup is kept; only a fresh verification code goes out.
    async function resendSignupOtp(
        c: { env: AuthEnv },
        secret: string,
        email: string,
        locale: string | undefined,
    ): Promise<Response> {
        const send = await sendOtp(c, secret, "verify", email, locale ?? "en");
        if (send.outcome === "failed") {
            return errorJson(500, "internal", "internal server error");
        }
        if (send.outcome === "limited") {
            return errorJson(429, "rate_limited", "too many requests", {
                "Retry-After": String(send.retryAfterSec),
            });
        }
        return Response.json({ ok: true });
    }

    // Mint a session id and refresh token without touching the database; the
    // caller decides how the row is persisted (plain insert for login/verify,
    // atomic rotation claim for refresh).
    async function mintSession(
        c: { env: AuthEnv; req: { header: (name: string) => string | undefined } },
        userId: string,
        nowMs: number,
    ): Promise<{
        sessionId: string;
        userId: string;
        refreshToken: string;
        refreshHash: string;
        expiresAt: string;
        userAgent: string | null;
        ip: string | null;
    }> {
        const refreshToken = generateRefreshToken();
        const refreshHash = await hashRefreshToken(refreshToken);
        const sessionId = crypto.randomUUID();
        const userAgent = c.req.header("User-Agent") ?? null;
        const ip = c.req.header("CF-Connecting-IP") ?? null;
        return {
            sessionId,
            userId,
            refreshToken,
            refreshHash,
            expiresAt: new Date(nowMs + REFRESH_TOKEN_TTL_MS).toISOString(),
            userAgent: userAgent === null ? null : userAgent.slice(0, 255),
            ip,
        };
    }

    async function createSession(
        c: { env: AuthEnv; req: { header: (name: string) => string | undefined } },
        userId: string,
        nowMs: number,
    ): Promise<{ sessionId: string; refreshToken: string }> {
        const minted = await mintSession(c, userId, nowMs);
        await insertSession(c.env.FIT_DB, minted);
        return { sessionId: minted.sessionId, refreshToken: minted.refreshToken };
    }

    async function issueTokenPair(
        c: { env: AuthEnv; req: { header: (name: string) => string | undefined } },
        secret: string,
        user: UserRow,
    ): Promise<TokenPair> {
        const nowMs = Date.now();
        const { refreshToken } = await createSession(c, user.user_id, nowMs);
        const accessToken = await signAccessToken(secret, user.user_id, user.token_version, nowMs);
        return { accessToken, refreshToken, expiresIn: ACCESS_TOKEN_TTL_SEC };
    }

    function otpFailureResponse(result: "invalid" | "expired"): Response {
        return result === "invalid"
            ? errorJson(401, "otp_invalid", "incorrect code")
            : errorJson(401, "otp_expired", "code expired or never issued");
    }

    app.post("/signup", async (c) => {
        const parsed = SignupSchema.safeParse(await c.req.json().catch(() => null));
        if (!parsed.success) {
            return errorJson(400, "bad_request", "invalid request body");
        }
        const limited = await rateLimited(
            c,
            "signup-ip",
            clientIp(c),
            SIGNUP_IP_LIMIT,
            SIGNUP_IP_WINDOW_SEC,
        );
        if (limited) {
            return limited;
        }
        const secret = requireSecret(c);
        if (!secret) {
            return errorJson(500, "internal", "internal server error");
        }
        const { email, password, locale } = parsed.data;

        // A repeat signup for an already-pending address only resends the
        // code: the submitted password is ignored and the password from the
        // initial signup is kept.
        const existing = await getUserByEmail(c.env.FIT_DB, email);
        if (existing?.status === "active") {
            return errorJson(409, "email_taken", "an account with this email already exists");
        }
        if (existing?.status === "pending") {
            return resendSignupOtp(c, secret, email, locale);
        }

        const userId = crypto.randomUUID();
        try {
            await insertUser(c.env.FIT_DB, userId, email, await hashPassword(password));
        } catch (error) {
            // Two concurrent signups for the same new address can both pass
            // the existence check above; the loser's insert then violates the
            // UNIQUE(email) constraint. Catch only that error, reload the
            // row, and follow the normal pending-resend or active-conflict
            // path instead of returning a 500.
            if (!isUniqueConstraintError(error)) {
                throw error;
            }
            const raced = await getUserByEmail(c.env.FIT_DB, email);
            if (raced?.status === "active") {
                return errorJson(409, "email_taken", "an account with this email already exists");
            }
            if (raced?.status === "pending") {
                return resendSignupOtp(c, secret, email, locale);
            }
            // The conflicting row vanished between the failed insert and the
            // reload; nothing sensible remains but the generic failure.
            throw error;
        }
        const send = await sendOtp(c, secret, "verify", email, locale ?? "en");
        if (send.outcome === "failed") {
            // The pending row stays; a retried signup follows the resend path.
            return errorJson(500, "internal", "internal server error");
        }
        if (send.outcome === "limited") {
            return errorJson(429, "rate_limited", "too many requests", {
                "Retry-After": String(send.retryAfterSec),
            });
        }
        return c.json({ userId }, 201);
    });

    app.post("/verify-email", async (c) => {
        const parsed = VerifyEmailSchema.safeParse(await c.req.json().catch(() => null));
        if (!parsed.success) {
            return errorJson(400, "bad_request", "invalid request body");
        }
        const secret = requireSecret(c);
        if (!secret) {
            return errorJson(500, "internal", "internal server error");
        }
        const { email, code } = parsed.data;

        const user = await getUserByEmail(c.env.FIT_DB, email);
        if (!user) {
            return errorJson(401, "otp_expired", "code expired or never issued");
        }
        if (user.status === "active") {
            return errorJson(409, "already_verified", "email is already verified");
        }
        const result = await verifyOtp(c.env.AUTH_OTP, secret, "verify", email, code);
        if (result !== "ok") {
            return otpFailureResponse(result);
        }
        await activateUser(c.env.FIT_DB, user.user_id);
        return c.json(await issueTokenPair(c, secret, user), 200);
    });

    app.post("/login", async (c) => {
        const parsed = LoginSchema.safeParse(await c.req.json().catch(() => null));
        if (!parsed.success) {
            return errorJson(400, "bad_request", "invalid request body");
        }
        const limitedIp = await rateLimited(
            c,
            "login-ip",
            clientIp(c),
            LOGIN_IP_LIMIT,
            LOGIN_IP_WINDOW_SEC,
        );
        if (limitedIp) {
            return limitedIp;
        }
        const { email, password } = parsed.data;
        // Keyed on email+IP so one source cannot exhaust a shared account
        // budget and knowing an address alone cannot lock the account out.
        const accountKey = `${email}:${clientIp(c)}`;
        const limitedAccount = await rateLimited(
            c,
            "login-account",
            accountKey,
            LOGIN_ACCOUNT_LIMIT,
            LOGIN_ACCOUNT_WINDOW_SEC,
        );
        if (limitedAccount) {
            return limitedAccount;
        }
        const secret = requireSecret(c);
        if (!secret) {
            return errorJson(500, "internal", "internal server error");
        }

        const user = await getUserByEmail(c.env.FIT_DB, email);
        if (!user) {
            await verifyPassword(password, DUMMY_PASSWORD_HASH);
            return errorJson(401, "invalid_credentials", "invalid email or password");
        }
        if (user.status === "pending") {
            // Best-effort verification nudge; cooldown and caps apply silently.
            await sendOtp(c, secret, "verify", email, "en");
            return errorJson(403, "email_unverified", "email address is not verified");
        }
        if (!(await verifyPassword(password, user.password_hash))) {
            return errorJson(401, "invalid_credentials", "invalid email or password");
        }
        // The quota counts failed attempts only, so refund the hit taken
        // above: a correct password must never consume the budget.
        await fixedWindowRefund(
            c.env.AUTH_RATE_LIMIT,
            "login-account",
            accountKey,
            LOGIN_ACCOUNT_WINDOW_SEC,
        );
        return c.json(await issueTokenPair(c, secret, user), 200);
    });

    app.post("/refresh", async (c) => {
        const parsed = RefreshSchema.safeParse(await c.req.json().catch(() => null));
        if (!parsed.success) {
            return errorJson(400, "bad_request", "invalid request body");
        }
        const limited = await rateLimited(
            c,
            "token-ip",
            clientIp(c),
            TOKEN_IP_LIMIT,
            TOKEN_IP_WINDOW_SEC,
        );
        if (limited) {
            return limited;
        }
        const secret = requireSecret(c);
        if (!secret) {
            return errorJson(500, "internal", "internal server error");
        }
        const { refreshToken } = parsed.data;
        const refreshHash = await hashRefreshToken(refreshToken);
        const session = await getSessionByRefreshHash(c.env.FIT_DB, refreshHash);
        const nowMs = Date.now();
        const nowIso = new Date(nowMs).toISOString();

        if (!session || session.revoked_at !== null || session.expires_at <= nowIso) {
            return errorJson(401, "invalid_token", "refresh token is invalid or expired");
        }
        if (session.replaced_by !== null) {
            if (session.rotation_grace_until !== null && nowIso < session.rotation_grace_until) {
                // Idempotent replay: the client lost the rotation response, so
                // hand back the same successor pair.
                const stashed = await c.env.AUTH_KV.get(rotationStashKey(refreshHash));
                if (stashed !== null) {
                    return c.json(JSON.parse(stashed) as TokenPair, 200);
                }
                return errorJson(401, "invalid_token", "refresh token is invalid or expired");
            }
            // A token older than the grace window is a genuine reuse signal:
            // revoke the user's whole session chain and bump token_version so
            // access tokens issued before the detection are invalidated too.
            await invalidateUserTokens(c.env.FIT_DB, session.user_id);
            return errorJson(401, "invalid_token", "refresh token is invalid or expired");
        }

        const user = await getUserById(c.env.FIT_DB, session.user_id);
        if (user?.status !== "active") {
            return errorJson(401, "invalid_token", "refresh token is invalid or expired");
        }

        const minted = await mintSession(c, user.user_id, nowMs);
        // Atomic claim: a concurrent rotation of the same token loses here and
        // must not issue its minted token, so no orphan or competing successor
        // session is ever created. The loser follows the same replay path as a
        // client that lost the rotation response.
        const claimed = await rotateSession(
            c.env.FIT_DB,
            session.session_id,
            minted,
            new Date(nowMs + ROTATION_GRACE_MS).toISOString(),
        );
        if (!claimed) {
            const stashed = await c.env.AUTH_KV.get(rotationStashKey(refreshHash));
            if (stashed !== null) {
                return c.json(JSON.parse(stashed) as TokenPair, 200);
            }
            return errorJson(401, "invalid_token", "refresh token is invalid or expired");
        }
        const pair: TokenPair = {
            accessToken: await signAccessToken(secret, user.user_id, user.token_version, nowMs),
            refreshToken: minted.refreshToken,
            expiresIn: ACCESS_TOKEN_TTL_SEC,
        };
        // Best-effort: the rotation is already committed in D1, so a failed
        // stash write must not fail the response — otherwise the client loses
        // the minted token and the grace-window replay path finds nothing,
        // forcing a full re-login. Degraded replay is acceptable; the client
        // still holds a working refresh token.
        try {
            await c.env.AUTH_KV.put(rotationStashKey(refreshHash), JSON.stringify(pair), {
                expirationTtl: ROTATION_STASH_TTL_SEC,
            });
        } catch (err) {
            console.error("rotation stash write failed", err);
        }
        return c.json(pair, 200);
    });

    app.post("/logout", async (c) => {
        const parsed = RefreshSchema.safeParse(await c.req.json().catch(() => null));
        if (!parsed.success) {
            return errorJson(400, "bad_request", "invalid request body");
        }
        const limited = await rateLimited(
            c,
            "token-ip",
            clientIp(c),
            TOKEN_IP_LIMIT,
            TOKEN_IP_WINDOW_SEC,
        );
        if (limited) {
            return limited;
        }
        const refreshHash = await hashRefreshToken(parsed.data.refreshToken);
        const session = await getSessionByRefreshHash(c.env.FIT_DB, refreshHash);
        if (session) {
            await revokeSession(c.env.FIT_DB, session.session_id);
        }
        return c.json({ ok: true }, 200);
    });

    app.post("/deregister", async (c) => {
        const secret = requireSecret(c);
        if (!secret) {
            return errorJson(500, "internal", "internal server error");
        }
        const header = c.req.header("Authorization") ?? "";
        const token = header.startsWith("Bearer ") ? header.slice("Bearer ".length) : null;
        const claims = token === null ? null : await verifyAccessToken(secret, token);
        if (!claims) {
            return errorJson(401, "invalid_token", "missing or invalid access token");
        }
        const user = await getUserById(c.env.FIT_DB, claims.sub);
        if (user?.status !== "active" || user.token_version !== claims.tv) {
            return errorJson(401, "invalid_token", "missing or invalid access token");
        }
        await deregisterUser(c.env.FIT_DB, user.user_id);
        return c.json({ ok: true }, 200);
    });

    app.post("/reset-password", async (c) => {
        const parsed = ResetRequestSchema.safeParse(await c.req.json().catch(() => null));
        if (!parsed.success) {
            return errorJson(400, "bad_request", "invalid request body");
        }
        const secret = requireSecret(c);
        if (!secret) {
            return errorJson(500, "internal", "internal server error");
        }
        const { email, locale } = parsed.data;

        const user = await getUserByEmail(c.env.FIT_DB, email);
        if (user?.status === "active") {
            const bucket = await fixedWindowLimit(
                c.env.AUTH_RATE_LIMIT,
                "reset-email",
                email,
                RESET_EMAIL_LIMIT,
                RESET_EMAIL_WINDOW_SEC,
            );
            if (bucket.allowed) {
                // Enumeration-safe: the outcome never leaks into the response.
                await sendOtp(c, secret, "reset", email, locale ?? "en");
            }
        }
        return c.json({ ok: true }, 200);
    });

    app.post("/reset-password/confirm", async (c) => {
        const parsed = ResetConfirmSchema.safeParse(await c.req.json().catch(() => null));
        if (!parsed.success) {
            return errorJson(400, "bad_request", "invalid request body");
        }
        const secret = requireSecret(c);
        if (!secret) {
            return errorJson(500, "internal", "internal server error");
        }
        const { email, code, newPassword } = parsed.data;

        const user = await getUserByEmail(c.env.FIT_DB, email);
        if (user?.status !== "active") {
            return errorJson(401, "otp_expired", "code expired or never issued");
        }
        const result = await verifyOtp(c.env.AUTH_OTP, secret, "reset", email, code);
        if (result !== "ok") {
            return otpFailureResponse(result);
        }
        await updateUserPassword(c.env.FIT_DB, user.user_id, await hashPassword(newPassword));
        await revokeAllUserSessions(c.env.FIT_DB, user.user_id);
        // updateUserPassword bumped token_version; the fresh pair must carry
        // the new version (reads-your-writes is not assumed here).
        const fresh: UserRow = { ...user, token_version: user.token_version + 1 };
        return c.json(await issueTokenPair(c, secret, fresh), 200);
    });

    app.onError((err, _c) => {
        console.error("Unhandled error", err);
        return errorJson(500, "internal", "internal server error");
    });

    return app;
}

export const authApp = createAuthApp();
