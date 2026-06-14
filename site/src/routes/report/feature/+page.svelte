<script lang="ts">
import {
    type ApiError,
    type IssueResult,
    type ValidationError,
    submitFeatureRequest,
} from "$lib/api/report";
import { t } from "$lib/i18n/index.svelte";
import { locale } from "$lib/i18n/index.svelte";

let title = $state("");
let problem = $state("");
let proposal = $state("");
let impact = $state("");

let attachExtras = $state(false);
let alternatives = $state("");
let extra = $state("");
let contact = $state("");
let metadata = $state<{ id: number; key: string; value: string }[]>([]);
let metadataNextId = $state(0);

let submitting = $state(false);
let success: IssueResult | null = $state(null);
let apiError: string = $state("");
let fieldErrors: ValidationError[] = $state([]);

function getFieldError(path: string): string {
    return fieldErrors.find((e) => e.path === path)?.message ?? "";
}

function hasFieldError(path: string): boolean {
    return fieldErrors.some((e) => e.path === path);
}

function addMetadataRow() {
    metadata = [...metadata, { id: metadataNextId++, key: "", value: "" }];
}

function removeMetadataRow(id: number) {
    metadata = metadata.filter((m) => m.id !== id);
}

function updateMetadataKey(id: number, key: string) {
    metadata = metadata.map((m) => (m.id === id ? { ...m, key } : m));
}

function updateMetadataValue(id: number, value: string) {
    metadata = metadata.map((m) => (m.id === id ? { ...m, value } : m));
}

async function handleSubmit(e: Event) {
    e.preventDefault();
    apiError = "";
    fieldErrors = [];
    success = null;

    const requiredFields = [
        { path: "title", value: title },
        { path: "problem", value: problem },
        { path: "proposal", value: proposal },
        { path: "impact", value: impact },
    ];

    const missing = requiredFields.filter((f) => !f.value.trim());
    if (missing.length > 0) {
        fieldErrors = missing.map((f) => ({
            path: f.path,
            message: t("report.form.required"),
        }));
        return;
    }

    submitting = true;
    try {
        const payload: import("$lib/api/report").FeatureRequestPayload = {
            language: locale.current,
            title: t("report.form.feature.prefix") + title.trim(),
            problem: problem.trim(),
            proposal: proposal.trim(),
            impact: impact.trim(),
        };

        if (attachExtras) {
            if (alternatives.trim()) payload.alternatives = alternatives.trim();
            if (extra.trim()) payload.extra = extra.trim();
            if (contact.trim()) payload.contact = contact.trim();
            const meta: Record<string, unknown> = {};
            let hasMeta = false;
            for (const m of metadata) {
                if (m.key.trim()) {
                    meta[m.key.trim()] = m.value;
                    hasMeta = true;
                }
            }
            if (hasMeta) payload.metadata = meta;
        }

        const result = await submitFeatureRequest(payload);
        success = result;
    } catch (err) {
        const apiErr = err as ApiError;
        if (apiErr.errors && apiErr.errors.length > 0) {
            fieldErrors = apiErr.errors;
        } else {
            apiError = apiErr.message || t("report.form.error.network");
        }
    } finally {
        submitting = false;
    }
}
</script>

<svelte:head>
    <title>{t("report.feature.title")} — {t("brand.name")}</title>
</svelte:head>

