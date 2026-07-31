export type Platform = "Android" | "iOS" | "Windows 10/11" | "Linux" | "Other";
export type Language = "en" | "zh";

export interface BugReportPayload {
    language: Language;
    title: string;
    summary: string;
    steps: string;
    expected: string;
    actual: string;
    platform: Platform;
    version?: string;
    logs?: string;
    contact?: string;
    labels?: string[];
    metadata?: Record<string, unknown>;
}

export interface FeatureRequestPayload {
    language: Language;
    title: string;
    problem: string;
    proposal: string;
    impact: string;
    alternatives?: string;
    extra?: string;
    contact?: string;
    labels?: string[];
    metadata?: Record<string, unknown>;
}

export interface IssueResult {
    issue_url: string;
    issue_number: number;
}

export interface ValidationError {
    path: string;
    message: string;
}

export interface ErrorResponse {
    error: string;
    details?: ValidationError[] | string;
}

const BASE_URL = "https://api.efa-tech.dev/issue-redirect";

export class ApiError extends Error {
    status: number;
    errors: ValidationError[];

    constructor(message: string, status: number, errors: ValidationError[] = []) {
        super(message);
        this.name = "ApiError";
        this.status = status;
        this.errors = errors;
    }

    static fromResponse(status: number, body: ErrorResponse): ApiError {
        const details = body.details;
        const errors = Array.isArray(details)
            ? details.map((d) => ({ path: d.path, message: d.message }))
            : [];
        return new ApiError(body.error, status, errors);
    }
}

async function post<T>(endpoint: string, body: unknown): Promise<T> {
    let res: Response;
    try {
        res = await fetch(`${BASE_URL}${endpoint}`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(body),
        });
    } catch {
        throw new ApiError("Network error", 0);
    }

    const json = (await res.json()) as ErrorResponse | IssueResult;

    if (!res.ok) {
        throw ApiError.fromResponse(res.status, json as ErrorResponse);
    }

    return json as T;
}

export function submitBugReport(payload: BugReportPayload): Promise<IssueResult> {
    return post<IssueResult>("/bug-report", payload);
}

export function submitFeatureRequest(payload: FeatureRequestPayload): Promise<IssueResult> {
    return post<IssueResult>("/feature-request", payload);
}
