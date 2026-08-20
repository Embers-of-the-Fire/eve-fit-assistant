/// <reference path="../.astro/types.d.ts" />

declare const __EFA_BUILD_ID__: string;

declare namespace Cloudflare {
    interface Env {
        PLATFORM_API: Fetcher;
    }
}
