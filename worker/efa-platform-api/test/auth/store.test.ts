import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { describe, it } from "node:test";
import {
    getSessionByRefreshHash,
    getUserById,
    insertSession,
    insertUser,
    invalidateUserTokens,
    rotateSession,
} from "../../src/auth/store.ts";
import { loadAuthDatabase, TestD1Database } from "./helpers.ts";

const EXPIRES_AT = "2030-01-01T00:00:00.000Z";
const GRACE_UNTIL = "2026-06-01T00:01:00.000Z";

function setupDb(): D1Database {
    return new TestD1Database(loadAuthDatabase()) as unknown as D1Database;
}

async function seedUser(db: D1Database): Promise<string> {
    const userId = randomUUID();
    await insertUser(db, userId, `${userId}@example.com`, "hash");
    return userId;
}

async function seedSession(db: D1Database, userId: string, refreshHash: string): Promise<string> {
    const sessionId = randomUUID();
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
        sessionId: randomUUID(),
        userId,
        refreshHash,
        expiresAt: EXPIRES_AT,
        userAgent: null,
        ip: null,
    };
}

describe("rotateSession", () => {
    it("claims the session and inserts the successor atomically", async () => {
        const db = setupDb();
        const userId = await seedUser(db);
        const sessionId = await seedSession(db, userId, "hash-old");

        const next = successor(userId, "hash-new");
        assert.equal(await rotateSession(db, sessionId, next, GRACE_UNTIL), true);

        const previous = await getSessionByRefreshHash(db, "hash-old");
        assert.equal(previous?.replaced_by, next.sessionId);
        assert.equal(previous?.rotation_grace_until, GRACE_UNTIL);
        const inserted = await getSessionByRefreshHash(db, "hash-new");
        assert.equal(inserted?.session_id, next.sessionId);
        assert.equal(inserted?.user_id, userId);
    });

    it("rejects a second rotation without inserting a competing successor", async () => {
        const db = setupDb();
        const userId = await seedUser(db);
        const sessionId = await seedSession(db, userId, "hash-old");

        const winner = successor(userId, "hash-winner");
        assert.equal(await rotateSession(db, sessionId, winner, GRACE_UNTIL), true);

        // A later rotation of the same session loses: its claim matches zero
        // rows and its successor is dropped.
        const loser = successor(userId, "hash-loser");
        assert.equal(await rotateSession(db, sessionId, loser, GRACE_UNTIL), false);

        const previous = await getSessionByRefreshHash(db, "hash-old");
        assert.equal(previous?.replaced_by, winner.sessionId);
        assert.equal(await getSessionByRefreshHash(db, "hash-loser"), null);
    });

    it("claims nothing for an unknown session", async () => {
        const db = setupDb();
        const userId = await seedUser(db);

        const next = successor(userId, "hash-new");
        assert.equal(await rotateSession(db, randomUUID(), next, GRACE_UNTIL), false);
        assert.equal(await getSessionByRefreshHash(db, "hash-new"), null);
    });

    it("reports failure when the claim matches but the guarded insert is skipped", async () => {
        const db = setupDb();
        const userId = await seedUser(db);
        const sessionId = await seedSession(db, userId, "hash-old");

        // Simulate replaced_by changing between the claim and the guarded
        // insert: the claim applies, but the insert's WHERE EXISTS no longer
        // matches, so no successor row is created and the caller must not
        // issue a token for it.
        const hijacked = randomUUID();
        const interleaved = {
            prepare: (sql: string) => db.prepare(sql),
            batch: async (statements: { run(): Promise<{ meta: { changes: number } }> }[]) => {
                const results = [] as { meta: { changes: number } }[];
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
        assert.equal(await rotateSession(interleaved, sessionId, next, GRACE_UNTIL), false);
        // The return value matches successor-row presence: none was inserted.
        assert.equal(await getSessionByRefreshHash(db, "hash-new"), null);
        const previous = await getSessionByRefreshHash(db, "hash-old");
        assert.equal(previous?.replaced_by, hijacked);
    });

    it("rolls back the claim when the successor insert fails", async () => {
        const db = setupDb();
        const userId = await seedUser(db);
        const sessionId = await seedSession(db, userId, "hash-old");
        // A conflicting row makes the successor insert violate UNIQUE(refresh_hash).
        await seedSession(db, userId, "hash-dup");

        await assert.rejects(
            rotateSession(db, sessionId, successor(userId, "hash-dup"), GRACE_UNTIL),
        );

        const previous = await getSessionByRefreshHash(db, "hash-old");
        assert.equal(previous?.replaced_by, null);
    });
});

describe("invalidateUserTokens", () => {
    it("revokes all sessions and bumps token_version atomically", async () => {
        const db = setupDb();
        const userId = await seedUser(db);
        await seedSession(db, userId, "hash-a");
        await seedSession(db, userId, "hash-b");

        const before = await getUserById(db, userId);
        await invalidateUserTokens(db, userId);

        const after = await getUserById(db, userId);
        assert.equal(after?.token_version, (before?.token_version ?? 0) + 1);
        for (const hash of ["hash-a", "hash-b"]) {
            const session = await getSessionByRefreshHash(db, hash);
            assert.ok(session?.revoked_at !== null);
        }
    });
});
