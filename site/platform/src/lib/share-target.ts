export type ShareTarget = "app" | "web" | "nightly";
export type ShareKind = "raw" | "registered";

export const APP_URI_BASES: Record<ShareKind, string> = {
    raw: "efa://fit/raw",
    registered: "efa://fit/registered",
};
export const WEB_URL = "https://app.efa-tech.dev";
export const NIGHTLY_URL = "https://app-preview.efa-tech.dev";
export const DOWNLOAD_URL = "https://efa-tech.dev/download";

export const WEB_FIT_PATHS: Record<ShareKind, string> = {
    raw: "/fit/raw",
    registered: "/fit/registered",
};

export const SHARE_PAGE_PATHS: Record<ShareKind, string> = {
    raw: "/share/fit/raw",
    registered: "/share/fit/registered",
};

export function registeredSharePageUrl(fitHash: string): string {
    return `${SHARE_PAGE_PATHS.registered}?hash=${encodeURIComponent(fitHash)}`;
}

const TARGET_KEY = "efa-share-target";

export function targetUrl(target: ShareTarget, search: string, kind: ShareKind): string {
    if (target === "app") return APP_URI_BASES[kind] + search;
    const base = target === "nightly" ? NIGHTLY_URL : WEB_URL;
    return base + WEB_FIT_PATHS[kind] + search;
}

export function readRememberedTarget(): ShareTarget | null {
    try {
        const stored = localStorage.getItem(TARGET_KEY);
        if (stored === "app" || stored === "web" || stored === "nightly") return stored;
    } catch {
        // Storage unavailable; remembering is best-effort.
    }
    return null;
}

export function rememberTarget(target: ShareTarget) {
    try {
        localStorage.setItem(TARGET_KEY, target);
    } catch {
        // Storage unavailable; remembering is best-effort.
    }
}

export function clearRememberedTarget() {
    try {
        localStorage.removeItem(TARGET_KEY);
    } catch {
        // Storage unavailable; nothing to clear.
    }
}
