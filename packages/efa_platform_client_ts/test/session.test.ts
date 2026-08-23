import { afterEach, describe, expect, it, vi } from "vitest";
import type { FetchLike } from "../src/lib/client";
import { AccountApiError, PlatformAuthRequiredError } from "../src/lib/errors";
import { PlatformSession } from "../src/lib/session";
import type { PlatformSessionStore } from "../src/lib/store";
import type { StoredPlatformSession } from "../src/lib/types";
import { fakeJwt } from "./helpers";

const ORIGIN = "https://api.example.test";

class MemoryStore implements PlatformSessionStore {
    value: StoredPlatformSession | null = null;
    read(): Promise<StoredPlatformSession | null> {
        return Promise.resolve(this.value);
    }
    write(session: StoredPlatformSession): Promise<void> {
        this.value = session;
        return Promise.resolve();
    }
    clear(): Promise<void> {
        this.value = null;
        return Promise.resolve();
    }
}

function storedSession(overrides: Partial<StoredPlatformSession> = {}): StoredPlatformSession {
    return {
        accessToken: fakeJwt("user-1"),
        refreshToken: "refresh-1",
        expiresAtMs: Date.now() + 600_000,
        email: "capsuleer@example.com",
        userId: "user-1",
        ...overrides,
    };
}

function tokenPairBody(userId = "user-1", refreshToken = "refresh-2") {
    return { accessToken: fakeJwt(userId), refreshToken, expiresIn: 900 };
}

function ok(body: unknown, status = 200) {
    return new Response(JSON.stringify(body), {
        status,
        headers: { "Content-Type": "application/json" },
    });
}

function authError(status: number, code: string) {
    return new Response(JSON.stringify({ error: code, message: code }), {
        status,
        headers: { "Content-Type": "application/json" },
    });
}

/** A fetch mock returning a fresh Response per call (Response bodies are single-use). */
function fetchReturning(body: () => Response) {
    return vi.fn().mockImplementation(() => Promise.resolve(body()));
}

function makeSession(
    store: MemoryStore,
    fetchFn: ReturnType<typeof vi.fn>,
    onAuthRequired?: () => void,
) {
    return new PlatformSession({
        origin: ORIGIN,
        store,
        fetchFn: fetchFn as unknown as FetchLike,
        onAuthRequired,
    });
}

afterEach(() => {
    vi.unstubAllGlobals();
});

describe("PlatformSession cold start", () => {
    it("reads as signed out with an empty store", async () => {
        const fetchFn = vi.fn();
        const session = makeSession(new MemoryStore(), fetchFn);
        await session.ready;
        expect(session.me).toBeNull();
        expect(fetchFn).not.toHaveBeenCalled();
    });

    it("rotates the stored session once and keeps the identity", async () => {
        const store = new MemoryStore();
        store.value = storedSession();
        const fetchFn = fetchReturning(() => ok(tokenPairBody()));
        const session = makeSession(store, fetchFn);
        await session.ready;

        expect(fetchFn).toHaveBeenCalledTimes(1);
        expect(store.value?.refreshToken).toBe("refresh-2");
        expect(session.me).toEqual({ userId: "user-1", email: "capsuleer@example.com" });
    });

    it("clears a session whose refresh token the server rejects, without firing onAuthRequired", async () => {
        const store = new MemoryStore();
        store.value = storedSession();
        const fetchFn = fetchReturning(() => authError(401, "invalid_token"));
        const onAuthRequired = vi.fn();
        const session = makeSession(store, fetchFn, onAuthRequired);
        await session.ready;

        expect(store.value).toBeNull();
        expect(session.me).toBeNull();
        expect(onAuthRequired).not.toHaveBeenCalled();
    });

    it("keeps the session when the cold-start refresh is offline", async () => {
        const store = new MemoryStore();
        store.value = storedSession();
        const fetchFn = vi.fn().mockImplementation(() => Promise.reject(new TypeError("offline")));
        const session = makeSession(store, fetchFn);
        await session.ready;

        expect(store.value?.refreshToken).toBe("refresh-1");
        expect(session.me?.userId).toBe("user-1");
    });

    it("keeps the stored session when the rotated pair identifies another account", async () => {
        const store = new MemoryStore();
        store.value = storedSession();
        const fetchFn = fetchReturning(() => ok(tokenPairBody("user-other")));
        const session = makeSession(store, fetchFn);
        await session.ready;

        expect(store.value?.refreshToken).toBe("refresh-1");
        expect(session.me?.userId).toBe("user-1");
    });
});

