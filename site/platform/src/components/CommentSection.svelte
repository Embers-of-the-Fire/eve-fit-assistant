<script lang="ts">
import { onMount } from "svelte";
import { createComment, deleteComment } from "../lib/account-api";
import { accountAclState, loadAccountAcl } from "../lib/acl.svelte";
import { fetchComments } from "../lib/api";
import { authState, getSession } from "../lib/auth.svelte";
import { locale, t } from "../lib/i18n.svelte";
import { renderMarkdown } from "../lib/markdown";
import type { Comment } from "../lib/types";

interface Props {
    postId: string;
}

const { postId }: Props = $props();

// Discussion section on the CDN-cached post page: everything identity- or
// deletion-dependent lives in this client island, never in SSR output.
const session = getSession();
const isServer = typeof window === "undefined";

let comments = $state<Comment[]>([]);
let nextCursor = $state<string | null>(null);
let loading = $state(true);
let loadError = $state(false);
let loadingMore = $state(false);
let loadMoreError = $state(false);

let draft = $state("");
let preview = $state(false);
let submitBusy = $state(false);
let submitError = $state<string | null>(null);

let confirmingDeleteId = $state<string | null>(null);
let deleteBusy = $state(false);
let deleteError = $state<string | null>(null);

$effect(() => {
    if (authState.ready) {
        loadAccountAcl();
    }
});

const identity = $derived(authState.identity);
const canCreate = $derived(
    identity !== null && accountAclState.acl.can("comment:create") === true,
);

// Client-side gate mirroring the API's qualifier check: `all` covers any
// comment, `own` only the account's own (matching is exact).
function canDeleteComment(comment: Comment): boolean {
    if (identity === null) return false;
    const qualifiers = accountAclState.acl.can("comment:delete");
    if (qualifiers === false) return false;
    return (
        qualifiers.includes("all") ||
        (qualifiers.includes("own") && comment.authorId === identity.userId)
    );
}

function formatDate(iso: string): string {
    const date = new Date(iso);
    const tag = locale.current === "zh" ? "zh-CN" : "en-US";
    return Number.isNaN(date.getTime()) ? iso : date.toLocaleString(tag);
}

async function loadInitial() {
    loading = true;
    loadError = false;
    try {
        const page = await fetchComments(postId);
        comments = page.comments;
        nextCursor = page.nextCursor;
    } catch {
        loadError = true;
    } finally {
        loading = false;
    }
}

async function loadMore() {
    if (nextCursor === null) return;
    loadingMore = true;
    loadMoreError = false;
    try {
        const page = await fetchComments(postId, nextCursor);
        comments = [...comments, ...page.comments];
        nextCursor = page.nextCursor;
    } catch {
        loadMoreError = true;
    } finally {
        loadingMore = false;
    }
}

async function submit() {
    const body = draft.trim();
    if (body.length === 0) return;
    submitBusy = true;
    submitError = null;
    try {
        const created = await createComment(session, postId, body);
        // The new comment is the latest row. If the list is only partially
        // loaded, page forward to the end so the created comment becomes
        // visible without skipping the unloaded middle pages.
        let cursor = nextCursor;
        while (cursor !== null) {
            const page = await fetchComments(postId, cursor);
            comments = [...comments, ...page.comments];
            cursor = page.nextCursor;
        }
        nextCursor = null;
        if (!comments.some((comment) => comment.commentId === created.commentId)) {
            comments = [...comments, created];
        }
        draft = "";
        preview = false;
    } catch (err) {
        submitError =
            err instanceof Error && err.message === "forbidden"
                ? t("comments.submitForbidden")
                : t("comments.submitFailed");
    } finally {
        submitBusy = false;
    }
}

async function doDelete(commentId: string) {
    deleteBusy = true;
    deleteError = null;
    try {
        await deleteComment(session, commentId);
        comments = comments.filter((comment) => comment.commentId !== commentId);
        confirmingDeleteId = null;
    } catch (err) {
        deleteError =
            err instanceof Error && err.message === "forbidden"
                ? t("comments.deleteForbidden")
                : t("comments.deleteFailed");
    } finally {
        deleteBusy = false;
    }
}

onMount(loadInitial);
</script>

