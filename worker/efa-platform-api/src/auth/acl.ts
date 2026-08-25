// ACL permission resolution for accounts. The account row's `acl_roles`
// column (JSON array of role names, see packages/efa_acl) is the source of
// truth; the resolved token set is mirrored into AUTH_KV so per-request
// permission reads stay off D1. Cached entries carry the roles JSON they
// were derived from, so a role change observed on a fresh row read
// self-heals the cache; explicit role writes go through setUserAclRoles,
// which busts the entry.

import { tokensForRoles } from "efa-acl-ts";

import { type UserRow, updateUserAclRoles } from "./store.ts";

// Resolved permissions change only with a role write, but the entry is kept
// short-lived so a missed invalidation (or a manual D1 edit) heals quickly.
export const ACL_CACHE_TTL_SEC = 300;

export interface UserAcl {
    roles: string[];
    permissions: string[];
}

interface AclCacheEntry {
    rolesJson: string;
    permissions: string[];
}

export interface AclEnv {
    FIT_DB: D1Database;
    AUTH_KV: KVNamespace;
}

function aclCacheKey(userId: string): string {
    return `acl:${userId}`;
}

// Tolerates malformed stored JSON: a broken row degrades to no roles (hence
// no permissions) instead of failing the request.
export function parseAclRoles(rolesJson: string): string[] {
    try {
        const parsed: unknown = JSON.parse(rolesJson);
        if (!Array.isArray(parsed)) {
            return [];
        }
        return parsed.filter((role): role is string => typeof role === "string");
    } catch {
        return [];
    }
}

/**
 * Resolves the account's roles into ACL tokens, serving from the AUTH_KV
 * cache when it still matches the roles JSON on the (already fetched) user
 * row and recomputing + re-caching otherwise.
 */
export async function getUserAcl(env: AclEnv, user: UserRow): Promise<UserAcl> {
    const cached = await env.AUTH_KV.get(aclCacheKey(user.user_id));
    if (cached !== null) {
        try {
            const entry = JSON.parse(cached) as Partial<AclCacheEntry>;
            if (entry.rolesJson === user.acl_roles && Array.isArray(entry.permissions)) {
                return {
                    roles: parseAclRoles(user.acl_roles),
                    permissions: entry.permissions as string[],
                };
            }
        } catch {
            // Fall through and recompute on a corrupt cache entry.
        }
    }
    const roles = parseAclRoles(user.acl_roles);
    const permissions = tokensForRoles(roles);
    const entry: AclCacheEntry = { rolesJson: user.acl_roles, permissions };
    // Best-effort: the cache must never fail the request.
    try {
        await env.AUTH_KV.put(aclCacheKey(user.user_id), JSON.stringify(entry), {
            expirationTtl: ACL_CACHE_TTL_SEC,
        });
    } catch (err) {
        console.error("acl cache write failed", err);
    }
    return { roles, permissions };
}

/** Writes the account's roles to D1 and busts the cached resolution. */
export async function setUserAclRoles(env: AclEnv, userId: string, roles: string[]): Promise<void> {
    await updateUserAclRoles(env.FIT_DB, userId, roles);
    try {
        await env.AUTH_KV.delete(aclCacheKey(userId));
    } catch (err) {
        // The roles JSON guard in getUserAcl heals the stale entry anyway.
        console.error("acl cache delete failed", err);
    }
}
