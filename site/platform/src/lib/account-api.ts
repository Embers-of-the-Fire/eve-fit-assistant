import type { PlatformSession } from "efa-platform-client-ts";
import type { Comment, PostsPage } from "./types";

// Authenticated platform API calls for browser islands (public reads stay in
// ./api.ts). The session's authedFetch attaches a valid access token,
// refreshing as needed and retrying once on a 401; a session rejected again
// after the retry surfaces through the session's onAuthRequired hook.

const API_ORIGIN = __PLATFORM_API_ORIGIN__;

export interface FetchMyPostsOptions {
    cursor?: string | null;
    limit?: number;
}

export async function fetchMyPosts(
    session: PlatformSession,
    locale: string,
    options: FetchMyPostsOptions = {},
): Promise<PostsPage> {
    const params = new URLSearchParams({ locale });
    if (options.limit !== undefined) params.set("limit", String(options.limit));
    if (options.cursor) params.set("cursor", options.cursor);
    const res = await session.authedFetch(
        `${API_ORIGIN}/platform/internal/my/posts?${params.toString()}`,
    );
    if (!res.ok) throw new Error(`Request failed: ${res.status}`);
    return (await res.json()) as PostsPage;
}

/** Deletes a post the session's account is allowed to delete (own, or any
 * with the `all` qualifier). Throws Error("forbidden") on a 403 so callers
 * can show a permission message instead of a generic failure. */
export async function deletePost(session: PlatformSession, postId: string): Promise<void> {
    const res = await session.authedFetch(`${API_ORIGIN}/platform/internal/posts/${postId}`, {
        method: "DELETE",
    });
    if (res.status === 403) throw new Error("forbidden");
    if (!res.ok) throw new Error(`Request failed: ${res.status}`);
}

/** Posts a markdown comment on a post's discussion thread. Returns the
 * created comment as stored. Throws Error("forbidden") on a 403. */
export async function createComment(
    session: PlatformSession,
    postId: string,
    body: string,
): Promise<Comment> {
    const res = await session.authedFetch(
        `${API_ORIGIN}/platform/internal/posts/${postId}/comments`,
        {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ body }),
        },
    );
    if (res.status === 403) throw new Error("forbidden");
    if (!res.ok) throw new Error(`Request failed: ${res.status}`);
    return (await res.json()) as Comment;
}

/** Deletes a comment the session's account is allowed to delete (own, or any
 * with the `all` qualifier). Throws Error("forbidden") on a 403. */
export async function deleteComment(session: PlatformSession, commentId: string): Promise<void> {
    const res = await session.authedFetch(`${API_ORIGIN}/platform/internal/comments/${commentId}`, {
        method: "DELETE",
    });
    if (res.status === 403) throw new Error("forbidden");
    if (!res.ok) throw new Error(`Request failed: ${res.status}`);
}
