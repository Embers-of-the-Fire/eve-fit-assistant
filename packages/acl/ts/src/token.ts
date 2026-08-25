const SEGMENT_PATTERN = /^[a-z][a-z0-9_]*$/;

/** Grammar-level parts of an ACL token: `{domain}:{action}[:{qualifier}]`. */
export interface TokenParts {
    domain: string;
    action: string;
    qualifier?: string;
}

/** Error thrown when a string does not satisfy the ACL token grammar. */
export class AclTokenError extends Error {
    readonly token: string;

    constructor(token: string, reason: string) {
        super(`Invalid ACL token "${token}": ${reason}`);
        this.name = "AclTokenError";
        this.token = token;
    }
}

/**
 * Parses `token` into its grammar-level parts.
 *
 * This validates the token grammar only; whether the domain, action, or
 * qualifier actually exist is a schema-level concern (see the generated
 * `isAclToken` guard). Throws {@link AclTokenError} on malformed input.
 */
export function parseToken(token: string): TokenParts {
    const segments = token.split(":");
    if (segments.length < 2 || segments.length > 3) {
        throw new AclTokenError(token, `expected 2 or 3 segments, found ${segments.length}`);
    }
    for (const segment of segments) {
        if (!SEGMENT_PATTERN.test(segment)) {
            throw new AclTokenError(token, `invalid segment "${segment}"`);
        }
    }
    const [domain, action, qualifier] = segments;
    return { domain, action, qualifier };
}

/** Encodes token parts back into their `{domain}:{action}[:{qualifier}]` string form. */
export function formatToken(parts: TokenParts): string {
    return parts.qualifier === undefined
        ? `${parts.domain}:${parts.action}`
        : `${parts.domain}:${parts.action}:${parts.qualifier}`;
}
