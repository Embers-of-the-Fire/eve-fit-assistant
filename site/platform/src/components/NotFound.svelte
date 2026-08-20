<script lang="ts">
import { t } from "../lib/i18n.svelte";
</script>

<section class="rounded border border-console-border bg-console-surface p-6">
    <h1 class="text-xl font-semibold text-console-highlight">{t("notFound.title")}</h1>
    <p class="mt-2 text-sm text-console-text-dim">{t("notFound.desc")}</p>
</section>
