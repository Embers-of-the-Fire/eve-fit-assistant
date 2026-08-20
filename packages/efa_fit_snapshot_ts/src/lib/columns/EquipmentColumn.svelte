<script lang="ts">
import { Subsystem_SubsystemType } from "efa-proto-ts/fit_pb";
import {
    type FitSnapshot,
    SnapshotFighter_SquadronGroup,
    SnapshotStatistics_Cargo_HoldKind,
} from "efa-proto-ts/fit_snapshot_pb";
import CapacityCounter from "../components/CapacityCounter.svelte";
import EfaIcon from "../components/EfaIcon.svelte";
import SectionHeader from "../components/SectionHeader.svelte";
import { snapshotDisplay } from "../context.svelte";
import { commaSeparated } from "../format";
import type { EfaIconName } from "../icons";
import DroneRow from "../rows/DroneRow.svelte";
import EmptySlotRow from "../rows/EmptySlotRow.svelte";
import FighterRow from "../rows/FighterRow.svelte";
import ModuleRow from "../rows/ModuleRow.svelte";
import TacticalModeRow from "../rows/TacticalModeRow.svelte";
import Rack from "./Rack.svelte";

interface Props {
    snapshot: FitSnapshot;
}

let { snapshot }: Props = $props();

const ctx = snapshotDisplay();

function subsystemPlaceholder(type: Subsystem_SubsystemType): EfaIconName {
    switch (type) {
        case Subsystem_SubsystemType.CORE:
            return "subsystem-core";
        case Subsystem_SubsystemType.DEFENSIVE:
            return "subsystem-defensive";
        case Subsystem_SubsystemType.OFFENSIVE:
            return "subsystem-offensive";
        case Subsystem_SubsystemType.PROPULSION:
            return "subsystem-propulsion";
        default:
            return "subsystem";
    }
}

const layout = $derived(snapshot.ship?.layout);

const usedTurret = $derived(
    snapshot.highSlots.filter((slot) => slot.item?.isTurret === true).length,
);
const usedLauncher = $derived(
    snapshot.highSlots.filter((slot) => slot.item?.isLauncher === true).length,
);

const stats = $derived(snapshot.statistics);

const fighters = $derived(snapshot.fighters);
const light = $derived(
    fighters.filter((f) => f.group === SnapshotFighter_SquadronGroup.LIGHT).length,
);
const heavy = $derived(
    fighters.filter((f) => f.group === SnapshotFighter_SquadronGroup.HEAVY).length,
);
const support = $derived(
    fighters.filter((f) => f.group === SnapshotFighter_SquadronGroup.SUPPORT).length,
);
const fighterBay = $derived(
    stats?.cargo?.holds.find((h) => h.kind === SnapshotStatistics_Cargo_HoldKind.FIGHTER_BAY),
);
</script>

<div class="efa-column">
    {#if snapshot.tacticalMode}
        <SectionHeader title={ctx.t("tacticalMode")} />
        <TacticalModeRow mode={snapshot.tacticalMode} />
    {/if}

    <Rack title={ctx.t("highSlot")} slots={snapshot.highSlots} placeholder="slot-high">
        {#snippet trailing()}
            {#if (layout?.turretHardpoints ?? 0) > 0 || usedTurret > 0}
                <span class="efa-hardpoint">
                    <EfaIcon name="turret-num" size={16} />
                    <span class:efa-over={usedTurret > (layout?.turretHardpoints ?? 0)}
                        >{usedTurret}</span
                    >
                    / {layout?.turretHardpoints ?? 0}
                </span>
            {/if}
            {#if (layout?.launcherHardpoints ?? 0) > 0 || usedLauncher > 0}
                <span class="efa-hardpoint">
                    <EfaIcon name="launcher-num" size={16} />
                    <span class:efa-over={usedLauncher > (layout?.launcherHardpoints ?? 0)}
                        >{usedLauncher}</span
                    >
                    / {layout?.launcherHardpoints ?? 0}
                </span>
            {/if}
        {/snippet}
    </Rack>

    <Rack title={ctx.t("midSlot")} slots={snapshot.mediumSlots} placeholder="slot-medium" />
    <Rack title={ctx.t("lowSlot")} slots={snapshot.lowSlots} placeholder="slot-low" />
    <Rack title={ctx.t("rigSlot")} slots={snapshot.rigSlots} placeholder="slot-rig" />

    {#if snapshot.subsystemSlots.length > 0}
        <SectionHeader title={ctx.t("subsystemSlot")} />
        {#each snapshot.subsystemSlots as slot (slot.index)}
            {#if slot.item}
                <ModuleRow module={slot.item} />
            {:else}
                <EmptySlotRow
                    index={slot.index}
                    slotName={ctx.t("subsystemSlot")}
                    placeholder={subsystemPlaceholder(slot.subsystemType)}
                />
            {/if}
        {/each}
    {/if}

    {#if snapshot.serviceSlots.length > 0}
        <Rack
            title={ctx.t("serviceSlot")}
            slots={snapshot.serviceSlots}
            placeholder="slot-service"
        />
    {/if}

    <SectionHeader title={ctx.t("drone")}>
        {#snippet trailing()}
            {#if stats?.drones && (stats.drones.bayCapacityM3 > 0 || stats.drones.bayUsedM3 > 0)}
                <CapacityCounter
                    count={Math.round(stats.drones.bayUsedM3)}
                    total={Math.round(stats.drones.bayCapacityM3)}
                    suffix="m³"
                />
            {/if}
        {/snippet}
    </SectionHeader>
    {#if snapshot.drones.length === 0}
        <div class="efa-section-empty">{ctx.t("slotEmpty", { slotName: ctx.t("drone") })}</div>
    {/if}
    {#each snapshot.drones as drone (drone.type?.typeId)}
        <DroneRow {drone} />
    {/each}

    {#if (layout?.fighterTubes ?? 0) > 0}
        <SectionHeader title={ctx.t("fighter")} />
        <div class="efa-fighter-counters">
            {#if heavy > 0}
                <span>H {heavy}</span>
            {/if}
            {#if light > 0}
                <span>L {light}</span>
            {/if}
            {#if support > 0}
                <span>S {support}</span>
            {/if}
            <CapacityCounter
                count={fighters.length}
                total={layout?.fighterTubes ?? 0}
                suffix="x"
            />
            {#if fighterBay}
                <span>{commaSeparated(Math.round(fighterBay.capacityM3))} m³</span>
            {/if}
        </div>
        <hr class="efa-divider" />
        {#if fighters.length === 0}
            <div class="efa-section-empty">
                {ctx.t("slotEmpty", { slotName: ctx.t("fighter") })}
            </div>
        {/if}
        {#each fighters as fighter (fighter.type?.typeId)}
            <FighterRow {fighter} />
        {/each}
    {/if}
</div>

<style>
    .efa-column {
        display: flex;
        flex-direction: column;
    }
    .efa-hardpoint {
        display: inline-flex;
        align-items: center;
        gap: 4px;
        font-variant-numeric: tabular-nums;
    }
    .efa-over {
        color: var(--efa-danger, #f44336);
    }
    .efa-fighter-counters {
        display: flex;
        justify-content: flex-end;
        align-items: center;
        gap: 10px;
        padding: 8px 10px 4px;
        font-size: 13px;
        color: var(--efa-text-dim, #9db8c6);
        font-variant-numeric: tabular-nums;
    }
    .efa-divider {
        border: none;
        border-top: 1px solid var(--efa-border, #22404f);
        margin: 4px 0;
    }
    .efa-section-empty {
        padding: 10px 14px;
        color: var(--efa-text-muted, #64808f);
    }
</style>
