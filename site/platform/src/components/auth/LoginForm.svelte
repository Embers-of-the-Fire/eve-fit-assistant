<script lang="ts">
import { AccountApiError } from "efa-platform-client-ts";
import { getSession } from "../../lib/auth.svelte";
import {
    accountErrorMessage,
    isValidAccountEmail,
    isValidAccountPassword,
} from "../../lib/auth-errors";
import { t } from "../../lib/i18n.svelte";
import { stashPendingVerificationEmail } from "../../lib/pending-verification";

const session = getSession();

let email = $state("");
let password = $state("");
let busy = $state(false);
let error = $state<string | null>(null);

async function submit() {
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
        await session.login(email.trim(), password);
        window.location.assign("/account");
    } catch (err) {
        if (err instanceof AccountApiError && err.isEmailUnverified) {
            // The server re-sent the code; continue on the verification step.
            // The address travels via sessionStorage so it stays out of the
            // URL (browser history, Referer headers, client analytics).
            stashPendingVerificationEmail(email.trim());
            window.location.assign("/account/register?verify=1");
            return;
        }
        error = accountErrorMessage(err);
    } finally {
        busy = false;
    }
}

const labelClass = "mb-1 block text-sm text-console-text-dim";
const inputClass =
    "w-full rounded border border-console-border bg-console-deep px-3 py-2 text-sm text-console-text placeholder:text-console-text-muted focus:border-console-primary focus:outline-none";
const linkClass = "text-sm text-console-primary hover:text-console-highlight";
</script>

<section class="mx-auto max-w-md rounded border border-console-border bg-console-surface p-6">
    <h1 class="mb-4 text-2xl font-bold text-console-text">{t("account.signInTitle")}</h1>

    {#if error !== null}
        <p class="mb-4 rounded border border-console-danger/50 bg-console-danger/10 px-3 py-2 text-sm text-console-danger">
            {error}
        </p>
    {/if}

    <form
        onsubmit={(event) => {
            event.preventDefault();
            void submit();
        }}
        class="grid gap-4"
    >
        <div>
            <label class={labelClass} for="login-email">{t("account.email")}</label>
            <input
                id="login-email"
                type="email"
                bind:value={email}
                autocomplete="email"
                class={inputClass}
            />
        </div>
        <div>
            <label class={labelClass} for="login-password">{t("account.password")}</label>
            <input
                id="login-password"
                type="password"
                bind:value={password}
                autocomplete="current-password"
                class={inputClass}
            />
        </div>
        <button
            type="submit"
            disabled={busy}
            class="rounded bg-console-primary px-3 py-2 text-sm font-semibold text-console-deep disabled:opacity-50"
        >
            {busy ? t("account.working") : t("account.signIn")}
        </button>
    </form>

    <div class="mt-4 flex justify-between">
        <a href="/account/reset" class={linkClass}>{t("account.forgotPassword")}</a>
        <a href="/account/register" class={linkClass}>{t("account.noAccount")}</a>
    </div>
</section>
