import cloudflare from "@astrojs/cloudflare";
import { cacheCloudflare } from "@astrojs/cloudflare/cache";
import svelte from "@astrojs/svelte";
import tailwindcss from "@tailwindcss/vite";
import { defineConfig } from "astro/config";

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
    },
});
