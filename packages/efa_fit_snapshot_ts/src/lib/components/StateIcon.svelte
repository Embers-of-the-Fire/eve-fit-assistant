<script lang="ts">
import type { Slots_SlotState } from "efa-proto-ts/fit_pb";
import { Slots_SlotState as SlotState } from "efa-proto-ts/fit_pb";
import type { Snippet } from "svelte";

interface Props {
    state: Slots_SlotState;
    shape?: "rect" | "circle";
    size?: number;
    children: Snippet;
}

let { state, shape = "rect", size = 35, children }: Props = $props();

const stateClass = $derived(
    state === SlotState.ACTIVE
        ? "active"
        : state === SlotState.ONLINE
          ? "online"
          : state === SlotState.OVERLOAD
            ? "overload"
            : "passive",
);
</script>

<span
    class="efa-state-icon efa-state-{stateClass}"
    class:efa-state-circle={shape === "circle"}
    style:width="{size}px"
    style:height="{size}px"
>
    {@render children()}
</span>

<style>
    .efa-state-icon {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        flex-shrink: 0;
        border: 2px solid var(--efa-state-passive, #2d2d2d);
        border-radius: 2px;
        overflow: hidden;
        box-sizing: border-box;
    }
    .efa-state-circle {
        border-radius: 50%;
    }
    .efa-state-active {
        border-color: var(--efa-state-active, #2e7d32);
    }
    .efa-state-online {
        border-color: var(--efa-state-online, #bdbdbd);
    }
    .efa-state-overload {
        border-color: var(--efa-state-overload, #ef5350);
    }
</style>
