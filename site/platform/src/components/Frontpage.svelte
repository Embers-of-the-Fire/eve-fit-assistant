<script lang="ts">
import { onMount, untrack } from "svelte";
import { fetchPosts, fetchStats } from "../lib/api";
import { initLocale, locale, t } from "../lib/i18n.svelte";
import { DOWNLOAD_URL, WEB_URL } from "../lib/share-target";
import type { Locale } from "../lib/translations";
import type { PlatformStats, PostSummary, TopShip } from "../lib/types";
import PostCard from "./PostCard.svelte";

const GITHUB_URL = "https://github.com/Embers-of-the-Fire/eve-fit-assistant";
const PAGE_SIZE = 20;

let stats = $state<PlatformStats | null>(null);
let posts = $state<PostSummary[]>([]);
let nextCursor = $state<string | null>(null);
let activeShip = $state<TopShip | null>(null);
let initialLoading = $state(true);
let failed = $state(false);
let loadingMore = $state(false);
let feedVersion = 0;
let statsVersion = 0;
let fetchedLocale: Locale | null = null;

async function loadStats() {
    const version = ++statsVersion;
    try {
        const value = await fetchStats(locale.current);
        if (version !== statsVersion) return;
        stats = value;
    } catch {
        if (version !== statsVersion) return;
        stats = null;
    }
}

async function loadFirstPage() {
    const version = ++feedVersion;
    fetchedLocale = locale.current;
    loadingMore = false;
    initialLoading = true;
    failed = false;
    try {
        const page = await fetchPosts(locale.current, {
            limit: PAGE_SIZE,
            shipTypeId: activeShip?.shipTypeId ?? null,
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
    try {
        const page = await fetchPosts(locale.current, {
            limit: PAGE_SIZE,
            cursor: nextCursor,
            shipTypeId: activeShip?.shipTypeId ?? null,
        });
        if (version !== feedVersion) return;
        posts = [...posts, ...page.posts];
        nextCursor = page.nextCursor;
    } catch {
        if (version === feedVersion) nextCursor = null;
    } finally {
        if (version === feedVersion) loadingMore = false;
    }
}

function selectShip(ship: TopShip) {
    activeShip = activeShip?.shipTypeId === ship.shipTypeId ? null : ship;
    loadFirstPage();
}

function clearFilter() {
    activeShip = null;
    loadFirstPage();
}

$effect(() => {
    const current = locale.current;
    if (fetchedLocale === null || current === fetchedLocale) return;
    untrack(() => {
        loadStats();
        loadFirstPage();
    });
});

onMount(() => {
    initLocale();
    loadStats();
    loadFirstPage();
});
</script>

<section class="mb-8">
    <p class="text-xs font-semibold uppercase tracking-widest text-console-primary">
        {t("home.eyebrow")}
    </p>
    <h1 class="mt-2 text-3xl font-bold tracking-tight text-console-text">{t("home.title")}</h1>
    <p class="mt-2 max-w-2xl text-sm text-console-text-dim">{t("home.desc")}</p>
    <div class="mt-4 flex flex-wrap items-center gap-3">
        <a
            href={WEB_URL}
            class="rounded bg-console-primary px-4 py-2 text-sm font-semibold text-console-deep transition-colors hover:bg-console-highlight"
        >
            {t("home.ctaApp")}
        </a>
        <a
            href={DOWNLOAD_URL}
            class="rounded border border-console-border px-4 py-2 text-sm text-console-text-dim transition-colors hover:border-console-primary hover:text-console-highlight"
        >
            {t("home.ctaDownload")}
        </a>
        <a
            href={GITHUB_URL}
            target="_blank"
            rel="noopener noreferrer"
            class="rounded border border-console-border px-4 py-2 text-sm text-console-text-dim transition-colors hover:border-console-primary hover:text-console-highlight"
        >
            {t("home.ctaGithub")}
        </a>
    </div>
</section>

{#if stats}
    <section class="mb-8 grid grid-cols-3 gap-3">
        <div class="rounded border border-console-border bg-console-surface px-4 py-3">
            <p class="text-2xl font-bold tabular-nums text-console-highlight">{stats.totalPosts}</p>
            <p class="mt-1 text-xs text-console-text-muted">{t("stats.fits")}</p>
        </div>
        <div class="rounded border border-console-border bg-console-surface px-4 py-3">
            <p class="text-2xl font-bold tabular-nums text-console-highlight">
                {stats.distinctShips}
            </p>
            <p class="mt-1 text-xs text-console-text-muted">{t("stats.ships")}</p>
        </div>
        <div class="rounded border border-console-border bg-console-surface px-4 py-3">
            <p class="text-2xl font-bold tabular-nums text-console-highlight">{stats.postsLast7d}</p>
            <p class="mt-1 text-xs text-console-text-muted">{t("stats.week")}</p>
        </div>
    </section>

    {#if stats.topShips.length > 0}
        <section class="mb-8">
            <div class="mb-3 flex items-center justify-between gap-2">
                <h2 class="text-xs font-semibold uppercase tracking-widest text-console-text-muted">
                    {t("ships.popular")}
                </h2>
                <a
                    href="/ships"
                    class="text-xs text-console-text-dim transition-colors hover:text-console-highlight"
                >
                    {t("ships.browseAll")} →
                </a>
            </div>
            <div class="flex flex-wrap gap-2">
                {#each stats.topShips as ship (ship.shipTypeId)}
                    <button
                        type="button"
                        onclick={() => selectShip(ship)}
                        class="rounded border px-3 py-1 text-sm transition-colors {activeShip?.shipTypeId ===
                        ship.shipTypeId
                            ? 'border-console-primary text-console-highlight'
                            : 'border-console-border text-console-text-dim hover:border-console-primary hover:text-console-highlight'}"
                    >
                        {ship.shipName}
                        <span class="tabular-nums text-console-text-muted">×{ship.postCount}</span>
                    </button>
                {/each}
            </div>
        </section>
    {/if}
{/if}

<section>
    <div class="mb-4 flex flex-wrap items-center justify-between gap-2">
        <h2 class="text-xs font-semibold uppercase tracking-widest text-console-text-muted">
            {t("feed.latest")}
        </h2>
        {#if activeShip}
            <div class="flex items-center gap-2 text-xs text-console-text-dim">
                <span>{t("feed.filteredBy")}: {activeShip.shipName}</span>
                <button
                    type="button"
                    aria-label={t("feed.clearFilter")}
                    onclick={clearFilter}
                    class="rounded border border-console-border px-1.5 py-0.5 text-console-text-muted transition-colors hover:border-console-primary hover:text-console-highlight"
                >
                    ✕
                </button>
            </div>
        {/if}
    </div>

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
                onclick={loadFirstPage}
                class="mt-2 rounded border border-console-border px-3 py-1 text-sm text-console-text-dim transition-colors hover:border-console-primary hover:text-console-highlight"
            >
                {t("feed.retry")}
            </button>
        </div>
    {:else if posts.length === 0}
        <p class="text-console-text-muted">
            {activeShip ? t("feed.emptyFiltered") : t("fits.empty")}
        </p>
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
