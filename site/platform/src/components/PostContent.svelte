<script lang="ts">
import { fromJson, type JsonValue } from "@bufbuild/protobuf";
import { FitSnapshotView } from "efa-fit-snapshot-ts";
import { FitSnapshotSchema } from "efa-proto-ts/fit_snapshot_pb";
import { deletePost } from "../lib/account-api";
import { accountAclState, loadAccountAcl } from "../lib/acl.svelte";
import { localizedName } from "../lib/api";
import { authState, getSession } from "../lib/auth.svelte";
import { locale, t } from "../lib/i18n.svelte";
import { registeredSharePageUrl } from "../lib/share-target";

interface SnapshotView {
    fitName: string;
    shipNames: Record<string, string>;
    postId: string;
    /** The authoring account's user id; null for tombstoned authors. */
    authorId: string | null;
    fitHash: string;
    snapshotJson: JsonValue;
}

interface Props {
    snapshot: SnapshotView | null;
}

const { snapshot }: Props = $props();

const fitSnapshot = $derived(snapshot ? fromJson(FitSnapshotSchema, snapshot.snapshotJson) : null);

// Post operations (delete): gated client-side on the account's ACL tokens —
// `post:delete:all` covers any post, `post:delete:own` only the account's own
// (matching is exact: `all` does not imply `own`). Real authorization is
// enforced by the API. The page is CDN-cached, so the group only ever
// renders client-side once auth and the ACL have resolved.
const session = getSession();
const isServer = typeof window === "undefined";

let confirmingDelete = $state(false);
let deleteBusy = $state(false);
let deleteError = $state<string | null>(null);

$effect(() => {
    if (authState.ready) {
        loadAccountAcl();
    }
});

const canDelete = $derived.by(() => {
    if (snapshot === null || authState.identity === null) return false;
    const qualifiers = accountAclState.acl.can("post:delete");
    if (qualifiers === false) return false;
    return (
        qualifiers.includes("all") ||
        (qualifiers.includes("own") && snapshot.authorId === authState.identity.userId)
    );
});

async function doDelete() {
    if (snapshot === null) return;
    deleteBusy = true;
    deleteError = null;
    try {
        await deletePost(session, snapshot.postId);
        window.location.assign("/");
    } catch (err) {
        deleteError =
            err instanceof Error && err.message === "forbidden"
                ? t("post.deleteForbidden")
                : t("post.deleteFailed");
        deleteBusy = false;
        confirmingDelete = false;
    }
}
</script>

{#if snapshot && fitSnapshot}
    <header class="mb-6">
        <div class="flex flex-wrap items-start justify-between gap-3">
            <h1 class="text-2xl font-bold text-console-text">
                {snapshot.fitName || t("fits.untitled")}
            </h1>
            <div class="flex flex-wrap items-center gap-2">
                <a
                    href={registeredSharePageUrl(snapshot.fitHash)}
                    target="_blank"
                    rel="noopener noreferrer"
                    class="rounded border border-console-primary px-3 py-1 text-xs text-console-primary transition-colors hover:bg-console-primary hover:text-console-deep"
                >
                    {t("fit.openInApp")}
                </a>
                {#if !isServer && canDelete}
                    {#if confirmingDelete}
                        <span class="text-xs text-console-danger">{t("post.deleteConfirm")}</span>
                        <button
                            type="button"
                            onclick={doDelete}
                            disabled={deleteBusy}
                            class="rounded bg-console-danger px-3 py-1 text-xs font-semibold text-console-text disabled:opacity-50"
                        >
                            {deleteBusy ? t("account.working") : t("account.confirm")}
                        </button>
                        <button
                            type="button"
                            onclick={() => (confirmingDelete = false)}
                            disabled={deleteBusy}
                            class="rounded border border-console-border px-3 py-1 text-xs text-console-text-dim disabled:opacity-50"
                        >
                            {t("account.cancel")}
                        </button>
                    {:else}
                        <button
                            type="button"
                            onclick={() => {
                                confirmingDelete = true;
                                deleteError = null;
                            }}
                            class="rounded border border-console-danger/50 px-3 py-1 text-xs text-console-danger transition-colors hover:bg-console-danger hover:text-console-text"
                        >
                            {t("post.delete")}
                        </button>
                    {/if}
                {/if}
            </div>
        </div>
        {#if deleteError !== null}
            <p class="mt-2 rounded border border-console-danger/50 bg-console-danger/10 px-3 py-2 text-sm text-console-danger">
                {deleteError}
            </p>
        {/if}
        <p class="mt-1 text-sm text-console-text-dim">
            {localizedName(snapshot.shipNames, locale.current)}
        </p>
        <p class="mt-1 font-mono text-xs break-all text-console-text-muted">
            post: {snapshot.postId}
        </p>
        <p class="font-mono text-xs break-all text-console-text-muted">
            fit: {snapshot.fitHash}
        </p>
    </header>
    <section class="overflow-hidden rounded border border-console-border">
        <FitSnapshotView snapshot={fitSnapshot} locale={locale.current} showHeader={false} />
    </section>
{:else}
    <p class="text-console-text-muted">{t("fit.notFound")}</p>
{/if}
