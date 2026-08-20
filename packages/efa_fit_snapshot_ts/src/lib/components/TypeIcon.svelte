<script lang="ts">
import { snapshotDisplay } from "../context.svelte";
import EfaIcon from "./EfaIcon.svelte";

interface Props {
    typeId: number;
    size?: number;
}

let { typeId, size = 35 }: Props = $props();

const ctx = snapshotDisplay();

let failed = $state(false);

$effect(() => {
    void typeId;
    failed = false;
});
</script>

{#if failed}
    <EfaIcon name="unknown" {size} />
{:else}
    <img
        class="efa-type-icon"
        src={ctx.typeIconUrl(typeId)}
        width={size}
        height={size}
        alt=""
        loading="lazy"
        draggable="false"
        onerror={() => (failed = true)}
    />
{/if}

<style>
    .efa-type-icon {
        display: block;
        border-radius: 2px;
        object-fit: contain;
    }
</style>
