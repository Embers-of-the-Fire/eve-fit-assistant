// CORS wiring tests: the public mount stays open to every origin while the
// auth mount answers only the platform's own web origins. The root
// composition is exercised through createRootApp with dummy sub-apps so no
// cloudflare:workers runtime module is needed.

import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { Hono } from "hono";
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
        assert.equal(res.status, 200);
        assert.equal(res.headers.get("Access-Control-Allow-Origin"), TRUSTED_ORIGIN);
        assert.ok(res.headers.get("Vary")?.includes("Origin"));
    });

    it("omits Allow-Origin for untrusted origins on actual requests", async () => {
        const res = await makeRoot().fetch(
            new Request(`${ORIGIN}${AUTH_MOUNT_PATH}/login`, {
                method: "POST",
                headers: { Origin: UNTRUSTED_ORIGIN, "Content-Type": "application/json" },
                body: "{}",
            }),
        );
        assert.equal(res.status, 200);
        assert.equal(res.headers.get("Access-Control-Allow-Origin"), null);
    });

    it("answers preflights only for trusted origins", async () => {
        const trusted = await makeRoot().fetch(
            preflight(`${AUTH_MOUNT_PATH}/login`, TRUSTED_ORIGIN),
        );
        assert.equal(trusted.status, 204);
        assert.equal(trusted.headers.get("Access-Control-Allow-Origin"), TRUSTED_ORIGIN);
        assert.ok(trusted.headers.get("Access-Control-Allow-Methods")?.includes("POST"));

        const untrusted = await makeRoot().fetch(
            preflight(`${AUTH_MOUNT_PATH}/login`, UNTRUSTED_ORIGIN),
        );
        assert.equal(untrusted.status, 204);
        assert.equal(untrusted.headers.get("Access-Control-Allow-Origin"), null);
    });

    it("does not let the public wildcard leak onto the auth mount", async () => {
        const res = await makeRoot().fetch(
            new Request(`${ORIGIN}${AUTH_MOUNT_PATH}/login`, {
                method: "POST",
                headers: { Origin: TRUSTED_ORIGIN, "Content-Type": "application/json" },
                body: "{}",
            }),
        );
        assert.notEqual(res.headers.get("Access-Control-Allow-Origin"), "*");
    });
});

describe("public mount CORS", () => {
    it("stays open to every origin on actual requests", async () => {
        const res = await makeRoot().fetch(
            new Request(`${ORIGIN}${MOUNT_PATH}/health`, {
                headers: { Origin: UNTRUSTED_ORIGIN },
            }),
        );
        assert.equal(res.status, 200);
        assert.equal(res.headers.get("Access-Control-Allow-Origin"), "*");
    });

    it("stays open to every origin on preflights", async () => {
        const res = await makeRoot().fetch(preflight(`${MOUNT_PATH}/posts`, UNTRUSTED_ORIGIN));
        assert.equal(res.status, 204);
        assert.equal(res.headers.get("Access-Control-Allow-Origin"), "*");
    });
});
