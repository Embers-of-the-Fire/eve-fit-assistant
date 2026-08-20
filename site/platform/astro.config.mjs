import cloudflare from "@astrojs/cloudflare";
import svelte from "@astrojs/svelte";
import tailwindcss from "@tailwindcss/vite";
import { defineConfig } from "astro/config";

// Baked into the bundle as __EFA_BUILD_ID__; the edge cache keys off it, so
// every rebuild automatically invalidates previously cached HTML.
const buildId = process.env.EFA_BUILD_ID ?? `${Date.now().toString(36)}`;

export default defineConfig({
    output: "server",
    adapter: cloudflare({
        imageService: "passthrough",
        platformProxy: {
            enabled: true,
        },
    }),
    session: false,
    integrations: [svelte()],
    vite: {
        plugins: [tailwindcss()],
        define: {
            __EFA_BUILD_ID__: JSON.stringify(buildId),
        },
    },
});
