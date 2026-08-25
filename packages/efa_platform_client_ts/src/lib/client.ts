import { AccountApiError } from "./errors";
import type { AuthTokenPair, PlatformAccountInfo } from "./types";

const AUTH_BASE_PATH = "/platform/auth";

export type FetchLike = (input: string, init?: RequestInit) => Promise<Response>;

/**
 * Client for the platform's email+password auth API
 * (`worker/efa-platform-api`, `{origin}/platform/auth`).
 *
 * All endpoints are POST with JSON bodies; errors follow the platform
 * envelope `{ "error": code, "message" }`.
 */
export class AccountApiClient {
    readonly origin: string;
    private readonly _fetch: FetchLike;

    constructor(origin: string, fetchFn?: FetchLike) {
        this.origin = origin;
        this._fetch = fetchFn ?? ((input, init) => fetch(input, init));
    }

    /**
     * `POST /signup`: creates a pending user and sends the verification OTP.
     * Repeating a signup for a pending address silently resends the code.
     */
    signup(email: string, password: string, locale?: string): Promise<void> {
        return this._post("/signup", { email, password, locale });
    }

    /**
     * `POST /signup/resend`: resends the verification OTP for a pending
     * address without requiring the password. Always 200 for unknown or
     * active addresses (enumeration-safe); `429 rate_limited` while the
     * 10-minute per-address resend cooldown is active.
     */
    signupResend(email: string, locale?: string): Promise<void> {
        return this._post("/signup/resend", { email, locale });
    }

    /** `POST /verify-email`: activates a pending user and issues a token pair. */
    verifyEmail(email: string, code: string): Promise<AuthTokenPair> {
        return this._postJson("/verify-email", { email, code });
    }

    /** `POST /login`: issues a token pair; `403 email_unverified` when pending. */
    login(email: string, password: string): Promise<AuthTokenPair> {
        return this._postJson("/login", { email, password });
    }

    /** `POST /refresh`: rotates the session and returns the successor pair. */
    refresh(refreshToken: string): Promise<AuthTokenPair> {
        return this._postJson("/refresh", { refreshToken });
    }

    /** `POST /logout`: revokes the session behind `refreshToken` (idempotent). */
    logout(refreshToken: string): Promise<void> {
        return this._post("/logout", { refreshToken });
    }

    /**
     * `POST /deregister`: irreversibly anonymizes the account. Requires the
     * current access token as Bearer plus the account password.
     */
    deregister(accessToken: string, password: string): Promise<void> {
        return this._post("/deregister", { password }, accessToken);
    }

    /**
     * `POST /account`: identity plus the account's ACL roles and their
     * resolved permission tokens. Requires the current access token as
     * Bearer.
     */
    async account(accessToken: string): Promise<PlatformAccountInfo> {
        const data = await this._postRaw("/account", {}, accessToken);
        if (data === null) {
            throw new AccountApiError(null, null, "empty response body");
        }
        const info = data as Partial<PlatformAccountInfo>;
        if (
            typeof info.userId !== "string" ||
            typeof info.email !== "string" ||
            !Array.isArray(info.roles) ||
            !info.roles.every((role) => typeof role === "string") ||
            !Array.isArray(info.permissions) ||
            !info.permissions.every((token) => typeof token === "string")
        ) {
            throw new AccountApiError(null, null, "malformed account info");
        }
        return {
            userId: info.userId,
            email: info.email,
            roles: info.roles,
            permissions: info.permissions,
        };
    }

    /**
     * `POST /reset-password`: always 200; sends a reset OTP when the address
     * belongs to an active account.
     */
    resetPassword(email: string, locale?: string): Promise<void> {
        return this._post("/reset-password", { email, locale });
    }

    /**
     * `POST /reset-password/confirm`: sets the new password, revokes all
     * sessions, and issues a fresh token pair.
     */
    resetPasswordConfirm(email: string, code: string, newPassword: string): Promise<AuthTokenPair> {
        return this._postJson("/reset-password/confirm", { email, code, newPassword });
    }

    private async _postJson(
        path: string,
        body: Record<string, unknown>,
        bearer?: string,
    ): Promise<AuthTokenPair> {
        const data = await this._postRaw(path, body, bearer);
        if (data === null) {
            throw new AccountApiError(null, null, "empty response body");
        }
        const pair = data as Partial<AuthTokenPair>;
        if (
            typeof pair.accessToken !== "string" ||
            typeof pair.refreshToken !== "string" ||
            typeof pair.expiresIn !== "number"
        ) {
            throw new AccountApiError(null, null, "malformed token pair");
        }
        return {
            accessToken: pair.accessToken,
            refreshToken: pair.refreshToken,
            expiresIn: pair.expiresIn,
        };
    }

    private async _post(
        path: string,
        body: Record<string, unknown>,
        bearer?: string,
    ): Promise<void> {
        await this._postRaw(path, body, bearer);
    }

    private async _postRaw(
        path: string,
        body: Record<string, unknown>,
        bearer?: string,
    ): Promise<Record<string, unknown> | null> {
        const headers: Record<string, string> = { "Content-Type": "application/json" };
        if (bearer !== undefined) headers.Authorization = `Bearer ${bearer}`;
        // Drop undefined fields (e.g. an absent locale) so the JSON body stays clean.
        const jsonBody = Object.fromEntries(
            Object.entries(body).filter(([, v]) => v !== undefined),
        );

        let response: Response;
        try {
            response = await this._fetch(`${this.origin}${AUTH_BASE_PATH}${path}`, {
                method: "POST",
                headers,
                body: JSON.stringify(jsonBody),
            });
        } catch (err) {
            throw new AccountApiError(
                null,
                null,
                err instanceof Error ? err.message : String(err),
                null,
                true,
            );
        }
        if (!response.ok) {
            throw await toAccountApiError(response);
        }
        const text = await response.text();
        if (text === "") return null;
        try {
            return JSON.parse(text) as Record<string, unknown>;
        } catch {
            return null;
        }
    }
}

async function toAccountApiError(response: Response): Promise<AccountApiError> {
    const retryAfterRaw = response.headers.get("retry-after");
    const retryAfterParsed =
        retryAfterRaw === null ? Number.NaN : Number.parseInt(retryAfterRaw, 10);
    const retryAfterSec = Number.isNaN(retryAfterParsed) ? null : retryAfterParsed;

    let code: string | null = null;
    let message: string | null = null;
    try {
        const json: unknown = await response.json();
        if (typeof json === "object" && json !== null) {
            const envelope = json as { error?: unknown; message?: unknown };
            if (typeof envelope.error === "string") code = envelope.error;
            if (typeof envelope.message === "string") message = envelope.message;
        }
    } catch {
        // Non-JSON error body; fall through with null code/message.
    }
    return new AccountApiError(response.status, code, message ?? undefined, retryAfterSec);
}
