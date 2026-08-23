// Hand-off for the email address between the login page and the registration
// verification step. Kept in sessionStorage so the address never appears in
// the URL (browser history, Referer headers, client analytics).
const STORAGE_KEY = "efa-platform-pending-verification-email";

export function stashPendingVerificationEmail(email: string): void {
    try {
        sessionStorage.setItem(STORAGE_KEY, email);
    } catch {
        // Storage unavailable; the form falls back to an empty field.
    }
}

export function readPendingVerificationEmail(): string {
    try {
        return sessionStorage.getItem(STORAGE_KEY) ?? "";
    } catch {
        // SSR or storage unavailable; read as empty.
        return "";
    }
}

export function clearPendingVerificationEmail(): void {
    try {
        sessionStorage.removeItem(STORAGE_KEY);
    } catch {
        // Storage unavailable; clearing is best-effort.
    }
}
