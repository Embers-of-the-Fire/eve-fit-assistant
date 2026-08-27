<script lang="ts">
import { type SnapshotFighter, SnapshotFighter_Ability } from "efa-proto-ts/fit_snapshot_pb";
import RelatedValues from "../components/RelatedValues.svelte";
import StateIcon from "../components/StateIcon.svelte";
import TypeIcon from "../components/TypeIcon.svelte";
import { snapshotDisplay } from "../context.svelte";
import type { SnapshotMessageKey } from "../i18n";

interface Props {
    fighter: SnapshotFighter;
}

let { fighter }: Props = $props();

const ctx = snapshotDisplay();

const ABILITY_LABELS: Record<SnapshotFighter_Ability, SnapshotMessageKey> = {
    [SnapshotFighter_Ability.TURRET]: "fighterAbilityTurret",
    [SnapshotFighter_Ability.MISSILES]: "fighterAbilityMissiles",
    [SnapshotFighter_Ability.ATTACK_MISSILES]: "fighterAbilityAttackMissiles",
    [SnapshotFighter_Ability.BOMB]: "fighterAbilityBomb",
};

function abilityLabel(ability: SnapshotFighter_Ability): string {
    const key = ABILITY_LABELS[ability];
    return key ? ctx.t(key) : String(ability);
}
</script>

<div class="efa-row">
    <StateIcon state={fighter.state}>
        {#if fighter.type}
            <TypeIcon typeId={fighter.type.typeId} url={fighter.type.iconUrl} size={31} />
        {/if}
    </StateIcon>
    <div class="efa-row-body">
        <div class="efa-row-title">{fighter.type ? ctx.name(fighter.type.names) : ""}</div>
        {#if fighter.abilities.length > 0}
            <div class="efa-abilities">
                {#each fighter.abilities as ability (ability)}
                    <span class="efa-chip">{abilityLabel(ability)}</span>
                {/each}
            </div>
        {/if}
        {#if fighter.relatedValues.length > 0}
            <RelatedValues values={fighter.relatedValues} />
        {/if}
    </div>
    <div class="efa-row-trailing">x {fighter.quantity} / {fighter.maxSquadronSize}</div>
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
        gap: 4px;
    }
    .efa-row-title {
        overflow: hidden;
        text-overflow: ellipsis;
        white-space: nowrap;
    }
    .efa-abilities {
        display: flex;
        flex-wrap: wrap;
        gap: 4px 6px;
    }
    .efa-chip {
        font-size: 11px;
        padding: 1px 8px;
        border: 1px solid var(--efa-border, #22404f);
        border-radius: 999px;
        color: var(--efa-text-dim, #9db8c6);
        white-space: nowrap;
    }
    .efa-row-trailing {
        flex-shrink: 0;
        color: var(--efa-text-dim, #9db8c6);
        font-variant-numeric: tabular-nums;
    }
</style>
