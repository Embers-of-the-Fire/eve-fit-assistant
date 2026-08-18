import type { APIRoute } from "astro";

import type { ThreadSummary } from "../../../../lib/types";

export const GET: APIRoute = async () => {
    const threads: ThreadSummary[] = [];
    return Response.json({ threads });
};
