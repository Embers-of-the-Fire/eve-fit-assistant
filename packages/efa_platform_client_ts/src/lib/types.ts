/**
 * Shared types of the platform client: the token pair issued by the auth
 * API, the locally stored session record, and the signed-in identity.
 */

/** A token pair issued by the auth API (`login`, `verify-email`, `refresh`, `reset-password/confirm`). */
export interface AuthTokenPair {
    accessToken: string;
    refreshToken: string;
    /** Access-token lifetime in seconds from issuance. */
    expiresIn: number;
}

/**
 * A locally held platform session: the token pair from the auth API plus
 * the access token's expiry instant and the cached account identity
 * (refresh tokens are rotated server-side on every refresh, so the stored
 * pair is always the latest).
 */
export interface StoredPlatformSession {
    accessToken: string;
    refreshToken: string;
    /** Unix milliseconds the access token expires at, derived from `expiresIn` at issuance. */
    expiresAtMs: number;
    /** The address the user authenticated with; the auth API has no profile endpoint, so it is cached here. */
    email: string;
    /** The account's user id (the access token's JWT subject). */
    userId: string;
}

/**
 * What the outside world knows about the signed-in user.
 *
 * Reserved placeholder: derived locally (JWT subject + cached email); no
 * server `/me` endpoint exists yet and the shape may change when one lands.
 */
export interface PlatformIdentity {
    userId: string;
    email: string;
}
