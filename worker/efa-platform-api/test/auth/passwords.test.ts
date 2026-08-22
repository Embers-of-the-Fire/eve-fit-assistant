import { describe, expect, it } from "vitest";
import { hashPassword, verifyPassword } from "../../src/auth/passwords.ts";

describe("passwords", () => {
    it("hashes in the pbkdf2$<iter>$<salt>$<hash> format and verifies", async () => {
        const stored = await hashPassword("correct horse battery");
        const parts = stored.split("$");
        expect(parts.length).toBe(4);
        expect(parts[0]).toBe("pbkdf2");
        expect(parts[1]).toBe("50000");
        expect(await verifyPassword("correct horse battery", stored)).toBe(true);
    });

    it("uses a fresh salt per hash", async () => {
        const a = await hashPassword("same-password");
        const b = await hashPassword("same-password");
        expect(a).not.toBe(b);
    });

    it("rejects a wrong password", async () => {
        const stored = await hashPassword("right-password");
        expect(await verifyPassword("wrong-password", stored)).toBe(false);
    });

    it("rejects malformed stored hashes without throwing", async () => {
        const stored = await hashPassword("some-password");
        for (const malformed of [
            "",
            "not-a-hash",
            "argon2$210000$AAAA$BBBB",
            "pbkdf2$0$AAAA$BBBB",
            "pbkdf2$abc$AAAA$BBBB",
            "pbkdf2$210000$!!!$BBBB",
            "pbkdf2$210000$AAAA",
            "pbkdf2$210000$AAAA$BBBB$EXTRA",
        ]) {
            expect(await verifyPassword(stored, malformed)).toBe(false);
        }
    });

    it("rejects iteration counts above the Workers cap without deriving", async () => {
        const parts = (await hashPassword("some-password")).split("$");
        // Just above workerd's 100,000 cap.
        parts[1] = "100001";
        expect(await verifyPassword("some-password", parts.join("$"))).toBe(false);
        // Above Web Crypto's unsigned long range (2^32 - 1), which would make
        // deriveBits reject; verification must return false instead.
        parts[1] = "4294967296";
        expect(await verifyPassword("some-password", parts.join("$"))).toBe(false);
    });
});
