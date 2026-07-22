<script lang="ts">
import { RELEASE_API_URL } from "$lib/api/releases";
import { downloadState } from "$lib/download-state.svelte";
import type { ArtifactInfo, VariantInfo } from "$lib/download-state.svelte";
import { t } from "$lib/i18n/index.svelte";

type ApiResponse =
    | {
          ok: true;
          artifacts: Record<string, ArtifactInfo>;
          channels: string[];
      }
    | {
          ok: false;
          error: string;
          channels: string[];
      };

function formatSize(bytes: number): string {
    const mb = bytes / (1024 * 1024);
    return mb < 10 ? mb.toFixed(1) : Math.round(mb).toString();
}

const variantLabels: Record<string, string> = {
    general: "Universal",
    arm64: "ARM64",
    armv7: "ARMv7",
    x64: "x86_64",
};

function variantLabel(key: string): string {
    return variantLabels[key] ?? key;
}

function recommendedVariant(arch: string | undefined, bitness: string | undefined): string {
    if (arch === "arm" && bitness === "64") return "arm64";
    if (arch === "arm" && bitness === "32") return "armv7";
    if (arch === "x86" || arch === "x86_64") return "x64";
    return "general";
}

function rawArchDisplay(arch: string | undefined, bitness: string | undefined): string {
    if (!arch && !bitness) return "Unknown";
    const bits = bitness ? `${bitness}-bit` : "unknown bitness";
    return arch ? `${arch} (${bits})` : `unknown arch (${bits})`;
}

let uaArch = $state<string | undefined>();
let uaBitness = $state<string | undefined>();

$effect(() => {
    if (typeof navigator === "undefined" || !("userAgentData" in navigator)) return;
    const uad: {
        getHighEntropyValues: (
            hints: string[],
        ) => Promise<{ architecture?: string; bitness?: string }>;
    } = (navigator as { userAgentData: unknown }).userAgentData as typeof uad;
    uad.getHighEntropyValues(["architecture", "bitness"]).then((v) => {
        uaArch = v.architecture;
        uaBitness = v.bitness;
    });
});

const detected = $derived(recommendedVariant(uaArch, uaBitness));

let cancelled = false;

$effect(() => {
    cancelled = false;
    fetch(RELEASE_API_URL)
        .then((r) => r.json() as Promise<ApiResponse>)
        .then((data) => {
            if (cancelled) return;
            downloadState.channels = data.channels;
            if (!data.ok) {
                downloadState.state = data.error.includes("not found") ? "empty" : "error";
                return;
            }
            downloadState.artifacts = data.artifacts;
            if (!data.artifacts[downloadState.activeChannel]) {
                downloadState.activeChannel = data.channels[0] ?? "";
            }
            downloadState.state = "loaded";
        })
        .catch(() => {
            if (cancelled) return;
            downloadState.state = "error";
        });
    return () => {
        cancelled = true;
    };
});

const artifact: ArtifactInfo | undefined = $derived(
    downloadState.artifacts[downloadState.activeChannel],
);

function onChannelChange(e: Event) {
    downloadState.activeChannel = (e.target as HTMLSelectElement).value;
}

const stagger1 = "animate-[fade-in-up_0.7s_ease-out_forwards] opacity-0";
const stagger2 = "animate-[fade-in-up_0.7s_ease-out_0.15s_forwards] opacity-0";
</script>

<svelte:head>
	<title>{t('download.title')}</title>
	<meta name="description" content={t('download.meta_description')} />
</svelte:head>

<section class="relative overflow-hidden">
	<div class="absolute top-0 right-0 w-96 h-96 bg-eve-gold-glow/20 rounded-full blur-3xl animate-[float_8s_ease-in-out_infinite]"></div>
	<div class="absolute bottom-0 left-12 w-72 h-72 bg-eve-cyan-dim/15 rounded-full blur-3xl animate-[float_6s_ease-in-out_infinite_1s]"></div>

	<div class="relative mx-auto max-w-6xl px-6 pt-24 pb-20 sm:pt-32 sm:pb-28 flex flex-col items-center text-center">
		<h1 class="{stagger1} max-w-3xl text-4xl font-bold tracking-tight sm:text-5xl lg:text-6xl" style="font-family: 'Orbitron', 'Inter', sans-serif;">
			<span class="text-eve-text">{t('download.heading')}</span>
		</h1>
		<p class="{stagger2} mt-6 max-w-xl text-lg leading-relaxed text-eve-text-muted">
			{t('download.subtitle')}
		</p>
	</div>
	<div class="eve-divider-gold"></div>
</section>

