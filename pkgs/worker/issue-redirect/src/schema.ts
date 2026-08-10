import { z } from "zod";

const PlatformEnum = z.enum(["Android", "iOS", "Web", "Windows 10/11", "Linux", "Other"]);

const LanguageEnum = z.enum(["en", "zh"]);

const MetadataSchema = z
    .record(z.enum(["os_version", "app_version"]), z.string().max(200))
    .optional();

const CommonFields = {
    language: LanguageEnum.default("en"),
    title: z.string().min(1, "title is required"),
    labels: z.array(z.string()).optional(),
    metadata: MetadataSchema,
};

export const BugReportSchema = z.object({
    ...CommonFields,
    summary: z.string().min(1, "summary is required"),
    steps: z.string().min(1, "steps is required"),
    expected: z.string().min(1, "expected is required"),
    actual: z.string().min(1, "actual is required"),
    platform: PlatformEnum,
    version: z.string().optional(),
    logs: z.string().optional(),
});

export const FeatureRequestSchema = z.object({
    ...CommonFields,
    problem: z.string().min(1, "problem is required"),
    proposal: z.string().min(1, "proposal is required"),
    alternatives: z.string().optional(),
    impact: z.string().min(1, "impact is required"),
    extra: z.string().optional(),
});

const DocsCommonFields = {
    language: LanguageEnum.default("en"),
    topic: z.string().min(1, "topic is required"),
    labels: z.array(z.string()).optional(),
    metadata: MetadataSchema,
};

export const DocsFlagSchema = z.object({
    ...DocsCommonFields,
    pagePath: z.string().min(1, "pagePath is required"),
    pageId: z.string().min(1, "pageId is required"),
    content: z.string().min(1, "content is required"),
});

export const DocsQuestionSchema = z.object({
    ...DocsCommonFields,
    content: z.string().min(1, "content is required"),
});

export const AgentFeedbackSchema = z.object({
    ...CommonFields,
    body: z.string().min(1, "body is required"),
    dialog: z.string().optional(),
});
