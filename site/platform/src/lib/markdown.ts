import DOMPurify from "dompurify";
import { marked } from "marked";

// Markdown rendering for discussion comments. Bodies arrive from the API as
// raw, untrusted markdown — every render passes through DOMPurify before it
// reaches `{@html}`. Client-side only: comment lists are populated from
// onMount fetches, so this never runs during SSR (where DOMPurify has no
// DOM).
marked.use({ gfm: true, breaks: true });

/** Renders a raw markdown comment body to sanitized HTML. */
export function renderMarkdown(body: string): string {
    if (!DOMPurify.isSupported) {
        throw new Error(
            "renderMarkdown is client-side only: DOMPurify has no DOM here. " +
                "Do not call it during SSR.",
        );
    }
    const html = marked.parse(body, { async: false });
    return DOMPurify.sanitize(html, { USE_PROFILES: { html: true } });
}
