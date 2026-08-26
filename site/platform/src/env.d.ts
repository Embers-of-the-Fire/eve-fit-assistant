/// <reference path="../.astro/types.d.ts" />

declare namespace Cloudflare {
    interface Env {
        PLATFORM_API: Fetcher;
    }
}

/** Platform API origin baked in at build time (see `astro.config.mjs`). */
declare const __PLATFORM_API_ORIGIN__: string;

/** Whether the /platform/* API proxy endpoint serves requests (preview builds only). */
declare const __PLATFORM_API_PROXY_ENABLED__: boolean;
