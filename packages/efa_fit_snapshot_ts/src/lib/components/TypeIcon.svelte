<script lang="ts">
import { snapshotDisplay } from "../context.svelte";
import EfaIcon from "./EfaIcon.svelte";

interface Props {
    typeId: number;
    /**
     * Baked, content-addressed icon URL from the snapshot (`SnapshotType.icon_url`).
     * Takes precedence over the context resolver; empty/absent falls back to
     * `ctx.typeIconUrl(typeId)` (the public EVE image server by default).
     */
    url?: string;
    size?: number;
}

let { typeId, url, size = 35 }: Props = $props();

const ctx = snapshotDisplay();

let failed = $state(false);

$effect(() => {
    void typeId;
    void url;
    failed = false;
});

const src = $derived(url || ctx.typeIconUrl(typeId));
</script>

{#if failed}
    <EfaIcon name="unknown" {size} />
{:else}
    <img
        class="efa-type-icon"
        {src}
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
