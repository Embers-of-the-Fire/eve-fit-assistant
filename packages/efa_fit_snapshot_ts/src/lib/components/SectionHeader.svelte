<script lang="ts">
import type { Snippet } from "svelte";

interface Props {
    title: string;
    trailing?: Snippet;
}

let { title, trailing }: Props = $props();
</script>

<header class="efa-section-header">
    <span class="efa-section-title">{title}</span>
    {#if trailing}
        <span class="efa-section-trailing">{@render trailing()}</span>
    {/if}
</header>

<style>
    .efa-section-header {
        display: flex;
        align-items: center;
        justify-content: space-between;
        gap: 8px;
        padding: 10px 14px 6px;
        border-bottom: 1px solid var(--efa-border, #22404f);
        margin-bottom: 2px;
    }
    .efa-section-title {
        font-size: 13px;
        font-weight: 600;
        letter-spacing: 0.06em;
        text-transform: uppercase;
        color: var(--efa-accent, #30b2e6);
    }
    .efa-section-trailing {
        display: inline-flex;
        align-items: center;
        gap: 10px;
        font-size: 13px;
        color: var(--efa-text-dim, #9db8c6);
    }
</style>
