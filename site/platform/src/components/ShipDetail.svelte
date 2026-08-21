<script lang="ts">
import { onMount, untrack } from "svelte";
import { fetchPosts, fetchShip } from "../lib/api";
import { initLocale, locale, t } from "../lib/i18n.svelte";
import type { Locale } from "../lib/translations";
import type { PostSummary, ShipDetail, TimeWindow } from "../lib/types";
import PostCard from "./PostCard.svelte";

const { shipTypeId }: { shipTypeId: number } = $props();

const PAGE_SIZE = 20;
const WINDOWS: TimeWindow[] = ["24h", "7d", "30d", "all"];

let detail = $state<ShipDetail | null>(null);
let detailFailed = $state(false);
let posts = $state<PostSummary[]>([]);
let nextCursor = $state<string | null>(null);
let activeWindow = $state<TimeWindow>("all");
let initialLoading = $state(true);
let failed = $state(false);
let loadingMore = $state(false);
let loadMoreFailed = $state(false);
let feedVersion = 0;
let fetchedLocale: Locale | null = null;

async function loadDetail() {
    detailFailed = false;
    try {
        detail = await fetchShip(shipTypeId, locale.current);
    } catch {
        detailFailed = true;
    }
}

async function loadFirstPage() {
    const version = ++feedVersion;
    fetchedLocale = locale.current;
    loadingMore = false;
    loadMoreFailed = false;
    initialLoading = true;
    failed = false;
    try {
        const page = await fetchPosts(locale.current, {
            limit: PAGE_SIZE,
            shipTypeId,
            window: activeWindow,
        });
        if (version !== feedVersion) return;
        posts = page.posts;
        nextCursor = page.nextCursor;
    } catch {
        if (version !== feedVersion) return;
        failed = true;
    } finally {
        if (version === feedVersion) initialLoading = false;
    }
}

async function loadMore() {
    if (!nextCursor || loadingMore) return;
    const version = feedVersion;
    loadingMore = true;
    loadMoreFailed = false;
    try {
        const page = await fetchPosts(locale.current, {
            limit: PAGE_SIZE,
            cursor: nextCursor,
            shipTypeId,
            window: activeWindow,
        });
        if (version !== feedVersion) return;
        posts = [...posts, ...page.posts];
        nextCursor = page.nextCursor;
    } catch {
        if (version !== feedVersion) return;
        loadMoreFailed = true;
    } finally {
        if (version === feedVersion) loadingMore = false;
    }
}

function selectWindow(window: TimeWindow) {
    if (activeWindow === window) return;
    activeWindow = window;
    loadFirstPage();
}

function retry() {
    loadDetail();
    loadFirstPage();
}

function formatDate(iso: string): string {
    const date = new Date(iso);
    const tag = locale.current === "zh" ? "zh-CN" : "en-US";
    return Number.isNaN(date.getTime()) ? iso : date.toLocaleString(tag);
}

$effect(() => {
    const current = locale.current;
    if (fetchedLocale === null || current === fetchedLocale) return;
    untrack(() => {
        loadDetail();
        loadFirstPage();
    });
});

onMount(() => {
    initLocale();
    loadDetail();
    loadFirstPage();
});
</script>

<section class="mb-8">
    <a
        href="/ships"
        class="text-xs text-console-text-dim transition-colors hover:text-console-highlight"
    >
        ← {t("ship.backToDirectory")}
    </a>
    {#if detail}
        <h1 class="mt-2 text-3xl font-bold tracking-tight text-console-text">{detail.shipName}</h1>
        <p class="mt-2 text-sm text-console-text-dim">
            {t("stats.fits")}: <span class="tabular-nums">{detail.postCount}</span> ·
            {t("ship.firstShared")}: {formatDate(detail.firstPostAt)} ·
            {t("ships.lastActive")}: {formatDate(detail.lastPostAt)}
        </p>
    {:else if detailFailed}
        <h1 class="mt-2 text-3xl font-bold tracking-tight text-console-text">
            {t("ship.notFound")}
        </h1>
    {:else}
        <div class="mt-2 h-8 w-48 animate-pulse rounded bg-console-surface-alt"></div>
        <div class="mt-2 h-4 w-72 animate-pulse rounded bg-console-surface-alt"></div>
    {/if}
    <div class="mt-4 flex flex-wrap gap-2">
        {#each WINDOWS as window (window)}
            <button
                type="button"
                onclick={() => selectWindow(window)}
                class="rounded border px-3 py-1 text-sm transition-colors {activeWindow === window
                    ? 'border-console-primary text-console-highlight'
                    : 'border-console-border text-console-text-dim hover:border-console-primary hover:text-console-highlight'}"
            >
                {t(`ships.time.${window}`)}
            </button>
        {/each}
    </div>
</section>

<section>
    {#if initialLoading}
        <ul class="grid gap-3">
            {#each [1, 2, 3] as skeleton (skeleton)}
                <li class="animate-pulse rounded border border-console-border bg-console-surface p-4">
                    <div class="h-3 w-24 rounded bg-console-surface-alt"></div>
                    <div class="mt-2 h-4 w-1/2 rounded bg-console-surface-alt"></div>
                    <div class="mt-2 h-3 w-3/4 rounded bg-console-surface-alt"></div>
                </li>
            {/each}
        </ul>
    {:else if failed}
        <div class="rounded border border-console-border bg-console-surface p-4">
            <p class="text-console-danger">{t("fits.error")}</p>
            <button
                type="button"
                onclick={retry}
                class="mt-2 rounded border border-console-border px-3 py-1 text-sm text-console-text-dim transition-colors hover:border-console-primary hover:text-console-highlight"
            >
                {t("feed.retry")}
            </button>
        </div>
    {:else if posts.length === 0}
        <p class="text-console-text-muted">{t("feed.emptyFiltered")}</p>
    {:else}
        <ul class="grid gap-3">
            {#each posts as post (post.postId)}
                <li>
                    <PostCard {post} />
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
