<script lang="ts">
import { snapshotDisplay } from "../context.svelte";

interface Props {
    typeId: number;
    size?: number;
}

let { typeId, size = 35 }: Props = $props();

const ctx = snapshotDisplay();
</script>

<img
    class="efa-type-icon"
    src={ctx.typeIconUrl(typeId)}
    width={size}
    height={size}
    alt=""
    loading="lazy"
    draggable="false"
/>

<style>
    .efa-type-icon {
        display: block;
        border-radius: 2px;
        object-fit: contain;
        background: var(--efa-deep, #0a1a2a);
    }
</style>
