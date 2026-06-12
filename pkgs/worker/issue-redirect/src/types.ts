import type { z } from "zod";
import type { BugReportSchema, FeatureRequestSchema } from "./schema.js";

export type BugReport = z.infer<typeof BugReportSchema>;
export type FeatureRequest = z.infer<typeof FeatureRequestSchema>;

export type TemplateType = "bug_report" | "feature_request";

export interface IssueResult {
    issue_url: string;
    issue_number: number;
}

export interface ErrorResponse {
    error: string;
    details?: unknown;
}
