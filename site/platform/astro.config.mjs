import cloudflare from "@astrojs/cloudflare";
import { cacheCloudflare } from "@astrojs/cloudflare/cache";
import svelte from "@astrojs/svelte";
import tailwindcss from "@tailwindcss/vite";
import { defineConfig } from "astro/config";

// Origin of the platform API worker (worker/efa-platform-api), baked into the
// client bundles at build time. The target environment is selected via
// CLOUDFLARE_ENV (see "Deploying" in AGENTS.md): preview builds talk to the
// preview API directly; everything else (production, local dev) talks to the
// production API.
const platformApiOrigin =
    process.env.CLOUDFLARE_ENV === "preview"
        ? "https://efa-platform-api-preview.stellarishs.workers.dev"
        : "https://api.efa-tech.dev";

export default defineConfig({
    output: "server",
    adapter: cloudflare({
        imageService: "passthrough",
        platformProxy: {
            enabled: true,
        },
    }),
    cache: {
        provider: cacheCloudflare(),
    },
    routeRules: {
        "/post/[id]": { maxAge: 31536000, swr: 86400 },
    },
    session: false,
    integrations: [svelte()],
    vite: {
        plugins: [tailwindcss()],
        define: {
            __PLATFORM_API_ORIGIN__: JSON.stringify(platformApiOrigin),
        },
    },
});
