// Pure helpers of efa-platform-api, kept free of protobuf imports so the
// unit tests can run under Node's strip-types mode (the protobuf-es generated
// bindings use non-erasable enums).

export const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// Fit hashes are lowercase hex SHA-256 digests over the canonical fit bytes.
export const FIT_HASH_PATTERN = /^[0-9a-f]{64}$/;

// D1's documented type conversion reads BLOB columns back as plain number
// arrays (Array.from over the stored bytes); other environments may yield an
// ArrayBuffer or a view. Normalize every observed shape into bytes; null
// means "not a blob we can serve".
export function normalizeBlob(value: unknown): Uint8Array | null {
    if (value instanceof ArrayBuffer) return new Uint8Array(value);
    if (ArrayBuffer.isView(value)) {
        return new Uint8Array(value.buffer, value.byteOffset, value.byteLength);
    }
    if (Array.isArray(value)) return Uint8Array.from(value as number[]);
    return null;
}

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

// Time-window filters over posts.created_at: the token maps to a SQLite
// datetime modifier; "all" (or an absent parameter) means no time condition.
const TIME_WINDOW_MODIFIERS: Record<string, string> = {
    "24h": "-1 day",
    "7d": "-7 days",
    "30d": "-30 days",
};

export function parseTimeWindow(raw: string | undefined): string | null | "invalid" {
    if (raw === undefined || raw === "all") return null;
    return TIME_WINDOW_MODIFIERS[raw] ?? "invalid";
}

// The ship-directory cursor token is the opaque base64url encoding of
// `{post_count}|{ship_type_id}`; clients must not parse it.
export function encodeShipCursor(postCount: number, shipTypeId: number): string {
    return btoa(`${postCount}|${shipTypeId}`)
        .replaceAll("+", "-")
        .replaceAll("/", "_")
        .replaceAll("=", "");
}

export function decodeShipCursor(token: string): { postCount: number; shipTypeId: number } | null {
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
    const postCount = Number(raw.slice(0, separator));
    const shipTypeId = Number(raw.slice(separator + 1));
    if (!Number.isSafeInteger(postCount) || postCount < 0) return null;
    if (!Number.isSafeInteger(shipTypeId) || shipTypeId <= 0) return null;
    return { postCount, shipTypeId };
}

// Escape the wildcard characters of a LIKE pattern (used with ESCAPE '\') so
// a free-text query matches literally.
export function escapeLikePattern(query: string): string {
    return query.replaceAll("\\", "\\\\").replaceAll("%", "\\%").replaceAll("_", "\\_");
}
