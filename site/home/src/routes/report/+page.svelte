<script lang="ts">
import { goto } from "$app/navigation";
import { page } from "$app/state";
import { t } from "$lib/i18n/index.svelte";

$effect(() => {
    const params = page.url.searchParams;
    const variant = params.get("variant");
    if (variant !== "bug" && variant !== "feature") return;

    const forward = new URLSearchParams(params);
    forward.delete("variant");
    const qs = forward.toString();
    goto(`/report/${variant}${qs ? `?${qs}` : ""}`, { replaceState: true });
});
</script>

<svelte:head>
    <title>{t("report.heading")} — {t("brand.name")}</title>
</svelte:head>

<section class="py-24 sm:py-32">
    <div class="mx-auto max-w-4xl px-6">
        <div class="text-center">
            <h1
                class="text-3xl font-bold tracking-tight text-eve-text sm:text-4xl"
                style="font-family: 'Orbitron', 'Inter', sans-serif;"
            >
                {t("report.heading")}
            </h1>
            <p class="mt-4 text-eve-text-muted">{t("report.description")}</p>
        </div>

        <div class="mt-16 grid gap-8 sm:grid-cols-2">
            <a
                href="/report/bug"
                class="card-hover-glow group block rounded-lg border border-eve-border bg-eve-surface p-10 text-center transition-all duration-300"
            >
                <div
                    class="mx-auto mb-6 flex h-16 w-16 items-center justify-center rounded border border-eve-border bg-eve-surface-alt text-2xl text-eve-red transition-all duration-300 group-hover:scale-110 group-hover:shadow-[0_0_20px_rgba(211,47,47,0.15)]"
                >
                    &#9888;
                </div>
                <h2 class="text-xl font-semibold text-eve-text transition-colors duration-300 group-hover:text-eve-gold">
                    {t("report.bug.title")}
                </h2>
                <p class="mt-3 text-sm leading-relaxed text-eve-text-muted">
                    {t("report.bug.description")}
                </p>
            </a>

            <a
                href="/report/feature"
                class="card-hover-glow group block rounded-lg border border-eve-border bg-eve-surface p-10 text-center transition-all duration-300"
            >
                <div
                    class="mx-auto mb-6 flex h-16 w-16 items-center justify-center rounded border border-eve-border bg-eve-surface-alt text-2xl text-eve-cyan transition-all duration-300 group-hover:scale-110 group-hover:shadow-[0_0_20px_rgba(0,229,255,0.15)]"
                >
                    &#10033;
                </div>
                <h2 class="text-xl font-semibold text-eve-text transition-colors duration-300 group-hover:text-eve-gold">
                    {t("report.feature.title")}
                </h2>
                <p class="mt-3 text-sm leading-relaxed text-eve-text-muted">
                    {t("report.feature.description")}
                </p>
            </a>
        </div>
    </div>
</section>
