<script lang="ts">
interface Props {
    count: number;
    total: number;
    suffix?: string;
}

let { count, total, suffix = "" }: Props = $props();
</script>

<span class="efa-capacity-counter">
    <span class:efa-over={count > total}>{count}</span>
    / {total}{suffix ? ` ${suffix}` : ""}
</span>

<style>
    .efa-capacity-counter {
        white-space: nowrap;
    }
    .efa-over {
        color: var(--efa-danger, #f44336);
    }
</style>
