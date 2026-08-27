<script lang="ts">
import { onMount } from "svelte";
import { initLocale, t } from "../lib/i18n.svelte";

onMount(initLocale);
</script>

<footer class="mt-12 border-t border-console-border">
    <div class="mx-auto grid max-w-5xl gap-2 px-4 py-4 text-xs text-console-text-muted">
        <p>{t("legal.securityNotice")}</p>
        <p>{t("legal.secretsNotice")}</p>
        <p>{t("legal.trademarkNotice")}</p>
    </div>
</footer>
