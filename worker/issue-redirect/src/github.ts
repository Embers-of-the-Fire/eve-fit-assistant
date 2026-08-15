import { App } from "@octokit/app";
import type { IssueResult } from "./types.js";

export interface GitHubConfig {
    appId: string;
    privateKey: string;
    installationId: string;
    owner: string;
    repo: string;
}

export function validateConfig(
    config: Record<string, string | undefined>,
): { valid: true; config: GitHubConfig } | { valid: false; missing: string[] } {
    const appId = config.GITHUB_APP_ID;
    const privateKey = config.GITHUB_APP_PRIVATE_KEY;
    const installationId = config.GITHUB_APP_INSTALLATION_ID;
    const owner = config.GITHUB_REPO_OWNER;
    const repo = config.GITHUB_REPO_NAME;

    const missing: string[] = [];
    if (!appId) missing.push("GITHUB_APP_ID");
    if (!privateKey) missing.push("GITHUB_APP_PRIVATE_KEY");
    if (!installationId) missing.push("GITHUB_APP_INSTALLATION_ID");
    if (!owner) missing.push("GITHUB_REPO_OWNER");
    if (!repo) missing.push("GITHUB_REPO_NAME");

    if (missing.length > 0) {
        return { valid: false, missing };
    }

    return {
        valid: true,
        config: {
            appId: appId as string,
            privateKey: privateKey as string,
            installationId: installationId as string,
            owner: owner as string,
            repo: repo as string,
        },
    };
}

export async function createIssue(
    config: GitHubConfig,
    title: string,
    body: string,
    labels: string[],
): Promise<IssueResult> {
    const app = new App({
        appId: config.appId,
        privateKey: config.privateKey,
    });

    const octokit = await app.getInstallationOctokit(Number(config.installationId));

    const { data } = await octokit.request("POST /repos/{owner}/{repo}/issues", {
        owner: config.owner,
        repo: config.repo,
        title,
        body,
        labels,
    });

    return {
        issue_url: data.html_url,
        issue_number: data.number,
    };
}
