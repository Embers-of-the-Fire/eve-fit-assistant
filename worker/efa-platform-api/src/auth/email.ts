// OTP email delivery via the Resend SDK. Templates are bilingual (en/zh);
// any locale starting with "zh" selects the Chinese copy.

import { Resend } from "resend";

export type OtpEmailPurpose = "verify" | "reset";

export interface OtpEmailInput {
    to: string;
    code: string;
    purpose: OtpEmailPurpose;
    locale: string;
}

const DEFAULT_FROM = "EFA Platform <noreply@platform.efa-tech.dev>";

interface Template {
    subject: string;
    heading: string;
    body: string;
    expiry: string;
}

const TEMPLATES: Record<OtpEmailPurpose, Record<"en" | "zh", Template>> = {
    verify: {
        en: {
            subject: "Your EFA Platform verification code",
            heading: "Verify your email",
            body: "Use this code to finish signing up for EFA Platform:",
            expiry: "The code expires in 10 minutes. If you did not sign up, ignore this email.",
        },
        zh: {
            subject: "您的 EFA Platform 验证码",
            heading: "验证您的邮箱",
            body: "使用以下验证码完成 EFA Platform 注册：",
            expiry: "验证码将在 10 分钟后失效。如果您没有注册账号，请忽略本邮件。",
        },
    },
    reset: {
        en: {
            subject: "Your EFA Platform password reset code",
            heading: "Reset your password",
            body: "Use this code to reset your EFA Platform password:",
            expiry: "The code expires in 10 minutes. If you did not request a reset, ignore this email.",
        },
        zh: {
            subject: "您的 EFA Platform 密码重置验证码",
            heading: "重置您的密码",
            body: "使用以下验证码重置 EFA Platform 密码：",
            expiry: "验证码将在 10 分钟后失效。如果您没有请求重置密码，请忽略本邮件。",
        },
    },
};

function renderHtml(template: Template, code: string): string {
    return (
        `<div style="font-family:sans-serif;max-width:480px;margin:0 auto">` +
        `<h2>${template.heading}</h2>` +
        `<p>${template.body}</p>` +
        `<p style="font-size:32px;font-weight:bold;letter-spacing:8px;text-align:center;` +
        `padding:16px 0">${code}</p>` +
        `<p style="color:#666">${template.expiry}</p>` +
        `</div>`
    );
}

function renderText(template: Template, code: string): string {
    return `${template.heading}\n\n${template.body}\n\n${code}\n\n${template.expiry}`;
}

export interface OtpEmailEnv {
    RESEND_API_KEY?: string;
    EMAIL_FROM?: string;
}

export async function sendOtpEmail(env: OtpEmailEnv, input: OtpEmailInput): Promise<boolean> {
    if (!env.RESEND_API_KEY) {
        console.error("RESEND_API_KEY is not set");
        return false;
    }
    const template = TEMPLATES[input.purpose][input.locale.startsWith("zh") ? "zh" : "en"];
    // Keyed per issued code: retries of the same send dedupe, while a fresh
    // code always produces a fresh key and actually sends.
    const idempotencyHash = await crypto.subtle.digest(
        "SHA-256",
        new TextEncoder().encode(`${input.purpose}|${input.to}|${input.code}`),
    );
    const idempotencyKey = `otp/${[...new Uint8Array(idempotencyHash)]
        .map((b) => b.toString(16).padStart(2, "0"))
        .join("")}`;

    const resend = new Resend(env.RESEND_API_KEY);
    // SDK contract: inspect { data, error } rather than try/catch for API errors.
    const { error } = await resend.emails.send(
        {
            from: env.EMAIL_FROM ?? DEFAULT_FROM,
            to: [input.to],
            subject: template.subject,
            html: renderHtml(template, input.code),
            text: renderText(template, input.code),
        },
        { idempotencyKey },
    );
    if (error) {
        console.error(`Resend send failed for ${input.purpose} OTP: ${error.message}`);
        return false;
    }
    return true;
}
