<script lang="ts">
import { fromJson, type JsonValue } from "@bufbuild/protobuf";
import { FitSnapshotView } from "efa-fit-snapshot-ts";
import { FitSnapshotSchema } from "efa-proto-ts/fit_snapshot_pb";
import { localizedName } from "../lib/d1";
import { locale, t } from "../lib/i18n.svelte";

interface SnapshotView {
    fitName: string;
    shipNames: Record<string, string>;
    requestId: string;
    fitHash: string;
    snapshotJson: JsonValue;
}

interface Props {
    snapshot: SnapshotView | null;
}

const { snapshot }: Props = $props();

const fitSnapshot = $derived(snapshot ? fromJson(FitSnapshotSchema, snapshot.snapshotJson) : null);
</script>

{#if snapshot && fitSnapshot}
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
    <section class="overflow-hidden rounded border border-console-border">
        <FitSnapshotView snapshot={fitSnapshot} locale={locale.current} showHeader={false} />
    </section>
    <details class="mt-4 rounded border border-console-border bg-console-surface p-4">
        <summary class="cursor-pointer text-lg font-semibold text-console-text">
            {t("fit.snapshotData")}
        </summary>
        <pre class="mt-2 max-h-[36rem] overflow-auto rounded bg-console-deep p-3 text-xs text-console-text-dim">
{JSON.stringify(snapshot.snapshotJson, null, 2)}</pre>
    </details>
{:else}
    <p class="text-console-text-muted">{t("fit.notFound")}</p>
{/if}
