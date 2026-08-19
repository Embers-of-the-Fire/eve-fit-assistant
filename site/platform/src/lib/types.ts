export interface FitListEntry {
    requestId: string;
    fitHash: string;
    fitName: string;
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

export interface ApiError {
    error: string;
    message: string;
}
