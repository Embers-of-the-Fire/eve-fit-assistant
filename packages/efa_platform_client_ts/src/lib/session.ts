import { AccountApiClient, type FetchLike } from "./client";
import { AccountApiError, PlatformAuthRequiredError } from "./errors";
import { decodeJwtSubject } from "./jwt";
import type { PlatformSessionStore } from "./store";
import type {
    AuthTokenPair,
    PlatformAccountInfo,
    PlatformIdentity,
    StoredPlatformSession,
} from "./types";

/**
 * Production origin of the platform API (`worker/efa-platform-api`): auth
 * endpoints are mounted at `/platform/auth`, public reads at
 * `/platform/internal`.
 */
export const platformApiProductionOrigin = "https://api.efa-tech.dev";

/** Refresh the access token when it expires within this window. */
const REFRESH_SKEW_MS = 60_000;

export interface PlatformSessionOptions {
    origin: string;
    store: PlatformSessionStore;
    /** Supplies the `locale` field for OTP emails (signup, resend, password reset). */
    emailLocale?: () => string | undefined;
    /**
     * Fires when the session is rejected server-side (refresh rejected or
     * revoked) and interactive login is required; throttled to once per
     * signed-out stretch.
     */
    onAuthRequired?: () => void;
    /** Fetch implementation override (tests, non-browser runtimes). */
    fetchFn?: FetchLike;
}

type IdentityListener = (identity: PlatformIdentity | null) => void;

/** Simple promise-chained mutex for serializing session mutations. */
class Mutex {
    private _last: Promise<unknown> = Promise.resolve();

    synchronized<T>(fn: () => Promise<T>): Promise<T> {
        const next = this._last.then(fn);
        this._last = next.then(
            () => undefined,
            () => undefined,
        );
        return next;
    }
}

/**
 * Facade over the platform account API: auth flows plus the whole token
 * lifecycle (storage, expiry tracking, mutex-serialized refresh, rotation
 * replay, 401 retry, session clearing).
 *
 * Embedders never touch an access token: everything token-shaped is
 * package-internal. The session record lives behind {@link PlatformSessionStore};
 * the cold-start rotation (offline-tolerant, with a subject-mismatch guard)
 * starts on construction and runs once per process, keeping the 30-day
 * refresh token alive for active users and dropping stale sessions early.
 */
export class PlatformSession {
    private readonly _store: PlatformSessionStore;
    private readonly _onAuthRequired?: () => void;
    private readonly _emailLocale?: () => string | undefined;
    private readonly _fetch: FetchLike;
    private readonly _authClient: AccountApiClient;
    private readonly _mutex = new Mutex();
    private readonly _ready: Promise<void>;

    private _identity: PlatformIdentity | null = null;
    private readonly _identityListeners = new Set<IdentityListener>();

    /**
     * Whether the `onAuthRequired` hook already fired for the current
     * signed-out stretch; reset on the next successful login so a burst of
     * failing requests triggers one navigation, not many.
     */
    private _authRequiredFired = false;

    constructor(options: PlatformSessionOptions) {
        this._store = options.store;
        this._onAuthRequired = options.onAuthRequired;
        this._emailLocale = options.emailLocale;
        this._fetch = options.fetchFn ?? ((input, init) => fetch(input, init));
        this._authClient = new AccountApiClient(options.origin, options.fetchFn);
        // Eagerly start the cold-start load/rotation (errors are contained in
        // `_ready`; the session simply reads as signed out).
        this._ready = this._initialize();
    }

    /**
     * Completes when the cold-start load and one-time rotation has settled
     * (never throws; a failure reads as signed out, like a missing session).
     */
    get ready(): Promise<void> {
        return this._ready;
    }

    // ---- state ----

    /** The signed-in identity, or null when signed out. Null until the stored
     * session (if any) has been loaded and validated at cold start. */
    get me(): PlatformIdentity | null {
        return this._identity;
    }

    /**
     * Subscribes to identity changes; the listener first receives the
     * post-cold-start value (like {@link me} once {@link ready} has
     * completed), then every subsequent change. Returns an unsubscribe
     * function.
     */
    subscribeIdentity(listener: IdentityListener): () => void {
        let active = true;
        void this._ready.then(() => {
            if (!active) return;
            listener(this._identity);
            this._identityListeners.add(listener);
        });
        return () => {
            active = false;
            this._identityListeners.delete(listener);
        };
    }

    private _setIdentity(value: PlatformIdentity | null): void {
        const unchanged =
            value === this._identity ||
            (value !== null &&
                this._identity !== null &&
                value.userId === this._identity.userId &&
                value.email === this._identity.email);
        if (unchanged) return;
        this._identity = value;
        for (const listener of [...this._identityListeners]) {
            listener(value);
        }
    }

    // ---- auth flows: no tokens cross the boundary ----

    /**
     * `POST /login`. Throws {@link AccountApiError} on failure; the UI maps
     * `email_unverified` to the verification flow.
     */
    async login(email: string, password: string): Promise<void> {
        const pair = await this._authClient.login(email, password);
        await this._acceptTokenPair(email, pair);
    }

