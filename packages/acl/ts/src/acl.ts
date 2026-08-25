/**
 * Result of {@link Acl.can}: `boolean` for actions declared without qualifiers,
 * the matched qualifier array (or `false` when absent) for qualified actions.
 */
export type CanResult<TMap, TAction extends string> = TAction extends keyof TMap
    ? [TMap[TAction]] extends [never]
        ? boolean
        : Extract<TMap[TAction], string>[] | false
    : never;

/**
 * A set of ACL tokens with membership and action-level queries.
 *
 * Matching is exact: a token only covers its own qualifier; broader qualifiers
 * never imply narrower ones (e.g. `post:delete:all` does not satisfy a query
 * for `own`).
 *
 * `TMap` maps action keys (`"{domain}:{action}"`) to their qualifier union, or
 * `never` for unqualified actions; it is normally supplied by the generated
 * `AclActionMap`. Without it, {@link can} falls back to `string[] | false` and
 * {@link has} accepts any string.
 *
 * Construction is O(n) and indexes tokens by action key, so both {@link has}
 * and {@link can} are O(1) hash lookups (plus O(k) for the k matched
 * qualifiers). Tokens are expected to satisfy the grammar; malformed tokens
 * are stored but not validated.
 */
export class Acl<TMap = Record<string, string>, TToken extends string = string> {
    readonly #tokens: ReadonlySet<string>;
    readonly #actions: ReadonlyMap<string, readonly string[]>;

    constructor(tokens: Iterable<string>) {
        const tokenSet = new Set(tokens);
        const actions = new Map<string, string[]>();
        for (const token of tokenSet) {
            const secondColon = token.indexOf(":", token.indexOf(":") + 1);
            if (secondColon === -1) {
                // Unqualified token: the token itself is the action key and is
                // answered by the exact-membership check in `can`.
                continue;
            }
            const key = token.slice(0, secondColon);
            const qualifiers = actions.get(key);
            if (qualifiers === undefined) {
                actions.set(key, [token.slice(secondColon + 1)]);
            } else {
                qualifiers.push(token.slice(secondColon + 1));
            }
        }
        this.#tokens = tokenSet;
        this.#actions = actions;
    }

    /** The raw token strings in this set. */
    get tokens(): ReadonlySet<string> {
        return this.#tokens;
    }

    /** Whether `token` is present exactly, qualifier included. */
    has(token: TToken): boolean {
        return this.#tokens.has(token);
    }

    /**
     * Queries an action key (`"{domain}:{action}"`).
     *
     * Returns `true`/`false` for actions declared without qualifiers, and the
     * array of matched qualifiers (or `false` when the action is absent) for
     * qualified actions.
     */
    can<TAction extends string & keyof TMap>(action: TAction): CanResult<TMap, TAction> {
        if (this.#tokens.has(action)) {
            return true as CanResult<TMap, TAction>;
        }
        const matched = this.#actions.get(action);
        return (matched === undefined ? false : matched.slice()) as CanResult<TMap, TAction>;
    }
}
