/**
 * Decodes the `sub` (user id) claim of an access-token JWT without
 * verifying the signature (display metadata only; the server verifies).
 */
export function decodeJwtSubject(token: string): string | null {
    const parts = token.split(".");
    if (parts.length !== 3) return null;
    try {
        const payload = decodeBase64Url(parts[1]);
        const json: unknown = JSON.parse(payload);
        if (typeof json === "object" && json !== null && "sub" in json) {
            const sub = (json as { sub: unknown }).sub;
            return typeof sub === "string" ? sub : null;
        }
    } catch {
        // Malformed token; treated as undecodable.
    }
    return null;
}

function decodeBase64Url(segment: string): string {
    const base64 = segment.replace(/-/g, "+").replace(/_/g, "/");
    const padded = base64.padEnd(base64.length + ((4 - (base64.length % 4)) % 4), "=");
    const binary = atob(padded);
    const bytes = Uint8Array.from(binary, (ch) => ch.charCodeAt(0));
    return new TextDecoder().decode(bytes);
}
