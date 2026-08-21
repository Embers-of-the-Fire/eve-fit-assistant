<script lang="ts">
import { locale, t } from "../lib/i18n.svelte";
import type { PostSummary } from "../lib/types";

const { post }: { post: PostSummary } = $props();

function formatDate(iso: string): string {
    const date = new Date(iso);
    const tag = locale.current === "zh" ? "zh-CN" : "en-US";
    return Number.isNaN(date.getTime()) ? iso : date.toLocaleString(tag);
}
</script>

<a
    href="/post/{post.postId}"
    class="block rounded border border-console-border bg-console-surface p-4 transition-colors hover:border-console-primary"
>
    <p class="text-xs uppercase tracking-wide text-console-text-muted">
        {post.shipName}
    </p>
    <p class="mt-1 font-semibold text-console-highlight">
        {post.fitName || t("fits.untitled")}
    </p>
    {#if post.description}
        <p class="mt-1 line-clamp-2 text-sm text-console-text-dim">
            {post.description}
        </p>
    {/if}
    <p class="mt-2 text-xs text-console-text-muted">
        {t("fits.uploaded")}: {formatDate(post.createdAt)}{#if post.generator}
            · {post.generator}{/if}
    </p>
</a>
