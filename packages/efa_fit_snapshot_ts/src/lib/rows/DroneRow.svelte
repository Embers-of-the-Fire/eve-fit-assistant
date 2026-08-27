<script lang="ts">
import type { SnapshotDrone } from "efa-proto-ts/fit_snapshot_pb";
import StateIcon from "../components/StateIcon.svelte";
import TypeIcon from "../components/TypeIcon.svelte";
import { snapshotDisplay } from "../context.svelte";

interface Props {
    drone: SnapshotDrone;
}

let { drone }: Props = $props();

const ctx = snapshotDisplay();
</script>

<div class="efa-row">
    <StateIcon state={drone.state}>
        {#if drone.type}
            <TypeIcon typeId={drone.type.typeId} url={drone.type.iconUrl} size={31} />
        {/if}
    </StateIcon>
    <div class="efa-row-body">
        <div class="efa-row-title">{drone.type ? ctx.name(drone.type.names) : ""}</div>
    </div>
    <div class="efa-row-trailing">x {drone.quantity}</div>
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
    }
    .efa-row-title {
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
