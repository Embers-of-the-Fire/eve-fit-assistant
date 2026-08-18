<script lang="ts">
import { onMount } from "svelte";
import { fetchFits } from "../lib/api";
import { locale, t } from "../lib/i18n.svelte";
import type { FitListEntry } from "../lib/types";

let fits = $state<FitListEntry[]>([]);
let loading = $state(true);
let failed = $state(false);

onMount(async () => {
    try {
        fits = await fetchFits();
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
    {:else if fits.length === 0}
        <p class="text-console-text-muted">{t("fits.empty")}</p>
    {:else}
        <ul class="grid gap-3">
            {#each fits as fit (fit.requestId)}
                <li>
                    <a
                        href="/post/{fit.requestId}"
                        class="block rounded border border-console-border bg-console-surface p-4 transition-colors hover:border-console-primary"
                    >
                        <div class="flex items-baseline justify-between gap-4">
                            <span class="font-semibold text-console-highlight">
                                {fit.fitName || t("fits.untitled")}
                            </span>
                            <span class="text-sm text-console-text-dim">{fit.shipName}</span>
                        </div>
                        <div class="mt-1 text-xs text-console-text-muted">
                            {t("fits.uploaded")}: {formatDate(fit.createdAt)}
                        </div>
                    </a>
                </li>
            {/each}
        </ul>
    {/if}
</section>
