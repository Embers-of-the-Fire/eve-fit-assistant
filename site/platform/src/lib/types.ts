export interface PostSummary {
    postId: string;
    /** The authoring account's user id; null for tombstoned authors. */
    authorId: string | null;
    /** True when the author is a tombstone or a deregistered account. */
    authorDeleted: boolean;
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

export interface Comment {
    commentId: string;
    /** The authoring account's user id; null for tombstoned authors. */
    authorId: string | null;
    /** True when the author is a tombstone or a deregistered account. */
    authorDeleted: boolean;
    /** Raw markdown body; render through lib/markdown.ts, never raw HTML. */
    body: string;
    createdAt: string;
}

export interface CommentsPage {
    comments: Comment[];
    nextCursor: string | null;
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

export type TimeWindow = "24h" | "7d" | "30d" | "all";

export interface ShipSummary {
    shipTypeId: number;
    shipName: string;
    postCount: number;
    lastPostAt: string;
}

export interface ShipsPage {
    ships: ShipSummary[];
    nextCursor: string | null;
}

export interface ShipDetail {
    shipTypeId: number;
    shipName: string;
    postCount: number;
    firstPostAt: string;
    lastPostAt: string;
}

export interface ApiError {
    error: string;
    message: string;
}
