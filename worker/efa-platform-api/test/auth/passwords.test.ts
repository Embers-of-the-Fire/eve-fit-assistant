import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { hashPassword, verifyPassword } from "../../src/auth/passwords.ts";

describe("passwords", () => {
    it("hashes in the pbkdf2$<iter>$<salt>$<hash> format and verifies", async () => {
        const stored = await hashPassword("correct horse battery");
        const parts = stored.split("$");
        assert.equal(parts.length, 4);
        assert.equal(parts[0], "pbkdf2");
        assert.equal(parts[1], "50000");
        assert.ok(await verifyPassword("correct horse battery", stored));
    });

    it("uses a fresh salt per hash", async () => {
        const a = await hashPassword("same-password");
        const b = await hashPassword("same-password");
        assert.notEqual(a, b);
    });

    it("rejects a wrong password", async () => {
        const stored = await hashPassword("right-password");
        assert.equal(await verifyPassword("wrong-password", stored), false);
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
            assert.equal(await verifyPassword(stored, malformed), false, malformed);
        }
    });

    it("rejects iteration counts above the Workers cap without deriving", async () => {
        const parts = (await hashPassword("some-password")).split("$");
        // Just above workerd's 100,000 cap.
        parts[1] = "100001";
        assert.equal(await verifyPassword("some-password", parts.join("$")), false);
        // Above Web Crypto's unsigned long range (2^32 - 1), which would make
        // deriveBits reject; verification must return false instead.
        parts[1] = "4294967296";
        assert.equal(await verifyPassword("some-password", parts.join("$")), false);
    });
});
