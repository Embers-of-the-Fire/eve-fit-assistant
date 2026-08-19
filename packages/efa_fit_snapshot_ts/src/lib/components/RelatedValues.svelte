<script lang="ts">
import type { SnapshotDisplayValue } from "efa-proto-ts/fit_snapshot_pb";
import { snapshotDisplay } from "../context.svelte";
import Glyph from "./Glyph.svelte";

interface Props {
    values: SnapshotDisplayValue[];
}

let { values }: Props = $props();

const ctx = snapshotDisplay();

function hintUrl(value: SnapshotDisplayValue): string | undefined {
    const icon = value.icon;
    if (!icon) return undefined;
    return ctx.iconHintUrl({
        graphicId: icon.graphicId !== 0 ? icon.graphicId : undefined,
        iconId: icon.iconId !== 0 ? icon.iconId : undefined,
    });
}
</script>

{#if values.length > 0}
    <div class="efa-related-values">
        {#each values as value, i (i)}
            {@const url = hintUrl(value)}
            <span class="efa-related-value">
                {#if url}
                    <img class="efa-related-icon" src={url} width="18" height="18" alt="" />
                {:else}
                    <Glyph name="unknown" size={18} />
                {/if}
                <span class="efa-related-text">{value.text}</span>
            </span>
        {/each}
    </div>
{/if}

<style>
    .efa-related-values {
        display: flex;
        flex-wrap: wrap;
        gap: 4px 10px;
        font-size: 13px;
        color: var(--efa-text-dim, #9db8c6);
        font-variant-numeric: tabular-nums;
    }
    .efa-related-value {
        display: inline-flex;
        align-items: center;
        gap: 4px;
        white-space: nowrap;
    }
    .efa-related-icon {
        display: block;
    }
</style>
