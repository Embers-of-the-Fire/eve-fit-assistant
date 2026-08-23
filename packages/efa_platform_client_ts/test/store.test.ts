import { beforeEach, describe, expect, it } from "vitest";
import { LocalStorageSessionStore } from "../src/lib/store";
import type { StoredPlatformSession } from "../src/lib/types";

const sample: StoredPlatformSession = {
    accessToken: "access",
    refreshToken: "refresh",
    expiresAtMs: 1_700_000_000_000,
    email: "capsuleer@example.com",
    userId: "user-1",
};

class MemoryStorage {
    private readonly map = new Map<string, string>();
    getItem(key: string): string | null {
        return this.map.get(key) ?? null;
    }
    setItem(key: string, value: string): void {
        this.map.set(key, value);
    }
    removeItem(key: string): void {
        this.map.delete(key);
    }
}

describe("LocalStorageSessionStore", () => {
    beforeEach(() => {
        globalThis.localStorage = new MemoryStorage() as unknown as Storage;
    });

    it("round-trips a session", async () => {
        const store = new LocalStorageSessionStore();
        await store.write(sample);
        expect(await store.read()).toEqual(sample);
    });

    it("reads null when nothing is stored", async () => {
        expect(await new LocalStorageSessionStore().read()).toBeNull();
    });

    it("reads null for a corrupt blob", async () => {
        localStorage.setItem("efa-platform-account-session", "{not json");
        expect(await new LocalStorageSessionStore().read()).toBeNull();
    });

    it("reads null for a blob with missing fields", async () => {
        localStorage.setItem(
            "efa-platform-account-session",
            JSON.stringify({ accessToken: "a", refreshToken: "r" }),
        );
        expect(await new LocalStorageSessionStore().read()).toBeNull();
    });

    it("clear drops the record", async () => {
        const store = new LocalStorageSessionStore();
        await store.write(sample);
        await store.clear();
        expect(await store.read()).toBeNull();
    });
});
