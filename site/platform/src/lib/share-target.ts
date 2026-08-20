export type ShareTarget = "app" | "web" | "nightly";

export const APP_URI_BASE = "efa://fit/raw";
export const WEB_URL = "https://app.efa-tech.dev";
export const NIGHTLY_URL = "https://app-preview.efa-tech.dev";
export const DOWNLOAD_URL = "https://efa-tech.dev/download";

export const WEB_FIT_PATH = "/fit/raw";

const TARGET_KEY = "efa-share-target";

export function targetUrl(target: ShareTarget, search: string): string {
    if (target === "app") return APP_URI_BASE + search;
    const base = target === "nightly" ? NIGHTLY_URL : WEB_URL;
    return base + WEB_FIT_PATH + search;
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
