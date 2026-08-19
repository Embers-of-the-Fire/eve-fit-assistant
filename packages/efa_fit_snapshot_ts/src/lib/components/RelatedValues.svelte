<script lang="ts">
import type { SnapshotDisplayValue } from "efa-proto-ts/fit_snapshot_pb";

interface Props {
    values: SnapshotDisplayValue[];
}

let { values }: Props = $props();
</script>

{#if values.length > 0}
    <div class="efa-related-values">
        {#each values as value, i (i)}
            <span class="efa-related-value">{value.text}</span>
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
        white-space: nowrap;
    }
</style>
