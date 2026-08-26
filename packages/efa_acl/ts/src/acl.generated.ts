// GENERATED CODE - DO NOT EDIT BY HAND. Regenerate with `acl-codegen`.

import { Acl } from "acl-ts";

/**
 * Delete fit posts.
 *
 * - `own`: Delete posts published by the account itself.
 * - `all`: Delete any post on the platform.
 */
export type PostDeleteQualifier = "own" | "all";

/**
 * Delete comments.
 *
 * - `own`: Delete comments written by the account itself.
 * - `all`: Delete any comment on the platform.
 */
export type CommentDeleteQualifier = "own" | "all";

/** Publish fit posts to the platform. */
export type PostCreate = "post:create";

/** Delete fit posts. */
export type PostDelete = `post:delete:${PostDeleteQualifier}`;

/** Fit post management permission group. */
export type PostToken = PostCreate | PostDelete;

/** Post comments on fit post threads. */
export type CommentCreate = "comment:create";

/** Delete comments. */
export type CommentDelete = `comment:delete:${CommentDeleteQualifier}`;

/** Post discussion comment permission group. */
export type CommentToken = CommentCreate | CommentDelete;

/** Assign or revoke account permission roles. */
export type AdminManageRoles = "admin:manage_roles";

/** Platform administration permission group. */
export type AdminToken = AdminManageRoles;

/** All ACL tokens defined by this schema. */
export type AclToken = PostToken | CommentToken | AdminToken;

/** Maps every action key to its qualifier union (`never` when unqualified). */
export interface AclActionMap {
    "post:create": never;
    "post:delete": PostDeleteQualifier;
    "comment:create": never;
    "comment:delete": CommentDeleteQualifier;
    "admin:manage_roles": never;
}

/** Every token literal defined by this schema. */
export const aclTokens = [
    "post:create",
    "post:delete:own",
    "post:delete:all",
    "comment:create",
    "comment:delete:own",
    "comment:delete:all",
    "admin:manage_roles",
] as const;

/** Schema-level guard: whether `token` is defined by this schema. */
export function isAclToken(token: string): token is AclToken {
    return (aclTokens as readonly string[]).includes(token);
}

/** Creates a typed `Acl` token set for this schema. */
export function createAcl(tokens: Iterable<AclToken>): Acl<AclActionMap, AclToken> {
    return new Acl<AclActionMap, AclToken>(tokens);
}

/**
 * Roles defined by this schema.
 *
 * - `user`: Base role granted to every account.
 * - `moderator`: Can moderate posts published by any account.
 * - `admin`: Full platform administration.
 */
export type AclRole = "user" | "moderator" | "admin";

/** All roles in declaration order. */
export const aclRoles = [
    "user",
    "moderator",
    "admin",
] as const;

/** Roles granted to fresh accounts by default. */
export const aclDefaultRoles = [
    "user",
] as const;

/** Schema-level guard: whether `role` is defined by this schema. */
export function isAclRole(role: string): role is AclRole {
    return (aclRoles as readonly string[]).includes(role);
}

/** The ACL tokens each role grants. */
const roleTokens = {
    user: ["post:create", "post:delete:own", "comment:create", "comment:delete:own"],
    moderator: ["post:create", "post:delete:own", "post:delete:all", "comment:create", "comment:delete:own", "comment:delete:all"],
    admin: ["post:create", "post:delete:all", "comment:create", "comment:delete:all", "admin:manage_roles"],
} as const satisfies Record<AclRole, readonly AclToken[]>;

/**
 * Resolves role names into the union of their ACL tokens. Unknown role names
 * are ignored so a stale or mistyped stored role cannot crash a consumer.
 */
export function tokensForRoles(roles: Iterable<string>): AclToken[] {
    const tokens = new Set<AclToken>();
    for (const role of roles) {
        if (!isAclRole(role)) {
            continue;
        }
        for (const token of roleTokens[role]) {
            tokens.add(token);
        }
    }
    return [...tokens];
}

/** Builds a typed `Acl` token set from role names. */
export function aclForRoles(roles: Iterable<string>): Acl<AclActionMap, AclToken> {
    return createAcl(tokensForRoles(roles));
}
