// Shared test doubles: a KV shim with manual time control and a D1 shim over
// node:sqlite loading the real migration SQL.

import { readFileSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";

export class TestKV {
    private readonly store = new Map<string, { value: string; expiresAt: number }>();
    private nowMs = Date.now();

    advance(ms: number): void {
        this.nowMs += ms;
    }

    get(key: string): Promise<string | null> {
        const entry = this.store.get(key);
        if (!entry) {
            return Promise.resolve(null);
        }
        if (entry.expiresAt <= this.nowMs) {
            this.store.delete(key);
            return Promise.resolve(null);
        }
        return Promise.resolve(entry.value);
    }

    put(key: string, value: string, options?: { expirationTtl?: number }): Promise<void> {
        const ttlMs = (options?.expirationTtl ?? 24 * 60 * 60) * 1000;
        this.store.set(key, { value, expiresAt: this.nowMs + ttlMs });
        return Promise.resolve();
    }

    delete(key: string): Promise<void> {
        this.store.delete(key);
        return Promise.resolve();
    }
}

type SqlParam = string | number | Uint8Array | null;

export class TestStatement {
    private readonly db: DatabaseSync;
    private readonly sql: string;
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
        return this.params.map(
            (value) => (value instanceof ArrayBuffer ? new Uint8Array(value) : value) as SqlParam,
        );
    }

    first<T>(): Promise<T | null> {
        const row = this.db.prepare(this.sql).get(...this.boundParams());
        return Promise.resolve((row as T | undefined) ?? null);
    }

    all<T>(): Promise<{ results: T[] }> {
        const rows = this.db.prepare(this.sql).all(...this.boundParams());
        return Promise.resolve({ results: rows as T[] });
    }

    run(): Promise<{ meta: { changes: number } }> {
        const info = this.db.prepare(this.sql).run(...this.boundParams());
        return Promise.resolve({ meta: { changes: Number(info.changes) } });
    }
}

export class TestD1Database {
    private readonly db: DatabaseSync;

    constructor(db: DatabaseSync) {
        this.db = db;
    }

    prepare(sql: string): TestStatement {
        return new TestStatement(this.db, sql);
    }
}

export function loadAuthDatabase(): DatabaseSync {
    const db = new DatabaseSync(":memory:");
    db.exec(readFileSync(new URL("../../migrations/0003_auth.sql", import.meta.url), "utf8"));
    return db;
}
