<script lang="ts">
import { t } from "$lib/i18n/index.svelte";

const featureKeys = [
    "local_fit",
    "item_detail",
    "skill_profiles",
    "rust_backend",
    "offline_data",
    "cross_platform",
] as const;

const featureIcons: Record<string, string> = {
    local_fit: "◆",
    item_detail: "◇",
    skill_profiles: "◈",
    rust_backend: "▣",
    offline_data: "▥",
    cross_platform: "◫",
};

const stagger1 = "animate-[fade-in-up_0.7s_ease-out_forwards] opacity-0";
const stagger2 = "animate-[fade-in-up_0.7s_ease-out_0.15s_forwards] opacity-0";
const stagger3 = "animate-[fade-in-up_0.7s_ease-out_0.3s_forwards] opacity-0";
const stagger4 = "animate-[fade-in-up_0.7s_ease-out_0.45s_forwards] opacity-0";
</script>

<svelte:head>
	<title>{t('home.title')}</title>
	<meta name="description" content={t('home.meta_description')} />
</svelte:head>

<!-- Hero -->
<section class="relative overflow-hidden">
	<div class="absolute top-0 right-0 w-96 h-96 bg-eve-gold-glow/20 rounded-full blur-3xl animate-[float_8s_ease-in-out_infinite]"></div>
	<div class="absolute bottom-0 left-12 w-72 h-72 bg-eve-cyan-dim/15 rounded-full blur-3xl animate-[float_6s_ease-in-out_infinite_1s]"></div>
	<div class="absolute top-1/3 left-1/4 w-48 h-48 bg-eve-gold-glow/10 rounded-full blur-2xl animate-[float_10s_ease-in-out_infinite_2s]"></div>

	<div class="absolute inset-0 overflow-hidden pointer-events-none opacity-[0.03]">
		<div class="absolute inset-0 animate-[scanline_8s_linear_infinite] bg-gradient-to-b from-transparent via-eve-gold to-transparent h-[40%] -top-full"></div>
	</div>

	<div
		class="relative mx-auto max-w-6xl px-6 pt-24 pb-20 sm:pt-32 sm:pb-28 flex flex-col items-center text-center"
	>
		<div
			class="{stagger1} mb-6 inline-flex items-center gap-2 rounded-full border border-eve-border bg-eve-surface px-4 py-1.5 text-xs text-eve-gold tracking-widest uppercase"
		>
			<span class="h-1.5 w-1.5 rounded-full bg-eve-gold animate-[twinkle_2s_ease-in-out_infinite]"></span>
			{t('hero.badge')}
		</div>

		<h1 class="{stagger2} max-w-3xl text-4xl font-bold tracking-tight sm:text-5xl lg:text-6xl" style="font-family: 'Orbitron', 'Inter', sans-serif;">
			<span class="text-eve-text">{t('hero.heading_1')}</span>
			<span
				class="mt-3 block bg-gradient-to-r from-eve-gold via-eve-cyan to-eve-gold bg-[length:200%_auto] bg-clip-text text-transparent text-gradient-animate"
			>
				{t('hero.heading_2')}
			</span>
		</h1>

		<p class="{stagger3} mt-6 max-w-xl text-lg leading-relaxed text-eve-text-muted">
			{t('hero.description')}
		</p>

		<div class="{stagger4} mt-10 flex flex-wrap items-center justify-center gap-4">
			<a
				href="https://app.efa-tech.dev"
				target="_blank"
				rel="noopener noreferrer"
				class="btn-glow eve-angle-cut inline-flex items-center gap-2 bg-eve-gold px-8 py-3 text-sm font-semibold text-eve-bg hover:bg-eve-gold/90 transition-all duration-300 group"
			>
				{t('hero.open_web_app')}
				<span class="text-lg transition-transform duration-300 group-hover:translate-x-1 inline-block">&rarr;</span>
			</a>
			<a
				href="/download"
				class="eve-angle-cut inline-flex items-center gap-2 bg-eve-surface px-8 py-3 text-sm font-medium text-eve-text hover:bg-eve-surface-alt transition-all duration-300 group"
			>
				{t('hero.get_started')}
				<span class="text-lg transition-transform duration-300 group-hover:translate-x-1 inline-block">&rarr;</span>
			</a>
			<a
				href="#features"
				class="eve-angle-cut inline-flex items-center gap-2 bg-eve-surface px-8 py-3 text-sm font-medium text-eve-text hover:bg-eve-surface-alt transition-all duration-300 group"
			>
				{t('hero.learn_more')}
			</a>
		</div>
	</div>
	<div class="eve-divider-gold"></div>
</section>

