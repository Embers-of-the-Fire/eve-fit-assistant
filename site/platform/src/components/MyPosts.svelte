<script lang="ts">
import { onMount, untrack } from "svelte";
import { fetchMyPosts } from "../lib/account-api";
import { authState, getSession } from "../lib/auth.svelte";
import { initLocale, locale, t } from "../lib/i18n.svelte";
import type { Locale } from "../lib/translations";
import type { PostSummary } from "../lib/types";
import PostCard from "./PostCard.svelte";

// The caller's own posts: an authenticated feed following the Frontpage
// pagination pattern over GET /platform/internal/my/posts. Like the account
// pages, the server render must match the client's first (not-yet-ready)
// render during hydration, so SSR always shows the loading state.
const PAGE_SIZE = 20;

const session = getSession();
const isServer = typeof window === "undefined";

let posts = $state<PostSummary[]>([]);
let nextCursor = $state<string | null>(null);
let initialLoading = $state(true);
let failed = $state(false);
let loadingMore = $state(false);
let feedVersion = 0;
let fetchedLocale: Locale | null = null;
let started = false;

async function loadFirstPage() {
    const version = ++feedVersion;
    fetchedLocale = locale.current;
    loadingMore = false;
    initialLoading = true;
    failed = false;
    try {
        const page = await fetchMyPosts(session, locale.current, { limit: PAGE_SIZE });
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
        const page = await fetchMyPosts(session, locale.current, {
            limit: PAGE_SIZE,
            cursor: nextCursor,
        });
        if (version !== feedVersion) return;
        posts = [...posts, ...page.posts];
        nextCursor = page.nextCursor;
    } catch {
        if (version !== feedVersion) nextCursor = null;
    } finally {
        if (version === feedVersion) loadingMore = false;
    }
}

// The feed needs the session to be settled; a signed-in identity starting (or
// changing) kicks off the first page exactly once per sign-in.
$effect(() => {
    if (!started && authState.ready && authState.identity !== null) {
        started = true;
        loadFirstPage();
    }
});

$effect(() => {
    const current = locale.current;
    if (!started || fetchedLocale === null || current === fetchedLocale) return;
    untrack(() => {
        loadFirstPage();
    });
});

onMount(() => {
    initLocale();
});
</script>

{#if isServer || !authState.ready}
    <section class="rounded border border-console-border bg-console-surface p-6">
        <h1 class="mb-2 text-2xl font-bold text-console-text">{t("myPosts.title")}</h1>
        <p class="text-console-text-muted">{t("myPosts.loading")}</p>
    </section>
{:else if authState.identity === null}
    <section class="rounded border border-console-border bg-console-surface p-6">
        <h1 class="mb-4 text-2xl font-bold text-console-text">{t("myPosts.title")}</h1>
        <p class="mb-4 text-sm text-console-text-muted">{t("myPosts.signInPrompt")}</p>
        <a
            href="/account/login"
            class="rounded bg-console-primary px-4 py-2 text-sm font-semibold text-console-deep transition-colors hover:bg-console-highlight"
        >
            {t("account.signIn")}
        </a>
    </section>
{:else}
    <section>
        <div class="mb-4 flex flex-wrap items-center justify-between gap-2">
            <h1 class="text-2xl font-bold text-console-text">{t("myPosts.title")}</h1>
            <a
                href="/account"
                class="text-xs text-console-text-dim transition-colors hover:text-console-highlight"
            >
                {t("account.backToAccount")} →
            </a>
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
            <p class="text-console-text-muted">{t("myPosts.empty")}</p>
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
{/if}
