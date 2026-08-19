export function defaultCache(): Cache {
    return (caches as unknown as { default: Cache }).default;
}
