<script lang="ts">
import { onMount } from "svelte";
import { fetchThreads } from "../lib/api";
import { t } from "../lib/i18n.svelte";
import type { ThreadSummary } from "../lib/types";

interface Props {
    requestId: string;
}

const { requestId }: Props = $props();

let threads = $state<ThreadSummary[]>([]);

onMount(async () => {
    try {
        threads = await fetchThreads(requestId);
    } catch {
        threads = [];
    }
});
</script>

<section class="mt-8 rounded border border-console-border bg-console-surface p-4">
    <h2 class="mb-2 text-lg font-semibold text-console-text">{t("threads.title")}</h2>
    {#if threads.length === 0}
        <p class="text-sm text-console-text-muted">{t("threads.comingSoon")}</p>
    {:else}
        <ul class="grid gap-2">
            {#each threads as thread (thread.id)}
                <li class="text-sm text-console-text-dim">{thread.title}</li>
            {/each}
        </ul>
    {/if}
</section>
