<script lang="ts">
import {
    type FitSnapshot,
    type SnapshotStatistics_Cargo_HoldKind as HoldKindType,
    SnapshotStatistics_Cargo_HoldKind,
    type SnapshotStatistics_DefenseLayer,
} from "efa-proto-ts/fit_snapshot_pb";
import CompareRow from "../components/CompareRow.svelte";
import Glyph from "../components/Glyph.svelte";
import ResonanceBox from "../components/ResonanceBox.svelte";
import ResourceBar from "../components/ResourceBar.svelte";
import TypeIcon from "../components/TypeIcon.svelte";
import { snapshotDisplay } from "../context.svelte";
import { commaSeparated, formatDuration, toMaxDecimals } from "../format";
import type { GlyphName } from "../glyphs";

interface Props {
    snapshot: FitSnapshot;
}

let { snapshot }: Props = $props();

const ctx = snapshotDisplay();

const stats = $derived(snapshot.statistics);
const ship = $derived(snapshot.ship?.type);
const profile = $derived(snapshot.damageProfile);

const capacitor = $derived(stats?.capacitor);
const capPercent = $derived(
    capacitor?.isStable === true ? Math.min(Math.max(capacitor.stableFraction * 100, 0), 100) : 0,
);
const capDelta = $derived((capacitor?.peakRechargeRate ?? 0) - (capacitor?.peakUseRate ?? 0));

const hpTotal = $derived(
    (stats?.shield?.hp ?? 0) + (stats?.armor?.hp ?? 0) + (stats?.hull?.hp ?? 0),
);
const ehpTotal = $derived(
    (stats?.shield?.ehp ?? 0) + (stats?.armor?.ehp ?? 0) + (stats?.hull?.ehp ?? 0),
);
const maxEhpGlyph: GlyphName = $derived.by(() => {
    const shield = stats?.shield?.ehp ?? 0;
    const armor = stats?.armor?.ehp ?? 0;
    const hull = stats?.hull?.ehp ?? 0;
    if (shield >= armor && shield >= hull) return "hp-shield";
    return armor >= hull ? "hp-armor" : "hp-hull";
});

const defenseLayers: { glyph: GlyphName; layer: SnapshotStatistics_DefenseLayer }[] = $derived.by(
    () => {
        const layers: { glyph: GlyphName; layer: SnapshotStatistics_DefenseLayer }[] = [];
        if (stats?.shield) layers.push({ glyph: "hp-shield", layer: stats.shield });
        if (stats?.armor) layers.push({ glyph: "hp-armor", layer: stats.armor });
        if (stats?.hull) layers.push({ glyph: "hp-hull", layer: stats.hull });
        return layers;
    },
);

const maxSensor: { glyph: GlyphName; value: number } = $derived.by(() => {
    const targeting = stats?.targeting;
    const radar = targeting?.radarStrength ?? 0;
    const ladar = targeting?.ladarStrength ?? 0;
    const magnetometric = targeting?.magnetometricStrength ?? 0;
    const gravimetric = targeting?.gravimetricStrength ?? 0;
    if (radar >= ladar && radar >= magnetometric && radar >= gravimetric) {
        return { glyph: "sensor-radar", value: radar };
    }
    if (ladar >= magnetometric && ladar >= gravimetric) {
        return { glyph: "sensor-ladar", value: ladar };
    }
    if (magnetometric >= gravimetric) {
        return { glyph: "sensor-magnetometric", value: magnetometric };
    }
    return { glyph: "sensor-gravimetric", value: gravimetric };
});

