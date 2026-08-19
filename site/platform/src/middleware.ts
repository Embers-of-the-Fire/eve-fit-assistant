import { defineMiddleware } from "astro:middleware";

import { defaultCache } from "./lib/cache";

const FIT_PAGE_PATH = /^\/post\/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\/?$/i;

export const onRequest = defineMiddleware(async (context, next) => {
    if (context.request.method !== "GET" || !FIT_PAGE_PATH.test(context.url.pathname)) {
        return next();
    }

    const cache = defaultCache();
    const cached = await cache.match(context.request);
    if (cached) return cached;

    const response = await next();
    if (response.status !== 200 || !response.headers.get("content-type")?.includes("text/html")) {
        return response;
    }

    const cacheable = new Response(response.body, response);
    cacheable.headers.set("Cache-Control", "public, max-age=31536000, immutable");
    context.locals.cfContext.waitUntil(cache.put(context.request, cacheable.clone()));
    return cacheable;
});
