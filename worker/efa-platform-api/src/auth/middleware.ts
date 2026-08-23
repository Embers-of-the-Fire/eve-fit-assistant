// Access-token middleware for the auth sub-app: verifies the Bearer access
// JWT (signature plus iat/exp with clock skew, via the token codec in
// tokens.ts) and publishes the claims as a Hono context variable, so route
// handlers never verify tokens manually. Handlers read the claims back with
// getAuthClaims.

import type { Context, Env, MiddlewareHandler } from "hono";
import { type AccessTokenClaims, verifyAccessToken } from "./tokens.ts";

declare module "hono" {
    interface ContextVariableMap {
        // Verified access-token claims; set by requireAccessToken.
        authClaims?: AccessTokenClaims;
    }
}

// Error envelope identical to the auth sub-app's (see ENDPOINTS.md); kept
// local so this module does not depend on the router it serves.
function errorJson(status: 401 | 500, code: string, message: string): Response {
    return Response.json({ error: code, message }, { status });
}

export interface RequireAccessTokenOptions<E extends Env> {
    // Static secret, or a resolver reading it from the request bindings so
    // missing configuration is reported per request (500) like the inline
    // checks did.
    secret: string | ((c: Context<E>) => string | null | undefined);
    // Optional post-verification hook, e.g. a D1 token_version check.
    // Returning a Response short-circuits the request with it.
    validateClaims?: (c: Context<E>, claims: AccessTokenClaims) => Promise<Response | undefined>;
}

export function requireAccessToken<E extends Env>(
    options: RequireAccessTokenOptions<E>,
): MiddlewareHandler<E> {
    return async (c, next) => {
        const secret = typeof options.secret === "function" ? options.secret(c) : options.secret;
        if (!secret) {
            console.error("AUTH_TOKEN_SECRET is not set");
            return errorJson(500, "internal", "internal server error");
        }
        const header = c.req.header("Authorization") ?? "";
        const token = header.startsWith("Bearer ") ? header.slice("Bearer ".length) : null;
        const claims = token === null ? null : await verifyAccessToken(secret, token);
        if (!claims) {
            return errorJson(401, "invalid_token", "missing or invalid access token");
        }
        c.set("authClaims", claims);
        const rejection = await options.validateClaims?.(c, claims);
        if (rejection) {
            return rejection;
        }
        await next();
    };
}

// The verified claims of the current request. Only callable in handlers
// guarded by requireAccessToken.
export function getAuthClaims(c: Context): AccessTokenClaims {
    const claims = c.get("authClaims");
    if (!claims) {
        throw new Error("getAuthClaims called without requireAccessToken");
    }
    return claims;
}
