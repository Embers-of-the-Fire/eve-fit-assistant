<script lang="ts">
import { commaSeparated } from "../format";

interface Props {
    count: number;
    total: number;
    suffix?: string;
}

let { count, total, suffix = "" }: Props = $props();
</script>

<span class="efa-capacity-counter">
    {commaSeparated(count)} / {commaSeparated(total)}{suffix ? ` ${suffix}` : ""}
</span>

<style>
    .efa-capacity-counter {
        white-space: nowrap;
    }
</style>
