import { en, type Locale, type TranslationKey, zh } from "./translations";

const translations = { en, zh } as const;

const STORAGE_KEY = "efa-locale";

function detectLocale(): Locale {
    if (typeof localStorage !== "undefined") {
        const stored = localStorage.getItem(STORAGE_KEY);
        if (stored === "en" || stored === "zh") return stored;
    }

    if (typeof navigator !== "undefined") {
        const lang = navigator.language;
        if (lang.startsWith("zh")) return "zh";
    }

    return "en";
}

let _locale = $state<Locale>("en");

export const locale = {
    get current() {
        return _locale;
    },
    set current(val: Locale) {
        _locale = val;
        if (typeof document !== "undefined") {
            document.documentElement.lang = val === "zh" ? "zh-CN" : "en";
        }
        if (typeof localStorage !== "undefined") {
            localStorage.setItem(STORAGE_KEY, val);
        }
    },
};

export function t(key: TranslationKey): string {
    const localeVal = _locale;
    return translations[localeVal][key] ?? key;
}

export function initLangAttribute() {
    if (typeof document !== "undefined") {
        const detected = detectLocale();
        if (_locale !== detected) {
            _locale = detected;
        }
        document.documentElement.lang = _locale === "zh" ? "zh-CN" : "en";
    }
}
