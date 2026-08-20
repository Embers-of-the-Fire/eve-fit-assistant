/// <reference path="../.astro/types.d.ts" />

declare namespace Cloudflare {
    interface Env {
        PLATFORM_API: Fetcher;
    }
}
