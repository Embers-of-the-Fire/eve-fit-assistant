<script lang="ts">
import { accountAclState, loadAccountAcl, roleLabel } from "../lib/acl.svelte";
import { authState, getSession } from "../lib/auth.svelte";
import { accountErrorMessage } from "../lib/auth-errors";
import { t } from "../lib/i18n.svelte";

// Start the cold-start load/rotation as soon as the island evaluates.
const session = getSession();

// The server render must always show the loading state so the client's first
// (not-yet-ready) render matches it during hydration.
const isServer = typeof window === "undefined";

let busy = $state(false);
let error = $state<string | null>(null);
let confirmingLogout = $state(false);
let confirmingDeregister = $state(false);
let deregisterPassword = $state("");

// Fetch the account's roles/permissions whenever a signed-in identity is
// present (loadAccountAcl no-ops while signed out or already loaded).
$effect(() => {
    if (authState.ready && authState.identity !== null) {
        loadAccountAcl();
    }
});

async function logout() {
    busy = true;
    error = null;
    try {
        await session.logout();
    } catch (err) {
        error = accountErrorMessage(err);
    } finally {
        busy = false;
        confirmingLogout = false;
    }
}

async function deregister() {
    if (deregisterPassword === "") return;
    busy = true;
    error = null;
    try {
        await session.deregister(deregisterPassword);
    } catch (err) {
        error = accountErrorMessage(err);
    } finally {
        busy = false;
        confirmingDeregister = false;
        deregisterPassword = "";
    }
}

const tileClass =
    "block rounded border border-console-border bg-console-surface p-4 transition-colors hover:border-console-primary";
const inputClass =
    "w-full rounded border border-console-border bg-console-deep px-3 py-2 text-sm text-console-text placeholder:text-console-text-muted focus:border-console-primary focus:outline-none";
</script>

{#if isServer || !authState.ready}
    <section class="rounded border border-console-border bg-console-surface p-6">
        <h1 class="mb-2 text-2xl font-bold text-console-text">{t("account.title")}</h1>
        <p class="text-console-text-muted">{t("account.loading")}</p>
    </section>
{:else if authState.identity === null}
    <section class="rounded border border-console-border bg-console-surface p-6">
        <h1 class="mb-4 text-2xl font-bold text-console-text">{t("account.title")}</h1>
        <div class="grid gap-3">
            <a href="/account/login" class={tileClass}>
                <p class="font-semibold text-console-text">{t("account.signInTile")}</p>
                <p class="text-sm text-console-text-muted">{t("account.signInTileDesc")}</p>
            </a>
            <a href="/account/register" class={tileClass}>
                <p class="font-semibold text-console-text">{t("account.registerTile")}</p>
                <p class="text-sm text-console-text-muted">{t("account.registerTileDesc")}</p>
            </a>
        </div>
    </section>
{:else}
    <section class="rounded border border-console-border bg-console-surface p-6">
        <h1 class="mb-4 text-2xl font-bold text-console-text">{t("account.title")}</h1>

        {#if error !== null}
            <p class="mb-4 rounded border border-console-danger/50 bg-console-danger/10 px-3 py-2 text-sm text-console-danger">
                {error}
            </p>
        {/if}

        <div class="mb-6 rounded border border-console-border bg-console-deep p-4">
            <p class="mb-1 text-sm text-console-text-muted">{t("account.currentAccount")}</p>
            <p class="font-semibold text-console-text">{authState.identity.email}</p>
            <p class="text-sm text-console-text-muted">
                {t("account.userId")}: {authState.identity.userId}
            </p>
            {#if accountAclState.roles.length > 0}
                <p class="text-sm text-console-text-muted">
                    {t("account.roles")}: {accountAclState.roles.map(roleLabel).join(", ")}
                </p>
            {/if}
        </div>

        <div class="grid gap-3">
            {#if confirmingLogout}
                <div class="rounded border border-console-border bg-console-deep p-4">
                    <p class="font-semibold text-console-text">{t("account.signOutConfirm")}</p>
                    <p class="mb-3 text-sm text-console-text-muted">
                        {t("account.signOutConfirmDesc")}
                    </p>
                    <div class="flex gap-2">
                        <button
                            type="button"
                            onclick={logout}
                            disabled={busy}
                            class="rounded bg-console-danger px-3 py-2 text-sm font-semibold text-console-text disabled:opacity-50"
                        >
                            {busy ? t("account.working") : t("account.confirm")}
                        </button>
                        <button
                            type="button"
                            onclick={() => (confirmingLogout = false)}
                            disabled={busy}
                            class="rounded border border-console-border px-3 py-2 text-sm text-console-text-dim disabled:opacity-50"
                        >
                            {t("account.cancel")}
                        </button>
                    </div>
                </div>
            {:else}
                <button
                    type="button"
                    onclick={() => {
                        confirmingLogout = true;
                        confirmingDeregister = false;
                        error = null;
                    }}
                    class="rounded border border-console-border bg-console-surface-alt px-3 py-2 text-left text-sm font-semibold text-console-text"
                >
                    {t("account.signOut")}
                </button>
            {/if}

            {#if confirmingDeregister}
                <div class="rounded border border-console-danger/50 bg-console-deep p-4">
                    <p class="font-semibold text-console-danger">{t("account.deleteAccountConfirm")}</p>
                    <p class="mb-3 text-sm text-console-text-muted">
                        {t("account.deleteAccountConfirmDesc")}
                    </p>
                    <form
                        onsubmit={(event) => {
                            event.preventDefault();
                            void deregister();
                        }}
                        class="grid gap-2"
                    >
                        <label class="block text-sm text-console-text-dim" for="deregister-password">
                            {t("account.deleteAccountPasswordPrompt")}
                        </label>
                        <input
                            id="deregister-password"
                            type="password"
                            bind:value={deregisterPassword}
                            autocomplete="current-password"
                            class={inputClass}
                        />
                        <div class="flex gap-2">
                            <button
                                type="submit"
                                disabled={busy || deregisterPassword === ""}
                                class="rounded bg-console-danger px-3 py-2 text-sm font-semibold text-console-text disabled:opacity-50"
                            >
                                {busy ? t("account.working") : t("account.deleteAccount")}
                            </button>
                            <button
                                type="button"
                                onclick={() => {
                                    confirmingDeregister = false;
                                    deregisterPassword = "";
                                }}
                                disabled={busy}
                                class="rounded border border-console-border px-3 py-2 text-sm text-console-text-dim disabled:opacity-50"
                            >
                                {t("account.cancel")}
                            </button>
                        </div>
                    </form>
                </div>
            {:else}
                <button
                    type="button"
                    onclick={() => {
                        confirmingDeregister = true;
                        confirmingLogout = false;
                        error = null;
                    }}
                    class="rounded border border-console-danger/50 px-3 py-2 text-left text-sm font-semibold text-console-danger"
                >
                    {t("account.deleteAccount")}
                </button>
            {/if}
        </div>
    </section>
{/if}
