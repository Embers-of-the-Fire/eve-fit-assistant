<script lang="ts">
import { untrack } from "svelte";
import { getSession } from "../../lib/auth.svelte";
import {
    accountErrorMessage,
    isValidAccountCode,
    isValidAccountEmail,
    isValidAccountPassword,
} from "../../lib/auth-errors";
import { t } from "../../lib/i18n.svelte";

interface Props {
    initialEmail?: string;
    startAtVerification?: boolean;
}

const { initialEmail = "", startAtVerification = false }: Props = $props();

const session = getSession();

// Props are static per page load; they only seed the initial state.
let step = $state<"form" | "verify">(untrack(() => (startAtVerification ? "verify" : "form")));
let email = $state(untrack(() => initialEmail));
let password = $state("");
let code = $state("");
let busy = $state(false);
let error = $state<string | null>(null);
let notice = $state<string | null>(null);

async function submitSignup() {
    error = null;
    if (!isValidAccountEmail(email)) {
        error = t("account.invalidEmail");
        return;
    }
    if (!isValidAccountPassword(password)) {
        error = t("account.passwordTooShort");
        return;
    }
    busy = true;
    try {
        await session.signup(email.trim(), password);
        notice = t("account.codeSent");
        step = "verify";
    } catch (err) {
        error = accountErrorMessage(err);
    } finally {
        busy = false;
    }
}

async function submitVerify() {
    error = null;
    if (!isValidAccountCode(code)) {
        error = t("account.invalidCode");
        return;
    }
    busy = true;
    try {
        await session.verifyEmail(email.trim(), code);
        window.location.assign("/account");
    } catch (err) {
        error = accountErrorMessage(err);
    } finally {
        busy = false;
    }
}

async function resend() {
    error = null;
    notice = null;
    busy = true;
    try {
        await session.resendSignupCode(email.trim());
        notice = t("account.codeSent");
    } catch (err) {
        error = accountErrorMessage(err);
    } finally {
        busy = false;
    }
}

const labelClass = "mb-1 block text-sm text-console-text-dim";
const inputClass =
    "w-full rounded border border-console-border bg-console-deep px-3 py-2 text-sm text-console-text placeholder:text-console-text-muted focus:border-console-primary focus:outline-none";
const linkClass = "text-sm text-console-primary hover:text-console-highlight";
const noticeClass =
    "mb-4 rounded border border-console-primary/50 bg-console-primary/10 px-3 py-2 text-sm text-console-primary";
const errorClass =
    "mb-4 rounded border border-console-danger/50 bg-console-danger/10 px-3 py-2 text-sm text-console-danger";
</script>

<section class="mx-auto max-w-md rounded border border-console-border bg-console-surface p-6">
    <h1 class="mb-4 text-2xl font-bold text-console-text">{t("account.registerTitle")}</h1>

    {#if error !== null}
        <p class={errorClass}>{error}</p>
    {/if}
    {#if notice !== null}
        <p class={noticeClass}>{notice}</p>
    {/if}

    {#if step === "form"}
        <form
            onsubmit={(event) => {
                event.preventDefault();
                void submitSignup();
            }}
            class="grid gap-4"
        >
            <div>
                <label class={labelClass} for="register-email">{t("account.email")}</label>
                <input
                    id="register-email"
                    type="email"
                    bind:value={email}
                    autocomplete="email"
                    class={inputClass}
                />
            </div>
            <div>
                <label class={labelClass} for="register-password">{t("account.password")}</label>
                <input
                    id="register-password"
                    type="password"
                    bind:value={password}
                    autocomplete="new-password"
                    class={inputClass}
                />
                <p class="mt-1 text-xs text-console-text-muted">{t("account.passwordHint")}</p>
            </div>
            <button
                type="submit"
                disabled={busy}
                class="rounded bg-console-primary px-3 py-2 text-sm font-semibold text-console-deep disabled:opacity-50"
            >
                {busy ? t("account.working") : t("account.register")}
            </button>
        </form>
        <div class="mt-4">
            <a href="/account/login" class={linkClass}>{t("account.haveAccount")}</a>
        </div>
    {:else}
        <form
            onsubmit={(event) => {
                event.preventDefault();
                void submitVerify();
            }}
            class="grid gap-4"
        >
            <div>
                <label class={labelClass} for="register-code">{t("account.code")}</label>
                <input
                    id="register-code"
                    type="text"
                    inputmode="numeric"
                    maxlength="6"
                    bind:value={code}
                    autocomplete="one-time-code"
                    class={inputClass}
                />
            </div>
            <button
                type="submit"
                disabled={busy}
                class="rounded bg-console-primary px-3 py-2 text-sm font-semibold text-console-deep disabled:opacity-50"
            >
                {busy ? t("account.working") : t("account.verify")}
            </button>
        </form>
        <div class="mt-4">
            <button type="button" onclick={() => void resend()} disabled={busy} class={linkClass}>
                {t("account.resendCode")}
            </button>
        </div>
    {/if}
</section>