const HOLD_GLYPHS: Record<HoldKindType, GlyphName> = {
    [SnapshotStatistics_Cargo_HoldKind.FLEET_HANGAR]: "hold-fleet",
    [SnapshotStatistics_Cargo_HoldKind.SHIP_MAINTENANCE_BAY]: "hold-ship",
    [SnapshotStatistics_Cargo_HoldKind.FIGHTER_BAY]: "drone-bandwidth",
    [SnapshotStatistics_Cargo_HoldKind.MINING_HOLD]: "hold-mining",
    [SnapshotStatistics_Cargo_HoldKind.GAS_HOLD]: "hold-gas",
    [SnapshotStatistics_Cargo_HoldKind.MINERAL_HOLD]: "hold-mineral",
    [SnapshotStatistics_Cargo_HoldKind.ICE_HOLD]: "hold-ice",
    [SnapshotStatistics_Cargo_HoldKind.COMMAND_CENTER_HOLD]: "hold-command",
    [SnapshotStatistics_Cargo_HoldKind.PLANETARY_COMMODITIES_HOLD]: "hold-planetary",
    [SnapshotStatistics_Cargo_HoldKind.FUEL_BAY]: "hold-fuel",
    [SnapshotStatistics_Cargo_HoldKind.AMMO_HOLD]: "alpha",
    [SnapshotStatistics_Cargo_HoldKind.QUAFE_BAY]: "cargo",
};

function holdGlyph(kind: HoldKindType): GlyphName {
    return HOLD_GLYPHS[kind] ?? "cargo";
}
</script>