<section class="py-16 sm:py-24">
	<div class="mx-auto max-w-5xl px-6">
		{#if downloadState.state === "loading"}
			<div class="flex flex-col items-center gap-4 py-16">
				<div
					class="h-10 w-10 animate-spin rounded-full border-2 border-eve-gold border-t-transparent"
				></div>
				<p class="text-sm text-eve-text-muted">{t('download.loading')}</p>
			</div>
		{:else if downloadState.state === "empty"}
			<div class="card-hover-glow mx-auto max-w-md rounded-lg border border-eve-border bg-eve-surface p-10 text-center">
				<div class="mb-4 text-4xl text-eve-text-muted">◫</div>
				<h2 class="text-xl font-semibold text-eve-text">{t('download.no_release')}</h2>
				<p class="mt-3 text-sm text-eve-text-muted">{t('download.no_release_desc')}</p>
				<a
					href="https://github.com/Embers-of-the-Fire/eve-fit-assistant"
					target="_blank"
					rel="noopener noreferrer"
					class="mt-6 inline-flex items-center gap-2 text-sm text-eve-gold hover:text-eve-gold/80 transition-colors"
				>
					{t('cta.github')} &rarr;
				</a>
			</div>
		{:else if downloadState.state === "error"}
			<div class="card-hover-glow mx-auto max-w-md rounded-lg border border-eve-red/30 bg-eve-surface p-10 text-center">
				<div class="mb-4 text-3xl text-eve-red">&#9888;</div>
				<h2 class="text-xl font-semibold text-eve-text">{t('download.error')}</h2>
				<p class="mt-3 text-sm text-eve-text-muted">{t('download.error_desc')}</p>
				<a
					href="https://github.com/Embers-of-the-Fire/eve-fit-assistant/releases"
					target="_blank"
					rel="noopener noreferrer"
					class="mt-6 inline-flex items-center gap-2 text-sm text-eve-gold hover:text-eve-gold/80 transition-colors"
				>
					{t('download.error_github')} &rarr;
				</a>
			</div>
		{:else if downloadState.state === "loaded"}
			<div class="mb-10 flex items-center justify-center gap-2">
				<label for="channel-select" class="text-sm text-eve-text-muted">{t('download.channel')}</label>
				<select
					id="channel-select"
					onchange={onChannelChange}
					class="rounded-lg border border-eve-border bg-eve-surface px-4 py-2 text-sm text-eve-text outline-none appearance-none cursor-pointer transition-colors hover:border-eve-gold/40 focus:border-eve-gold focus:ring-1 focus:ring-eve-gold/30"
					style='background-image: url("data:image/svg+xml,%3Csvg xmlns=%27http://www.w3.org/2000/svg%27 width=%2712%27 height=%2712%27 fill=%27%23888%27 viewBox=%270 0 16 16%27%3E%3Cpath d=%27M8 11L3 6h10z%27/%3E%3C/svg%3E"); background-repeat: no-repeat; background-position: right 0.75rem center; padding-right: 2rem;'
				>
					{#each downloadState.channels as ch}
						<option value={ch} selected={ch === downloadState.activeChannel}>{ch}</option>
					{/each}
				</select>
			</div>

			{#if artifact?.android?.[detected]}
				{@const rec = artifact.android[detected]}
				<a
					href={rec.download_url}
					target="_blank"
					rel="noopener noreferrer"
					class="card-hover-glow group relative mx-auto mb-6 block max-w-xl rounded-lg border-2 border-eve-gold/40 bg-eve-surface p-8 text-center transition-all duration-300"
				>
					<div class="mb-2 inline-block rounded-full bg-eve-gold/15 px-3 py-0.5 text-xs font-semibold uppercase tracking-wider text-eve-gold">{t('download.recommended')}</div>
					<h2 class="text-xl font-semibold text-eve-text transition-colors duration-300 group-hover:text-eve-gold">
						Android — {variantLabel(detected)}
					</h2>
					<p class="mt-1 text-xs text-eve-text-muted">v{artifact.version}</p>
					<p class="mt-3 text-sm leading-relaxed text-eve-text-muted">{t('download.android.desc')}</p>
					<div class="mt-5 flex items-center justify-center gap-2 text-sm text-eve-gold">
						<span class="font-medium">{t('download.android.apk')}</span>
						<span class="text-lg transition-transform duration-300 group-hover:translate-x-1">&rarr;</span>
					</div>
				</a>
			{/if}

			<div class="mb-10 text-center text-xs text-eve-text-muted">
				<span class="text-eve-text-muted">{t('download.detected')}</span> {rawArchDisplay(uaArch, uaBitness)} — {variantLabel(detected)}
			</div>

			<div class="eve-divider-gold mb-10"></div>

			<div class="grid gap-8 md:grid-cols-2">
				{#if artifact?.android}
					{#each Object.entries(artifact.android) as [key, info]}
						<a
							href={info.download_url}
							target="_blank"
							rel="noopener noreferrer"
							class="card-hover-glow group relative rounded-lg border border-eve-border bg-eve-surface p-8 transition-all duration-300"
						>
							<div class="card-icon mb-5 inline-flex h-14 w-14 items-center justify-center rounded border border-eve-border bg-eve-surface-alt text-eve-gold text-2xl transition-all duration-300 group-hover:scale-110 group-hover:rotate-6">▣</div>
							<h2 class="text-xl font-semibold text-eve-text transition-colors duration-300 group-hover:text-eve-gold">
								Android — {variantLabel(key)}
							</h2>
							<p class="mt-1 text-xs text-eve-text-muted">
								v{artifact.version}
							</p>
							<p class="mt-3 text-sm leading-relaxed text-eve-text-muted">
								{t('download.android.desc')}
							</p>
							<div class="mt-6 flex items-center justify-between">
								<div class="flex items-center gap-2 text-sm text-eve-gold">
									<span class="font-medium">{t('download.android.apk')}</span>
									<span class="text-lg transition-transform duration-300 group-hover:translate-x-1">&rarr;</span>
								</div>
								<span class="text-xs text-eve-text-muted">
									{formatSize(info.size)} MB
								</span>
							</div>
						</a>
					{/each}
				{/if}

				{#if !artifact?.android?.general}
					<a
						href="https://github.com/Embers-of-the-Fire/eve-fit-assistant/releases/latest"
						target="_blank"
						rel="noopener noreferrer"
						class="card-hover-glow group relative rounded-lg border border-eve-border bg-eve-surface p-8 transition-all duration-300"
					>
						<div class="card-icon mb-5 inline-flex h-14 w-14 items-center justify-center rounded border border-eve-border bg-eve-surface-alt text-eve-gold text-2xl transition-all duration-300 group-hover:scale-110 group-hover:rotate-6">▣</div>
						<h2 class="text-xl font-semibold text-eve-text transition-colors duration-300 group-hover:text-eve-gold">
							{t('download.android.title')}
						</h2>
						<p class="mt-3 text-sm leading-relaxed text-eve-text-muted">
							{t('download.android.desc')}
						</p>
						<div class="mt-6 flex items-center gap-2 text-sm text-eve-gold">
							<span class="font-medium">{t('download.android.apk')}</span>
							<span class="text-lg transition-transform duration-300 group-hover:translate-x-1">&rarr;</span>
						</div>
						<div class="mt-2 text-xs text-eve-text-muted">
							{t('download.android.requirements')}
						</div>
					</a>
				{/if}

				<div class="card-hover-glow group relative rounded-lg border border-eve-border bg-eve-surface p-8 transition-all duration-300 cursor-default">
					<div class="card-icon mb-5 inline-flex h-14 w-14 items-center justify-center rounded border border-eve-border bg-eve-surface-alt text-eve-text-muted text-2xl transition-all duration-300">◇</div>
					<h2 class="text-xl font-semibold text-eve-text transition-colors duration-300">
						{t('download.ios.title')}
					</h2>
					<p class="mt-3 text-sm leading-relaxed text-eve-text-muted">
						{t('download.ios.desc')}
					</p>
					<div class="mt-6 flex items-center gap-2 text-sm text-eve-text-muted">
						<span>{t('download.ios.build')}</span>
					</div>
				</div>

				<a
					href="https://github.com/Embers-of-the-Fire/eve-fit-assistant"
					target="_blank"
					rel="noopener noreferrer"
					class="card-hover-glow group relative rounded-lg border border-eve-border bg-eve-surface p-8 transition-all duration-300"
				>
					<div class="card-icon mb-5 inline-flex h-14 w-14 items-center justify-center rounded border border-eve-border bg-eve-surface-alt text-eve-gold text-2xl transition-all duration-300 group-hover:scale-110 group-hover:rotate-6">◈</div>
					<h2 class="text-xl font-semibold text-eve-text transition-colors duration-300 group-hover:text-eve-gold">
						{t('download.source.title')}
					</h2>
					<p class="mt-3 text-sm leading-relaxed text-eve-text-muted">
						{t('download.source.desc')}
					</p>
					<div class="mt-6 flex items-center gap-2 text-sm text-eve-gold">
						<span class="font-medium">{t('download.source.github')}</span>
						<span class="text-lg transition-transform duration-300 group-hover:translate-x-1">&rarr;</span>
					</div>
				</a>
			</div>
		{/if}
	</div>
</section>
