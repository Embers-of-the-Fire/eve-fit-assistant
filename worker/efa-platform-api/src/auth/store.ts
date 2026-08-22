// D1 access for the auth tables. Timestamps are ISO-8601 UTC strings in the
// strftime('%Y-%m-%dT%H:%M:%fZ') shape; lexicographic comparison over them is
// chronological.

export type UserStatus = "pending" | "active" | "deregistered";

export interface UserRow {
    user_id: string;
    email: string;
    password_hash: string;
    status: UserStatus;
    token_version: number;
    created_at: string;
    updated_at: string;
}

export interface SessionRow {
    session_id: string;
    user_id: string;
    refresh_hash: string;
    created_at: string;
    expires_at: string;
    revoked_at: string | null;
    replaced_by: string | null;
    rotation_grace_until: string | null;
    user_agent: string | null;
    ip: string | null;
}

const TOUCH = "updated_at = strftime('%Y-%m-%dT%H:%M:%fZ','now')";

export async function getUserByEmail(db: D1Database, email: string): Promise<UserRow | null> {
    return db.prepare("SELECT * FROM users WHERE email = ?").bind(email).first<UserRow>();
}

export async function getUserById(db: D1Database, userId: string): Promise<UserRow | null> {
    return db.prepare("SELECT * FROM users WHERE user_id = ?").bind(userId).first<UserRow>();
}

export async function insertUser(
    db: D1Database,
    userId: string,
    email: string,
    passwordHash: string,
): Promise<void> {
    await db
        .prepare(
            "INSERT INTO users (user_id, email, password_hash, status) VALUES (?, ?, ?, 'pending')",
        )
        .bind(userId, email, passwordHash)
        .run();
}

export async function activateUser(db: D1Database, userId: string): Promise<void> {
    await db
        .prepare(`UPDATE users SET status = 'active', ${TOUCH} WHERE user_id = ?`)
        .bind(userId)
        .run();
}

export async function updateUserPassword(
    db: D1Database,
    userId: string,
    passwordHash: string,
): Promise<void> {
    await db
        .prepare(
            `UPDATE users SET password_hash = ?, token_version = token_version + 1, ${TOUCH} ` +
                "WHERE user_id = ?",
        )
        .bind(passwordHash, userId)
        .run();
}

// Anonymize the account in one atomic batch: tombstone the email so the
// address is free for re-signup, blank the hash, and bump token_version so
// outstanding access tokens fail their version check; revoke all sessions
// and clear their retained PII (user_agent, ip). The user row stays for
// referential integrity.
export async function deregisterUser(db: D1Database, userId: string): Promise<void> {
    await db.batch([
        db
            .prepare(
                "UPDATE users SET email = ?, password_hash = '', status = 'deregistered', " +
                    `token_version = token_version + 1, ${TOUCH} WHERE user_id = ?`,
            )
            .bind(`deleted-${userId}@deregistered.invalid`, userId),
        db
            .prepare(
                "UPDATE auth_sessions SET " +
                    "revoked_at = COALESCE(revoked_at, strftime('%Y-%m-%dT%H:%M:%fZ','now')), " +
                    "user_agent = NULL, ip = NULL WHERE user_id = ?",
            )
            .bind(userId),
    ]);
}

export async function insertSession(
    db: D1Database,
    session: {
        sessionId: string;
        userId: string;
        refreshHash: string;
        expiresAt: string;
        userAgent: string | null;
        ip: string | null;
    },
): Promise<void> {
    await db
        .prepare(
            "INSERT INTO auth_sessions (session_id, user_id, refresh_hash, expires_at, user_agent, ip) " +
                "VALUES (?, ?, ?, ?, ?, ?)",
        )
        .bind(
            session.sessionId,
            session.userId,
            session.refreshHash,
            session.expiresAt,
            session.userAgent,
            session.ip,
        )
        .run();
}

export async function getSessionByRefreshHash(
    db: D1Database,
    refreshHash: string,
): Promise<SessionRow | null> {
    return db
        .prepare("SELECT * FROM auth_sessions WHERE refresh_hash = ?")
        .bind(refreshHash)
        .first<SessionRow>();
}

// Claim `sessionId` for rotation and insert its successor in one atomic D1
// batch (D1 batches execute as a single SQL transaction with statements
// applied sequentially, so the guarded insert observes this batch's claim).
// The claim is conditional (`replaced_by IS NULL`) and the successor insert
// only applies for the request that won the claim, so concurrent rotations of
// the same token cannot create orphan or competing successor sessions.
// Returns true only when the guarded successor insert applied — the caller
// claimed the rotation, the successor row exists, and the caller may issue
// the successor's refresh token. False when the claim lost or the guarded
// insert was skipped; in both cases there is no successor row to issue a
// token for.
export async function rotateSession(
    db: D1Database,
    sessionId: string,
    successor: {
        sessionId: string;
        userId: string;
        refreshHash: string;
        expiresAt: string;
        userAgent: string | null;
        ip: string | null;
    },
    graceUntil: string,
): Promise<boolean> {
    const [, insert] = await db.batch([
        db
            .prepare(
                "UPDATE auth_sessions SET replaced_by = ?, rotation_grace_until = ? " +
                    "WHERE session_id = ? AND replaced_by IS NULL",
            )
            .bind(successor.sessionId, graceUntil, sessionId),
        db
            .prepare(
                "INSERT INTO auth_sessions " +
                    "(session_id, user_id, refresh_hash, expires_at, user_agent, ip) " +
                    "SELECT ?, ?, ?, ?, ?, ? WHERE EXISTS (" +
                    "SELECT 1 FROM auth_sessions WHERE session_id = ? AND replaced_by = ?)",
            )
            .bind(
                successor.sessionId,
                successor.userId,
                successor.refreshHash,
                successor.expiresAt,
                successor.userAgent,
                successor.ip,
                sessionId,
                successor.sessionId,
            ),
    ]);
    return insert.meta.changes === 1;
}

export async function revokeSession(db: D1Database, sessionId: string): Promise<void> {
    await db
        .prepare(
            "UPDATE auth_sessions SET revoked_at = strftime('%Y-%m-%dT%H:%M:%fZ','now') " +
                "WHERE session_id = ? AND revoked_at IS NULL",
        )
        .bind(sessionId)
        .run();
}

export async function revokeAllUserSessions(db: D1Database, userId: string): Promise<void> {
    await db
        .prepare(
            "UPDATE auth_sessions SET revoked_at = strftime('%Y-%m-%dT%H:%M:%fZ','now') " +
                "WHERE user_id = ? AND revoked_at IS NULL",
        )
        .bind(userId)
        .run();
}

// Refresh-token reuse response: revoke the user's whole session chain and
// bump token_version so access tokens the attacker may already hold fail
// their version check. Both statements run in one atomic batch so a partial
// failure cannot leave the account half-invalidated.
export async function invalidateUserTokens(db: D1Database, userId: string): Promise<void> {
    await db.batch([
        db
            .prepare(
                "UPDATE auth_sessions SET revoked_at = strftime('%Y-%m-%dT%H:%M:%fZ','now') " +
                    "WHERE user_id = ? AND revoked_at IS NULL",
            )
            .bind(userId),
        db
            .prepare(
                `UPDATE users SET token_version = token_version + 1, ${TOUCH} WHERE user_id = ?`,
            )
            .bind(userId),
    ]);
}
