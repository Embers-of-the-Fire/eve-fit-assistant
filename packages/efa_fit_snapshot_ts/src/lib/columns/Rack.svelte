<script lang="ts">
import type { SnapshotSlot } from "efa-proto-ts/fit_snapshot_pb";
import type { Snippet } from "svelte";
import SectionHeader from "../components/SectionHeader.svelte";
import { snapshotDisplay } from "../context.svelte";
import type { EfaIconName } from "../icons";
import EmptySlotRow from "../rows/EmptySlotRow.svelte";
import ModuleRow from "../rows/ModuleRow.svelte";

interface Props {
    title: string;
    slots: SnapshotSlot[];
    placeholder: EfaIconName;
    trailing?: Snippet;
}

let { title, slots, placeholder, trailing }: Props = $props();

const ctx = snapshotDisplay();
</script>

<SectionHeader {title} {trailing} />
{#each slots as slot (slot.index)}
    {#if slot.item}
        <ModuleRow module={slot.item} />
    {:else}
        <EmptySlotRow index={slot.index} slotName={title} {placeholder} />
    {/if}
{/each}
{#if slots.length === 0}
    <div class="efa-rack-empty">{ctx.t("slotEmpty", { slotName: title })}</div>
{/if}

<style>
    .efa-rack-empty {
        padding: 10px 14px;
        color: var(--efa-text-muted, #64808f);
    }
</style>
