<script lang="ts">
import { onMount } from "svelte";
import NotFound from "$lib/components/NotFound.svelte";
import { t } from "$lib/i18n.svelte";
import { isValidPayload } from "$lib/payload";
import {
    APP_URI_BASE,
    clearRememberedTarget,
    DOWNLOAD_URL,
    NIGHTLY_URL,
    readRememberedTarget,
    rememberTarget,
    type ShareTarget,
    WEB_URL,
} from "$lib/target";

const REDIRECT_DELAY_MS = 750;
const APP_FAILURE_TIMEOUT_MS = 2500;

let checked = $state(false);
let valid = $state(false);
let redirecting = $state(false);
let appFailed = $state(false);
let hasRemembered = $state(false);
let remember = $state<Record<ShareTarget, boolean>>({
    app: false,
    web: false,
    nightly: false,
});

let redirectTimer: ReturnType<typeof setTimeout> | null = null;
let appFailureTimer: ReturnType<typeof setTimeout> | null = null;
let removeAppLaunchListeners: (() => void) | null = null;

function stopTimers() {
    if (redirectTimer !== null) {
        clearTimeout(redirectTimer);
        redirectTimer = null;
    }
    if (appFailureTimer !== null) {
        clearTimeout(appFailureTimer);
        appFailureTimer = null;
    }
    removeAppLaunchListeners?.();
    removeAppLaunchListeners = null;
}

function redirectTo(target: ShareTarget) {
    redirecting = true;
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
    removeAppLaunchListeners?.();
    removeAppLaunchListeners = () => {
        document.removeEventListener("visibilitychange", onVisibility);
        window.removeEventListener("blur", markLaunched);
    };
    appFailureTimer = setTimeout(() => {
        removeAppLaunchListeners?.();
        removeAppLaunchListeners = null;
        if (!launched) {
            redirecting = false;
            appFailed = true;
        }
    }, APP_FAILURE_TIMEOUT_MS);
}

function chooseTarget(target: ShareTarget) {
    if (remember[target]) {
        rememberTarget(target);
        hasRemembered = true;
    }
    appFailed = false;
    redirectTo(target);
}

function cancelRedirect() {
    stopTimers();
    redirecting = false;
}

function resetPreference() {
    clearRememberedTarget();
    hasRemembered = false;
    cancelRedirect();
}

onMount(() => {
    valid = isValidPayload(new URLSearchParams(location.search).get("payload"));
    checked = true;
    if (!valid) return stopTimers;
    const remembered = readRememberedTarget();
    hasRemembered = remembered !== null;
    if (remembered !== null) redirectTo(remembered);
    return stopTimers;
});
</script>

{#if checked}
    {#if valid}
        <section>
            <h1>{t("heading")}</h1>
            <p class="description">{t("description")}</p>
            {#if redirecting}
                <div class="status">
                    <span>{t("redirecting")}</span>
                    <button type="button" onclick={cancelRedirect}>
                        {t("cancelRedirect")}
                    </button>
                </div>
            {/if}
            <div class="options">
                <div class="option">
                    <button type="button" class="option-button" onclick={() => chooseTarget("app")}>
                        <span class="option-title">{t("optionApp")}</span>
                        <span class="option-desc">{t("optionAppDesc")}</span>
                    </button>
                    <label class="remember">
                        <input type="checkbox" bind:checked={remember.app} />
                        <span>{t("rememberChoice")}</span>
                    </label>
                </div>
                <div class="option">
                    <button type="button" class="option-button" onclick={() => chooseTarget("web")}>
                        <span class="option-title">{t("optionWeb")}</span>
                        <span class="option-desc">{t("optionWebDesc")}</span>
                    </button>
                    <label class="remember">
                        <input type="checkbox" bind:checked={remember.web} />
                        <span>{t("rememberChoice")}</span>
                    </label>
                </div>
                <div class="option">
                    <button
                        type="button"
                        class="option-button"
                        onclick={() => chooseTarget("nightly")}
                    >
                        <span class="option-title">{t("optionNightly")}</span>
                        <span class="option-desc">{t("optionNightlyDesc")}</span>
                    </button>
                    <label class="remember">
                        <input type="checkbox" bind:checked={remember.nightly} />
                        <span>{t("rememberChoice")}</span>
                    </label>
                </div>
            </div>
            {#if appFailed}
                <div class="download-panel">
                    <h2>{t("downloadTitle")}</h2>
                    <p>{t("downloadDesc")}</p>
                    <a class="download-link" href={DOWNLOAD_URL}>{t("downloadButton")}</a>
                </div>
            {/if}
            {#if hasRemembered}
                <button type="button" class="reset-preference" onclick={resetPreference}>
                    {t("resetPreference")}
                </button>
            {/if}
        </section>
    {:else}
        <NotFound />
    {/if}
{/if}
