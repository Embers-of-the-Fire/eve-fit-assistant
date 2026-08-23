/** Builds an unsigned JWT-shaped string with the given `sub` claim for tests. */
export function fakeJwt(sub: string | null): string {
    const payload = sub === null ? {} : { sub };
    const encode = (obj: unknown) => {
        const bytes = new TextEncoder().encode(JSON.stringify(obj));
        const binary = Array.from(bytes, (b) => String.fromCharCode(b)).join("");
        return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
    };
    return `${encode({ alg: "HS256", typ: "JWT" })}.${encode(payload)}.fakesig`;
}
