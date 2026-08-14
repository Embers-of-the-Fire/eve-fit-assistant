<script lang="ts">
import { onMount } from "svelte";
import "../app.css";
import { initLocale, locale, t } from "$lib/i18n.svelte";

let { children } = $props();

onMount(initLocale);
</script>

<svelte:head>
    <title>{t("title")}</title>
</svelte:head>

<header class="topbar">
    <span class="brand">EVE Fit Assistant</span>
    <button type="button" class="lang-toggle" onclick={() => locale.toggle()}>
        {t("langToggle")}
    </button>
</header>

<main>
    {@render children()}
</main>

<style>
    .topbar {
        display: flex;
        align-items: center;
        justify-content: space-between;
        padding: 16px 24px;
        border-bottom: 1px solid var(--border);
    }

    .brand {
        font-weight: 600;
        letter-spacing: 0.02em;
    }

    .lang-toggle {
        background: none;
        border: 1px solid var(--border);
        border-radius: 6px;
        color: var(--text);
        padding: 4px 12px;
        cursor: pointer;
    }
</style>
