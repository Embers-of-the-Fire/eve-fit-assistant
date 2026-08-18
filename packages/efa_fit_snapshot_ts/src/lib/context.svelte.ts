import { getContext, setContext } from "svelte";
import {
    resolveSnapshotName,
    type SnapshotMessageKey,
    type SnapshotTranslateParams,
    translateSnapshot,
} from "./i18n";

/** Resolves a `type_id` to an image URL (defaults to the public EVE image server). */
export type TypeIconResolver = (typeId: number) => string;

export function defaultTypeIconUrl(typeId: number): string {
    return `https://images.evetech.net/types/${typeId}/icon?size=64`;
}

/**
 * Display-scoped configuration carried down the component tree, the Svelte
 * counterpart of the Flutter `SnapshotDisplay` inherited widget plus the
 * snapshot `Localizations`.
 */
export interface SnapshotDisplayContext {
    /** Active BCP-47 locale of the component. */
    readonly locale: string;
    t(key: SnapshotMessageKey, params?: SnapshotTranslateParams): string;
    /** Resolves a snapshot `names` map against the active locale. */
    name(names: Record<string, string>): string;
    typeIconUrl(typeId: number): string;
}

const CONTEXT_KEY = "efa-fit-snapshot-display";

export function setSnapshotContext(
    locale: () => string,
    resolver?: () => TypeIconResolver | undefined,
): void {
    setContext<SnapshotDisplayContext>(CONTEXT_KEY, {
        get locale() {
            return locale();
        },
        t: (key, params) => translateSnapshot(locale(), key, params),
        name: (names) => resolveSnapshotName(names, locale()),
        typeIconUrl: (typeId) => resolver?.()?.(typeId) ?? defaultTypeIconUrl(typeId),
    });
}

export function snapshotDisplay(): SnapshotDisplayContext {
    const ctx = getContext<SnapshotDisplayContext | undefined>(CONTEXT_KEY);
    if (!ctx) {
        throw new Error(
            "efa-fit-snapshot-ts: snapshot components must be rendered inside <FitSnapshotView>",
        );
    }
    return ctx;
}
