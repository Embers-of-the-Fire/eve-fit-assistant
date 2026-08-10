import type {
    AgentFeedback,
    BugReport,
    DocsFlag,
    DocsQuestion,
    FeatureRequest,
    IssueRequest,
    TemplateType,
} from "./types.js";

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

function formatDocsFlagEn(req: DocsFlag): string {
    const lines: string[] = [];
    lines.push("## Page");
    lines.push(`Path: ${req.pagePath}`);
    lines.push(`ID: ${req.pageId}`);
    lines.push("");
    lines.push("## Report");
    lines.push(req.content);
    return lines.join("\n");
}

function formatDocsFlagZh(req: DocsFlag): string {
    const lines: string[] = [];
    lines.push("## 页面");
    lines.push(`路径：${req.pagePath}`);
    lines.push(`ID：${req.pageId}`);
    lines.push("");
    lines.push("## 问题反馈");
    lines.push(req.content);
    return lines.join("\n");
}

function formatDocsQuestionEn(req: DocsQuestion): string {
    const lines: string[] = [];
    lines.push("## Question");
    lines.push(req.content);
    return lines.join("\n");
}

function formatDocsQuestionZh(req: DocsQuestion): string {
    const lines: string[] = [];
    lines.push("## 问题描述");
    lines.push(req.content);
    return lines.join("\n");
}

function formatAgentFeedbackEn(req: AgentFeedback): string {
    const lines: string[] = [];
    if (req.dialog) {
        lines.push("## Description");
        lines.push(req.body);
        lines.push("");
        lines.push("## Dialog");
        lines.push("<details>");
        lines.push("  <summary/>");
        lines.push(req.dialog);
        lines.push("</details>");
    } else {
        lines.push(req.body);
    }
    return lines.join("\n");
}

function formatAgentFeedbackZh(req: AgentFeedback): string {
    const lines: string[] = [];
    if (req.dialog) {
        lines.push("## 描述");
        lines.push(req.body);
        lines.push("");
        lines.push("## 对话记录");
        lines.push("<details>");
        lines.push("  <summary/>");
        lines.push(req.dialog);
        lines.push("</details>");
    } else {
        lines.push(req.body);
    }
    return lines.join("\n");
}

function formatFooter(req: IssueRequest): string {
    const parts: string[] = [];
    if (req.metadata) {
        const entries = Object.entries(req.metadata);
        if (entries.length > 0) {
            parts.push(entries.map(([k, v]) => `${k}: ${v}`).join(" | "));
        }
    }
    if (parts.length === 0) {
        return "";
    }
    return `\n\n---\n*${parts.join("  \n")}*`;
}

function formatFooterSmall(req: IssueRequest): string {
    const parts: string[] = [];
    if (req.metadata) {
        const entries = Object.entries(req.metadata);
        if (entries.length > 0) {
            parts.push(entries.map(([k, v]) => `${k}: ${v}`).join(" | "));
        }
    }
    if (parts.length === 0) {
        return "";
    }
    return `\n\n---\n<small>${parts.join("<br/>")}</small>`;
}

export function formatIssueBody(type: TemplateType, req: IssueRequest): string {
    let body: string;
    if (type === "bug_report") {
        body =
            req.language === "zh"
                ? formatBugReportZh(req as BugReport)
                : formatBugReportEn(req as BugReport);
    } else if (type === "feature_request") {
        body =
            req.language === "zh"
                ? formatFeatureRequestZh(req as FeatureRequest)
                : formatFeatureRequestEn(req as FeatureRequest);
    } else if (type === "docs_flag") {
        body =
            req.language === "zh"
                ? formatDocsFlagZh(req as DocsFlag)
                : formatDocsFlagEn(req as DocsFlag);
    } else if (type === "agent_feedback") {
        body =
            req.language === "zh"
                ? formatAgentFeedbackZh(req as AgentFeedback)
                : formatAgentFeedbackEn(req as AgentFeedback);
        const footer = formatFooterSmall(req);
        return footer ? body + footer : body;
    } else {
        body =
            req.language === "zh"
                ? formatDocsQuestionZh(req as DocsQuestion)
                : formatDocsQuestionEn(req as DocsQuestion);
    }
    const footer = formatFooter(req);
    return footer ? body + footer : body;
}

const DefaultLabels: Record<string, string[]> = {
    bug_report: ["T-Bug", "V-Needs Triage"],
    feature_request: ["T-Feature", "V-Needs Triage"],
    docs_flag: ["F-App", "T-Docs", "T-Bug", "V-Needs Triage"],
    docs_question: ["F-App", "T-Docs", "T-Question", "V-Needs Triage"],
    agent_feedback: ["C-Feedback", "V-Needs Triage"],
};

export function resolveTitle(type: TemplateType, req: IssueRequest): string {
    if ("topic" in req) {
        return `[Docs] ${req.topic}`;
    }
    if (type === "agent_feedback") {
        return `[Feedback/Agent]: ${req.title}`;
    }
    return req.title;
}

export function resolveLabels(type: TemplateType, req: IssueRequest): string[] {
    if (req.labels && req.labels.length > 0) {
        return req.labels;
    }
    return DefaultLabels[type];
}