    /**
     * `POST /signup`: creates the pending account and sends the verification
     * code. Also used to resend the code for an already-pending address.
     */
    signup(email: string, password: string): Promise<void> {
        return this._authClient.signup(email, password, this._emailLocale?.());
    }

    /**
     * `POST /signup/resend`: resends the verification code for a pending
     * account without a password (the verification step may be reached from
     * the login redirect, where the password was never collected).
     */
    resendSignupCode(email: string): Promise<void> {
        return this._authClient.signupResend(email, this._emailLocale?.());
    }

    /** `POST /verify-email`: activates the pending account and signs in. */
    async verifyEmail(email: string, code: string): Promise<void> {
        const pair = await this._authClient.verifyEmail(email, code);
        await this._acceptTokenPair(email, pair);
    }

    /**
     * `POST /reset-password`: sends a reset code when the address belongs to
     * an active account (the response never reveals which).
     */
    requestPasswordReset(email: string): Promise<void> {
        return this._authClient.resetPassword(email, this._emailLocale?.());
    }

    /**
     * `POST /reset-password/confirm`: sets the new password and signs in with
     * the freshly issued pair (all previous sessions are revoked server-side).
     */
    async confirmPasswordReset(email: string, code: string, newPassword: string): Promise<void> {
        const pair = await this._authClient.resetPasswordConfirm(email, code, newPassword);
        await this._acceptTokenPair(email, pair);
    }

    /** `POST /logout` (best-effort), then clears the local session. */
    logout(): Promise<void> {
        return this._mutex.synchronized(async () => {
            const session = await this._store.read();
            if (session !== null) {
                try {
                    await this._authClient.logout(session.refreshToken);
                } catch {
                    // Logout stays local: the refresh token dies with its 30-day TTL.
                }
            }
            await this._clearSessionLocked();
        });
    }

    /**
     * `POST /deregister` with a fresh access token plus password
     * re-authentication, then clears the local session.
     */
    async deregister(password: string): Promise<void> {
        const accessToken = await this._requireValidAccessToken();
        await this._authClient.deregister(accessToken, password);
        await this._clearSession();
    }

    /**
     * `POST /account` with a fresh access token: identity plus the account's
     * ACL roles and their resolved permission tokens (see `packages/efa_acl`).
     */
    async accountInfo(): Promise<PlatformAccountInfo> {
        const accessToken = await this._requireValidAccessToken();
        return this._authClient.account(accessToken);
    }

    // ---- escape hatch for future authenticated endpoints ----

    /**
     * Runs a `fetch` that transparently attaches a valid access token
     * (refreshing as needed) and retries once after a forced rotation when
     * the server answers 401. Throws {@link PlatformAuthRequiredError} when
     * no valid session exists.
     */
    async authedFetch(url: string, init: RequestInit = {}): Promise<Response> {
        const token = await this._requireValidAccessToken();
        let response = await this._sendWithBearer(url, init, token);
        if (response.status !== 401) return response;
        // The attached token was rejected (e.g. the account's token version
        // moved past it): force one rotation and retry the request once.
        const rotated = await this._forceRefreshAccessToken();
        response = await this._sendWithBearer(url, init, rotated);
        return response;
    }

    private _sendWithBearer(url: string, init: RequestInit, token: string): Promise<Response> {
        const headers = new Headers(init.headers);
        headers.set("Authorization", `Bearer ${token}`);
        return this._fetch(url, { ...init, headers });
    }

    // ---- token lifecycle (package-internal) ----

    /** Cold start: loads the stored session and rotates it once. Never
     * throws: an unreadable store reads as signed out. */
    private async _initialize(): Promise<void> {
        try {
            const session = await this._store.read();
            if (session === null) return;
            await this._startupRefresh(session);
        } catch {
            this._setIdentity(null);
        }
    }

    /** Rotates the stored session. Offline-tolerant: any failure other than
     * the server rejecting the token keeps the session as-is. */
    private _startupRefresh(session: StoredPlatformSession): Promise<void> {
        return this._mutex.synchronized(async () => {
            // Re-read inside the critical section: a login or logout may have
            // replaced the session while this refresh was queued on the mutex.
            const current = await this._store.read();
            if (current === null) {
                this._setIdentity(null);
                return;
            }
            if (current.refreshToken !== session.refreshToken) {
                // Another flow already rotated or replaced the session; keep it.
                this._setIdentity(identityOf(current));
                return;
            }
            try {
                const pair = await this._authClient.refresh(current.refreshToken);
                // Validate the rotated pair against the stored identity before
                // persistence: a refresh result identifying another account
                // must not replace the stored access token while the state
                // still identifies the prior account. Keep the stored session
                // as-is; the server already rotated the refresh token, so a
                // later expiry-triggered refresh will be rejected and force a
                // re-login.
                const subject = decodeJwtSubject(pair.accessToken);
                if (subject === null || subject === "" || subject !== current.userId) {
                    this._setIdentity(identityOf(current));
                    return;
                }
                try {
                    await this._store.write(rotated(current, pair));
                } catch {
                    // The server already rotated the pair but the successor could
                    // not be persisted. The stored session is untouched
                    // (single-key atomic write), so the app keeps working on it;
                    // the next expiry-triggered refresh may be rejected and force
                    // a re-login.
                }
            } catch (err) {
                if (err instanceof AccountApiError && err.isInvalidToken) {
                    // The refresh token is dead (expired, revoked, or reused):
                    // sign out. Deliberately no onAuthRequired here: nothing is
                    // in flight that a login redirect would recover, and a
                    // navigation at cold start would yank the user out of
                    // whatever they opened.
                    await this._clearSessionLocked();
                    return;
                }
                // Rate-limited, offline, or unreachable: keep the stored session.
            }
            this._setIdentity(identityOf(current));
        });
    }

