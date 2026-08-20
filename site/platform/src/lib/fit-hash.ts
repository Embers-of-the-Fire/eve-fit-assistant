// A registered fit hash is the lowercase hex sha256 of the canonical fit
// state (worker/efa-platform-fit-storage/src/hash.rs).
export const FIT_HASH_PATTERN = /^[0-9a-f]{64}$/;

export function isValidFitHash(hash: string | null): boolean {
    return typeof hash === "string" && FIT_HASH_PATTERN.test(hash);
}
