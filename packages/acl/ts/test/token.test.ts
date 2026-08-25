import { describe, expect, it } from "vitest";

import { AclTokenError, formatToken, parseToken } from "../src/index";

describe("parseToken", () => {
    it("parses an unqualified token", () => {
        expect(parseToken("post:create")).toEqual({ domain: "post", action: "create" });
    });

    it("parses a qualified token", () => {
        expect(parseToken("post:delete:own")).toEqual({
            domain: "post",
            action: "delete",
            qualifier: "own",
        });
    });

    it("accepts underscores and digits in segments", () => {
        expect(parseToken("blog_post:edit_v2:v2_draft")).toEqual({
            domain: "blog_post",
            action: "edit_v2",
            qualifier: "v2_draft",
        });
    });

    it.each([
        ["", "2 or 3 segments"],
        ["post", "2 or 3 segments"],
        ["post:delete:own:extra", "2 or 3 segments"],
        ["post::own", "invalid segment"],
        [":create", "invalid segment"],
        ["Post:create", "invalid segment"],
        ["post:Create", "invalid segment"],
        ["post:create:Own", "invalid segment"],
        ["post:create-own", "invalid segment"],
        ["post:delete:", "invalid segment"],
    ])("rejects malformed token %j", (token, reason) => {
        expect(() => parseToken(token)).toThrowError(AclTokenError);
        expect(() => parseToken(token)).toThrowError(new RegExp(reason));
    });

    it("exposes the offending token on the error", () => {
        try {
            parseToken("nope");
            expect.unreachable();
        } catch (error) {
            expect(error).toBeInstanceOf(AclTokenError);
            expect((error as AclTokenError).token).toBe("nope");
        }
    });
});

describe("formatToken", () => {
    it("round-trips unqualified tokens", () => {
        expect(formatToken({ domain: "post", action: "create" })).toBe("post:create");
    });

    it("round-trips qualified tokens", () => {
        const parts = parseToken("post:delete:own");
        expect(formatToken(parts)).toBe("post:delete:own");
    });
});
