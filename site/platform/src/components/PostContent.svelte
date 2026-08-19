<script lang="ts">
import { localizedName } from "../lib/d1";
import { locale, t } from "../lib/i18n.svelte";

interface SnapshotView {
    fitName: string;
    shipNames: Record<string, string>;
    requestId: string;
    fitHash: string;
    snapshotJson: string;
}

interface Props {
    snapshot: SnapshotView | null;
}

const { snapshot }: Props = $props();
</script>

{#if snapshot}
    <header class="mb-6">
        <h1 class="text-2xl font-bold text-console-text">
            {snapshot.fitName || t("fits.untitled")}
        </h1>
        <p class="mt-1 text-sm text-console-text-dim">
            {localizedName(snapshot.shipNames, locale.current)}
        </p>
        <p class="mt-1 font-mono text-xs break-all text-console-text-muted">
            request: {snapshot.requestId}
        </p>
        <p class="font-mono text-xs break-all text-console-text-muted">
            fit: {snapshot.fitHash}
        </p>
    </header>
    <section class="rounded border border-console-border bg-console-surface p-4">
        <h2 class="mb-2 text-lg font-semibold text-console-text">
            {t("fit.snapshotData")}
        </h2>
        <pre class="max-h-[36rem] overflow-auto rounded bg-console-deep p-3 text-xs text-console-text-dim">
{snapshot.snapshotJson}</pre>
    </section>
{:else}
    <p class="text-console-text-muted">{t("fit.notFound")}</p>
{/if}
