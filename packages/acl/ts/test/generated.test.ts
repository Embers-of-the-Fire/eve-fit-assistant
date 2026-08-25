import { describe, expect, expectTypeOf, it } from "vitest";

import type { Acl } from "../src/index";
import {
    type AclActionMap,
    type AclToken,
    aclTokens,
    type CommentDeleteQualifier,
    createAcl,
    isAclToken,
    type PostDeleteQualifier,
} from "./fixtures/generated/acl.generated";

describe("generated bindings (example schema)", () => {
    it("lists every schema token", () => {
        expect(aclTokens).toEqual([
            "post:create",
            "post:delete:own",
            "post:delete:all",
            "comment:create",
            "comment:delete:own",
            "comment:delete:all",
        ]);
    });

    it("guards tokens against the schema", () => {
        expect(isAclToken("post:create")).toBe(true);
        expect(isAclToken("post:delete:own")).toBe(true);
        expect(isAclToken("post:delete:other")).toBe(false);
        expect(isAclToken("post:delete")).toBe(false);
        expect(isAclToken("unknown:create")).toBe(false);
    });

    it("types can() per action", () => {
        const acl = createAcl(["post:create", "post:delete:all"]);

        const create = acl.can("post:create");
        expectTypeOf(create).toEqualTypeOf<boolean>();
        expect(create).toBe(true);

        const del = acl.can("post:delete");
        expectTypeOf(del).toEqualTypeOf<PostDeleteQualifier[] | false>();
        expect(del).toEqual(["all"]);

        const missing = acl.can("comment:delete");
        expectTypeOf(missing).toEqualTypeOf<CommentDeleteQualifier[] | false>();
        expect(missing).toBe(false);
    });

    it("types has() per token", () => {
        const acl = createAcl(["post:create"]);
        expectTypeOf(acl.has).parameter(0).toEqualTypeOf<AclToken>();
        expect(acl.has("post:create")).toBe(true);
        expect(acl.has("comment:create")).toBe(false);
    });

    it("composes with the untyped runtime", () => {
        const acl: Acl<AclActionMap, AclToken> = createAcl(["comment:delete:own"]);
        expect(acl.can("comment:delete")).toEqual(["own"]);
        expect(acl.tokens).toEqual(new Set(["comment:delete:own"]));
    });
});
