import { describe, expect, it, vi } from "vitest";
import { AccountApiClient } from "../src/lib/client";
import { AccountApiError } from "../src/lib/errors";
import { fakeJwt } from "./helpers";

const ORIGIN = "https://api.example.test";

function jsonResponse(status: number, body: unknown, headers: Record<string, string> = {}) {
    return new Response(JSON.stringify(body), {
        status,
        headers: { "Content-Type": "application/json", ...headers },
    });
}

describe("AccountApiClient", () => {
    it("posts JSON to the auth mount and decodes the token pair", async () => {
        const fetchFn = vi.fn().mockImplementation(() =>
            Promise.resolve(
                jsonResponse(200, {
                    accessToken: fakeJwt("user-1"),
                    refreshToken: "refresh",
                    expiresIn: 900,
                }),
            ),
        );
        const client = new AccountApiClient(ORIGIN, fetchFn);
        const pair = await client.login("a@b.c", "password123");
        expect(pair.expiresIn).toBe(900);

        const [url, init] = fetchFn.mock.calls[0] as [string, RequestInit];
        expect(url).toBe(`${ORIGIN}/platform/auth/login`);
        expect(init.method).toBe("POST");
        expect(JSON.parse(init.body as string)).toEqual({
            email: "a@b.c",
            password: "password123",
        });
    });

    it("omits an absent locale from the body and forwards a present one", async () => {
        const fetchFn = vi
            .fn()
            .mockImplementation(() => Promise.resolve(jsonResponse(200, { ok: true })));
        const client = new AccountApiClient(ORIGIN, fetchFn);

        await client.signup("a@b.c", "password123");
        expect(
            JSON.parse((fetchFn.mock.calls[0] as [string, RequestInit])[1].body as string),
        ).toEqual({
            email: "a@b.c",
            password: "password123",
        });

        await client.resetPassword("a@b.c", "zh");
        expect(
            JSON.parse((fetchFn.mock.calls[1] as [string, RequestInit])[1].body as string),
        ).toEqual({
            email: "a@b.c",
            locale: "zh",
        });
    });

    it("maps the error envelope and Retry-After header", async () => {
        const fetchFn = vi
            .fn()
            .mockImplementation(() =>
                Promise.resolve(
                    jsonResponse(
                        429,
                        { error: "rate_limited", message: "slow down" },
                        { "Retry-After": "42" },
                    ),
                ),
            );
        const client = new AccountApiClient(ORIGIN, fetchFn);
        const error = await client.login("a@b.c", "password123").catch((e: unknown) => e);
        expect(error).toBeInstanceOf(AccountApiError);
        const apiError = error as AccountApiError;
        expect(apiError.statusCode).toBe(429);
        expect(apiError.code).toBe("rate_limited");
        expect(apiError.retryAfterSec).toBe(42);
        expect(apiError.isInvalidToken).toBe(false);
        expect(apiError.transportFailure).toBe(false);
    });

    it("flags invalid_token and email_unverified", async () => {
        const fetchFn = vi
            .fn()
            .mockImplementationOnce(() =>
                Promise.resolve(jsonResponse(401, { error: "invalid_token" })),
            )
            .mockImplementationOnce(() =>
                Promise.resolve(jsonResponse(403, { error: "email_unverified" })),
            );
        const client = new AccountApiClient(ORIGIN, fetchFn);

        const invalid = (await client.refresh("dead").catch((e: unknown) => e)) as AccountApiError;
        expect(invalid.isInvalidToken).toBe(true);

        const unverified = (await client
            .login("a@b.c", "password123")
            .catch((e: unknown) => e)) as AccountApiError;
        expect(unverified.isEmailUnverified).toBe(true);
        expect(unverified.isInvalidToken).toBe(false);
    });

    it("maps network failures to a status-less transport error", async () => {
        const fetchFn = vi.fn().mockRejectedValue(new TypeError("fetch failed"));
        const client = new AccountApiClient(ORIGIN, fetchFn);
        const error = (await client
            .login("a@b.c", "password123")
            .catch((e: unknown) => e)) as AccountApiError;
        expect(error).toBeInstanceOf(AccountApiError);
        expect(error.statusCode).toBeNull();
        expect(error.code).toBeNull();
        expect(error.transportFailure).toBe(true);
    });

    it("sends the bearer token for deregister", async () => {
        const fetchFn = vi
            .fn()
            .mockImplementation(() => Promise.resolve(jsonResponse(200, { ok: true })));
        const client = new AccountApiClient(ORIGIN, fetchFn);
        await client.deregister("the-access-token", "password123");
        const [, init] = fetchFn.mock.calls[0] as [string, RequestInit];
        expect((init.headers as Record<string, string>).Authorization).toBe(
            "Bearer the-access-token",
        );
    });

    it("sends the bearer token for account and decodes the account info", async () => {
        const fetchFn = vi.fn().mockImplementation(() =>
            Promise.resolve(
                jsonResponse(200, {
                    userId: "u-1",
                    email: "a@b.c",
                    roles: ["user"],
                    permissions: ["post:create", "post:delete:own"],
                }),
            ),
        );
        const client = new AccountApiClient(ORIGIN, fetchFn);
        const info = await client.account("the-access-token");
        const [url, init] = fetchFn.mock.calls[0] as [string, RequestInit];
        expect(url).toBe(`${ORIGIN}/platform/auth/account`);
        expect((init.headers as Record<string, string>).Authorization).toBe(
            "Bearer the-access-token",
        );
        expect(info).toEqual({
            userId: "u-1",
            email: "a@b.c",
            roles: ["user"],
            permissions: ["post:create", "post:delete:own"],
        });
    });

    it("rejects a malformed account info body as a local parsing failure", async () => {
        const fetchFn = vi
            .fn()
            .mockImplementation(() => Promise.resolve(jsonResponse(200, { userId: 1 })));
        const client = new AccountApiClient(ORIGIN, fetchFn);
        const error = (await client
            .account("the-access-token")
            .catch((e: unknown) => e)) as AccountApiError;
        expect(error).toBeInstanceOf(AccountApiError);
        expect(error.statusCode).toBeNull();
        expect(error.transportFailure).toBe(false);
    });

    it("rejects a malformed token pair body as a local parsing failure", async () => {
        const fetchFn = vi
            .fn()
            .mockImplementation(() => Promise.resolve(jsonResponse(200, { accessToken: 1 })));
        const client = new AccountApiClient(ORIGIN, fetchFn);
        const error = (await client
            .login("a@b.c", "password123")
            .catch((e: unknown) => e)) as AccountApiError;
        expect(error).toBeInstanceOf(AccountApiError);
        expect(error.statusCode).toBeNull();
        expect(error.transportFailure).toBe(false);
    });
});
