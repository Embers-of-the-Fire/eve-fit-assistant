// Password hashing: PBKDF2-HMAC-SHA256 over WebCrypto, no native deps. The
// serialized hash carries its iteration count so parameters can be raised
// later without invalidating existing hashes.

const ALGORITHM = "pbkdf2";
// The Workers runtime hard-caps PBKDF2 iterations (currently 100,000 — see
// workerd's checkPbkdfLimits); stay well below it so the cap can shrink
// without breaking hashing.
export const ITERATIONS = 50_000;
// Verification rejects any stored hash above the Workers runtime cap
// (100,000, per workerd's checkPbkdfLimits) before derivation, so a crafted
// hash cannot request excessive PBKDF2 work or exceed Web Crypto's unsigned
// long range and make deriveBits reject.
const MAX_ITERATIONS = 100_000;
const SALT_BYTES = 16;
const DERIVED_BITS = 256;

function bytesToBase64(bytes: Uint8Array): string {
    let binary = "";
    for (const b of bytes) {
        binary += String.fromCharCode(b);
    }
    return btoa(binary);
}

function base64ToBytes(value: string): Uint8Array | null {
    try {
        const binary = atob(value);
        const bytes = new Uint8Array(binary.length);
        for (let i = 0; i < binary.length; i++) {
            bytes[i] = binary.charCodeAt(i);
        }
        return bytes;
    } catch {
        return null;
    }
}

async function deriveKey(
    password: string,
    salt: Uint8Array,
    iterations: number,
): Promise<Uint8Array> {
    const material = await crypto.subtle.importKey(
        "raw",
        new TextEncoder().encode(password),
        "PBKDF2",
        false,
        ["deriveBits"],
    );
    const bits = await crypto.subtle.deriveBits(
        {
            name: "PBKDF2",
            hash: "SHA-256",
            salt: salt.buffer as ArrayBuffer,
            iterations,
        },
        material,
        DERIVED_BITS,
    );
    return new Uint8Array(bits);
}

export async function hashPassword(password: string): Promise<string> {
    const salt = crypto.getRandomValues(new Uint8Array(SALT_BYTES));
    const derived = await deriveKey(password, salt, ITERATIONS);
    return [ALGORITHM, String(ITERATIONS), bytesToBase64(salt), bytesToBase64(derived)].join("$");
}

export async function verifyPassword(password: string, stored: string): Promise<boolean> {
    const parts = stored.split("$");
    if (parts.length !== 4 || parts[0] !== ALGORITHM) {
        return false;
    }
    const iterations = Number(parts[1]);
    if (!Number.isSafeInteger(iterations) || iterations <= 0 || iterations > MAX_ITERATIONS) {
        return false;
    }
    const salt = base64ToBytes(parts[2]);
    const expected = base64ToBytes(parts[3]);
    if (!salt || !expected || expected.length !== DERIVED_BITS / 8) {
        return false;
    }
    const derived = await deriveKey(password, salt, iterations);
    // Constant-time comparison over the fixed-width derived keys.
    let diff = 0;
    for (let i = 0; i < derived.length; i++) {
        diff |= derived[i] ^ expected[i];
    }
    return diff === 0;
}
