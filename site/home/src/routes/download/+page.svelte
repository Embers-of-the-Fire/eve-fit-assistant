<script lang="ts">
import { RELEASE_API_URL } from "$lib/api/releases";
import type { ArtifactInfo, VariantInfo } from "$lib/download-state.svelte";
import { downloadState } from "$lib/download-state.svelte";
import { t } from "$lib/i18n/index.svelte";
import type { TranslationKey } from "$lib/i18n/translations";

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

const androidVariants = ["general", "armv7", "arm64", "x64"] as const;
const linuxVariants = ["appimage", "native"] as const;
// Installer is listed first: on Windows the MSI bundle is the recommended
// distribution, the native zip is a fallback.
const windowsVariants = ["installer", "native"] as const;

const variantLabels: Record<string, string> = {
    general: "Universal",
    arm64: "ARM64",
    armv7: "ARMv7",
    x64: "x86_64",
    appimage: "AppImage",
    native: "Native (zip)",
    installer: "Installer (MSI)",
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

const linuxCtaKeys: Record<(typeof linuxVariants)[number], TranslationKey> = {
    appimage: "download.linux.appimage",
    native: "download.linux.native",
};

const windowsCtaKeys: Record<(typeof windowsVariants)[number], TranslationKey> = {
    installer: "download.windows.installer",
    native: "download.windows.native",
};

type DetectedOS = "android" | "linux" | "windows" | "other";

let uaPlatform = $state("");
let uaArch = $state<string | undefined>();
let uaBitness = $state<string | undefined>();

$effect(() => {
    if (typeof navigator === "undefined") return;
    uaPlatform = navigator.platform ?? "";
    if (!("userAgentData" in navigator)) return;
    const uad: {
        getHighEntropyValues: (
            hints: string[],
        ) => Promise<{ architecture?: string; bitness?: string }>;
    } = (navigator as { userAgentData: unknown }).userAgentData as typeof uad;
    uad.getHighEntropyValues(["architecture", "bitness"])
        .then((v) => {
            uaArch = v.architecture;
            uaBitness = v.bitness;
        })
        .catch(() => {});
});

// Android browsers report navigator.platform as "Linux armv8l", so the
// android substring must win over linux.
const detectedOS = $derived.by<DetectedOS>(() => {
    const platform = uaPlatform.toLowerCase();
    const ua = typeof navigator === "undefined" ? "" : navigator.userAgent.toLowerCase();
    if (platform.includes("android") || ua.includes("android")) return "android";
    if (platform.startsWith("win") || ua.includes("windows")) return "windows";
    if (platform.includes("linux")) return "linux";
    return "other";
});

const detected = $derived(recommendedVariant(uaArch, uaBitness));

// Linux builds ship x86-64 only; unknown arch (non-Chromium) is assumed x86-64.
const linuxSupported = $derived.by(() => {
    if (uaArch === undefined && uaBitness === undefined) return true;
    if (uaArch === "arm") return false;
    return !(uaBitness === "32");
});

type PlatformTab = "android" | "linux" | "windows" | "web" | "other";
const tabKeys: Record<PlatformTab, TranslationKey> = {
    android: "download.tabs.android",
    linux: "download.tabs.linux",
    windows: "download.tabs.windows",
    web: "download.tabs.web",
    other: "download.tabs.other",
};
const tabs: PlatformTab[] = ["web", "android", "linux", "windows", "other"];

let tabOverride = $state<PlatformTab | null>(null);
const activeTab = $derived<PlatformTab>(
    tabOverride ??
        (detectedOS === "linux" ? "linux" : detectedOS === "windows" ? "windows" : "android"),
);

function rawArchDisplay(arch: string | undefined, bitness: string | undefined): string {
    if (!arch && !bitness) return "Unknown";
    const bits = bitness ? `${bitness}-bit` : "unknown bitness";
    return arch ? `${arch} (${bits})` : `unknown arch (${bits})`;
}

function osDisplay(os: DetectedOS): string {
    if (os === "android") return "Android";
    if (os === "linux") return "Linux";
    if (os === "windows") return "Windows";
    return uaPlatform || "Unknown";
}

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

const availableLinux = $derived(linuxVariants.filter((k) => artifact?.linux?.[k]));
const availableWindows = $derived(windowsVariants.filter((k) => artifact?.windows?.[k]));

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

{#snippet variantCard(
    platform: string,
    key: string,
    info: VariantInfo | undefined,
    descKey: TranslationKey,
    ctaKey: TranslationKey,
    hero: boolean,
)}
	{#if info}
		<a
			href={info.download_url}
			target="_blank"
			rel="noopener noreferrer"
			class="card-hover-glow group relative rounded-lg bg-eve-surface p-8 transition-all duration-300 {hero ? 'border-2 border-eve-gold/40 text-center' : 'border border-eve-border'}"
		>
			{#if hero}
				<div class="mb-2 inline-block rounded-full bg-eve-gold/15 px-3 py-0.5 text-xs font-semibold uppercase tracking-wider text-eve-gold">{t('download.recommended')}</div>
			{:else}
				<div class="card-icon mb-5 inline-flex h-14 w-14 items-center justify-center rounded border border-eve-border bg-eve-surface-alt text-eve-gold text-2xl transition-all duration-300 group-hover:scale-110 group-hover:rotate-6">▣</div>
			{/if}
			<h2 class="text-xl font-semibold text-eve-text transition-colors duration-300 group-hover:text-eve-gold">
				{platform} — {variantLabel(key)}
			</h2>
			{#if artifact}
				<p class="mt-1 text-xs text-eve-text-muted">v{artifact.version}</p>
			{/if}
			<p class="mt-3 text-sm leading-relaxed text-eve-text-muted">{t(descKey)}</p>
			<div class="mt-6 flex items-center {hero ? 'justify-center' : 'justify-between'}">
				<div class="flex items-center gap-2 text-sm text-eve-gold">
					<span class="font-medium">{t(ctaKey)}</span>
					<span class="text-lg transition-transform duration-300 group-hover:translate-x-1">&rarr;</span>
				</div>
				{#if !hero}
					<span class="text-xs text-eve-text-muted">{formatSize(info.size)} MB</span>
				{/if}
			</div>
		</a>
	{:else}
		<div
			class="relative rounded-lg border border-dashed border-eve-border bg-eve-surface p-8 cursor-not-allowed {hero ? 'text-center' : ''}"
		>
			{#if hero}
				<div class="mb-2 inline-block rounded-full bg-eve-surface-alt px-3 py-0.5 text-xs font-semibold uppercase tracking-wider text-eve-text-dim">{t('download.not_available')}</div>
			{:else}
				<div class="card-icon mb-5 inline-flex h-14 w-14 items-center justify-center rounded border border-eve-border bg-eve-surface-alt text-eve-text-dim text-2xl">▣</div>
			{/if}
			<h2 class="text-xl font-semibold text-eve-text-dim">
				{platform} — {variantLabel(key)}
			</h2>
			<p class="mt-3 text-sm leading-relaxed text-eve-text-dim">{t(descKey)}</p>
			<div class="mt-6 flex items-center {hero ? 'justify-center' : 'justify-between'}">
				<span class="text-sm text-eve-text-dim">{t('download.not_available')}</span>
			</div>
		</div>
	{/if}
{/snippet}

{#snippet unavailableNotice(descKey: TranslationKey)}
	<div class="mx-auto mb-6 max-w-xl rounded-lg border border-eve-border bg-eve-surface p-8 text-center opacity-80">
		<h2 class="text-xl font-semibold text-eve-text-muted">{t('download.unavailable.title')}</h2>
		<p class="mt-3 text-sm leading-relaxed text-eve-text-muted">{t(descKey)}</p>
	</div>
{/snippet}

{#snippet loadingIndicator()}
	<div class="flex flex-col items-center gap-4 py-16">
		<div
			class="h-10 w-10 animate-spin rounded-full border-2 border-eve-gold border-t-transparent"
		></div>
		<p class="text-sm text-eve-text-muted">{t('download.loading')}</p>
	</div>
{/snippet}

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
			{@render loadingIndicator()}
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

			{#if detectedOS === "linux"}
				{#if !linuxSupported}
					{@render unavailableNotice("download.unavailable.linux_unsupported")}
				{:else if availableLinux.length === 0}
					{@render unavailableNotice("download.unavailable.desc")}
				{:else}
					<div class="mx-auto mb-6 grid max-w-4xl gap-6 sm:grid-cols-2">
						{#each linuxVariants as key}
							{@render variantCard("Linux", key, artifact?.linux?.[key], "download.linux.desc", linuxCtaKeys[key], key === "appimage")}
						{/each}
					</div>
				{/if}
			{:else if detectedOS === "windows"}
				<!-- No architecture gate here (unlike Linux): Windows on ARM runs the
				     x86-64 build under emulation, so offering it is intentional. -->
				{#if availableWindows.length === 0}
					{@render unavailableNotice("download.unavailable.desc")}
				{:else}
					<div class="mx-auto mb-6 grid max-w-4xl gap-6 sm:grid-cols-2">
						{#each windowsVariants as key}
							{@render variantCard("Windows", key, artifact?.windows?.[key], "download.windows.desc", windowsCtaKeys[key], key === "installer")}
						{/each}
					</div>
				{/if}
			{:else if detectedOS === "android"}
				{#if artifact?.android?.[detected]}
					<div class="mx-auto mb-6 max-w-xl">
						{@render variantCard("Android", detected, artifact.android[detected], "download.android.desc", "download.android.apk", true)}
					</div>
				{:else}
					{@render unavailableNotice("download.unavailable.desc")}
				{/if}
			{:else}
				{@render unavailableNotice("download.unavailable.desc")}
			{/if}

			<div class="mb-10 text-center text-xs text-eve-text-muted">
				<span class="text-eve-text-muted">{t('download.detected')}</span> {osDisplay(detectedOS)}{#if detectedOS === "android"} — {rawArchDisplay(uaArch, uaBitness)}{#if artifact?.android?.[detected]} — {variantLabel(detected)}{/if}{:else if detectedOS === "linux"} — {availableLinux.length > 0 ? availableLinux.map(variantLabel).join(" / ") : t('download.detected.unavailable')}{:else if detectedOS === "windows"} — {availableWindows.length > 0 ? availableWindows.map(variantLabel).join(" / ") : t('download.detected.unavailable')}{/if}
			</div>
		{/if}

		<div class="eve-divider-gold mb-10"></div>

		<div class="mb-8 flex justify-center gap-2" role="tablist">
			{#each tabs as tab}
				<button
					role="tab"
					aria-selected={activeTab === tab}
					onclick={() => (tabOverride = tab)}
					class="rounded-lg border px-4 py-2 text-sm transition-colors cursor-pointer {activeTab === tab ? 'border-eve-gold/60 bg-eve-gold/10 text-eve-gold' : 'border-eve-border bg-eve-surface text-eve-text-muted hover:border-eve-gold/40 hover:text-eve-text'}"
				>
					{t(tabKeys[tab])}
				</button>
			{/each}
		</div>

		{#if activeTab === "web"}
			<div class="grid gap-8 md:grid-cols-2">
				<a
					href="https://app.efa-tech.dev"
					target="_blank"
					rel="noopener noreferrer"
					class="card-hover-glow group relative rounded-lg border-2 border-eve-gold/40 bg-eve-surface p-8 transition-all duration-300"
				>
					<div class="mb-2 inline-block rounded-full bg-eve-gold/15 px-3 py-0.5 text-xs font-semibold uppercase tracking-wider text-eve-gold">{t('download.recommended')}</div>
					<h2 class="text-xl font-semibold text-eve-text transition-colors duration-300 group-hover:text-eve-gold">
						{t('download.web.stable.title')}
					</h2>
					<p class="mt-3 text-sm leading-relaxed text-eve-text-muted">
						{t('download.web.stable.desc')}
					</p>
					<div class="mt-6 flex items-center gap-2 text-sm text-eve-gold">
						<span class="font-medium">{t('download.web.stable.cta')}</span>
						<span class="text-lg transition-transform duration-300 group-hover:translate-x-1">&rarr;</span>
					</div>
				</a>
				<a
					href="https://app-preview.efa-tech.dev"
					target="_blank"
					rel="noopener noreferrer"
					class="card-hover-glow group relative rounded-lg border border-eve-border bg-eve-surface p-8 transition-all duration-300"
				>
					<div class="card-icon mb-5 inline-flex h-14 w-14 items-center justify-center rounded border border-eve-border bg-eve-surface-alt text-eve-gold text-2xl transition-all duration-300 group-hover:scale-110 group-hover:rotate-6">◈</div>
					<h2 class="text-xl font-semibold text-eve-text transition-colors duration-300 group-hover:text-eve-gold">
						{t('download.web.preview.title')}
					</h2>
					<p class="mt-3 text-sm leading-relaxed text-eve-text-muted">
						{t('download.web.preview.desc')}
					</p>
					<div class="mt-6 flex items-center gap-2 text-sm text-eve-gold">
						<span class="font-medium">{t('download.web.preview.cta')}</span>
						<span class="text-lg transition-transform duration-300 group-hover:translate-x-1">&rarr;</span>
					</div>
				</a>
			</div>
			<p class="mt-6 text-center text-xs text-eve-text-muted">{t('download.web.browser_note')}</p>
		{:else if activeTab === "other"}
			<div class="grid gap-8 md:grid-cols-2">
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
		{:else if downloadState.state === "loading"}
			{@render loadingIndicator()}
		{:else if activeTab === "android"}
			<div class="grid gap-8 md:grid-cols-2">
				{#each androidVariants as key}
					{@render variantCard("Android", key, artifact?.android?.[key], "download.android.desc", "download.android.apk", false)}
				{/each}

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
			</div>
		{:else if activeTab === "linux"}
			<div class="grid gap-8 md:grid-cols-2">
				{#each linuxVariants as key}
					{@render variantCard("Linux", key, artifact?.linux?.[key], "download.linux.desc", linuxCtaKeys[key], false)}
				{/each}
			</div>
		{:else}
			<div class="grid gap-8 md:grid-cols-2">
				{#each windowsVariants as key}
					{@render variantCard("Windows", key, artifact?.windows?.[key], "download.windows.desc", windowsCtaKeys[key], false)}
				{/each}
			</div>
		{/if}
	</div>
</section>
