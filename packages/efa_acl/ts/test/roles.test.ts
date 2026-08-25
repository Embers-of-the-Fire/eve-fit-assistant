import { describe, expect, it } from "vitest";

import {
    aclDefaultRoles,
    aclForRoles,
    aclRoles,
    isAclRole,
    tokensForRoles,
} from "../src/index";

describe("roles", () => {
    it("grants fresh accounts the default user role", () => {
        expect(aclDefaultRoles).toEqual(["user"]);
        expect(tokensForRoles(aclDefaultRoles)).toEqual(["post:create", "post:delete:own"]);
    });

    it("resolves roles to the union of their tokens in declaration order", () => {
        expect(tokensForRoles(["moderator"])).toEqual([
            "post:create",
            "post:delete:own",
            "post:delete:all",
        ]);
        expect(tokensForRoles(["user", "admin"])).toEqual([
            "post:create",
            "post:delete:own",
            "post:delete:all",
            "admin:manage_roles",
        ]);
    });

    it("ignores unknown role names", () => {
        expect(tokensForRoles(["superuser"])).toEqual([]);
        expect(tokensForRoles(["superuser", "user"])).toEqual(["post:create", "post:delete:own"]);
    });

    it("guards role names", () => {
        for (const role of aclRoles) {
            expect(isAclRole(role)).toBe(true);
        }
        expect(isAclRole("superuser")).toBe(false);
    });

    it("builds a queryable token set", () => {
        const acl = aclForRoles(["admin"]);
        expect(acl.can("post:create")).toBe(true);
        expect(acl.can("post:delete")).toEqual(["all"]);
        expect(acl.can("admin:manage_roles")).toBe(true);
        expect(aclForRoles(["user"]).can("admin:manage_roles")).toBe(false);
    });
});
