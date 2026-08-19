<script module lang="ts">
export type ResourceUsage = "success" | "warning" | "danger";

/** The shared green/orange/red steps used by resource usage displays. */
export function resourceUsage(used: number, all: number, warning = true): ResourceUsage {
    if (used > all) return "danger";
    if (warning && used > all * 0.9) return "warning";
    return "success";
}
</script>

<script lang="ts">
interface Props {
    used: number;
    all: number;
    /** Near-capacity usage turns the fill orange. */
    warning?: boolean;
    /** Paints the track red (e.g. unstable capacitor). */
    dangerTrack?: boolean;
}

let { used, all, warning = true, dangerTrack = false }: Props = $props();

const fraction = $derived(all <= 0 ? (used > all ? 1 : 0) : Math.min(Math.max(used / all, 0), 1));
const usage = $derived(resourceUsage(used, all, warning));
</script>

<div class="efa-resource-bar" class:efa-resource-danger-track={dangerTrack} role="presentation">
    <div
        class="efa-resource-fill efa-fill-{usage}"
        style:width="{fraction * 100}%"
    ></div>
</div>

<style>
    .efa-resource-bar {
        height: 4px;
        border-radius: 2px;
        background: var(--efa-bar-track, #1a2e3a);
        overflow: hidden;
    }
    .efa-resource-danger-track {
        background: color-mix(in srgb, var(--efa-danger, #f44336) 30%, transparent);
    }
    .efa-resource-fill {
        height: 100%;
        border-radius: 2px;
        transition: width 300ms cubic-bezier(0.215, 0.61, 0.355, 1);
    }
    .efa-fill-success {
        background: var(--efa-success, #4caf50);
    }
    .efa-fill-warning {
        background: var(--efa-warning, #ff9800);
    }
    .efa-fill-danger {
        background: var(--efa-danger, #f44336);
    }
</style>
