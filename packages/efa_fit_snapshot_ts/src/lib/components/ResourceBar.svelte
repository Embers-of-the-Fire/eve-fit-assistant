<script lang="ts">
interface Props {
    used: number;
    all: number;
    /** Over-budget usage turns the fill red. */
    warning?: boolean;
    /** Paints the track red (e.g. unstable capacitor). */
    dangerTrack?: boolean;
}

let { used, all, warning = true, dangerTrack = false }: Props = $props();

const fraction = $derived(all > 0 ? Math.min(Math.max(used / all, 0), 1) : 0);
const over = $derived(warning && used > all);
</script>

<div class="efa-resource-bar" class:efa-resource-danger-track={dangerTrack} role="presentation">
    <div
        class="efa-resource-fill"
        class:efa-resource-over={over}
        style:width="{fraction * 100}%"
    ></div>
</div>

<style>
    .efa-resource-bar {
        height: 6px;
        border-radius: 3px;
        background: var(--efa-bar-track, #1a2e3a);
        overflow: hidden;
    }
    .efa-resource-danger-track {
        background: color-mix(in srgb, var(--efa-danger, #ef5350) 30%, transparent);
    }
    .efa-resource-fill {
        height: 100%;
        border-radius: 3px;
        background: var(--efa-accent, #30b2e6);
    }
    .efa-resource-over {
        background: var(--efa-danger, #ef5350);
    }
</style>
