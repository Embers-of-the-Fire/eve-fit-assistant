import type { z } from "zod";
import type {
    BugReportSchema,
    DocsFlagSchema,
    DocsQuestionSchema,
    FeatureRequestSchema,
} from "./schema.js";

export type BugReport = z.infer<typeof BugReportSchema>;
export type FeatureRequest = z.infer<typeof FeatureRequestSchema>;
export type DocsFlag = z.infer<typeof DocsFlagSchema>;
export type DocsQuestion = z.infer<typeof DocsQuestionSchema>;

export type IssueRequest = BugReport | FeatureRequest | DocsFlag | DocsQuestion;

export type TemplateType = "bug_report" | "feature_request" | "docs_flag" | "docs_question";

export interface IssueResult {
    issue_url: string;
    issue_number: number;
}

export interface ErrorResponse {
    error: string;
    details?: unknown;
}