<section class="py-24 sm:py-32 relative overflow-hidden">
    <div class="absolute top-0 right-0 w-80 h-80 bg-eve-cyan-dim/20 rounded-full blur-3xl"></div>
    <div class="absolute bottom-0 left-12 w-64 h-64 bg-eve-gold-glow/10 rounded-full blur-3xl"></div>

    <div class="mx-auto max-w-2xl px-6 relative">
        <a href="/report" class="mb-8 inline-flex items-center gap-2 text-sm text-eve-text-muted hover:text-eve-gold transition-colors">
            <span>&larr;</span>
            {t("report.form.back")}
        </a>

        <div class="mb-10">
            <div class="inline-flex items-center gap-2 rounded-full border border-eve-cyan/20 bg-eve-cyan-dim/10 px-4 py-1.5 text-xs text-eve-cyan tracking-widest uppercase">
                <span class="h-1.5 w-1.5 rounded-full bg-eve-cyan animate-[twinkle_2s_ease-in-out_infinite]"></span>
                {t("report.feature.title")}
            </div>
            <p class="mt-2 text-sm text-eve-text-muted">{t("report.feature.description")}</p>
        </div>

        {#if success}
            <div class="mt-10 rounded-lg border border-eve-gold/30 bg-eve-surface p-10 text-center">
                <div class="mb-4 text-3xl">&#10003;</div>
                <h2 class="text-xl font-semibold text-eve-gold">{t("report.form.success.title")}</h2>
                <a
                    href={success.issue_url}
                    target="_blank"
                    rel="noopener noreferrer"
                    class="btn-glow eve-angle-cut mt-6 inline-flex items-center gap-2 bg-eve-gold px-6 py-2.5 text-sm font-semibold text-eve-bg hover:bg-eve-gold/90 transition-all duration-300"
                >
                    {t("report.form.success.view_on_github")}
                    <span class="text-lg">&rarr;</span>
                </a>
            </div>
        {:else}
            <form onsubmit={handleSubmit} class="space-y-6">

                {#if apiError}
                    <div class="rounded border border-eve-red/30 bg-eve-red/5 px-4 py-3 text-sm text-eve-red">
                        <strong>{t("report.form.error.title")}:</strong> {apiError}
                    </div>
                {/if}

                <div class="rounded-lg border border-eve-border bg-eve-surface p-6 sm:p-8 space-y-6">
                    <label class="block">
                        <div class="flex items-stretch rounded border {hasFieldError('title') ? 'border-eve-red' : 'border-eve-border'} bg-eve-bg focus-within:border-eve-gold transition-colors">
                            <span class="flex items-center px-3.5 py-3 text-base font-semibold text-eve-gold whitespace-nowrap select-none border-r border-eve-border">
                                {t("report.form.feature.prefix")}
                            </span>
                            <input
                                type="text"
                                bind:value={title}
                                placeholder={t("report.form.title.placeholder")}
                                class="flex-1 bg-transparent px-3.5 py-3 text-base font-semibold text-eve-text placeholder:text-eve-text-muted/40 focus:outline-none transition-colors min-w-0"
                            />
                        </div>
                        {#if hasFieldError("title")}
                            <span class="mt-1 block text-xs text-eve-red">{getFieldError("title")}</span>
                        {/if}
                    </label>

                    <div class="eve-divider"></div>

                    <label class="block">
                        <span class="block text-xs font-medium text-eve-text-muted mb-1.5">{t("report.form.feature.problem")}</span>
                        <textarea
                            bind:value={problem}
                            rows="2"
                            class="w-full rounded border border-eve-border bg-eve-bg px-3.5 py-2.5 text-sm text-eve-text placeholder:text-eve-text-muted/50 focus:border-eve-gold focus:outline-none transition-colors resize-y"
                        ></textarea>
                        {#if hasFieldError("problem")}
                            <span class="mt-1 block text-xs text-eve-red">{getFieldError("problem")}</span>
                        {/if}
                    </label>

                    <label class="block">
                        <span class="block text-xs font-medium text-eve-text-muted mb-1.5">{t("report.form.feature.proposal")}</span>
                        <textarea
                            bind:value={proposal}
                            rows="3"
                            class="w-full rounded border border-eve-border bg-eve-bg px-3.5 py-2.5 text-sm text-eve-text placeholder:text-eve-text-muted/50 focus:border-eve-gold focus:outline-none transition-colors resize-y"
                        ></textarea>
                        {#if hasFieldError("proposal")}
                            <span class="mt-1 block text-xs text-eve-red">{getFieldError("proposal")}</span>
                        {/if}
                    </label>

                    <label class="block">
                        <span class="block text-xs font-medium text-eve-text-muted mb-1.5">{t("report.form.feature.impact")}</span>
                        <textarea
                            bind:value={impact}
                            rows="2"
                            class="w-full rounded border border-eve-border bg-eve-bg px-3.5 py-2.5 text-sm text-eve-text placeholder:text-eve-text-muted/50 focus:border-eve-gold focus:outline-none transition-colors resize-y"
                        ></textarea>
                        {#if hasFieldError("impact")}
                            <span class="mt-1 block text-xs text-eve-red">{getFieldError("impact")}</span>
                        {/if}
                    </label>
                </div>

                <!-- Attach extras toggle -->
                <div class="rounded-lg border {attachExtras ? 'border-eve-cyan/30 bg-eve-cyan-dim/5' : 'border-eve-border bg-eve-surface'} p-6 sm:p-8 transition-colors duration-300">
                    <label class="flex items-center justify-between cursor-pointer">
                        <span class="text-sm text-eve-text">+ {t("report.form.attach_extras")}</span>
                        <button
                            type="button"
                            onclick={() => (attachExtras = !attachExtras)}
                            aria-label={t("report.form.attach_extras")}
                            class="relative inline-flex h-6 w-11 items-center rounded-full transition-colors duration-300 {attachExtras ? 'bg-eve-cyan' : 'bg-eve-border'}"
                        >
                            <span class="inline-block h-4 w-4 transform rounded-full bg-eve-bg transition-transform duration-300 {attachExtras ? 'translate-x-6' : 'translate-x-1'}"></span>
                        </button>
                    </label>

                    {#if attachExtras}
                        <div class="eve-divider my-6"></div>

                        <div class="space-y-5">
                            <label class="block">
                                <span class="block text-xs font-medium text-eve-text-muted mb-1.5">{t("report.form.feature.alternatives")}</span>
                                <textarea
                                    bind:value={alternatives}
                                    placeholder={t("report.form.feature.alternatives.placeholder")}
                                    rows="3"
                                    class="w-full rounded border border-eve-border bg-eve-bg px-3.5 py-2.5 text-sm text-eve-text placeholder:text-eve-text-muted/50 focus:border-eve-gold focus:outline-none transition-colors resize-y"
                                ></textarea>
                            </label>

                            <label class="block">
                                <span class="block text-xs font-medium text-eve-text-muted mb-1.5">{t("report.form.feature.extra")}</span>
                                <textarea
                                    bind:value={extra}
                                    placeholder={t("report.form.feature.extra.placeholder")}
                                    rows="3"
                                    class="w-full rounded border border-eve-border bg-eve-bg px-3.5 py-2.5 text-sm text-eve-text placeholder:text-eve-text-muted/50 focus:border-eve-gold focus:outline-none transition-colors resize-y"
                                ></textarea>
                            </label>

                            <label class="block">
                                <span class="block text-xs font-medium text-eve-text-muted mb-1.5">{t("report.form.contact")}</span>
                                <input
                                    type="text"
                                    bind:value={contact}
                                    placeholder={t("report.form.contact.placeholder")}
                                    class="w-full rounded border border-eve-border bg-eve-bg px-3.5 py-2.5 text-sm text-eve-text placeholder:text-eve-text-muted/50 focus:border-eve-gold focus:outline-none transition-colors"
                                />
                            </label>

                            <div>
                                <div class="mb-3 flex items-center justify-between">
                                    <span class="text-xs font-medium text-eve-text-muted">{t("report.form.metadata")}</span>
                                    <button
                                        type="button"
                                        onclick={addMetadataRow}
                                        class="rounded border border-eve-border px-3 py-1 text-xs text-eve-text-muted hover:text-eve-gold hover:border-eve-gold/30 transition-colors"
                                    >
                                        + {t("report.form.metadata.add")}
                                    </button>
                                </div>
                                {#each metadata as row, i (row.id)}
                                    <div class="mb-3 flex items-start gap-3">
                                        <div class="flex-1">
                                            <input
                                                type="text"
                                                value={row.key}
                                                oninput={(e) => updateMetadataKey(row.id, e.currentTarget.value)}
                                                placeholder={t("report.form.metadata.key.placeholder")}
                                                class="w-full rounded border border-eve-border bg-eve-bg px-3 py-2 text-sm text-eve-text placeholder:text-eve-text-muted/50 focus:border-eve-gold focus:outline-none transition-colors"
                                            />
                                        </div>
                                        <div class="flex-1">
                                            <input
                                                type="text"
                                                value={row.value}
                                                oninput={(e) => updateMetadataValue(row.id, e.currentTarget.value)}
                                                placeholder={t("report.form.metadata.value.placeholder")}
                                                class="w-full rounded border border-eve-border bg-eve-bg px-3 py-2 text-sm text-eve-text placeholder:text-eve-text-muted/50 focus:border-eve-gold focus:outline-none transition-colors"
                                            />
                                        </div>
                                        <button
                                            type="button"
                                            onclick={() => removeMetadataRow(row.id)}
                                            class="rounded border border-eve-border px-2 py-2 text-xs text-eve-text-muted hover:text-eve-red hover:border-eve-red/30 transition-colors"
                                        >
                                            &times;
                                        </button>
                                    </div>
                                {/each}
                            </div>
                        </div>
                    {/if}
                </div>

                <button
                    type="submit"
                    disabled={submitting}
                    class="btn-glow eve-angle-cut w-full bg-eve-gold px-8 py-3.5 text-sm font-semibold text-eve-bg hover:bg-eve-gold/90 transition-all duration-300 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                    {submitting ? t("report.form.submitting") : t("report.form.submit")}
                </button>
            </form>
        {/if}
    </div>
</section>
