// Token primitives: HS256 access JWTs and opaque refresh tokens. WebCrypto
// only. Only SHA-256 hashes of refresh tokens are ever persisted.

export const ACCESS_TOKEN_TTL_SEC = 15 * 60;
export const REFRESH_TOKEN_TTL_MS = 30 * 24 * 60 * 60 * 1000;
// The just-rotated-out refresh token replays the same successor pair within
// this window, so a response lost client-side (tunnel drop, app backgrounded
// mid-refresh) does not force a logout.
export const ROTATION_GRACE_MS = 60 * 1000;
// Mobile device clocks drift; verification tolerates this much skew on
// iat/exp.
export const CLOCK_SKEW_MS = 30 * 1000;

const REFRESH_TOKEN_BYTES = 32;

export interface AccessTokenClaims {
    sub: string;
    iat: number;
    exp: number;
    jti: string;
    tv: number;
}

function bytesToBase64Url(bytes: Uint8Array): string {
    let binary = "";
    for (const b of bytes) {
        binary += String.fromCharCode(b);
    }
    return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

function base64UrlToBytes(value: string): Uint8Array | null {
    try {
        const base64 = value.replaceAll("-", "+").replaceAll("_", "/");
        const padded = base64 + "=".repeat((4 - (base64.length % 4)) % 4);
        const binary = atob(padded);
        const bytes = new Uint8Array(binary.length);
        for (let i = 0; i < binary.length; i++) {
            bytes[i] = binary.charCodeAt(i);
        }
        return bytes;
    } catch {
        return null;
    }
}

async function importHmacKey(secret: string, usages: ("sign" | "verify")[]): Promise<CryptoKey> {
    return crypto.subtle.importKey(
        "raw",
        new TextEncoder().encode(secret),
        { name: "HMAC", hash: "SHA-256" },
        false,
        usages,
    );
}

export async function signAccessToken(
    secret: string,
    userId: string,
    tokenVersion: number,
    nowMs: number = Date.now(),
): Promise<string> {
    const nowSec = Math.floor(nowMs / 1000);
    const claims: AccessTokenClaims = {
        sub: userId,
        iat: nowSec,
        exp: nowSec + ACCESS_TOKEN_TTL_SEC,
        jti: crypto.randomUUID(),
        tv: tokenVersion,
    };
    const header = bytesToBase64Url(
        new TextEncoder().encode(JSON.stringify({ alg: "HS256", typ: "JWT" })),
    );
    const payload = bytesToBase64Url(new TextEncoder().encode(JSON.stringify(claims)));
    const key = await importHmacKey(secret, ["sign"]);
    const signature = await crypto.subtle.sign(
        "HMAC",
        key,
        new TextEncoder().encode(`${header}.${payload}`),
    );
    return `${header}.${payload}.${bytesToBase64Url(new Uint8Array(signature))}`;
}

export async function verifyAccessToken(
    secret: string,
    token: string,
    nowMs: number = Date.now(),
): Promise<AccessTokenClaims | null> {
    const parts = token.split(".");
    if (parts.length !== 3) {
        return null;
    }
    const signature = base64UrlToBytes(parts[2]);
    if (!signature) {
        return null;
    }
    const key = await importHmacKey(secret, ["verify"]);
    const valid = await crypto.subtle.verify(
        "HMAC",
        key,
        signature.buffer as ArrayBuffer,
        new TextEncoder().encode(`${parts[0]}.${parts[1]}`),
    );
    if (!valid) {
        return null;
    }
    const payloadBytes = base64UrlToBytes(parts[1]);
    if (!payloadBytes) {
        return null;
    }
    let claims: AccessTokenClaims;
    try {
        claims = JSON.parse(new TextDecoder().decode(payloadBytes)) as AccessTokenClaims;
    } catch {
        return null;
    }
    if (
        typeof claims.sub !== "string" ||
        typeof claims.iat !== "number" ||
        typeof claims.exp !== "number" ||
        typeof claims.jti !== "string" ||
        typeof claims.tv !== "number"
    ) {
        return null;
    }
    const nowSec = nowMs / 1000;
    const skewSec = CLOCK_SKEW_MS / 1000;
    if (nowSec > claims.exp + skewSec || claims.iat - skewSec > nowSec) {
        return null;
    }
    return claims;
}

export function generateRefreshToken(): string {
    return bytesToBase64Url(crypto.getRandomValues(new Uint8Array(REFRESH_TOKEN_BYTES)));
}

export async function hashRefreshToken(token: string): Promise<string> {
    const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(token));
    let hex = "";
    for (const b of new Uint8Array(digest)) {
        hex += b.toString(16).padStart(2, "0");
    }
    return hex;
}
