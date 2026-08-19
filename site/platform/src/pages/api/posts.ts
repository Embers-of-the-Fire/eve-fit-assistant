import { env } from "cloudflare:workers";
import type { APIRoute } from "astro";

import { listFits } from "../../lib/d1";

export const GET: APIRoute = async () => {
    try {
        const fits = await listFits(env.FIT_DB);
        return Response.json({ fits }, { headers: { "Cache-Control": "public, max-age=30" } });
    } catch {
        return Response.json(
            { error: "internal", message: "internal server error" },
            { status: 500 },
        );
    }
};
