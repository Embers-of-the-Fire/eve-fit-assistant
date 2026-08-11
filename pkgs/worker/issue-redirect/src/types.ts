import type { z } from "zod";
import type {
    AgentFeedbackSchema,
    BugReportSchema,
    DocsFlagSchema,
    DocsQuestionSchema,
    FeatureRequestSchema,
} from "./schema.js";

export type BugReport = z.infer<typeof BugReportSchema>;
export type FeatureRequest = z.infer<typeof FeatureRequestSchema>;
export type DocsFlag = z.infer<typeof DocsFlagSchema>;
export type DocsQuestion = z.infer<typeof DocsQuestionSchema>;
export type AgentFeedback = z.infer<typeof AgentFeedbackSchema>;

export type IssueRequest = BugReport | FeatureRequest | DocsFlag | DocsQuestion | AgentFeedback;

export type TemplateType =
    | "bug_report"
    | "feature_request"
    | "docs_flag"
    | "docs_question"
    | "agent_feedback";

export interface IssueResult {
    issue_url: string;
    issue_number: number;
}

export interface ErrorResponse {
    error: string;
    details?: unknown;
}
