<script lang="ts">
import { Slots_SlotState, TacticalMode_TacticalModeVariant } from "efa-proto-ts/fit_pb";
import type { SnapshotTacticalMode } from "efa-proto-ts/fit_snapshot_pb";
import EfaIcon from "../components/EfaIcon.svelte";
import StateIcon from "../components/StateIcon.svelte";
import { snapshotDisplay } from "../context.svelte";
import type { EfaIconName } from "../icons";

interface Props {
    mode: SnapshotTacticalMode;
}

let { mode }: Props = $props();

const ctx = snapshotDisplay();

const icon: EfaIconName = $derived(
    mode.variant === TacticalMode_TacticalModeVariant.DEFENSE
        ? "mode-defense"
        : mode.variant === TacticalMode_TacticalModeVariant.SPEED
          ? "mode-speed"
          : mode.variant === TacticalMode_TacticalModeVariant.TARGET
            ? "mode-target"
            : "unknown",
);
</script>

<div class="efa-row">
    <StateIcon state={Slots_SlotState.ACTIVE} shape="circle">
        <EfaIcon name={icon} size={31} />
    </StateIcon>
    <div class="efa-row-body">
        <div class="efa-row-title">{mode.type ? ctx.name(mode.type.names) : ""}</div>
    </div>
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
</style>
