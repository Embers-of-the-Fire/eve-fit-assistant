<script lang="ts">
import LangSwitcher from "$lib/components/LangSwitcher.svelte";
import { initLangAttribute, t } from "$lib/i18n/index.svelte";
import "./layout.css";

const { children } = $props();

$effect(() => {
    initLangAttribute();
});
</script>

<svelte:head>
	<link rel="preconnect" href="https://fonts.googleapis.com" />
	<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin="anonymous" />
	<link
		href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&family=Orbitron:wght@500;600;700;800&display=swap"
		rel="stylesheet"
	/>
</svelte:head>

<div class="flex min-h-screen flex-col">
	<header class="fixed top-0 z-50 w-full border-b border-eve-border backdrop-blur-md bg-eve-bg/80">
		<nav class="mx-auto flex max-w-6xl items-center justify-between px-6 py-4">
			<a href="/" class="flex items-center gap-3 group">
				<img
					src="/logo.png"
					alt={t('brand.name')}
					class="h-8 w-auto transition-transform duration-300 group-hover:scale-105"
				/>
				<span
					class="text-lg font-semibold text-eve-text tracking-wide transition-colors duration-300 group-hover:text-eve-gold"
				>
					{t('brand.name')}
				</span>
			</a>
			<div class="flex items-center gap-8 text-sm text-eve-text-muted">
				<a href="/#features" class="nav-link pb-0.5 hover:text-eve-gold transition-colors">{t('nav.features')}</a>
				<a href="/download" class="nav-link pb-0.5 hover:text-eve-gold transition-colors">{t('nav.download')}</a>
				<a href="/#about" class="nav-link pb-0.5 hover:text-eve-gold transition-colors">{t('nav.about')}</a>
				<a href="/report" class="nav-link pb-0.5 hover:text-eve-gold transition-colors">{t('nav.report')}</a>
				<a
					href="/#get-started"
					class="rounded border border-eve-gold/40 px-4 py-1.5 text-eve-gold hover:bg-eve-gold/10 transition-all duration-300 text-sm hover:border-eve-gold/60 hover:shadow-[0_0_20px_rgba(200,169,81,0.1)]"
				>
					{t('nav.get_started')}
				</a>
				<LangSwitcher />
			</div>
		</nav>
	</header>

	<main class="flex-1 pt-16">
		{@render children()}
	</main>

	<footer class="border-t border-eve-border">
		<div class="mx-auto max-w-6xl px-6 py-10">
			<div class="eve-divider mb-8"></div>
			<div class="flex flex-col items-center gap-4 sm:flex-row sm:justify-between">
				<div class="flex items-center gap-3">
					<img
						src="/logo.png"
						alt={t('brand.name')}
						class="h-5 w-auto opacity-60 transition-opacity duration-300 hover:opacity-80"
					/>
					<span class="text-sm text-eve-text-muted">{t('brand.name')}</span>
				</div>
				<div class="text-xs text-eve-text-muted">
					<p>{t('footer.trademark_1')}</p>
					<p class="mt-1">{t('footer.trademark_2')}</p>
				</div>
			</div>
		</div>
	</footer>
</div>
