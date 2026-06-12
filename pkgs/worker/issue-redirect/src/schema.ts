import { z } from "zod";

const PlatformEnum = z.enum(["Android", "iOS", "Windows 10/11", "Linux", "Other"]);

const LanguageEnum = z.enum(["en", "zh"]);

const CommonFields = {
    language: LanguageEnum.default("en"),
    title: z.string().min(1, "title is required"),
    labels: z.array(z.string()).optional(),
    contact: z.string().optional(),
    metadata: z.record(z.unknown()).optional(),
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
