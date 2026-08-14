export const PAYLOAD_PREFIX = "EFA2:";

const MAX_PAYLOAD_CHARS = 7800;
const BASE64URL_ALPHABET = /^[A-Za-z0-9_-]*$/;
const GZIP_MAGIC_0 = 0x1f;
const GZIP_MAGIC_1 = 0x8b;

function decodeBase64Url(encoded: string): string | null {
    const base64 = encoded.replace(/-/g, "+").replace(/_/g, "/");
    const padded = base64.padEnd(base64.length + ((4 - (base64.length % 4)) % 4), "=");
    try {
        return atob(padded);
    } catch {
        return null;
    }
}

export function isValidPayload(payload: string | null): boolean {
    if (typeof payload !== "string" || payload.length > MAX_PAYLOAD_CHARS) return false;
    if (!payload.startsWith(PAYLOAD_PREFIX)) return false;
    const encoded = payload.slice(PAYLOAD_PREFIX.length);
    if (encoded.length === 0 || !BASE64URL_ALPHABET.test(encoded)) return false;
    const decoded = decodeBase64Url(encoded);
    if (decoded === null || decoded.length < 2) return false;
    return decoded.charCodeAt(0) === GZIP_MAGIC_0 && decoded.charCodeAt(1) === GZIP_MAGIC_1;
}
