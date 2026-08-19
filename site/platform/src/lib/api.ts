import type { PostSummary, ThreadSummary } from "./types";

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

export async function fetchPosts(locale: string, limit = 50): Promise<PostSummary[]> {
    const data = await getJson<{ posts: PostSummary[] }>(
        `${API_ORIGIN}/platform/internal/posts?limit=${limit}&locale=${encodeURIComponent(locale)}`,
    );
    return data.posts;
}

export async function fetchThreads(postId: string): Promise<ThreadSummary[]> {
    const data = await getJson<{ threads: ThreadSummary[] }>(
        `${API_ORIGIN}/platform/internal/posts/${postId}/threads`,
    );
    return data.threads;
}
