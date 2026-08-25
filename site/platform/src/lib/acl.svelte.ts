import {
    type Acl,
    type AclActionMap,
    type AclRole,
    type AclToken,
    createAcl,
    isAclRole,
    isAclToken,
} from "efa-acl-ts";
import type { PlatformAccountInfo } from "efa-platform-client-ts";
import { authState, getSession } from "./auth.svelte";
import { t } from "./i18n.svelte";
import type { TranslationKey } from "./translations";

// ACL state for the signed-in account: the account info (roles + resolved
// permission tokens) is fetched from the platform API once per identity and
// bridged into runes, mirroring how auth.svelte.ts bridges identity. The
// token set is pre-filtered through the schema guard so tokens from a newer
// server schema degrade to "no permission" instead of breaking typing.
let _info = $state<PlatformAccountInfo | null>(null);
let _loadingFor: string | null = null;
let _acl = $state<Acl<AclActionMap, AclToken>>(createAcl([]));

/**
 * Ensures the account info (roles + permissions) for the current identity is
 * loaded; islands rendering permission-gated UI call this from an `$effect`.
 * No-op while signed out (clears the state) or already loaded/in-flight.
 */
export function loadAccountAcl(): void {
    const identity = authState.identity;
    if (identity === null) {
        _info = null;
        _loadingFor = null;
        _acl = createAcl([]);
        return;
    }
    if (_loadingFor === identity.userId) {
        return;
    }
    _loadingFor = identity.userId;
    getSession()
        .accountInfo()
        .then(
            (info) => {
                if (_loadingFor !== info.userId) {
                    return;
                }
                _info = info;
                _acl = createAcl(info.permissions.filter(isAclToken));
            },
            () => {
                // Keep the signed-out-shaped default; the next call retries.
                _loadingFor = null;
            },
        );
}

/** Reactive ACL state for islands: empty while signed out or unloaded. */
export const accountAclState = {
    /** The fetched account info; null until loaded. */
    get info(): PlatformAccountInfo | null {
        return _info;
    },
    /** The account's placeholder permission roles. */
    get roles(): string[] {
        return _info?.roles ?? [];
    },
    /** The account's typed ACL token set. */
    get acl(): Acl<AclActionMap, AclToken> {
        return _acl;
    },
};

// Role keys are internal vocabulary; the UI shows localized labels instead.
const roleLabelKeys: Record<AclRole, TranslationKey> = {
    user: "role.user",
    moderator: "role.moderator",
    admin: "role.admin",
};

/**
 * Maps a stored role key to its localized display label. Unknown keys (e.g. a
 * role added server-side before this client was rebuilt) render as the raw
 * key, so a new role degrades gracefully instead of breaking the page.
 */
export function roleLabel(role: string): string {
    return isAclRole(role) ? t(roleLabelKeys[role]) : role;
}
