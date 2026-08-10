<script lang="ts">
import { page } from "$app/state";
import {
    type AgentFeedbackPayload,
    type ApiError,
    type IssueResult,
    submitAgentFeedback,
    type ValidationError,
} from "$lib/api/report";
import { locale, t } from "$lib/i18n/index.svelte";

let title = $state("");
let body = $state("");

let submitting = $state(false);
let success: IssueResult | null = $state(null);
let apiError: string = $state("");
let fieldErrors: ValidationError[] = $state([]);

$effect(() => {
    const params = page.url.searchParams;

    if (params.has("title")) title = params.get("title") ?? "";
    if (params.has("body")) body = params.get("body") ?? "";
});

function getFieldError(path: string): string {
    return fieldErrors.find((e) => e.path === path)?.message ?? "";
}

function hasFieldError(path: string): boolean {
    return fieldErrors.some((e) => e.path === path);
}

async function handleSubmit(e: Event) {
    e.preventDefault();
    apiError = "";
    fieldErrors = [];
    success = null;

    const requiredFields = [
        { path: "title", value: title },
        { path: "body", value: body },
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
        const payload: AgentFeedbackPayload = {
            language: locale.current,
            title: title.trim(),
            body: body.trim(),
        };

        const result = await submitAgentFeedback(payload);
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
    <title>{t("report.agent.title")} — {t("brand.name")}</title>
</svelte:head>

<section class="py-24 sm:py-32 relative overflow-hidden">
    <div class="absolute top-0 right-0 w-80 h-80 bg-eve-gold/5 rounded-full blur-3xl"></div>
    <div class="absolute bottom-0 left-12 w-64 h-64 bg-eve-gold-glow/10 rounded-full blur-3xl"></div>

    <div class="mx-auto max-w-2xl px-6 relative">
        <a href="/report" class="mb-8 inline-flex items-center gap-2 text-sm text-eve-text-muted hover:text-eve-gold transition-colors">
            <span>&larr;</span>
            {t("report.form.back")}
        </a>

        <div class="mb-10">
            <div class="inline-flex items-center gap-2 rounded-full border border-eve-gold/20 bg-eve-gold/5 px-4 py-1.5 text-xs text-eve-gold tracking-widest uppercase">
                <span class="h-1.5 w-1.5 rounded-full bg-eve-gold animate-[twinkle_2s_ease-in-out_infinite]"></span>
                {t("report.agent.title")}
            </div>
            <p class="mt-2 text-sm text-eve-text-muted">{t("report.agent.description")}</p>
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
                        <input
                            type="text"
                            bind:value={title}
                            placeholder={t("report.form.title.placeholder")}
                            class="w-full rounded border {hasFieldError('title') ? 'border-eve-red' : 'border-eve-border'} bg-eve-bg px-3.5 py-3 text-base font-semibold text-eve-text placeholder:text-eve-text-muted/40 focus:border-eve-gold focus:outline-none transition-colors"
                        />
                        {#if hasFieldError("title")}
                            <span class="mt-1 block text-xs text-eve-red">{getFieldError("title")}</span>
                        {/if}
                    </label>

                    <div class="eve-divider"></div>

                    <label class="block">
                        <span class="block text-xs font-medium text-eve-text-muted mb-1.5">{t("report.form.agent.body")}</span>
                        <textarea
                            bind:value={body}
                            rows="6"
                            placeholder={t("report.form.agent.body.placeholder")}
                            class="w-full rounded border {hasFieldError('body') ? 'border-eve-red' : 'border-eve-border'} bg-eve-bg px-3.5 py-2.5 text-sm text-eve-text placeholder:text-eve-text-muted/50 focus:border-eve-gold focus:outline-none transition-colors resize-y"
                        ></textarea>
                        {#if hasFieldError("body")}
                            <span class="mt-1 block text-xs text-eve-red">{getFieldError("body")}</span>
                        {/if}
                    </label>
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
