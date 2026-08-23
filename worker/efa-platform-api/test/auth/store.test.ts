// Session store tests against the real local D1 database (migrated from
// migrations/ by the test setup file). D1 batches provide the same
// single-transaction semantics the store relies on.

import { env } from "cloudflare:workers";
import { beforeEach, describe, expect, it } from "vitest";
import {
    getSessionByRefreshHash,
    getUserById,
    insertSession,
    insertUser,
    invalidateUserTokens,
    rotateSession,
} from "../../src/auth/store.ts";
import { clearAuthState } from "./helpers.ts";

const EXPIRES_AT = "2030-01-01T00:00:00.000Z";
const GRACE_UNTIL = "2026-06-01T00:01:00.000Z";

const db = env.FIT_DB;

beforeEach(async () => {
    await clearAuthState();
});

async function seedUser(): Promise<string> {
    const userId = crypto.randomUUID();
    await insertUser(db, userId, `${userId}@example.com`, "hash");
    return userId;
}

async function seedSession(userId: string, refreshHash: string): Promise<string> {
    const sessionId = crypto.randomUUID();
    await insertSession(db, {
        sessionId,
        userId,
        refreshHash,
        expiresAt: EXPIRES_AT,
        userAgent: null,
        ip: null,
    });
    return sessionId;
}

function successor(userId: string, refreshHash: string) {
    return {
        sessionId: crypto.randomUUID(),
        userId,
        refreshHash,
        expiresAt: EXPIRES_AT,
        userAgent: null,
        ip: null,
    };
}

describe("rotateSession", () => {
    it("claims the session and inserts the successor atomically", async () => {
        const userId = await seedUser();
        const sessionId = await seedSession(userId, "hash-old");

        const next = successor(userId, "hash-new");
        expect(await rotateSession(db, sessionId, next, GRACE_UNTIL)).toBe(true);

        const previous = await getSessionByRefreshHash(db, "hash-old");
        expect(previous?.replaced_by).toBe(next.sessionId);
        expect(previous?.rotation_grace_until).toBe(GRACE_UNTIL);
        const inserted = await getSessionByRefreshHash(db, "hash-new");
        expect(inserted?.session_id).toBe(next.sessionId);
        expect(inserted?.user_id).toBe(userId);
    });

    it("rejects a second rotation without inserting a competing successor", async () => {
        const userId = await seedUser();
        const sessionId = await seedSession(userId, "hash-old");

        const winner = successor(userId, "hash-winner");
        expect(await rotateSession(db, sessionId, winner, GRACE_UNTIL)).toBe(true);

        // A later rotation of the same session loses: its claim matches zero
        // rows and its successor is dropped.
        const loser = successor(userId, "hash-loser");
        expect(await rotateSession(db, sessionId, loser, GRACE_UNTIL)).toBe(false);

        const previous = await getSessionByRefreshHash(db, "hash-old");
        expect(previous?.replaced_by).toBe(winner.sessionId);
        expect(await getSessionByRefreshHash(db, "hash-loser")).toBe(null);
    });

    it("claims nothing for an unknown session", async () => {
        const userId = await seedUser();

        const next = successor(userId, "hash-new");
        expect(await rotateSession(db, crypto.randomUUID(), next, GRACE_UNTIL)).toBe(false);
        expect(await getSessionByRefreshHash(db, "hash-new")).toBe(null);
    });

    it("reports failure when the claim matches but the guarded insert is skipped", async () => {
        const userId = await seedUser();
        const sessionId = await seedSession(userId, "hash-old");

        // Simulate replaced_by changing between the claim and the guarded
        // insert: the claim applies, but the insert's WHERE EXISTS no longer
        // matches, so no successor row is created and the caller must not
        // issue a token for it. The wrapper delegates to the real D1
        // statements, running them outside a batch to allow the interleave.
        const hijacked = crypto.randomUUID();
        const interleaved = {
            prepare: (sql: string) => db.prepare(sql),
            batch: async (statements: D1PreparedStatement[]) => {
                const results = [];
                results.push(await statements[0].run());
                await db
                    .prepare("UPDATE auth_sessions SET replaced_by = ? WHERE session_id = ?")
                    .bind(hijacked, sessionId)
                    .run();
                results.push(await statements[1].run());
                return results;
            },
        } as unknown as D1Database;

        const next = successor(userId, "hash-new");
        expect(await rotateSession(interleaved, sessionId, next, GRACE_UNTIL)).toBe(false);
        // The return value matches successor-row presence: none was inserted.
        expect(await getSessionByRefreshHash(db, "hash-new")).toBe(null);
        const previous = await getSessionByRefreshHash(db, "hash-old");
        expect(previous?.replaced_by).toBe(hijacked);
    });

    it("rolls back the claim when the successor insert fails", async () => {
        const userId = await seedUser();
        const sessionId = await seedSession(userId, "hash-old");
        // A conflicting row makes the successor insert violate UNIQUE(refresh_hash).
        await seedSession(userId, "hash-dup");

        await expect(
            rotateSession(db, sessionId, successor(userId, "hash-dup"), GRACE_UNTIL),
        ).rejects.toThrow();

        const previous = await getSessionByRefreshHash(db, "hash-old");
        expect(previous?.replaced_by).toBe(null);
    });
});

describe("invalidateUserTokens", () => {
    it("revokes all sessions and bumps token_version atomically", async () => {
        const userId = await seedUser();
        await seedSession(userId, "hash-a");
        await seedSession(userId, "hash-b");

        const before = await getUserById(db, userId);
        await invalidateUserTokens(db, userId);

        const after = await getUserById(db, userId);
        expect(after?.token_version).toBe((before?.token_version ?? 0) + 1);
        for (const hash of ["hash-a", "hash-b"]) {
            const session = await getSessionByRefreshHash(db, hash);
            expect(session?.revoked_at).not.toBe(null);
        }
    });
});
