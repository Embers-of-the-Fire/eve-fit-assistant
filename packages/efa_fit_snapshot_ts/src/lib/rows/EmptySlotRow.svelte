<script lang="ts">
import EfaIcon from "../components/EfaIcon.svelte";
import { snapshotDisplay } from "../context.svelte";
import type { EfaIconName } from "../icons";

interface Props {
    index: number;
    slotName: string;
    placeholder: EfaIconName;
}

let { index, slotName, placeholder }: Props = $props();

const ctx = snapshotDisplay();
</script>

<div class="efa-row efa-row-empty">
    <span class="efa-empty-icon">
        <EfaIcon name={placeholder} size={31} />
    </span>
    <div class="efa-row-body">
        <div class="efa-row-title efa-empty-title">{ctx.t("slotEmpty", { slotName })}</div>
    </div>
    <div class="efa-row-trailing">{index + 1}</div>
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
    .efa-row-body {
        flex: 1;
        min-width: 0;
    }
    .efa-empty-title {
        color: var(--efa-text-muted, #64808f);
    }
    .efa-row-trailing {
        flex-shrink: 0;
        color: var(--efa-text-dim, #9db8c6);
        font-variant-numeric: tabular-nums;
    }
</style>
