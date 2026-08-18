import type { FitListEntry, ThreadSummary } from "./types";

async function getJson<T>(url: string): Promise<T> {
    const res = await fetch(url);
    if (!res.ok) throw new Error(`Request failed: ${res.status}`);
    return (await res.json()) as T;
}

export async function fetchFits(): Promise<FitListEntry[]> {
    const data = await getJson<{ fits: FitListEntry[] }>("/api/posts");
    return data.fits;
}

export async function fetchThreads(requestId: string): Promise<ThreadSummary[]> {
    const data = await getJson<{ threads: ThreadSummary[] }>(`/api/posts/${requestId}/threads`);
    return data.threads;
}
