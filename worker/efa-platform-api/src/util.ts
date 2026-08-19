// Pure helpers of efa-platform-api, kept free of protobuf imports so the
// unit tests can run under Node's strip-types mode (the protobuf-es generated
// bindings use non-erasable enums).

export const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// Port of timingSafeEqual in worker/efa-platform-data-sync/src/index.ts.
export function timingSafeEqual(a: string, b: string): boolean {
    const encoder = new TextEncoder();
    const aBytes = encoder.encode(a);
    const bBytes = encoder.encode(b);
    if (aBytes.length !== bBytes.length) {
        return false;
    }
    let diff = 0;
    for (let i = 0; i < aBytes.length; i++) {
        diff |= aBytes[i] ^ bBytes[i];
    }
    return diff === 0;
}

export function truncateCodePoints(text: string, limit: number): string {
    return [...text].slice(0, limit).join("");
}

// The cursor token is the opaque base64url encoding of `{created_at}|{post_id}`;
// clients must not parse it.
export function encodeCursor(createdAt: string, postId: string): string {
    return btoa(`${createdAt}|${postId}`)
        .replaceAll("+", "-")
        .replaceAll("/", "_")
        .replaceAll("=", "");
}

export function decodeCursor(token: string): { createdAt: string; postId: string } | null {
    let raw: string;
    try {
        const base64 = token.replaceAll("-", "+").replaceAll("_", "/");
        const padded = base64 + "=".repeat((4 - (base64.length % 4)) % 4);
        raw = atob(padded);
    } catch {
        return null;
    }
    const separator = raw.lastIndexOf("|");
    if (separator <= 0) return null;
    const createdAt = raw.slice(0, separator);
    const postId = raw.slice(separator + 1);
    if (!UUID_PATTERN.test(postId)) return null;
    return { createdAt, postId };
}

export function resolveShipName(shipNamesJson: string, locale: string): string {
    let names: Record<string, string>;
    try {
        names = JSON.parse(shipNamesJson) as Record<string, string>;
    } catch {
        return "";
    }
    return names[locale] ?? names.en ?? Object.values(names)[0] ?? "";
}
