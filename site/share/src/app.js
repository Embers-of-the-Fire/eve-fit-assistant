(() => {
    const { STRINGS, STORAGE_KEY, negotiate } = window.EfaShareI18n;

    const CANONICAL_PATH = "/fit/raw";
    const PAYLOAD_PREFIX = "EFA2:";
    const APP_URI_BASE = "efa://fit/raw";
    const WEB_URL = "https://app.efa-tech.dev";
    const NIGHTLY_URL = "https://app-preview.efa-tech.dev";
    const TARGET_KEY = "efa-share-target";
    const REDIRECT_DELAY_MS = 750;
    const APP_FAILURE_TIMEOUT_MS = 2500;

    let lang = negotiate();
    let redirectTimer = null;
    let appFailureTimer = null;

    function t(key) {
        return STRINGS[lang][key] || STRINGS.en[key] || key;
    }

    function applyLanguage() {
        document.documentElement.lang = lang;
        document.title = t("title");
        for (const element of document.querySelectorAll("[data-i18n]")) {
            element.textContent = t(element.dataset.i18n);
        }
    }

    function readStored(key) {
        try {
            return localStorage.getItem(key);
        } catch (_) {
            return null;
        }
    }

    function writeStored(key, value) {
        try {
            localStorage.setItem(key, value);
        } catch (_) {
            // Storage unavailable; remembering is best-effort.
        }
    }

    function clearStored(key) {
        try {
            localStorage.removeItem(key);
        } catch (_) {
            // Storage unavailable; nothing to clear.
        }
    }

    function isFitLink() {
        if (location.pathname !== CANONICAL_PATH) return false;
        const payload = new URLSearchParams(location.search).get("payload");
        return typeof payload === "string" && payload.startsWith(PAYLOAD_PREFIX);
    }

    function show(elementId) {
        document.getElementById(elementId).hidden = false;
    }

    function hide(elementId) {
        document.getElementById(elementId).hidden = true;
    }

    function stopTimers() {
        if (redirectTimer !== null) {
            clearTimeout(redirectTimer);
            redirectTimer = null;
        }
        if (appFailureTimer !== null) {
            clearTimeout(appFailureTimer);
            appFailureTimer = null;
        }
    }

    function updateResetVisibility() {
        document.getElementById("reset-preference").hidden = readStored(TARGET_KEY) === null;
    }

    function redirectTo(target) {
        show("status");
        stopTimers();
        if (target === "app") {
            redirectTimer = setTimeout(() => {
                location.href = APP_URI_BASE + location.search;
                watchAppLaunch();
            }, REDIRECT_DELAY_MS);
            return;
        }
        const base = target === "nightly" ? NIGHTLY_URL : WEB_URL;
        redirectTimer = setTimeout(() => {
            location.href = base + location.pathname + location.search;
        }, REDIRECT_DELAY_MS);
    }

    function watchAppLaunch() {
        let launched = false;
        const markLaunched = () => {
            launched = true;
            stopTimers();
        };
        const onVisibility = () => {
            if (document.visibilityState === "hidden") markLaunched();
        };
        document.addEventListener("visibilitychange", onVisibility, { once: true });
        window.addEventListener("blur", markLaunched, { once: true });
        appFailureTimer = setTimeout(() => {
            document.removeEventListener("visibilitychange", onVisibility);
            window.removeEventListener("blur", markLaunched);
            if (!launched) {
                hide("status");
                show("download-panel");
            }
        }, APP_FAILURE_TIMEOUT_MS);
    }

    function chooseTarget(target) {
        const checkbox = document.querySelector(`input[data-remember="${target}"]`);
        if (checkbox?.checked) {
            writeStored(TARGET_KEY, target);
            updateResetVisibility();
        }
        hide("download-panel");
        redirectTo(target);
    }

    function cancelRedirect() {
        stopTimers();
        hide("status");
    }

    function resetPreference() {
        clearStored(TARGET_KEY);
        updateResetVisibility();
        cancelRedirect();
    }

    function initChooser() {
        for (const button of document.querySelectorAll(".option-button")) {
            button.addEventListener("click", () => chooseTarget(button.dataset.target));
        }
        document.getElementById("cancel-redirect").addEventListener("click", cancelRedirect);
        document.getElementById("reset-preference").addEventListener("click", resetPreference);
        updateResetVisibility();

        const remembered = readStored(TARGET_KEY);
        if (remembered === "app" || remembered === "web" || remembered === "nightly") {
            redirectTo(remembered);
        }
    }

    function init() {
        applyLanguage();
        document.getElementById("lang-toggle").addEventListener("click", () => {
            lang = lang === "zh" ? "en" : "zh";
            writeStored(STORAGE_KEY, lang);
            applyLanguage();
        });

        if (!isFitLink()) {
            show("state-notfound");
            return;
        }
        show("state-chooser");
        initChooser();
    }

    init();
})();
