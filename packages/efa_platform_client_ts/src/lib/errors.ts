/**
 * Error types of the platform client.
 */

/**
 * HTTP failure from the auth API; `code` is the worker's error-envelope code
 * (`invalid_credentials`, `otp_invalid`, `email_taken`, ...) when present.
 */
export class AccountApiError extends Error {
    /** HTTP status, or null when the request never reached the server (network failure). */
    readonly statusCode: number | null;
    /** The worker's error-envelope code, when present. */
    readonly code: string | null;
    /** Value of the `Retry-After` header on `429 rate_limited` responses. */
    readonly retryAfterSec: number | null;

    constructor(
        statusCode: number | null,
        code: string | null,
        message?: string,
        retryAfterSec?: number | null,
    ) {
        super(message ?? code ?? "account API error");
        this.name = "AccountApiError";
        this.statusCode = statusCode;
        this.code = code;
        this.retryAfterSec = retryAfterSec ?? null;
    }

    get isInvalidToken(): boolean {
        return this.statusCode === 401 || this.code === "invalid_token";
    }

    get isEmailUnverified(): boolean {
        return this.code === "email_unverified";
    }
}

/**
 * Thrown when a request needs auth but no valid session exists (never
 * logged in, refresh rejected, or the session was revoked server-side).
 * The session's `onAuthRequired` hook fires before this propagates.
 */
export class PlatformAuthRequiredError extends Error {
    constructor(message = "a valid session is required") {
        super(message);
        this.name = "PlatformAuthRequiredError";
    }
}
