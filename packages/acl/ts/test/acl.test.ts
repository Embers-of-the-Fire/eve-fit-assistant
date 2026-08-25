import { describe, expect, it } from "vitest";

import { Acl } from "../src/index";

describe("Acl (untyped)", () => {
    it("reports exact token membership", () => {
        const acl = new Acl(["post:create", "post:delete:all"]);
        expect(acl.has("post:create")).toBe(true);
        expect(acl.has("post:delete:all")).toBe(true);
        expect(acl.has("post:delete:own")).toBe(false);
        expect(acl.has("post:delete")).toBe(false);
        expect(acl.has("comment:create")).toBe(false);
    });

    it("exposes the raw token set", () => {
        const acl = new Acl(["post:create"]);
        expect(acl.tokens).toEqual(new Set(["post:create"]));
    });

    it("returns true for a granted unqualified action", () => {
        expect(new Acl(["post:create"]).can("post:create")).toBe(true);
    });

    it("returns false for a missing unqualified action", () => {
        expect(new Acl([]).can("post:create")).toBe(false);
    });

    it("returns matched qualifiers for a granted qualified action", () => {
        const acl = new Acl(["post:delete:own", "post:delete:all"]);
        expect(acl.can("post:delete")).toEqual(["own", "all"]);
    });

    it("never implies narrower qualifiers from broader ones", () => {
        expect(new Acl(["post:delete:all"]).can("post:delete")).toEqual(["all"]);
    });

    it("returns false for a missing qualified action", () => {
        expect(new Acl(["post:create"]).can("post:delete")).toBe(false);
    });

    it("does not confuse similarly prefixed actions", () => {
        const acl = new Acl(["post:create_all:own"]);
        expect(acl.can("post:create")).toBe(false);
    });
});
