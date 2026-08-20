<script lang="ts">
import type { EfaIconName } from "../icons";
import EfaIcon from "./EfaIcon.svelte";
import ResourceBar, { resourceUsage } from "./ResourceBar.svelte";

interface Props {
    icon: EfaIconName;
    used: number;
    all: number;
    unit?: string;
    warning?: boolean;
    iconSize?: number;
}

let { icon, used, all, unit, warning = true, iconSize = 28 }: Props = $props();

const usage = $derived(resourceUsage(used, all, warning));
</script>

<div class="efa-compare-row">
    <EfaIcon name={icon} size={iconSize} />
    <div class="efa-compare-body">
        <div class="efa-compare-text">
            <span class="efa-usage-{usage}">{used.toFixed(0)}</span>/{all.toFixed(0)}{unit
                ? ` ${unit}`
                : ""}
        </div>
        <ResourceBar {used} {all} {warning} />
    </div>
</div>

<style>
    .efa-compare-row {
        display: flex;
        align-items: center;
        gap: 10px;
        min-width: 0;
    }
    .efa-compare-body {
        flex: 1;
        min-width: 0;
        display: flex;
        flex-direction: column;
        gap: 4px;
    }
    .efa-compare-text {
        text-align: end;
        font-variant-numeric: tabular-nums;
    }
    .efa-usage-success {
        color: var(--efa-success, #4caf50);
    }
    .efa-usage-warning {
        color: var(--efa-warning, #ff9800);
    }
    .efa-usage-danger {
        color: var(--efa-danger, #f44336);
    }
</style>
