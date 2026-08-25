// Root composition: mounts the public and auth sub-apps and owns the CORS
// policy. Kept free of cloudflare:workers imports so tests can exercise the
// wiring under plain Node.

import type { Env, Schema } from "hono";
import { Hono } from "hono";
import { cors } from "hono/cors";

export const MOUNT_PATH = "/platform/internal";
export const AUTH_MOUNT_PATH = "/platform/auth";

// Browser origins allowed to call the auth mount. The discussion site and
// the web app builds are the only browser clients; native app builds send no
// Origin header and are unaffected by the allowlist.
const AUTH_TRUSTED_ORIGINS = new Set([
    "https://platform.efa-tech.dev",
    "https://app.efa-tech.dev",
    "https://app-preview.efa-tech.dev",
    // The preview deployment of the discussion site calls the preview API
    // directly from the browser (build-time origin, see site/platform).
    "https://efa-platform-preview.stellarishs.workers.dev",
    // Local development: the `./x dev platform` multi-worker session serves
    // the site on :8787, a standalone `astro dev` uses :4321. Loopback
    // origins are not a production attack surface.
    "http://localhost:8787",
    "http://127.0.0.1:8787",
    "http://localhost:4321",
    "http://127.0.0.1:4321",
]);

// The sub-apps carry incompatible Bindings (the public app extends the auth
// env), so the composition is generic over each app's own env and schema.
export function createRootApp<
    PublicEnv extends Env,
    PublicSchema extends Schema,
    AuthEnv extends Env,
    AuthSchema extends Schema,
>(publicApp: Hono<PublicEnv, PublicSchema>, authApp: Hono<AuthEnv, AuthSchema>): Hono {
    const root = new Hono();

    // The public mount stays readable from any origin; the auth mount manages
    // its own CORS with a trusted-origin allowlist (below), so the wildcard
    // handlers must stay scoped away from it and never overwrite its headers.
    root.use(`${MOUNT_PATH}/*`, async (c, next) => {
        try {
            await next();
        } catch (err) {
            console.error("Unhandled error", err);
            c.res = Response.json(
                { error: "internal", message: "internal server error" },
                { status: 500 },
            );
        }
        c.res.headers.set("Access-Control-Allow-Origin", "*");
    });

    root.options(`${MOUNT_PATH}/*`, () => {
        return new Response(null, {
            status: 204,
            headers: {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "GET, POST, DELETE, OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type, Authorization",
            },
        });
    });

    // Auth endpoints answer token and email flows guarded by IP-based rate
    // limits; restricting browser access to the platform's own web origins
    // keeps arbitrary sites from relaying those flows through a visitor's IP.
    // Clients without an Origin header (the native app) are unaffected.
    // Preflights are answered by this middleware directly, so the catch-all
    // OPTIONS above never sees them.
    root.use(
        `${AUTH_MOUNT_PATH}/*`,
        cors({
            origin: (origin) => (AUTH_TRUSTED_ORIGINS.has(origin) ? origin : null),
            allowMethods: ["POST", "OPTIONS"],
            allowHeaders: ["Content-Type", "Authorization"],
        }),
    );

    root.route(MOUNT_PATH, publicApp);
    root.route(AUTH_MOUNT_PATH, authApp);
    return root;
}
