/// <reference path="../.astro/types.d.ts" />

declare namespace Cloudflare {
    interface Env {
        FIT_DB: D1Database;
    }
}
