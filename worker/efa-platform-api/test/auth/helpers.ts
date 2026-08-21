// Shared test doubles: a KV shim with manual time control, a D1 shim over
// node:sqlite loading the real migration SQL, and in-memory Durable Object
// namespace doubles that run the real transactional core functions.

import { readFileSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";
import {
    type OtpEntry,
    type OtpVerifyResult,
    otpStateClear,
    otpStateHasCooldown,
    otpStateStore,
    otpStateVerify,
} from "../../src/auth/otp-core.ts";
import {
    type RateLimitOutcome,
    rateWindowHit,
    rateWindowRefund,
} from "../../src/auth/rate-core.ts";

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

    runSync(): number {
        const info = this.db.prepare(this.sql).run(...this.boundParams());
        return Number(info.changes);
    }

    run(): Promise<{ meta: { changes: number } }> {
        return Promise.resolve({ meta: { changes: this.runSync() } });
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

    // Mirrors D1's batch contract: the statements run sequentially inside a
    // single transaction that rolls back if any statement fails, and each
    // result reports its own change count.
    batch(statements: TestStatement[]): Promise<{ meta: { changes: number } }[]> {
        this.db.exec("BEGIN");
        try {
            const results = statements.map((stmt) => ({ meta: { changes: stmt.runSync() } }));
            this.db.exec("COMMIT");
            return Promise.resolve(results);
        } catch (error) {
            this.db.exec("ROLLBACK");
            throw error;
        }
    }
}

export function loadAuthDatabase(): DatabaseSync {
    const db = new DatabaseSync(":memory:");
    db.exec(readFileSync(new URL("../../migrations/0003_auth.sql", import.meta.url), "utf8"));
    return db;
}

// In-memory Durable Object storage. transaction() serializes closures per
// instance through a promise chain, mirroring the per-instance input-gate
// serialization of a real Durable Object (and unlike plain KV, where
// concurrent read-modify-write interleaves).
class TestDurableStorage {
    private readonly map = new Map<string, unknown>();
    private queue: Promise<unknown> = Promise.resolve();

    get<T>(key: string): Promise<T | undefined> {
        return Promise.resolve(this.map.get(key) as T | undefined);
    }

    put(key: string, value: unknown): Promise<void> {
        this.map.set(key, value);
        return Promise.resolve();
    }

    delete(key: string): Promise<boolean> {
        return Promise.resolve(this.map.delete(key));
    }

    transaction<T>(closure: (tx: TestDurableStorage) => Promise<T>): Promise<T> {
        const result = this.queue.then(() => closure(this));
        this.queue = result.catch(() => {});
        return result;
    }
}

// Double for the AUTH_OTP namespace. advance() shifts the time seen by
// subsequent queries (verify/hasCooldown), like TestKV.advance: timestamps
// written by store stay fixed at write time.
export class TestOtpStateNamespace {
    private readonly instances = new Map<string, TestDurableStorage>();
    private offsetMs = 0;

    advance(ms: number): void {
        this.offsetMs += ms;
    }

    idFromName(name: string): string {
        return name;
    }

    private instance(name: string): TestDurableStorage {
        let storage = this.instances.get(name);
        if (!storage) {
            storage = new TestDurableStorage();
            this.instances.set(name, storage);
        }
        return storage;
    }

    get(name: string) {
        const storage = this.instance(name);
        return {
            store: (entry: OtpEntry, cooldownUntilMs: number): Promise<void> =>
                storage.transaction((tx) => otpStateStore(tx, entry, cooldownUntilMs)),
            verify: (candidateHmac: string, nowMs: number): Promise<OtpVerifyResult> =>
                storage.transaction((tx) =>
                    otpStateVerify(tx, candidateHmac, nowMs + this.offsetMs),
                ),
            hasCooldown: (nowMs: number): Promise<boolean> =>
                storage.transaction((tx) => otpStateHasCooldown(tx, nowMs + this.offsetMs)),
            clear: (): Promise<void> => storage.transaction((tx) => otpStateClear(tx)),
        };
    }
}

// Double for the AUTH_RATE_LIMIT namespace; advance() shifts query time like
// TestOtpStateNamespace.
export class TestRateLimitNamespace {
    private readonly instances = new Map<string, TestDurableStorage>();
    private offsetMs = 0;

    advance(ms: number): void {
        this.offsetMs += ms;
    }

    idFromName(name: string): string {
        return name;
    }

    get(name: string) {
        let storage = this.instances.get(name);
        if (!storage) {
            storage = new TestDurableStorage();
            this.instances.set(name, storage);
        }
        return {
            hit: (limit: number, windowSec: number, nowMs: number): Promise<RateLimitOutcome> =>
                storage.transaction((tx) =>
                    rateWindowHit(tx, limit, windowSec, nowMs + this.offsetMs),
                ),
            refund: (windowSec: number, nowMs: number): Promise<void> =>
                storage.transaction((tx) => rateWindowRefund(tx, windowSec, nowMs + this.offsetMs)),
        };
    }
}
