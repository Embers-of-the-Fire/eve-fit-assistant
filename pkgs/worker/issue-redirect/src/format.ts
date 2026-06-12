import type { BugReport, FeatureRequest, TemplateType } from "./types.js";

function formatBugReportEn(req: BugReport): string {
    const lines: string[] = [];
    lines.push("## Summary");
    lines.push(req.summary);
    lines.push("");
    lines.push("## Steps to Reproduce");
    lines.push(req.steps);
    lines.push("");
    lines.push("## Expected Behavior");
    lines.push(req.expected);
    lines.push("");
    lines.push("## Actual Behavior");
    lines.push(req.actual);
    lines.push("");
    lines.push("## Platform");
    lines.push(req.platform);
    if (req.version) {
        lines.push("");
        lines.push("## App Version");
        lines.push(req.version);
    }
    if (req.logs) {
        lines.push("");
        lines.push("## Logs / Screenshots / Extra Context");
        lines.push(req.logs);
    }
    return lines.join("\n");
}

function formatBugReportZh(req: BugReport): string {
    const lines: string[] = [];
    lines.push("## 概述");
    lines.push(req.summary);
    lines.push("");
    lines.push("## 复现步骤");
    lines.push(req.steps);
    lines.push("");
    lines.push("## 预期行为");
    lines.push(req.expected);
    lines.push("");
    lines.push("## 实际行为");
    lines.push(req.actual);
    lines.push("");
    lines.push("## 平台");
    lines.push(req.platform);
    if (req.version) {
        lines.push("");
        lines.push("## 应用版本");
        lines.push(req.version);
    }
    if (req.logs) {
        lines.push("");
        lines.push("## 日志 / 截图 / 其他补充");
        lines.push(req.logs);
    }
    return lines.join("\n");
}

function formatFeatureRequestEn(req: FeatureRequest): string {
    const lines: string[] = [];
    lines.push("## Problem to Solve");
    lines.push(req.problem);
    lines.push("");
    lines.push("## Proposed Solution");
    lines.push(req.proposal);
    lines.push("");
    lines.push("## Use Case / Impact");
    lines.push(req.impact);
    if (req.alternatives) {
        lines.push("");
        lines.push("## Alternatives Considered");
        lines.push(req.alternatives);
    }
    if (req.extra) {
        lines.push("");
        lines.push("## Mockups / References / Extra Context");
        lines.push(req.extra);
    }
    return lines.join("\n");
}

function formatFeatureRequestZh(req: FeatureRequest): string {
    const lines: string[] = [];
    lines.push("## 要解决的问题");
    lines.push(req.problem);
    lines.push("");
    lines.push("## 期望方案");
    lines.push(req.proposal);
    lines.push("");
    lines.push("## 使用场景 / 影响");
    lines.push(req.impact);
    if (req.alternatives) {
        lines.push("");
        lines.push("## 替代方案");
        lines.push(req.alternatives);
    }
    if (req.extra) {
        lines.push("");
        lines.push("## 原型 / 参考 / 其他补充");
        lines.push(req.extra);
    }
    return lines.join("\n");
}

function formatFooter(req: BugReport | FeatureRequest): string {
    const parts: string[] = [];
    if (req.metadata) {
        const entries = Object.entries(req.metadata);
        if (entries.length > 0) {
            parts.push(entries.map(([k, v]) => `${k}: ${v}`).join(" | "));
        }
    }
    if (req.contact) {
        parts.push(`contact: ${req.contact}`);
    }
    if (parts.length === 0) {
        return "";
    }
    return `\n\n---\n*${parts.join("  \n")}*`;
}

export function formatIssueBody(type: TemplateType, req: BugReport | FeatureRequest): string {
    let body: string;
    if (type === "bug_report") {
        body =
            req.language === "zh"
                ? formatBugReportZh(req as BugReport)
                : formatBugReportEn(req as BugReport);
    } else {
        body =
            req.language === "zh"
                ? formatFeatureRequestZh(req as FeatureRequest)
                : formatFeatureRequestEn(req as FeatureRequest);
    }
    const footer = formatFooter(req);
    return footer ? body + footer : body;
}

const DefaultLabels: Record<string, string[]> = {
    bug_report: ["bug", "triage"],
    feature_request: ["enhancement", "triage"],
};

export function resolveTitle(_type: TemplateType, req: BugReport | FeatureRequest): string {
    return req.title;
}

export function resolveLabels(type: TemplateType, req: BugReport | FeatureRequest): string[] {
    if (req.labels && req.labels.length > 0) {
        return req.labels;
    }
    return DefaultLabels[type];
}
