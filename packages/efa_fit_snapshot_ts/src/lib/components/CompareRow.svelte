<script lang="ts">
import { commaSeparated, toMaxDecimals } from "../format";
import type { GlyphName } from "../glyphs";
import Glyph from "./Glyph.svelte";
import ResourceBar from "./ResourceBar.svelte";

interface Props {
    icon: GlyphName;
    used: number;
    all: number;
    unit?: string;
    warning?: boolean;
    iconSize?: number;
}

let { icon, used, all, unit, warning = true, iconSize = 28 }: Props = $props();
</script>

<div class="efa-compare-row">
    <Glyph name={icon} size={iconSize} />
    <div class="efa-compare-body">
        <div class="efa-compare-text" class:efa-compare-over={warning && used > all}>
            {commaSeparated(Math.round(used * 10) / 10)} / {toMaxDecimals(all, 1)}{unit
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
    .efa-compare-over {
        color: var(--efa-danger, #ef5350);
    }
</style>
