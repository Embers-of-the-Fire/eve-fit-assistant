// ACL permission middleware: the action-level gate for routes already
// guarded by requireAccessToken + requireActiveAccount. Matching here is
// deliberately simple membership — unqualified actions ("post:create")
// require the exact token, and qualified actions ("post:delete") pass when
// ANY qualifier token is present; the handler then validates the qualifier
// against the resource (e.g. own vs. all) using getAuthPermissions.

import { type AclActionMap, createAcl, isAclToken } from "efa-acl-ts";
import type { Context, Env, MiddlewareHandler } from "hono";

import { type AclEnv, getUserAcl } from "./acl.ts";
import { getAuthUser } from "./middleware.ts";

declare module "hono" {
    interface ContextVariableMap {
        // Resolved ACL permission tokens; set by requirePermission.
        authPermissions?: string[];
    }
}

// Error envelope identical to the public app's; kept local so this module
// does not depend on the app it serves (same pattern as middleware.ts).
function errorJson(status: 403, code: string, message: string): Response {
    return Response.json({ error: code, message }, { status });
}

/**
 * Gates a route on an ACL action (`"{domain}:{action}"`). Requires the
 * authUser context variable, so it must run after requireAccessToken with
 * requireActiveAccount as its validateClaims. Resolved permissions are
 * published as the authPermissions context variable for the handler's
 * qualifier validation.
 */
export function requirePermission<E extends Env & { Bindings: AclEnv }>(
    action: string & keyof AclActionMap,
): MiddlewareHandler<E> {
    return async (c, next) => {
        const { permissions } = await getUserAcl(c.env, getAuthUser(c));
        c.set("authPermissions", permissions);
        // Schema guard drops tokens from a newer/older schema revision.
        const acl = createAcl(permissions.filter(isAclToken));
        if (acl.can(action) === false) {
            return errorJson(403, "forbidden", "permission denied");
        }
        await next();
    };
}

// The resolved permission tokens of the current request. Only callable
// downstream of requirePermission.
export function getAuthPermissions(c: Context): string[] {
    const permissions = c.get("authPermissions");
    if (!permissions) {
        throw new Error("getAuthPermissions called without requirePermission");
    }
    return permissions;
}
