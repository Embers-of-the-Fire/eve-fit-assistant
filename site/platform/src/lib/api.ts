import type {
    PlatformStats,
    PostsPage,
    ShipDetail,
    ShipsPage,
    ThreadSummary,
    TimeWindow,
} from "./types";

// Browser islands call the public platform API directly (CORS permits this);
// SSR frontmatter uses the PLATFORM_API service binding (./platform.ts).
const API_ORIGIN = "https://api.efa-tech.dev";

async function getJson<T>(url: string): Promise<T> {
    const res = await fetch(url);
    if (!res.ok) throw new Error(`Request failed: ${res.status}`);
    return (await res.json()) as T;
}

export function localizedName(names: Record<string, string>, locale = "en"): string {
    return names[locale] ?? names.en ?? Object.values(names)[0] ?? "";
}

export interface FetchPostsOptions {
    cursor?: string | null;
    shipTypeId?: number | null;
    window?: TimeWindow;
    limit?: number;
}

export async function fetchPosts(
    locale: string,
    options: FetchPostsOptions = {},
): Promise<PostsPage> {
    const params = new URLSearchParams({ locale });
    if (options.limit !== undefined) params.set("limit", String(options.limit));
    if (options.cursor) params.set("cursor", options.cursor);
    if (options.shipTypeId) params.set("shipTypeId", String(options.shipTypeId));
    if (options.window && options.window !== "all") params.set("window", options.window);
    return getJson<PostsPage>(`${API_ORIGIN}/platform/internal/posts?${params.toString()}`);
}

export interface FetchShipsOptions {
    q?: string | null;
    window?: TimeWindow;
    cursor?: string | null;
    limit?: number;
}

export async function fetchShips(
    locale: string,
    options: FetchShipsOptions = {},
): Promise<ShipsPage> {
    const params = new URLSearchParams({ locale });
    if (options.limit !== undefined) params.set("limit", String(options.limit));
    if (options.cursor) params.set("cursor", options.cursor);
    if (options.q) params.set("q", options.q);
    if (options.window && options.window !== "all") params.set("window", options.window);
    return getJson<ShipsPage>(`${API_ORIGIN}/platform/internal/ships?${params.toString()}`);
}

export async function fetchShip(shipTypeId: number, locale: string): Promise<ShipDetail> {
    return getJson<ShipDetail>(
        `${API_ORIGIN}/platform/internal/ships/${shipTypeId}?locale=${encodeURIComponent(locale)}`,
    );
}

export async function fetchStats(locale: string): Promise<PlatformStats> {
    return getJson<PlatformStats>(
        `${API_ORIGIN}/platform/internal/stats?locale=${encodeURIComponent(locale)}`,
    );
}

export async function fetchThreads(postId: string): Promise<ThreadSummary[]> {
    const data = await getJson<{ threads: ThreadSummary[] }>(
        `${API_ORIGIN}/platform/internal/posts/${postId}/threads`,
    );
    return data.threads;
}
