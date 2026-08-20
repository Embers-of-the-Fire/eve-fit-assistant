import { defineMiddleware } from "astro:middleware";

import { defaultCache, edgeCacheKey } from "./lib/cache";

const EDGE_CACHE_CONTROL = "public, max-age=31536000, immutable";
const BROWSER_CACHE_CONTROL = "public, max-age=60";

function isCacheableHtml(response: Response): boolean {
    return (
        response.status === 200 &&
        (response.headers.get("content-type")?.includes("text/html") ?? false) &&
        !response.headers.has("set-cookie")
    );
}

function withBrowserCacheControl(response: Response): Response {
    const result = new Response(response.body, response);
    result.headers.set("Cache-Control", BROWSER_CACHE_CONTROL);
    return result;
}

export const onRequest = defineMiddleware(async (context, next) => {
    if (
        import.meta.env.DEV ||
        context.request.method !== "GET" ||
        context.request.headers.has("cookie")
    ) {
        return next();
    }

    const cache = defaultCache();
    const cacheKey = edgeCacheKey(context.request);
    const hit = await cache.match(cacheKey);
    if (hit) return withBrowserCacheControl(hit);

    const response = await next();
    if (!isCacheableHtml(response)) return response;

    const edgeCopy = new Response(response.body, response);
    edgeCopy.headers.set("Cache-Control", EDGE_CACHE_CONTROL);
    context.locals.cfContext.waitUntil(cache.put(cacheKey, edgeCopy.clone()));
    return withBrowserCacheControl(edgeCopy);
});
