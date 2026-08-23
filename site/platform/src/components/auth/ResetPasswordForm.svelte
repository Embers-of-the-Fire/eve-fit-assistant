<script lang="ts">
import { getSession } from "../../lib/auth.svelte";
import {
    accountErrorMessage,
    isValidAccountCode,
    isValidAccountEmail,
    isValidAccountPassword,
} from "../../lib/auth-errors";
import { t } from "../../lib/i18n.svelte";

const session = getSession();

let step = $state<"email" | "confirm">("email");
let email = $state("");
let code = $state("");
let newPassword = $state("");
let busy = $state(false);
let error = $state<string | null>(null);
let notice = $state<string | null>(null);

async function submitEmail() {
    error = null;
    if (!isValidAccountEmail(email)) {
        error = t("account.invalidEmail");
        return;
    }
    busy = true;
    try {
        await session.requestPasswordReset(email.trim());
        // Enumeration-safe: the response never reveals whether the address exists.
        notice = t("account.resetCodeSent");
        step = "confirm";
    } catch (err) {
        error = accountErrorMessage(err);
    } finally {
        busy = false;
    }
}

async function submitConfirm() {
    error = null;
    if (!isValidAccountCode(code)) {
        error = t("account.invalidCode");
        return;
    }
    if (!isValidAccountPassword(newPassword)) {
        error = t("account.passwordTooShort");
        return;
    }
    busy = true;
    try {
        await session.confirmPasswordReset(email.trim(), code, newPassword);
        window.location.assign("/account");
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
    <h1 class="mb-4 text-2xl font-bold text-console-text">{t("account.resetTitle")}</h1>

    {#if error !== null}
        <p class={errorClass}>{error}</p>
    {/if}
    {#if notice !== null}
        <p class={noticeClass}>{notice}</p>
    {/if}

    {#if step === "email"}
        <form
            onsubmit={(event) => {
                event.preventDefault();
                void submitEmail();
            }}
            class="grid gap-4"
        >
            <div>
                <label class={labelClass} for="reset-email">{t("account.email")}</label>
                <input
                    id="reset-email"
                    type="email"
                    bind:value={email}
                    autocomplete="email"
                    class={inputClass}
                />
            </div>
            <button
                type="submit"
                disabled={busy}
                class="rounded bg-console-primary px-3 py-2 text-sm font-semibold text-console-deep disabled:opacity-50"
            >
                {busy ? t("account.working") : t("account.sendCode")}
            </button>
        </form>
    {:else}
        <form
            onsubmit={(event) => {
                event.preventDefault();
                void submitConfirm();
            }}
            class="grid gap-4"
        >
            <div>
                <label class={labelClass} for="reset-code">{t("account.code")}</label>
                <input
                    id="reset-code"
                    type="text"
                    inputmode="numeric"
                    maxlength="6"
                    bind:value={code}
                    autocomplete="one-time-code"
                    class={inputClass}
                />
            </div>
            <div>
                <label class={labelClass} for="reset-new-password">{t("account.newPassword")}</label>
                <input
                    id="reset-new-password"
                    type="password"
                    bind:value={newPassword}
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
                {busy ? t("account.working") : t("account.resetPassword")}
            </button>
        </form>
    {/if}

    <div class="mt-4">
        <a href="/account/login" class={linkClass}>{t("account.haveAccount")}</a>
    </div>
</section>
