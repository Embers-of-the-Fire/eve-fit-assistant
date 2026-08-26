import {
    LocalStorageSessionStore,
    type PlatformIdentity,
    PlatformSession,
} from "efa-platform-client-ts";
import { locale } from "./i18n.svelte";

// Singleton session for the browser islands. The module also evaluates during
// SSR: the localStorage store then reads as empty, so the session stays
// signed out server-side and only ever holds credentials on the client.
let _session: PlatformSession | null = null;

let _identity = $state<PlatformIdentity | null>(null);
let _ready = $state(false);

export function getSession(): PlatformSession {
    if (_session === null) {
        _session = new PlatformSession({
            // Build-time constant: preview builds target the API same-origin
            // through the /platform/* proxy (see astro.config.mjs).
            origin: __PLATFORM_API_ORIGIN__,
            store: new LocalStorageSessionStore(),
            emailLocale: () => locale.current,
            onAuthRequired: () => {
                // The session was rejected server-side mid-flight; send the
                // user through interactive login again.
                window.location.assign("/account/login");
            },
        });
        void _session.ready.then(() => {
            _ready = true;
        });
        _session.subscribeIdentity((value) => {
            _identity = value;
        });
    }
    return _session;
}

/** Reactive auth state for islands: `identity` is null while signed out. */
export const authState = {
    get identity(): PlatformIdentity | null {
        return _identity;
    },
    /** False until the cold-start load/rotation has settled. */
    get ready(): boolean {
        return _ready;
    },
};
