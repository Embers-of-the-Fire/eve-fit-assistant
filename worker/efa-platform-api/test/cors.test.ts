// CORS wiring tests: the public mount stays open to every origin while the
// auth mount answers only the platform's own web origins. The root
// composition is exercised through createRootApp with dummy sub-apps so no
// bindings are needed.

import { Hono } from "hono";
import { describe, expect, it } from "vitest";
import { AUTH_MOUNT_PATH, createRootApp, MOUNT_PATH } from "../src/root.ts";

const ORIGIN = "https://api.efa-tech.dev";
const TRUSTED_ORIGIN = "https://platform.efa-tech.dev";
const UNTRUSTED_ORIGIN = "https://attacker.example";

function makeRoot(): Hono {
    const publicApp = new Hono();
    publicApp.get("/health", (c) => c.json({ ok: true }));
    const authApp = new Hono();
    authApp.post("/login", (c) => c.json({ ok: true }));
    return createRootApp(publicApp, authApp);
}

function preflight(path: string, origin: string): Request {
    return new Request(`${ORIGIN}${path}`, {
        method: "OPTIONS",
        headers: {
            Origin: origin,
            "Access-Control-Request-Method": "POST",
            "Access-Control-Request-Headers": "content-type",
        },
    });
}

describe("auth mount CORS", () => {
    it("reflects trusted origins on actual requests", async () => {
        const res = await makeRoot().fetch(
            new Request(`${ORIGIN}${AUTH_MOUNT_PATH}/login`, {
                method: "POST",
                headers: { Origin: TRUSTED_ORIGIN, "Content-Type": "application/json" },
                body: "{}",
            }),
        );
        expect(res.status).toBe(200);
        expect(res.headers.get("Access-Control-Allow-Origin")).toBe(TRUSTED_ORIGIN);
        expect(res.headers.get("Vary")).toContain("Origin");
    });

    it("omits Allow-Origin for untrusted origins on actual requests", async () => {
        const res = await makeRoot().fetch(
            new Request(`${ORIGIN}${AUTH_MOUNT_PATH}/login`, {
                method: "POST",
                headers: { Origin: UNTRUSTED_ORIGIN, "Content-Type": "application/json" },
                body: "{}",
            }),
        );
        expect(res.status).toBe(200);
        expect(res.headers.get("Access-Control-Allow-Origin")).toBe(null);
    });

    it("answers preflights only for trusted origins", async () => {
        const trusted = await makeRoot().fetch(
            preflight(`${AUTH_MOUNT_PATH}/login`, TRUSTED_ORIGIN),
        );
        expect(trusted.status).toBe(204);
        expect(trusted.headers.get("Access-Control-Allow-Origin")).toBe(TRUSTED_ORIGIN);
        expect(trusted.headers.get("Access-Control-Allow-Methods")).toContain("POST");

        const untrusted = await makeRoot().fetch(
            preflight(`${AUTH_MOUNT_PATH}/login`, UNTRUSTED_ORIGIN),
        );
        expect(untrusted.status).toBe(204);
        expect(untrusted.headers.get("Access-Control-Allow-Origin")).toBe(null);
    });

    it("does not let the public wildcard leak onto the auth mount", async () => {
        const res = await makeRoot().fetch(
            new Request(`${ORIGIN}${AUTH_MOUNT_PATH}/login`, {
                method: "POST",
                headers: { Origin: TRUSTED_ORIGIN, "Content-Type": "application/json" },
                body: "{}",
            }),
        );
        expect(res.headers.get("Access-Control-Allow-Origin")).not.toBe("*");
    });
});

describe("public mount CORS", () => {
    it("stays open to every origin on actual requests", async () => {
        const res = await makeRoot().fetch(
            new Request(`${ORIGIN}${MOUNT_PATH}/health`, {
                headers: { Origin: UNTRUSTED_ORIGIN },
            }),
        );
        expect(res.status).toBe(200);
        expect(res.headers.get("Access-Control-Allow-Origin")).toBe("*");
    });

    it("stays open to every origin on preflights", async () => {
        const res = await makeRoot().fetch(preflight(`${MOUNT_PATH}/posts`, UNTRUSTED_ORIGIN));
        expect(res.status).toBe(204);
        expect(res.headers.get("Access-Control-Allow-Origin")).toBe("*");
    });
});
