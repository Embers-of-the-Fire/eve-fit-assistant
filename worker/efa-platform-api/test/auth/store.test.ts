import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { describe, it } from "node:test";
import {
    getSessionByRefreshHash,
    insertSession,
    insertUser,
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

        // A concurrent request that read the session before the claim loses
        // the race: its claim matches zero rows and its successor is dropped.
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
