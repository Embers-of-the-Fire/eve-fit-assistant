import { en, type Locale, type TranslationKey, zh } from "./translations";

const translations = { en, zh } as const;

const STORAGE_KEY = "efa-platform-lang";

function detectLocale(): Locale {
    try {
        const stored = localStorage.getItem(STORAGE_KEY);
        if (stored === "en" || stored === "zh") return stored;
    } catch {
        // localStorage unavailable; fall through to negotiation.
    }
    const nav = (navigator.language || "en").toLowerCase();
    return nav.startsWith("zh") ? "zh" : "en";
}

let _locale = $state<Locale>("en");

export const locale = {
    get current() {
        return _locale;
    },
    set current(val: Locale) {
        _locale = val;
        document.documentElement.lang = val;
        try {
            localStorage.setItem(STORAGE_KEY, val);
        } catch {
            // Storage unavailable; remembering is best-effort.
        }
    },
    toggle() {
        this.current = _locale === "zh" ? "en" : "zh";
    },
};

export function t(key: TranslationKey): string {
    return translations[_locale][key] ?? en[key] ?? key;
}

export function initLocale() {
    _locale = detectLocale();
    document.documentElement.lang = _locale;
}
