export interface PostSummary {
    postId: string;
    fitHash: string;
    fitName: string;
    /** Preview of the fit's description, truncated to 280 code points. */
    description: string;
    shipName: string;
    shipTypeId: number;
    createdAt: string;
    lastModifiedMs: number;
    generator: string | null;
}

export interface ThreadSummary {
    id: string;
    title: string;
    author: string;
    replyCount: number;
    lastActivityAt: string;
}

export interface PostsPage {
    posts: PostSummary[];
    nextCursor: string | null;
}

export interface TopShip {
    shipTypeId: number;
    shipName: string;
    postCount: number;
}

export interface PlatformStats {
    totalPosts: number;
    distinctShips: number;
    postsLast7d: number;
    topShips: TopShip[];
}

export interface ApiError {
    error: string;
    message: string;
}