describe("PlatformSession auth flows", () => {
    it("login stores the pair and publishes the identity", async () => {
        const store = new MemoryStore();
        const fetchFn = fetchReturning(() => ok(tokenPairBody()));
        const session = makeSession(store, fetchFn);
        await session.ready;

        const identities: unknown[] = [];
        const unsubscribe = session.subscribeIdentity((v) => identities.push(v));
        await session.login("capsuleer@example.com", "password123");

        expect(store.value?.refreshToken).toBe("refresh-2");
        expect(session.me).toEqual({ userId: "user-1", email: "capsuleer@example.com" });
        expect(identities).toEqual([null, { userId: "user-1", email: "capsuleer@example.com" }]);
        unsubscribe();
    });

    it("rejects a login pair whose access token has no subject", async () => {
        const store = new MemoryStore();
        const fetchFn = fetchReturning(() =>
            ok({ accessToken: fakeJwt(null), refreshToken: "r", expiresIn: 900 }),
        );
        const session = makeSession(store, fetchFn);
        await session.ready;

        const error = await session.login("a@b.c", "password123").catch((e: unknown) => e);
        expect(error).toBeInstanceOf(AccountApiError);
        expect((error as AccountApiError).code).toBe("invalid_token");
        expect(store.value).toBeNull();
    });

    it("forwards the email locale on signup and password reset", async () => {
        const store = new MemoryStore();
        const fetchFn = fetchReturning(() => ok({ ok: true }));
        const session = new PlatformSession({
            origin: ORIGIN,
            store,
            fetchFn: fetchFn as unknown as FetchLike,
            emailLocale: () => "zh",
        });
        await session.ready;

        await session.signup("a@b.c", "password123");
        await session.requestPasswordReset("a@b.c");
        const bodies = fetchFn.mock.calls.map((c) =>
            JSON.parse((c as [string, RequestInit])[1].body as string),
        );
        expect(bodies).toEqual([
            { email: "a@b.c", password: "password123", locale: "zh" },
            { email: "a@b.c", locale: "zh" },
        ]);
    });

    it("logout revokes server-side best-effort and clears locally", async () => {
        const store = new MemoryStore();
        store.value = storedSession();
        const fetchFn = vi
            .fn()
            .mockImplementationOnce(() => Promise.resolve(ok(tokenPairBody()))) // cold start
            .mockImplementationOnce(() => Promise.reject(new TypeError("offline"))); // logout fails
        const session = makeSession(store, fetchFn);
        await session.ready;

        await session.logout();

        expect(store.value).toBeNull();
        expect(session.me).toBeNull();
        expect(fetchFn.mock.calls.some((c) => String(c[0]).endsWith("/platform/auth/logout"))).toBe(
            true,
        );
    });

    it("deregister posts the password with a bearer token, then clears", async () => {
        const store = new MemoryStore();
        store.value = storedSession();
        const fetchFn = fetchReturning(() => ok(tokenPairBody()));
        const session = makeSession(store, fetchFn);
        await session.ready;

        await session.deregister("password123");
        const deregisterCall = fetchFn.mock.calls.find((c) =>
            String(c[0]).endsWith("/platform/auth/deregister"),
        ) as [string, RequestInit];
        expect(deregisterCall).toBeDefined();
        expect((deregisterCall[1].headers as Record<string, string>).Authorization).toMatch(
            /^Bearer /,
        );
        expect(JSON.parse(deregisterCall[1].body as string)).toEqual({ password: "password123" });
        expect(store.value).toBeNull();
    });
});

