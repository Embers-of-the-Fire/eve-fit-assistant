<script lang="ts">
import { onMount } from "svelte";
import { isValidPayload } from "../lib/fit-payload";
import { t } from "../lib/i18n.svelte";
import {
    clearRememberedTarget,
    DOWNLOAD_URL,
    readRememberedTarget,
    rememberTarget,
    type ShareTarget,
    targetUrl,
} from "../lib/share-target";
import FitLinkNotFound from "./FitLinkNotFound.svelte";

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
    redirectTimer = setTimeout(() => {
        location.href = targetUrl(target, location.search);
        if (target === "app") watchAppLaunch();
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

const targets: {
    id: ShareTarget;
    titleKey: "share.optionApp" | "share.optionWeb" | "share.optionNightly";
    descKey: "share.optionAppDesc" | "share.optionWebDesc" | "share.optionNightlyDesc";
}[] = [
    { id: "app", titleKey: "share.optionApp", descKey: "share.optionAppDesc" },
    { id: "web", titleKey: "share.optionWeb", descKey: "share.optionWebDesc" },
    { id: "nightly", titleKey: "share.optionNightly", descKey: "share.optionNightlyDesc" },
];
</script>

{#if checked}
    {#if valid}
        <section class="rounded border border-console-border bg-console-surface p-6">
            <h1 class="text-xl font-semibold text-console-highlight">{t("share.heading")}</h1>
            <p class="mt-2 text-sm text-console-text-dim">{t("share.description")}</p>
            {#if redirecting}
                <div
                    class="mt-4 flex items-center justify-between rounded border border-console-border bg-console-surface-alt px-4 py-2 text-sm"
                >
                    <span class="text-console-text">{t("share.redirecting")}</span>
                    <button
                        type="button"
                        onclick={cancelRedirect}
                        class="rounded border border-console-border px-2 py-1 text-xs text-console-text-dim transition-colors hover:border-console-primary hover:text-console-highlight"
                    >
                        {t("share.cancelRedirect")}
                    </button>
                </div>
            {/if}
            <div class="mt-4 flex flex-col gap-3">
                {#each targets as target (target.id)}
                    <div>
                        <button
                            type="button"
                            onclick={() => chooseTarget(target.id)}
                            class="flex w-full flex-col gap-1 rounded border border-console-border bg-console-surface-alt px-4 py-3 text-left transition-colors hover:border-console-primary"
                        >
                            <span class="text-sm font-medium text-console-highlight">
                                {t(target.titleKey)}
                            </span>
                            <span class="text-xs text-console-text-muted">
                                {t(target.descKey)}
                            </span>
                        </button>
                        <label
                            class="mt-1 flex items-center gap-2 px-1 text-xs text-console-text-muted"
                        >
                            <input type="checkbox" bind:checked={remember[target.id]} />
                            <span>{t("share.rememberChoice")}</span>
                        </label>
                    </div>
                {/each}
            </div>
            {#if appFailed}
                <div
                    class="mt-4 rounded border border-console-border bg-console-surface-alt px-4 py-3"
                >
                    <h2 class="text-sm font-semibold text-console-highlight">
                        {t("share.downloadTitle")}
                    </h2>
                    <p class="mt-1 text-xs text-console-text-dim">{t("share.downloadDesc")}</p>
                    <a
                        class="mt-2 inline-block rounded border border-console-primary px-3 py-1 text-xs text-console-primary transition-colors hover:bg-console-primary hover:text-console-deep"
                        href={DOWNLOAD_URL}>{t("share.downloadButton")}</a
                    >
                </div>
            {/if}
            {#if hasRemembered}
                <button
                    type="button"
                    onclick={resetPreference}
                    class="mt-4 rounded border border-console-border px-2 py-1 text-xs text-console-text-dim transition-colors hover:border-console-primary hover:text-console-highlight"
                >
                    {t("share.resetPreference")}
                </button>
            {/if}
        </section>
    {:else}
        <FitLinkNotFound />
    {/if}
{/if}