    /**
     * Returns a usable access token, refreshing (and persisting the rotated
     * pair) when the stored one is expired or about to expire.
     *
     * The whole read-check-refresh-write sequence runs inside the session
     * mutex: a concurrent caller observes the already-rotated pair on its
     * re-read and reuses it instead of rotating a second time (a duplicate
     * refresh would invalidate the freshly stored pair server-side).
     */
    private _requireValidAccessToken(): Promise<string> {
        return this._mutex.synchronized(async () => {
            const session = await this._store.read();
            if (session === null) {
                this._setIdentity(null);
                this._fireAuthRequired();
                throw new PlatformAuthRequiredError("not signed in");
            }
            if (session.expiresAtMs > Date.now() + REFRESH_SKEW_MS) {
                return session.accessToken;
            }
            return this._refreshLocked(session);
        });
    }

    /**
     * Returns a freshly rotated access token regardless of the stored one's
     * expiry; used by the 401 retry path, where the attached token was
     * rejected despite looking valid locally.
     */
    private _forceRefreshAccessToken(): Promise<string> {
        return this._mutex.synchronized(async () => {
            const session = await this._store.read();
            if (session === null) {
                this._setIdentity(null);
                this._fireAuthRequired();
                throw new PlatformAuthRequiredError("not signed in");
            }
            return this._refreshLocked(session);
        });
    }

    /**
     * Rotates `session`'s refresh token and persists the successor pair.
     * Caller must hold the session mutex. A rejected refresh or a rotated
     * pair identifying another account clears the doomed session (the server
     * already rotated its refresh token, so it can never produce a usable
     * token again) and throws {@link PlatformAuthRequiredError}.
     */
    private async _refreshLocked(session: StoredPlatformSession): Promise<string> {
        let pair: AuthTokenPair;
        try {
            pair = await this._authClient.refresh(session.refreshToken);
        } catch (err) {
            if (err instanceof AccountApiError && err.isInvalidToken) {
                await this._clearSessionLocked();
                this._fireAuthRequired();
                throw new PlatformAuthRequiredError("the session was rejected by the server");
            }
            throw err;
        }
        const subject = decodeJwtSubject(pair.accessToken);
        if (subject === null || subject === "" || subject !== session.userId) {
            await this._clearSessionLocked();
            this._fireAuthRequired();
            throw new PlatformAuthRequiredError(
                "the refreshed token identifies a different account",
            );
        }
        const next = rotated(session, pair);
        await this._store.write(next);
        return next.accessToken;
    }

    private async _acceptTokenPair(email: string, pair: AuthTokenPair): Promise<void> {
        // The auth API has no profile endpoint; the user id comes from the JWT
        // subject and the email is the address the user just authenticated with.
        // Reject a pair whose access token carries no usable subject: persisting
        // it would create a signed-in state with an invalid cached identity.
        const userId = decodeJwtSubject(pair.accessToken);
        if (userId === null || userId === "") {
            await this._clearSession();
            throw new AccountApiError(null, "invalid_token", "access token has no usable subject");
        }
        await this._mutex.synchronized(async () => {
            await this._store.write({
                accessToken: pair.accessToken,
                refreshToken: pair.refreshToken,
                expiresAtMs: Date.now() + pair.expiresIn * 1000,
                email,
                userId,
            });
            this._authRequiredFired = false;
            this._setIdentity({ userId, email });
        });
    }

    private _clearSession(): Promise<void> {
        return this._mutex.synchronized(() => this._clearSessionLocked());
    }

    /** Session clear for callers already holding the session mutex. */
    private async _clearSessionLocked(): Promise<void> {
        await this._store.clear();
        this._setIdentity(null);
    }

    private _fireAuthRequired(): void {
        if (this._authRequiredFired) return;
        this._authRequiredFired = true;
        this._onAuthRequired?.();
    }
}

function identityOf(session: StoredPlatformSession): PlatformIdentity {
    return { userId: session.userId, email: session.email };
}

function rotated(session: StoredPlatformSession, pair: AuthTokenPair): StoredPlatformSession {
    return {
        accessToken: pair.accessToken,
        refreshToken: pair.refreshToken,
        expiresAtMs: Date.now() + pair.expiresIn * 1000,
        email: session.email,
        userId: session.userId,
    };
}
