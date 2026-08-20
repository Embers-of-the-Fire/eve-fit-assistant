export const buildId: string = __EFA_BUILD_ID__;

export function defaultCache(): Cache {
    return (caches as unknown as { default: Cache }).default;
}

export function edgeCacheKey(request: Request): Request {
    const url = new URL(request.url);
    url.searchParams.set("__efa_build", buildId);
    return new Request(url, request);
}
