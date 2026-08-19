<script module lang="ts">
export type DamageType = "em" | "thermal" | "kinetic" | "explosive";
</script>

<script lang="ts">
interface Props {
    /** Filled fraction, 0..1. */
    ratio: number;
    type: DamageType;
    size?: number;
}

let { ratio, type, size = 16 }: Props = $props();

const clamped = $derived(Math.min(Math.max(ratio, 0), 1));
</script>

<span
    class="efa-resonance efa-resonance-{type}"
    style:width="{size}px"
    style:height="{size}px"
    role="presentation"
>
    <span class="efa-resonance-fill" style:height="{clamped * 100}%"></span>
</span>

<style>
    .efa-resonance {
        display: inline-flex;
        flex-direction: column-reverse;
        border: 1px solid var(--efa-border, #22404f);
        border-radius: 1px;
        overflow: hidden;
        box-sizing: border-box;
    }
    .efa-resonance-fill {
        display: block;
        width: 100%;
    }
    .efa-resonance-em .efa-resonance-fill {
        background: #4d9fff;
    }
    .efa-resonance-thermal .efa-resonance-fill {
        background: #e5484d;
    }
    .efa-resonance-kinetic .efa-resonance-fill {
        background: #9aa4af;
    }
    .efa-resonance-explosive .efa-resonance-fill {
        background: #f5a623;
    }
</style>