<!-- Features -->
<section id="features" class="py-24 sm:py-32">
	<div class="mx-auto max-w-6xl px-6">
		<div class="text-center">
			<h2 class="text-3xl font-bold tracking-tight text-eve-text sm:text-4xl" style="font-family: 'Orbitron', 'Inter', sans-serif;">
				{t('features.heading')}
			</h2>
			<div class="mt-4 flex items-center justify-center gap-3">
				<div class="eve-divider w-12 hidden sm:block"></div>
				<p class="text-eve-text-muted">{t('features.subtitle')}</p>
				<div class="eve-divider w-12 hidden sm:block"></div>
			</div>
		</div>

		<div class="mt-16 grid gap-8 sm:grid-cols-2 lg:grid-cols-3">
			{#each featureKeys as key, i}
				{@const delay = `${0.15 + i * 0.1}s`}
				<div
					class="card-hover-glow group relative rounded-lg border border-eve-border bg-eve-surface p-8"
					style="animation: fade-in-up 0.7s ease-out {delay} forwards; opacity: 0;"
				>
					<div
						class="card-icon mb-4 inline-flex h-12 w-12 items-center justify-center rounded border border-eve-border bg-eve-surface-alt text-eve-gold text-xl transition-all duration-300 group-hover:scale-110 group-hover:rotate-6"
					>
						{featureIcons[key]}
					</div>
					<h3 class="text-lg font-semibold text-eve-text transition-colors duration-300 group-hover:text-eve-gold">
						{t(`features.${key}.title`)}
					</h3>
					<p class="mt-3 text-sm leading-relaxed text-eve-text-muted">{t(`features.${key}.desc`)}</p>
				</div>
			{/each}
		</div>
	</div>
</section>

<!-- Divider -->
<div class="eve-divider mx-auto max-w-6xl px-6"></div>

<!-- Architecture -->
<section id="about" class="py-24 sm:py-32">
	<div class="mx-auto max-w-6xl px-6">
		<div
			class="card-hover-glow rounded-lg border border-eve-border bg-eve-surface p-10 sm:p-16 transition-all duration-500"
		>
			<div class="flex flex-col items-center text-center">
				<div
					class="mb-4 text-sm font-medium tracking-widest text-eve-gold uppercase animate-[twinkle_3s_ease-in-out_infinite]"
				>
					{t('architecture.label')}
				</div>
				<h2
					class="max-w-2xl text-2xl font-bold tracking-tight text-eve-text sm:text-3xl"
					style="font-family: 'Orbitron', 'Inter', sans-serif;"
				>
					{t('architecture.heading')}
				</h2>
				<p class="mt-4 max-w-xl text-sm leading-relaxed text-eve-text-muted">
					{t('architecture.description')}
				</p>
				<div class="mt-8 flex flex-wrap items-center justify-center gap-6 text-sm text-eve-text-muted">
					<div class="flex items-center gap-2 transition-colors duration-300 hover:text-eve-gold">
						<span class="h-1.5 w-1.5 rounded-full bg-eve-gold/50"></span>
						{t('architecture.tech_flutter')}
					</div>
					<div class="flex items-center gap-2 transition-colors duration-300 hover:text-eve-gold">
						<span class="h-1.5 w-1.5 rounded-full bg-eve-gold/50"></span>
						{t('architecture.tech_rust')}
					</div>
					<div class="flex items-center gap-2 transition-colors duration-300 hover:text-eve-gold">
						<span class="h-1.5 w-1.5 rounded-full bg-eve-gold/50"></span>
						{t('architecture.tech_python')}
					</div>
					<div class="flex items-center gap-2 transition-colors duration-300 hover:text-eve-gold">
						<span class="h-1.5 w-1.5 rounded-full bg-eve-gold/50"></span>
						{t('architecture.tech_offline')}
					</div>
					<div class="flex items-center gap-2 transition-colors duration-300 hover:text-eve-gold">
						<span class="h-1.5 w-1.5 rounded-full bg-eve-gold/50"></span>
						{t('architecture.tech_oss')}
					</div>
				</div>
			</div>
		</div>
	</div>
</section>

<!-- CTA -->
<section id="get-started" class="py-24 sm:py-32">
	<div class="mx-auto max-w-6xl px-6">
		<div
			class="rounded-lg border border-eve-gold/20 bg-gradient-to-br from-eve-surface via-eve-surface to-eve-gold-glow/30 p-10 sm:p-16 text-center transition-all duration-500 hover:border-eve-gold/40 hover:shadow-[0_0_60px_rgba(200,169,81,0.06)]"
		>
			<h2
				class="text-2xl font-bold tracking-tight text-eve-text sm:text-3xl"
				style="font-family: 'Orbitron', 'Inter', sans-serif;"
			>
				{t('cta.heading')}
			</h2>
			<p class="mt-4 max-w-lg mx-auto text-sm text-eve-text-muted">
				{t('cta.description')}
			</p>
			<div class="mt-8 flex flex-wrap items-center justify-center gap-4">
				<a
					href="https://github.com/Embers-of-the-Fire/eve-fit-assistant"
					target="_blank"
					rel="noopener noreferrer"
					class="btn-glow eve-angle-cut inline-flex cursor-pointer items-center gap-2 bg-eve-gold px-10 py-3.5 text-sm font-semibold text-eve-bg hover:bg-eve-gold/90 transition-all duration-300 group animate-[glow-pulse_3s_ease-in-out_infinite]"
				>
					{t('cta.github')}
					<span class="text-lg transition-transform duration-300 group-hover:translate-x-1 inline-block">&rarr;</span>
				</a>
			<a
				href="https://qm.qq.com/q/bLyF0dNYTm"
				target="_blank"
				rel="noopener noreferrer"
				class="eve-angle-cut inline-flex items-center gap-2 bg-eve-surface px-10 py-3.5 text-sm font-medium text-eve-text hover:bg-eve-surface-alt transition-all duration-300 group"
			>
				{t('cta.qq_group')}
				<span class="text-lg transition-transform duration-300 group-hover:translate-x-1 inline-block">&rarr;</span>
			</a>
			<a
				href="https://docs.efa-tech.dev"
				target="_blank"
				rel="noopener noreferrer"
				class="eve-angle-cut inline-flex items-center gap-2 bg-eve-surface px-10 py-3.5 text-sm font-medium text-eve-text hover:bg-eve-surface-alt transition-all duration-300 group"
			>
				{t('cta.manual')}
				<span class="text-lg transition-transform duration-300 group-hover:translate-x-1 inline-block">&rarr;</span>
			</a>
			</div>
		</div>
	</div>
</section>