<section class="mt-8 rounded border border-console-border bg-console-surface p-4">
    <h2 class="mb-4 text-lg font-semibold text-console-text">{t("comments.title")}</h2>

    {#if loading}
        <p class="text-sm text-console-text-muted">{t("comments.loading")}</p>
    {:else if loadError}
        <p class="text-sm text-console-danger">{t("comments.error")}</p>
    {:else}
        {#if comments.length === 0}
            <p class="text-sm text-console-text-muted">{t("comments.empty")}</p>
        {:else}
            <ul class="grid gap-3">
                {#each comments as comment (comment.commentId)}
                    <li class="rounded border border-console-border bg-console-surface-alt p-3">
                        <div class="flex flex-wrap items-center justify-between gap-2">
                            <p class="text-xs text-console-text-muted">
                                {formatDate(comment.createdAt)}
                            </p>
                            {#if !isServer && canDeleteComment(comment)}
                                {#if confirmingDeleteId === comment.commentId}
                                    <span class="flex items-center gap-2">
                                        <span class="text-xs text-console-danger">
                                            {t("comments.deleteConfirm")}
                                        </span>
                                        <button
                                            type="button"
                                            onclick={() => doDelete(comment.commentId)}
                                            disabled={deleteBusy}
                                            class="rounded bg-console-danger px-2 py-0.5 text-xs font-semibold text-console-text disabled:opacity-50"
                                        >
                                            {deleteBusy ? t("account.working") : t("account.confirm")}
                                        </button>
                                        <button
                                            type="button"
                                            onclick={() => (confirmingDeleteId = null)}
                                            disabled={deleteBusy}
                                            class="rounded border border-console-border px-2 py-0.5 text-xs text-console-text-dim disabled:opacity-50"
                                        >
                                            {t("account.cancel")}
                                        </button>
                                    </span>
                                {:else}
                                    <button
                                        type="button"
                                        onclick={() => {
                                            confirmingDeleteId = comment.commentId;
                                            deleteError = null;
                                        }}
                                        class="rounded border border-console-danger/50 px-2 py-0.5 text-xs text-console-danger transition-colors hover:bg-console-danger hover:text-console-text"
                                    >
                                        {t("comments.delete")}
                                    </button>
                                {/if}
                            {/if}
                        </div>
                        <!-- Bodies are untrusted markdown; renderMarkdown sanitizes. -->
                        <div class="markdown-body mt-2 text-sm text-console-text">
                            {@html renderMarkdown(comment.body)}
                        </div>
                    </li>
                {/each}
            </ul>
        {/if}

        {#if deleteError !== null}
            <p class="mt-3 rounded border border-console-danger/50 bg-console-danger/10 px-3 py-2 text-sm text-console-danger">
                {deleteError}
            </p>
        {/if}

        {#if nextCursor !== null}
            <div class="mt-4">
                <button
                    type="button"
                    onclick={loadMore}
                    disabled={loadingMore}
                    class="rounded border border-console-border px-3 py-1 text-xs text-console-text-dim transition-colors hover:border-console-primary hover:text-console-highlight disabled:opacity-50"
                >
                    {loadingMore ? t("comments.loadingMore") : t("comments.loadMore")}
                </button>
                {#if loadMoreError}
                    <p class="mt-2 text-xs text-console-danger">{t("comments.loadMoreFailed")}</p>
                {/if}
            </div>
        {/if}

        {#if !isServer && authState.ready}
            {#if identity === null}
                <p class="mt-4 border-t border-console-border pt-4 text-sm">
                    <a
                        href="/account/login"
                        class="text-console-primary transition-colors hover:text-console-highlight"
                    >
                        {t("comments.signInPrompt")}
                    </a>
                </p>
            {:else if canCreate}
                <div class="mt-4 border-t border-console-border pt-4">
                    <div class="mb-2 flex items-center gap-2">
                        <button
                            type="button"
                            onclick={() => (preview = false)}
                            class="rounded px-2 py-0.5 text-xs {preview
                                ? 'text-console-text-dim hover:text-console-highlight'
                                : 'bg-console-surface-alt font-semibold text-console-text'}"
                        >
                            {t("comments.write")}
                        </button>
                        <button
                            type="button"
                            onclick={() => (preview = true)}
                            class="rounded px-2 py-0.5 text-xs {preview
                                ? 'bg-console-surface-alt font-semibold text-console-text'
                                : 'text-console-text-dim hover:text-console-highlight'}"
                        >
                            {t("comments.preview")}
                        </button>
                        <span class="ml-auto text-xs text-console-text-muted">
                            {t("comments.markdownHint")}
                        </span>
                    </div>
                    {#if preview}
                        <div
                            class="markdown-body min-h-24 w-full rounded border border-console-border bg-console-deep p-2 text-sm text-console-text"
                        >
                            {#if draft.trim().length > 0}
                                {@html renderMarkdown(draft)}
                            {:else}
                                <p class="text-console-text-muted">{t("comments.placeholder")}</p>
                            {/if}
                        </div>
                    {:else}
                        <textarea
                            bind:value={draft}
                            rows="4"
                            maxlength="10000"
                            placeholder={t("comments.placeholder")}
                            class="w-full rounded border border-console-border bg-console-deep p-2 text-sm text-console-text placeholder:text-console-text-muted focus:border-console-primary focus:outline-none"
                        ></textarea>
                    {/if}
                    {#if submitError !== null}
                        <p class="mt-2 rounded border border-console-danger/50 bg-console-danger/10 px-3 py-2 text-sm text-console-danger">
                            {submitError}
                        </p>
                    {/if}
                    <div class="mt-2 flex justify-end">
                        <button
                            type="button"
                            onclick={submit}
                            disabled={submitBusy || draft.trim().length === 0}
                            class="rounded border border-console-primary px-3 py-1 text-xs font-semibold text-console-primary transition-colors hover:bg-console-primary hover:text-console-deep disabled:opacity-50"
                        >
                            {submitBusy ? t("account.working") : t("comments.submit")}
                        </button>
                    </div>
                </div>
            {/if}
        {/if}
    {/if}
</section>
