<script lang="ts">
import { onMount } from "svelte";
import { fetchPosts } from "../lib/api";
import { locale, t } from "../lib/i18n.svelte";
import type { PostSummary } from "../lib/types";

let posts = $state<PostSummary[]>([]);
let loading = $state(true);
let failed = $state(false);

onMount(async () => {
    try {
        posts = await fetchPosts(locale.current);
    } catch {
        failed = true;
    } finally {
        loading = false;
    }
});

function formatDate(iso: string): string {
    const date = new Date(iso);
    const tag = locale.current === "zh" ? "zh-CN" : "en-US";
    return Number.isNaN(date.getTime()) ? iso : date.toLocaleString(tag);
}
</script>

<section>
    <h1 class="mb-6 text-2xl font-bold text-console-text">{t("fits.title")}</h1>

    {#if loading}
        <p class="text-console-text-muted">{t("fits.loading")}</p>
    {:else if failed}
        <p class="text-console-danger">{t("fits.error")}</p>
    {:else if posts.length === 0}
        <p class="text-console-text-muted">{t("fits.empty")}</p>
    {:else}
        <ul class="grid gap-3">
            {#each posts as post (post.postId)}
                <li>
                    <a
                        href="/post/{post.postId}"
                        class="block rounded border border-console-border bg-console-surface p-4 transition-colors hover:border-console-primary"
                    >
                        <div class="flex items-baseline justify-between gap-4">
                            <span class="font-semibold text-console-highlight">
                                {post.fitName || t("fits.untitled")}
                            </span>
                            <span class="text-sm text-console-text-dim">{post.shipName}</span>
                        </div>
                        {#if post.description}
                            <p class="mt-1 line-clamp-2 text-sm text-console-text-dim">
                                {post.description}
                            </p>
                        {/if}
                        <div class="mt-1 text-xs text-console-text-muted">
                            {t("fits.uploaded")}: {formatDate(post.createdAt)}
                        </div>
                    </a>
                </li>
            {/each}
        </ul>
    {/if}
</section>
