<script lang="ts">
import { locale } from "$lib/i18n/index.svelte";
import type { Locale } from "$lib/i18n/translations";

const langs: { code: Locale; label: string }[] = [
    { code: "en", label: "EN" },
    { code: "zh", label: "中文" },
];

function switchTo(code: Locale) {
    locale.current = code;
}
</script>

<div class="flex items-center gap-1 text-xs">
	{#each langs as lang}
		<button
			onclick={() => switchTo(lang.code)}
			class="rounded px-2 py-1 transition-all duration-200 {locale.current === lang.code
				? 'bg-eve-gold/15 text-eve-gold border border-eve-gold/30'
				: 'text-eve-text-muted hover:text-eve-text hover:bg-eve-surface-alt border border-transparent'}"
		>
			{lang.label}
		</button>
	{/each}
</div>
