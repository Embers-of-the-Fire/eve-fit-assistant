import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";
import { describe, it } from "node:test";
import worker from "../src/index.ts";

const MOUNT = "/platform/storage/data-sync";
const TOKEN = "test-token";

interface D1ResultLike {
    results: unknown[];
    success: boolean;
    meta: { changes: number };
}

type SqlParam = string | number | Uint8Array | null;

function toSqlParam(value: unknown): SqlParam {
    if (value instanceof ArrayBuffer) {
        return new Uint8Array(value);
    }
    return value as SqlParam;
}

class TestStatement {
    private readonly db: DatabaseSync;
    readonly sql: string;
    private readonly params: unknown[];

    constructor(db: DatabaseSync, sql: string, params: unknown[] = []) {
        this.db = db;
        this.sql = sql;
        this.params = params;
    }

    bind(...params: unknown[]): TestStatement {
        return new TestStatement(this.db, this.sql, params);
    }

    private boundParams(): SqlParam[] {
        return this.params.map(toSqlParam);
    }

    async first<T>(): Promise<T | null> {
        const row = this.db.prepare(this.sql).get(...this.boundParams());
        return (row as T | undefined) ?? null;
    }

    async all<T>(): Promise<D1ResultLike & { results: T[] }> {
        const rows = this.db.prepare(this.sql).all(...this.boundParams());
        return { results: rows as T[], success: true, meta: { changes: 0 } };
    }

    async run(): Promise<D1ResultLike> {
        const info = this.db.prepare(this.sql).run(...this.boundParams());
        return { results: [], success: true, meta: { changes: Number(info.changes) } };
    }

    executeForBatch(): Promise<D1ResultLike> {
        return /^\s*select/i.test(this.sql) ? this.all() : this.run();
    }
}

class TestD1Database {
    private readonly db: DatabaseSync;

    constructor(db: DatabaseSync) {
        this.db = db;
    }

    prepare(sql: string): TestStatement {
        return new TestStatement(this.db, sql);
    }

    async batch(statements: TestStatement[]): Promise<D1ResultLike[]> {
        this.db.exec("BEGIN");
        try {
            const results: D1ResultLike[] = [];
            for (const statement of statements) {
                results.push(await statement.executeForBatch());
            }
            this.db.exec("COMMIT");
            return results;
        } catch (error) {
            this.db.exec("ROLLBACK");
            throw error;
        }
    }
}

interface TestContext {
    db: DatabaseSync;
    post: (path: string, body: unknown) => Promise<Response>;
    get: (path: string) => Promise<Response>;
}

function setup(): TestContext {
    const db = new DatabaseSync(":memory:");
    db.exec(readFileSync(new URL("../migrations/0001_init.sql", import.meta.url), "utf8"));
    const env = { PLATFORM_DB: new TestD1Database(db) as unknown as D1Database, SYNC_TOKEN: TOKEN };
    return {
        db,
        post: (path, body) =>
            worker.fetch(
                new Request(`https://example.com${MOUNT}${path}`, {
                    method: "POST",
                    headers: {
                        "content-type": "application/json",
                        authorization: `Bearer ${TOKEN}`,
                    },
                    body: JSON.stringify(body),
                }),
                env,
            ),
        get: (path) => worker.fetch(new Request(`https://example.com${MOUNT}${path}`), env),
    };
}

async function sha256Hex(data: Uint8Array): Promise<string> {
    const digest = await crypto.subtle.digest("SHA-256", data.buffer as ArrayBuffer);
    return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function toBase64(data: Uint8Array): string {
    return btoa(String.fromCharCode(...data));
}

describe("snapshot freeze", () => {
    it("rejects /register after /complete and keeps the registration set frozen", async () => {
        const { db, post, get } = setup();
        const serverId = "tranquility";
        const snapshotHash = "ab".repeat(32);

        const content = new TextEncoder().encode("type-entry-1");
        const contentHash = await sha256Hex(content);

        let res = await post("/content", {
            entries: [
                { family: "types", content_hash: contentHash, content_b64: toBase64(content) },
            ],
        });
        assert.equal(res.status, 200);

        res = await post("/register", {
            server_id: serverId,
            snapshot_hash: snapshotHash,
            entries: [{ family: "types", entry_id: 1, content_hash: contentHash }],
        });
        assert.equal(res.status, 200);
        assert.deepEqual(await res.json(), { ok: true, inserted: 1 });

        res = await post("/complete", {
            server_id: serverId,
            snapshot_hash: snapshotHash,
            entry_count: 1,
        });
        assert.equal(res.status, 200);

        res = await post("/register", {
            server_id: serverId,
            snapshot_hash: snapshotHash,
            entries: [{ family: "types", entry_id: 2, content_hash: contentHash }],
        });
        assert.equal(res.status, 409);
        const conflict = (await res.json()) as { ok: boolean; error: string };
        assert.equal(conflict.ok, false);
        assert.equal(conflict.error, "Snapshot already complete");

        const regCount = db
            .prepare(
                "SELECT COUNT(*) AS n FROM types_reg WHERE server_id = ? AND snapshot_hash = ?",
            )
            .get(serverId, snapshotHash) as { n: number };
        assert.equal(regCount.n, 1);

        res = await get(`/snapshot?server_id=${serverId}&snapshot_hash=${snapshotHash}`);
        assert.equal(res.status, 200);
        const snapshot = (await res.json()) as {
            ok: boolean;
            complete: boolean;
            entry_count: number;
        };
        assert.equal(snapshot.complete, true);
        assert.equal(snapshot.entry_count, 1);
    });
});

describe("entry_id validation", () => {
    it("accepts negative entry IDs used by engine-internal pseudo entries", async () => {
        const { post } = setup();
        const serverId = "tranquility";
        const snapshotHash = "cd".repeat(32);

        const content = new TextEncoder().encode("pseudo-effect");
        const contentHash = await sha256Hex(content);

        let res = await post("/content", {
            entries: [
                { family: "dogma_effects", content_hash: contentHash, content_b64: toBase64(content) },
            ],
        });
        assert.equal(res.status, 200);

        res = await post("/register", {
            server_id: serverId,
            snapshot_hash: snapshotHash,
            entries: [{ family: "dogma_effects", entry_id: -64, content_hash: contentHash }],
        });
        assert.equal(res.status, 200);
        assert.deepEqual(await res.json(), { ok: true, inserted: 1 });
    });

    it("rejects entry IDs outside the int32 range", async () => {
        const { post } = setup();
        const snapshotHash = "ef".repeat(32);
        const contentHash = "ab".repeat(32);

        for (const entryId of [-2147483649, 2147483648]) {
            const res = await post("/register", {
                server_id: "tranquility",
                snapshot_hash: snapshotHash,
                entries: [{ family: "types", entry_id: entryId, content_hash: contentHash }],
            });
            assert.equal(res.status, 400);
        }
    });
});
