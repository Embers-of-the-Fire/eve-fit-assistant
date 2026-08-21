<script lang="ts">
import { onMount, untrack } from "svelte";
import { fetchShips } from "../lib/api";
import { initLocale, locale, t } from "../lib/i18n.svelte";
import type { Locale } from "../lib/translations";
import type { ShipSummary, TimeWindow } from "../lib/types";

const PAGE_SIZE = 24;
const SEARCH_DEBOUNCE_MS = 300;
const WINDOWS: TimeWindow[] = ["24h", "7d", "30d", "all"];

let ships = $state<ShipSummary[]>([]);
let nextCursor = $state<string | null>(null);
let query = $state("");
let activeWindow = $state<TimeWindow>("all");
let initialLoading = $state(true);
let failed = $state(false);
let loadingMore = $state(false);
let loadMoreFailed = $state(false);
let directoryVersion = 0;
let searchTimer: ReturnType<typeof setTimeout> | undefined;
let fetchedLocale: Locale | null = null;

async function loadFirstPage() {
    const version = ++directoryVersion;
    fetchedLocale = locale.current;
    loadingMore = false;
    loadMoreFailed = false;
    initialLoading = true;
    failed = false;
    try {
        const page = await fetchShips(locale.current, {
            limit: PAGE_SIZE,
            q: query.trim() || null,
            window: activeWindow,
        });
        if (version !== directoryVersion) return;
        ships = page.ships;
        nextCursor = page.nextCursor;
    } catch {
        if (version !== directoryVersion) return;
        failed = true;
    } finally {
        if (version === directoryVersion) initialLoading = false;
    }
}

async function loadMore() {
    if (!nextCursor || loadingMore) return;
    const version = directoryVersion;
    loadingMore = true;
    loadMoreFailed = false;
    try {
        const page = await fetchShips(locale.current, {
            limit: PAGE_SIZE,
            cursor: nextCursor,
            q: query.trim() || null,
            window: activeWindow,
        });
        if (version !== directoryVersion) return;
        ships = [...ships, ...page.ships];
        nextCursor = page.nextCursor;
    } catch {
        if (version !== directoryVersion) return;
        loadMoreFailed = true;
    } finally {
        if (version === directoryVersion) loadingMore = false;
    }
}

function onSearchInput(event: Event) {
    query = (event.currentTarget as HTMLInputElement).value;
    clearTimeout(searchTimer);
    searchTimer = setTimeout(loadFirstPage, SEARCH_DEBOUNCE_MS);
}

function selectWindow(window: TimeWindow) {
    if (activeWindow === window) return;
    activeWindow = window;
    loadFirstPage();
}

function formatDate(iso: string): string {
    const date = new Date(iso);
    const tag = locale.current === "zh" ? "zh-CN" : "en-US";
    return Number.isNaN(date.getTime()) ? iso : date.toLocaleDateString(tag);
}

$effect(() => {
    const current = locale.current;
    if (fetchedLocale === null || current === fetchedLocale) return;
    untrack(loadFirstPage);
});

onMount(() => {
    initLocale();
    loadFirstPage();
    return () => clearTimeout(searchTimer);
});
</script>

<section class="mb-8">
    <p class="text-xs font-semibold uppercase tracking-widest text-console-primary">
        {t("nav.ships")}
    </p>
    <h1 class="mt-2 text-3xl font-bold tracking-tight text-console-text">{t("ships.title")}</h1>
    <p class="mt-2 max-w-2xl text-sm text-console-text-dim">{t("ships.desc")}</p>
    <div class="mt-4 flex flex-wrap items-center gap-3">
        <input
            type="search"
            value={query}
            oninput={onSearchInput}
            placeholder={t("ships.searchPlaceholder")}
            class="w-full max-w-sm rounded border border-console-border bg-console-surface px-3 py-2 text-sm text-console-text placeholder:text-console-text-muted focus:border-console-primary focus:outline-none"
        />
        <div class="flex flex-wrap gap-2">
            {#each WINDOWS as window (window)}
                <button
                    type="button"
                    onclick={() => selectWindow(window)}
                    class="rounded border px-3 py-1 text-sm transition-colors {activeWindow ===
                    window
                        ? 'border-console-primary text-console-highlight'
                        : 'border-console-border text-console-text-dim hover:border-console-primary hover:text-console-highlight'}"
                >
                    {t(`ships.time.${window}`)}
                </button>
            {/each}
        </div>
    </div>
</section>

<section>
    {#if initialLoading}
        <ul class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            {#each [1, 2, 3, 4, 5, 6] as skeleton (skeleton)}
                <li class="animate-pulse rounded border border-console-border bg-console-surface p-4">
                    <div class="h-4 w-1/2 rounded bg-console-surface-alt"></div>
                    <div class="mt-2 h-3 w-24 rounded bg-console-surface-alt"></div>
                </li>
            {/each}
        </ul>
    {:else if failed}
        <div class="rounded border border-console-border bg-console-surface p-4">
            <p class="text-console-danger">{t("ships.error")}</p>
            <button
                type="button"
                onclick={loadFirstPage}
                class="mt-2 rounded border border-console-border px-3 py-1 text-sm text-console-text-dim transition-colors hover:border-console-primary hover:text-console-highlight"
            >
                {t("feed.retry")}
            </button>
        </div>
    {:else if ships.length === 0}
        <p class="text-console-text-muted">{t("ships.empty")}</p>
    {:else}
        <ul class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            {#each ships as ship (ship.shipTypeId)}
                <li>
                    <a
                        href="/ship/{ship.shipTypeId}"
                        class="block rounded border border-console-border bg-console-surface p-4 transition-colors hover:border-console-primary"
                    >
                        <p class="font-semibold text-console-highlight">{ship.shipName}</p>
                        <p class="mt-1 text-xs text-console-text-muted">
                            <span class="tabular-nums">×{ship.postCount}</span>
                            · {t("ships.lastActive")}: {formatDate(ship.lastPostAt)}
                        </p>
                    </a>
                </li>
            {/each}
        </ul>
        {#if nextCursor}
            <div class="mt-4 text-center">
                {#if loadMoreFailed}
                    <p class="mb-2 text-sm text-console-danger">{t("feed.loadMoreFailed")}</p>
                {/if}
                <button
                    type="button"
                    onclick={loadMore}
                    disabled={loadingMore}
                    class="rounded border border-console-border px-4 py-2 text-sm text-console-text-dim transition-colors hover:border-console-primary hover:text-console-highlight disabled:opacity-50"
                >
                    {loadingMore ? t("feed.loadingMore") : t("feed.loadMore")}
                </button>
            </div>
        {/if}
    {/if}
</section>