{#if stats}
    <div class="efa-column">
        <div class="efa-ship-header">
            {#if ship}
                <TypeIcon typeId={ship.typeId} size={40} />
                <span class="efa-ship-name">{ctx.name(ship.names)}</span>
            {/if}
        </div>
        <hr class="efa-divider" />

        {#if capacitor}
            <div class="efa-stat-row">
                <Glyph name="capacitor" size={28} />
                <div class="efa-stat-body">
                    <div class="efa-stat-line">
                        {#if !capacitor.isStable && capacitor.depletesInS > 0}
                            <span class="efa-danger">{formatDuration(capacitor.depletesInS)}</span>
                        {:else if capacitor.isStable}
                            <span class="efa-success">
                                {ctx.t("capacitorStable", { percent: capPercent.toFixed(1) })}
                            </span>
                        {:else}
                            <span class="efa-danger">{ctx.t("capacitorUnstable")}</span>
                        {/if}
                        <span class="efa-sep">|</span>
                        <span class:efa-danger={capDelta < 0} class:efa-success={capDelta >= 0}>
                            {capDelta < 0 ? "-" : "+"}{toMaxDecimals(Math.abs(capDelta), 2)} GJ/s
                        </span>
                        <span class="efa-sep">|</span>
                        <span>{Math.round(capacitor.capacityGj)} GJ</span>
                    </div>
                    <ResourceBar
                        used={capPercent}
                        all={100}
                        warning={false}
                        dangerTrack={!capacitor.isStable}
                    />
                </div>
            </div>
        {/if}

        {#if stats.weapons}
            <div class="efa-stat-row">
                <Glyph name="alpha" size={28} />
                <div class="efa-stat-body">
                    <div class="efa-stat-line">
                        <span>{stats.weapons.dpsTotal.toFixed(1)}/s</span>
                        <span class="efa-sep">|</span>
                        <span>{stats.weapons.dpsWithReload.toFixed(1)}/s</span>
                        <span class="efa-sep">|</span>
                        <span>{stats.weapons.alphaVolley.toFixed(1)}</span>
                    </div>
                </div>
            </div>
        {/if}

        {#if stats.resources}
            <div class="efa-resources">
                <CompareRow
                    icon="cpu"
                    used={stats.resources.cpuUsed}
                    all={stats.resources.cpuTotal}
                    unit="tf"
                />
                <CompareRow
                    icon="power"
                    used={stats.resources.powergridUsed}
                    all={stats.resources.powergridTotal}
                    unit="MW"
                />
                <div class="efa-resources-split">
                    <CompareRow
                        icon="rig"
                        used={stats.resources.calibrationUsed}
                        all={stats.resources.calibrationTotal}
                        warning={false}
                    />
                    <CompareRow
                        icon="drone-bandwidth"
                        used={stats.resources.droneBandwidthUsed}
                        all={stats.resources.droneBandwidthTotal}
                        unit="MB/s"
                        warning={false}
                    />
                </div>
            </div>
        {/if}

        {#if stats.shield && stats.armor && stats.hull}
            <div class="efa-stat-row">
                <Glyph name={maxEhpGlyph} size={36} />
                <div class="efa-stat-body">
                    <div class="efa-stat-line">
                        <span>{Math.round(hpTotal)} HP</span>
                        <span class="efa-sep">|</span>
                        <span>{Math.round(ehpTotal)} EHP</span>
                    </div>
                </div>
            </div>
            <table class="efa-defense">
                <thead>
                    <tr>
                        <th></th>
                        <th>HP</th>
                        <th>EHP</th>
                        <th><Glyph name="resist-em" size={20} color="#4d9fff" /></th>
                        <th><Glyph name="resist-thermal" size={20} color="#e5484d" /></th>
                        <th><Glyph name="resist-kinetic" size={20} color="#9aa4af" /></th>
                        <th><Glyph name="resist-explosive" size={20} color="#f5a623" /></th>
                    </tr>
                </thead>
                <tbody>
                    {#each defenseLayers as { glyph, layer } (glyph)}
                        <tr>
                            <td><Glyph name={glyph} size={20} /></td>
                            <td>{Math.round(layer.hp)}</td>
                            <td>{Math.round(layer.ehp)}</td>
                            <td>
                                <ResonanceBox ratio={1 - (layer.resistances?.em ?? 0)} type="em" />
                            </td>
                            <td>
                                <ResonanceBox
                                    ratio={1 - (layer.resistances?.thermal ?? 0)}
                                    type="thermal"
                                />
                            </td>
                            <td>
                                <ResonanceBox
                                    ratio={1 - (layer.resistances?.kinetic ?? 0)}
                                    type="kinetic"
                                />
                            </td>
                            <td>
                                <ResonanceBox
                                    ratio={1 - (layer.resistances?.explosive ?? 0)}
                                    type="explosive"
                                />
                            </td>
                        </tr>
                    {/each}
                    {#if profile}
                        <tr>
                            <td><Glyph name="turret" size={20} /></td>
                            <td></td>
                            <td></td>
                            <td><ResonanceBox ratio={1 - profile.em} type="em" /></td>
                            <td><ResonanceBox ratio={1 - profile.thermal} type="thermal" /></td>
                            <td><ResonanceBox ratio={1 - profile.kinetic} type="kinetic" /></td>
                            <td><ResonanceBox ratio={1 - profile.explosive} type="explosive" /></td>
                        </tr>
                    {/if}
                </tbody>
            </table>
        {/if}

        {#if stats.mobility && stats.targeting}
            <table class="efa-pairs">
                <tbody>
                    <tr>
                        <td><Glyph name="speed" size={20} /></td>
                        <td>{toMaxDecimals(stats.mobility.maxVelocityMs, 1)} m/s</td>
                        <td></td>
                        <td><Glyph name="warp" size={20} /></td>
                        <td>{toMaxDecimals(stats.mobility.warpSpeedAuS, 1)} AU/s</td>
                    </tr>
                    <tr>
                        <td><Glyph name="target-range" size={20} /></td>
                        <td>{Math.round(stats.targeting.maxTargetRangeM / 1000)} km</td>
                        <td></td>
                        <td><Glyph name="scan-resolution" size={20} /></td>
                        <td>{Math.round(stats.targeting.scanResolutionMm)} mm</td>
                    </tr>
                    <tr>
                        <td><Glyph name="lock-num" size={20} /></td>
                        <td>{stats.targeting.maxLockedTargets}</td>
                        <td></td>
                        <td><Glyph name={maxSensor.glyph} size={20} /></td>
                        <td>{toMaxDecimals(maxSensor.value, 1)}</td>
                    </tr>
                    <tr>
                        <td><Glyph name="align-time" size={20} /></td>
                        <td>{toMaxDecimals(stats.mobility.alignTimeS, 2)} s</td>
                        <td></td>
                        <td><Glyph name="signature" size={20} /></td>
                        <td>{toMaxDecimals(stats.mobility.signatureRadiusM, 0)} m</td>
                    </tr>
                </tbody>
            </table>
        {/if}

        {#if stats.drones}
            <table class="efa-pairs">
                <tbody>
                    <tr>
                        <td><Glyph name="drone" size={20} /></td>
                        <td>{stats.drones.maxActiveDrones}</td>
                        <td></td>
                        <td><Glyph name="drone-range" size={20} /></td>
                        <td>{toMaxDecimals(stats.drones.controlRangeM / 1000, 1)} km</td>
                    </tr>
                </tbody>
            </table>
        {/if}

        {#if stats.cargo}
            <div class="efa-cargo">
                <div class="efa-stat-row">
                    <Glyph name="mass" size={28} />
                    <div class="efa-stat-body">
                        <div class="efa-stat-line">{commaSeparated(stats.cargo.massKg)} kg</div>
                    </div>
                </div>
                <div class="efa-stat-row">
                    <Glyph name="cargo" size={28} />
                    <div class="efa-stat-body">
                        <div class="efa-stat-line">{commaSeparated(stats.cargo.capacityM3)} m³</div>
                    </div>
                </div>
                {#each stats.cargo.holds as hold (hold.kind)}
                    <div class="efa-stat-row">
                        <span class="efa-hold-icons">
                            <Glyph name="cargo" size={28} />
                            <Glyph name={holdGlyph(hold.kind)} size={28} />
                        </span>
                        <div class="efa-stat-body">
                            <div class="efa-stat-line">
                                {commaSeparated(hold.capacityM3)} m³
                            </div>
                        </div>
                    </div>
                {/each}
            </div>
        {/if}
    </div>
{/if}

<style>
    .efa-column {
        display: flex;
        flex-direction: column;
        gap: 8px;
        padding-bottom: 8px;
    }
    .efa-ship-header {
        display: flex;
        flex-direction: column;
        align-items: center;
        gap: 8px;
        padding: 12px 14px 8px;
    }
    .efa-ship-name {
        font-weight: 700;
        text-align: center;
    }
    .efa-divider {
        border: none;
        border-top: 1px solid var(--efa-border, #22404f);
        margin: 0;
    }
    .efa-stat-row {
        display: flex;
        align-items: center;
        gap: 12px;
        padding: 2px 20px;
    }
    .efa-stat-body {
        flex: 1;
        min-width: 0;
        display: flex;
        flex-direction: column;
        gap: 4px;
    }
    .efa-stat-line {
        display: flex;
        flex-wrap: wrap;
        justify-content: flex-end;
        gap: 6px;
        font-variant-numeric: tabular-nums;
    }
    .efa-sep {
        color: var(--efa-text-muted, #64808f);
    }
    .efa-success {
        color: var(--efa-success, #2e7d32);
    }
    .efa-danger {
        color: var(--efa-danger, #ef5350);
    }
    .efa-resources {
        display: flex;
        flex-direction: column;
        gap: 10px;
        padding: 0 20px;
    }
    .efa-resources-split {
        display: grid;
        grid-template-columns: 1fr 1fr;
        gap: 10px;
    }
    .efa-defense,
    .efa-pairs {
        width: calc(100% - 40px);
        margin: 0 20px;
        border-collapse: collapse;
        font-variant-numeric: tabular-nums;
    }
    .efa-defense th {
        font-weight: 400;
        color: var(--efa-text-dim, #9db8c6);
    }
    .efa-defense th,
    .efa-defense td,
    .efa-pairs td {
        text-align: center;
        vertical-align: middle;
        padding: 2px;
    }
    .efa-defense th:first-child,
    .efa-defense td:first-child,
    .efa-pairs td:first-child,
    .efa-pairs td:nth-child(4) {
        width: 28px;
    }
    .efa-pairs td:nth-child(2),
    .efa-pairs td:nth-child(5) {
        text-align: end;
    }
    .efa-cargo {
        display: flex;
        flex-direction: column;
        gap: 8px;
    }
    .efa-hold-icons {
        display: inline-flex;
        gap: 6px;
        flex-shrink: 0;
    }
</style>
