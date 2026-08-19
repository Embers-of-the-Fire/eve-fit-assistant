<script lang="ts">
import { type FitSnapshot, SnapshotCharacter_Builtin } from "efa-proto-ts/fit_snapshot_pb";
import Glyph from "../components/Glyph.svelte";
import SectionHeader from "../components/SectionHeader.svelte";
import StateIcon from "../components/StateIcon.svelte";
import TypeIcon from "../components/TypeIcon.svelte";
import { snapshotDisplay } from "../context.svelte";
import ModuleRow from "../rows/ModuleRow.svelte";

interface Props {
    snapshot: FitSnapshot;
}

let { snapshot }: Props = $props();

const ctx = snapshotDisplay();

const characterName = $derived.by(() => {
    const character = snapshot.character;
    if (!character) return "";
    if (Object.keys(character.names).length > 0) return ctx.name(character.names);
    switch (character.builtin) {
        case SnapshotCharacter_Builtin.ALL_5:
            return ctx.t("skillProfileAll5");
        case SnapshotCharacter_Builtin.ALL_0:
            return ctx.t("skillProfileAll0");
        case SnapshotCharacter_Builtin.ALPHA_MAX:
            return ctx.t("skillProfileAlphaMax");
        default:
            return "";
    }
});
</script>

<div class="efa-column">
    <div class="efa-character-header">
        <Glyph name="person" size={22} />
        <span class="efa-character-name">{characterName}</span>
    </div>
    <hr class="efa-divider" />

    <SectionHeader title={ctx.t("implantSlot")} />
    {#each snapshot.implants as implant (implant.slotIndex)}
        {#if implant.item}
            <ModuleRow module={implant.item} />
        {:else}
            <div class="efa-row">
                <span class="efa-empty-icon">
                    <Glyph name="implant" size={20} />
                </span>
                <div class="efa-row-body">
                    <div class="efa-empty-title">
                        {ctx.t("slotEmpty", { slotName: ctx.t("implantSlot") })}
                    </div>
                </div>
                <div class="efa-row-trailing">{implant.slotIndex}</div>
            </div>
        {/if}
    {/each}

    <SectionHeader title={ctx.t("boosterSlot")} />
    {#if snapshot.boosters.length === 0}
        <div class="efa-section-empty">
            {ctx.t("slotEmpty", { slotName: ctx.t("boosterSlot") })}
        </div>
    {/if}
    {#each snapshot.boosters as booster (booster.slotIndex)}
        <div class="efa-row">
            <StateIcon state={booster.state}>
                {#if booster.type}
                    <TypeIcon typeId={booster.type.typeId} size={31} />
                {/if}
            </StateIcon>
            <div class="efa-row-body">
                <div class="efa-row-title">
                    {booster.type ? ctx.name(booster.type.names) : ""}
                </div>
                <div class="efa-row-subtitle">{ctx.t("boosterSlot")} {booster.slotIndex}</div>
            </div>
        </div>
    {/each}
</div>

<style>
    .efa-column {
        display: flex;
        flex-direction: column;
    }
    .efa-character-header {
        display: flex;
        align-items: center;
        justify-content: center;
        gap: 8px;
        padding: 12px 14px;
        color: var(--efa-text, #e0f4ff);
    }
    .efa-character-name {
        font-weight: 400;
    }
    .efa-divider {
        border: none;
        border-top: 1px solid var(--efa-border, #22404f);
        margin: 0;
    }
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
    .efa-row-trailing {
        flex-shrink: 0;
        color: var(--efa-text-dim, #9db8c6);
        font-variant-numeric: tabular-nums;
    }
    .efa-empty-icon {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        width: 35px;
        height: 35px;
        flex-shrink: 0;
        border: 2px solid var(--efa-state-passive, #2d2d2d);
        border-radius: 2px;
        background: var(--efa-state-passive, #2d2d2d);
        color: var(--efa-text-muted, #64808f);
        box-sizing: border-box;
    }
    .efa-empty-title {
        color: var(--efa-text-muted, #64808f);
    }
    .efa-section-empty {
        padding: 10px 14px;
        color: var(--efa-text-muted, #64808f);
    }
</style>
