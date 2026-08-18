import cloudflare from "@astrojs/cloudflare";
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
    session: false,
    integrations: [svelte()],
    vite: {
        plugins: [tailwindcss()],
    },
});
