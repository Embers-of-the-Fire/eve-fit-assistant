<script lang="ts">
import type { FitSnapshot } from "efa-proto-ts/fit_snapshot_pb";
import CharacterColumn from "./columns/CharacterColumn.svelte";
import EquipmentColumn from "./columns/EquipmentColumn.svelte";
import StatisticsColumn from "./columns/StatisticsColumn.svelte";
import { type IconHintResolver, setSnapshotContext, type TypeIconResolver } from "./context.svelte";
import { resolveSnapshotName, translateSnapshot } from "./i18n";

interface Props {
    /** Decoded `fit.FitSnapshot` protobuf message (see `efa-proto-ts/fit_snapshot_pb`). */
    snapshot: FitSnapshot;
    /**
     * Component-level BCP-47 locale (e.g. `"en"`, `"zh"`, `"zh-CN"`). Drives both the
     * component chrome translations and the resolution of snapshot `names` maps.
     */
    locale?: string;
    /** Overrides type-icon resolution; defaults to the public EVE image server. */
    iconResolver?: TypeIconResolver;
    /** Resolves `SnapshotDisplayValue` icon hints (graphic/icon ids) to image URLs. */
    iconHintResolver?: IconHintResolver;
    /** Whether to show the fit name/description header above the columns. */
    showHeader?: boolean;
}

let {
    snapshot,
    locale = "en",
    iconResolver,
    iconHintResolver,
    showHeader = true,
}: Props = $props();

setSnapshotContext(
    () => locale,
    () => iconResolver,
    () => iconHintResolver,
);

const shipName = $derived(snapshot.ship?.type?.names ?? {});
</script>

<div class="efa-snapshot">
    {#if showHeader && snapshot.header}
        <header class="efa-snapshot-header">
            <h2 class="efa-snapshot-title">
                {translateSnapshot(locale, "fitPageTitle", {
                    fitName: snapshot.header.fitName,
                    shipName: resolveSnapshotName(shipName, locale),
                })}
            </h2>
            {#if snapshot.header.description}
                <p class="efa-snapshot-description">{snapshot.header.description}</p>
            {/if}
        </header>
    {/if}
    <div class="efa-snapshot-columns">
        <section class="efa-frame efa-col-character">
            <CharacterColumn {snapshot} />
        </section>
        <section class="efa-frame efa-col-equipment">
            <EquipmentColumn {snapshot} />
        </section>
        <section class="efa-frame efa-col-stats">
            <StatisticsColumn {snapshot} />
        </section>
    </div>
</div>

<style>
    .efa-snapshot {
        --efa-bg: #0c1213;
        --efa-deep: #0a1a2a;
        --efa-surface: #12202a;
        --efa-surface-alt: #1a2e3a;
        --efa-border: #22404f;
        --efa-text: #e0f4ff;
        --efa-text-dim: #9db8c6;
        --efa-text-muted: #64808f;
        --efa-accent: #30b2e6;
        --efa-highlight: #4ed4ff;
        --efa-success: #4caf50;
        --efa-warning: #ff9800;
        --efa-danger: #f44336;
        --efa-state-active: #2e7d32;
        --efa-state-online: #bdbdbd;
        --efa-state-overload: #ef5350;
        --efa-state-passive: #2d2d2d;
        --efa-bar-track: #1a2e3a;

        container-type: inline-size;
        background: var(--efa-bg);
        color: var(--efa-text);
        font-size: 14px;
        line-height: 1.4;
        padding: 12px;
        box-sizing: border-box;
    }
    .efa-snapshot *,
    .efa-snapshot *::before,
    .efa-snapshot *::after {
        box-sizing: border-box;
    }
    .efa-snapshot-header {
        padding: 4px 4px 12px;
    }
    .efa-snapshot-title {
        margin: 0;
        font-size: 16px;
        font-weight: 400;
    }
    .efa-snapshot-description {
        margin: 4px 0 0;
        font-size: 14px;
        color: var(--efa-text-dim);
        white-space: pre-wrap;
    }
    .efa-snapshot-columns {
        display: grid;
        grid-template-columns: 1fr;
        gap: 12px;
        align-items: start;
    }
    .efa-frame {
        background: var(--efa-surface);
        border: 1px solid var(--efa-border);
        padding: 8px 0;
        min-width: 0;
    }

    @container (max-width: 875.98px) {
        .efa-col-equipment {
            order: 1;
        }
        .efa-col-character {
            order: 2;
        }
        .efa-col-stats {
            order: 3;
        }
    }

    @container (min-width: 876px) {
        .efa-snapshot-columns {
            grid-template-columns: 1fr 1fr;
        }
        .efa-col-equipment {
            grid-column: 1;
            grid-row: 1 / span 2;
        }
        .efa-col-character {
            grid-column: 2;
            grid-row: 1;
        }
        .efa-col-stats {
            grid-column: 2;
            grid-row: 2;
        }
    }

    @container (min-width: 1308px) {
        .efa-snapshot-columns {
            grid-template-columns: 1fr 1fr 1fr;
        }
        .efa-col-character {
            grid-column: 1;
            grid-row: 1;
        }
        .efa-col-equipment {
            grid-column: 2;
            grid-row: 1;
        }
        .efa-col-stats {
            grid-column: 3;
            grid-row: 1;
        }
    }
</style>
