<script module lang="ts">
export type DamageType = "em" | "thermal" | "kinetic" | "explosive";

const TYPE_COLORS: Record<DamageType, string> = {
    em: "#2196f3",
    thermal: "#f44336",
    kinetic: "#9e9e9e",
    explosive: "#ff9800",
};
</script>

<script lang="ts">
interface Props {
    /** Raw value; `1 - ratio` is the displayed resistance fraction. */
    ratio: number;
    type: DamageType;
}

let { ratio, type }: Props = $props();

const percent = $derived(Math.round((1 - ratio) * 100));
</script>

<span
    class="efa-resonance"
    style:background="linear-gradient(to right, {TYPE_COLORS[type]} {percent}%, #000 {percent}%)"
    role="presentation"
>
    {percent}%
</span>

<style>
    .efa-resonance {
        display: block;
        margin: 4px 10px;
        height: 22px;
        border: 1px solid #fff;
        border-radius: 1px;
        box-sizing: border-box;
        text-align: center;
        font-size: 13px;
        line-height: 20px;
        font-variant-numeric: tabular-nums;
    }
</style>
