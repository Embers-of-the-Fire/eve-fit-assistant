import { Hono } from "hono";
import { cors } from "hono/cors";
import type { z } from "zod";
import { formatIssueBody, resolveLabels, resolveTitle } from "./format.js";
import { createIssue, validateConfig } from "./github.js";
import { BugReportSchema, FeatureRequestSchema } from "./schema.js";
import type {
    BugReport,
    ErrorResponse,
    FeatureRequest,
    IssueResult,
    TemplateType,
} from "./types.js";

interface Env {
    GITHUB_APP_ID?: string;
    GITHUB_APP_PRIVATE_KEY?: string;
    GITHUB_APP_INSTALLATION_ID?: string;
    GITHUB_REPO_OWNER?: string;
    GITHUB_REPO_NAME?: string;
}

const app = new Hono<{ Bindings: Env }>();

app.use("*", cors());

async function handleCreateIssue(
    c: import("hono").Context<{ Bindings: Env }>,
    type: TemplateType,
    schema: z.ZodTypeAny,
) {
    let body: unknown;
    try {
        body = await c.req.json();
    } catch {
        const err: ErrorResponse = { error: "Invalid JSON body" };
        return c.json(err, 400);
    }

    const parsed = schema.safeParse(body);
    if (!parsed.success) {
        const details = parsed.error.issues.map((issue) => ({
            path: issue.path.join("."),
            message: issue.message,
        }));
        const err: ErrorResponse = { error: "Validation failed", details };
        return c.json(err, 400);
    }

    const req = parsed.data as BugReport | FeatureRequest;

    const configResult = validateConfig(c.env as unknown as Record<string, string | undefined>);
    if (!configResult.valid) {
        const err: ErrorResponse = {
            error: "Server misconfigured",
            details: `Missing required environment variables: ${configResult.missing.join(", ")}`,
        };
        return c.json(err, 500);
    }

    try {
        const title = resolveTitle(type, req);
        const issueBody = formatIssueBody(type, req);
        const labels = resolveLabels(type, req);

        const result = await createIssue(configResult.config, title, issueBody, labels);

        const resp: IssueResult = {
            issue_url: result.issue_url,
            issue_number: result.issue_number,
        };
        return c.json(resp, 201);
    } catch (error) {
        const message = error instanceof Error ? error.message : String(error);

        const err: ErrorResponse = {
            error: "Failed to create issue",
            details: message,
        };
        return c.json(err, 502);
    }
}

app.post("/bug-report", (c) => handleCreateIssue(c, "bug_report", BugReportSchema));

app.post("/feature-request", (c) => handleCreateIssue(c, "feature_request", FeatureRequestSchema));

app.onError((err, c) => {
    const message = err instanceof Error ? err.message : String(err);
    const resp: ErrorResponse = { error: "Internal server error", details: message };
    return c.json(resp, 500);
});

const root = new Hono<{ Bindings: Env }>();
root.route("/issue-redirect", app);
export default root;
