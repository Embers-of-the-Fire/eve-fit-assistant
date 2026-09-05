<script lang="ts">
import { onMount } from "svelte";
import { initLocale, locale, t } from "../lib/i18n.svelte";

onMount(initLocale);
</script>

<header class="border-b border-console-border bg-console-surface">
    <div class="mx-auto flex h-14 max-w-5xl items-center gap-6 px-4">
        <a href="/" class="text-lg font-bold tracking-wide text-console-primary">
            EFA <span class="text-console-text">Platform</span>
        </a>
        <nav class="flex flex-1 items-center gap-4 text-sm">
            <a href="/" class="text-console-text-dim transition-colors hover:text-console-highlight">
                {t("nav.fits")}
            </a>
            <a
                href="/ships"
                class="text-console-text-dim transition-colors hover:text-console-highlight"
            >
                {t("nav.ships")}
            </a>
        </nav>
        <a
            href="https://ifdian.net/a/embersofthefire"
            target="_blank"
            rel="noopener noreferrer"
            class="text-sm text-console-text-dim transition-colors hover:text-console-highlight"
        >
            {t("nav.sponsor")}
        </a>
        <a
            href="https://efa-tech.dev/report/platform"
            target="_blank"
            rel="noopener noreferrer"
            class="text-sm text-console-text-dim transition-colors hover:text-console-highlight"
        >
            {t("nav.feedback")}
        </a>
        <button
            type="button"
            onclick={() => locale.toggle()}
            class="rounded border border-console-border px-2 py-1 text-xs text-console-text-dim transition-colors hover:border-console-primary hover:text-console-highlight"
        >
            {locale.current === "zh" ? "EN" : "中文"}
        </button>
        <a
            href="/account"
            class="text-sm text-console-text-dim transition-colors hover:text-console-highlight"
        >
            {t("nav.account")}
        </a>
        <a
            href={locale.current === "zh"
                ? "https://docs.efa-tech.dev/zh/sharing/publishing-fits/"
                : "https://docs.efa-tech.dev/sharing/publishing-fits/"}
            target="_blank"
            rel="noopener noreferrer"
            class="rounded bg-console-primary px-3 py-1 text-sm font-semibold text-console-deep transition-colors hover:bg-console-highlight"
        >
            {t("nav.upload")}
        </a>
    </div>
</header>
