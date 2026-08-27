<script lang="ts">
import type { SnapshotModule } from "efa-proto-ts/fit_snapshot_pb";
import type { Snippet } from "svelte";
import RelatedValues from "../components/RelatedValues.svelte";
import StateIcon from "../components/StateIcon.svelte";
import TypeIcon from "../components/TypeIcon.svelte";
import { snapshotDisplay } from "../context.svelte";

interface Props {
    module: SnapshotModule;
    trailing?: Snippet;
}

let { module, trailing }: Props = $props();

const ctx = snapshotDisplay();

const type = $derived(module.type);
const charge = $derived(module.charge);
</script>

<div class="efa-row">
    <StateIcon state={module.state}>
        {#if type}
            <TypeIcon typeId={type.typeId} url={type.iconUrl} size={31} />
        {/if}
    </StateIcon>
    <div class="efa-row-body">
        <div class="efa-row-title">{type ? ctx.name(type.names) : ""}</div>
        {#if charge?.type}
            <div class="efa-row-subtitle efa-charge">
                {#if charge.quantity > 0}
                    <span>{charge.quantity} x</span>
                {/if}
                <TypeIcon typeId={charge.type.typeId} url={charge.type.iconUrl} size={16} />
                <span class="efa-charge-name">{ctx.name(charge.type.names)}</span>
            </div>
        {/if}
        {#if module.relatedValues.length > 0}
            <RelatedValues values={module.relatedValues} />
        {/if}
    </div>
    {#if trailing}
        <div class="efa-row-trailing">{@render trailing()}</div>
    {/if}
</div>

<style>
    .efa-row {
        display: flex;
        align-items: center;
        gap: 12px;
        padding: 6px 14px;
        min-height: 48px;
        box-sizing: border-box;
    }
    .efa-row-body {
        flex: 1;
        min-width: 0;
        display: flex;
        flex-direction: column;
        gap: 2px;
    }
    .efa-row-title {
        overflow: hidden;
        text-overflow: ellipsis;
        white-space: nowrap;
    }
    .efa-row-subtitle {
        font-size: 13px;
        color: var(--efa-text-dim, #9db8c6);
    }
    .efa-charge {
        display: flex;
        align-items: center;
        gap: 4px;
    }
    .efa-charge-name {
        overflow: hidden;
        text-overflow: ellipsis;
        white-space: nowrap;
    }
    .efa-row-trailing {
        flex-shrink: 0;
        color: var(--efa-text-dim, #9db8c6);
        font-variant-numeric: tabular-nums;
    }
</style>
