<script lang="ts">
import { GLYPHS, type GlyphName } from "../glyphs";

interface Props {
    name: GlyphName;
    size?: number;
    color?: string;
}

let { name, size = 24, color }: Props = $props();
</script>

<svg
    class="efa-glyph"
    width={size}
    height={size}
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    stroke-width="1.8"
    stroke-linecap="round"
    stroke-linejoin="round"
    style:color
    aria-hidden="true"
>
    {@html GLYPHS[name] ?? ""}
</svg>

<style>
    .efa-glyph {
        display: inline-block;
        flex-shrink: 0;
        vertical-align: middle;
    }
</style>
