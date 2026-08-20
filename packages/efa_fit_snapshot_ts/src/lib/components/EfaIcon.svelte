<script lang="ts">
import { type EfaIconName, ICONS } from "../icons";

interface Props {
    name: EfaIconName;
    size?: number;
}

let { name, size = 24 }: Props = $props();
</script>

<img
    class="efa-icon"
    src={ICONS[name]}
    width={size}
    height={size}
    alt=""
    loading="lazy"
    draggable="false"
    aria-hidden="true"
/>

<style>
    .efa-icon {
        display: inline-block;
        flex-shrink: 0;
        vertical-align: middle;
        object-fit: contain;
    }
</style>