describe("PlatformSession.authedFetch", () => {
    it("attaches the stored access token when it is still valid", async () => {
        const store = new MemoryStore();
        store.value = storedSession();
        const fetchFn = fetchReturning(() => ok(tokenPairBody()));
        const session = makeSession(store, fetchFn);
        await session.ready;
        fetchFn.mockClear();

        fetchFn.mockImplementation(() => Promise.resolve(new Response("ok", { status: 200 })));
        const response = await session.authedFetch("https://api.example.test/platform/auth/x");
        expect(response.status).toBe(200);
        const headers = (fetchFn.mock.calls[0] as [string, RequestInit])[1].headers as Headers;
        expect(headers.get("Authorization")).toMatch(/^Bearer /);
    });

    it("refreshes an expired access token before the request", async () => {
        const store = new MemoryStore();
        store.value = storedSession({ expiresAtMs: Date.now() - 1000 });
        const fetchFn = vi
            .fn()
            // Cold start is offline, so the expired stored session stays in place.
            .mockImplementationOnce(() => Promise.reject(new TypeError("offline")))
            .mockImplementation(() => Promise.resolve(ok(tokenPairBody())));
        const session = makeSession(store, fetchFn);
        await session.ready;
        fetchFn.mockClear();

        await session.authedFetch("https://api.example.test/x");
        // One rotation plus the request itself, both through fetchFn.
        expect(fetchFn).toHaveBeenCalledTimes(2);
        expect(store.value?.refreshToken).toBe("refresh-2");
    });

    it("serializes concurrent rotations through the mutex", async () => {
        const store = new MemoryStore();
        store.value = storedSession({ expiresAtMs: Date.now() - 1000 });
        const fetchFn = vi
            .fn()
            .mockImplementationOnce(() => Promise.reject(new TypeError("offline")))
            .mockImplementation(() => Promise.resolve(ok(tokenPairBody())));
        const session = makeSession(store, fetchFn);
        await session.ready;
        fetchFn.mockClear();

        await Promise.all([
            session.authedFetch("https://api.example.test/a"),
            session.authedFetch("https://api.example.test/b"),
        ]);
        // The second caller reuses the pair rotated by the first: one
        // rotation plus the two requests, all through fetchFn.
        expect(fetchFn).toHaveBeenCalledTimes(3);
    });

    it("force-rotates once and retries when the server answers 401", async () => {
        const store = new MemoryStore();
        store.value = storedSession();
        const fetchFn = fetchReturning(() => ok(tokenPairBody()));
        const session = makeSession(store, fetchFn);
        await session.ready;
        fetchFn.mockClear();

        fetchFn
            .mockImplementationOnce(() => Promise.resolve(new Response("nope", { status: 401 })))
            .mockImplementationOnce(() => Promise.resolve(ok(tokenPairBody())))
            .mockImplementationOnce(() => Promise.resolve(new Response("ok", { status: 200 })));

        const response = await session.authedFetch("https://api.example.test/x");
        expect(response.status).toBe(200);
        // Rejected request, forced rotation, retried request.
        expect(fetchFn).toHaveBeenCalledTimes(3);
    });

    it("clears the session and fires onAuthRequired once when the rotation is rejected", async () => {
        const store = new MemoryStore();
        store.value = storedSession();
        // Cold-start refresh succeeds; later rotations are rejected.
        const fetchFn = vi
            .fn()
            .mockImplementationOnce(() => Promise.resolve(ok(tokenPairBody())))
            .mockImplementation(() => Promise.resolve(authError(401, "invalid_token")));
        const onAuthRequired = vi.fn();
        const session = makeSession(store, fetchFn, onAuthRequired);
        await session.ready;

        await expect(session.authedFetch("https://api.example.test/a")).rejects.toBeInstanceOf(
            PlatformAuthRequiredError,
        );
        await expect(session.authedFetch("https://api.example.test/b")).rejects.toBeInstanceOf(
            PlatformAuthRequiredError,
        );
        expect(store.value).toBeNull();
        expect(session.me).toBeNull();
        expect(onAuthRequired).toHaveBeenCalledTimes(1);
    });

    it("throws PlatformAuthRequiredError when signed out", async () => {
        const session = makeSession(new MemoryStore(), vi.fn());
        await session.ready;
        await expect(session.authedFetch("https://api.example.test/x")).rejects.toBeInstanceOf(
            PlatformAuthRequiredError,
        );
    });
});
