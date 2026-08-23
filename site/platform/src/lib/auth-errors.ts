import { AccountApiError } from "efa-platform-client-ts";
import { t } from "./i18n.svelte";
import type { TranslationKey } from "./translations";

const EMAIL_PATTERN = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

/** Client-side email shape check (the server validates authoritatively). */
export function isValidAccountEmail(email: string): boolean {
    return EMAIL_PATTERN.test(email.trim());
}

/** Mirrors the server-side password policy (`min(10).max(128)`). */
export function isValidAccountPassword(password: string): boolean {
    return password.length >= 10 && password.length <= 128;
}

const CODE_PATTERN = /^[0-9]{6}$/;

/** Verification codes are exactly 6 ASCII digits. */
export function isValidAccountCode(code: string): boolean {
    return CODE_PATTERN.test(code);
}

/** Maps an auth flow failure to a localized, user-facing message. */
export function accountErrorMessage(error: unknown): string {
    if (error instanceof AccountApiError) {
        const key = ERROR_KEY_BY_CODE[error.code ?? ""];
        if (key !== undefined) return t(key);
        if (error.statusCode === null) return t("account.error.network");
    }
    return t("account.error.generic");
}

const ERROR_KEY_BY_CODE: Record<string, TranslationKey> = {
    invalid_credentials: "account.error.invalidCredentials",
    email_taken: "account.error.emailTaken",
    otp_invalid: "account.error.otpInvalid",
    otp_expired: "account.error.otpExpired",
    email_unverified: "account.error.emailUnverified",
    rate_limited: "account.error.rateLimited",
};
