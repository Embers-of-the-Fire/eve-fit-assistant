import type { StoredPlatformSession } from "./types";

/**
 * Persistence boundary of the platform session: the embedder implements
 * this over whatever storage it trusts. Implementations must write a
 * session atomically (a single-key document), so a failure mid-rotation can
 * never leave a partially updated (mixed-generation) credential set behind.
 */
export interface PlatformSessionStore {
    /** The stored session, or null when signed out (or the blob is corrupt). */
    read(): Promise<StoredPlatformSession | null>;
    /** Persists `session` as one atomic write. */
    write(session: StoredPlatformSession): Promise<void>;
    /**
     * Drops the stored session completely; must not fail silently (a
     * surviving record would resurrect the dead session on the next read).
     */
    clear(): Promise<void>;
}

const STORAGE_KEY = "efa-platform-account-session";

/**
 * Browser `localStorage` session store: a single JSON document under one
 * key, so writes stay atomic. The auth API issues tokens in JSON bodies and
 * sets no cookies by design, so the refresh token necessarily lives in
 * script-readable storage here; treat any XSS as credential exposure.
 */
export class LocalStorageSessionStore implements PlatformSessionStore {
    read(): Promise<StoredPlatformSession | null> {
        let raw: string | null;
        try {
            raw = localStorage.getItem(STORAGE_KEY);
        } catch {
            return Promise.resolve(null);
        }
        return Promise.resolve(raw === null ? null : parseStoredSession(raw));
    }

    write(session: StoredPlatformSession): Promise<void> {
        localStorage.setItem(STORAGE_KEY, JSON.stringify(session));
        return Promise.resolve();
    }

    clear(): Promise<void> {
        localStorage.removeItem(STORAGE_KEY);
        return Promise.resolve();
    }
}

function parseStoredSession(raw: string): StoredPlatformSession | null {
    try {
        const json: unknown = JSON.parse(raw);
        if (typeof json !== "object" || json === null) return null;
        const record = json as Record<string, unknown>;
        if (
            typeof record.accessToken !== "string" ||
            typeof record.refreshToken !== "string" ||
            typeof record.expiresAtMs !== "number" ||
            typeof record.email !== "string" ||
            typeof record.userId !== "string"
        ) {
            return null;
        }
        return {
            accessToken: record.accessToken,
            refreshToken: record.refreshToken,
            expiresAtMs: record.expiresAtMs,
            email: record.email,
            userId: record.userId,
        };
    } catch {
        // Corrupt blob reads as "no session".
        return null;
    }
}
