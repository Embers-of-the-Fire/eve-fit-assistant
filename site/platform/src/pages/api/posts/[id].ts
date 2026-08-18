import { env } from "cloudflare:workers";
import { toJson } from "@bufbuild/protobuf";
import type { APIRoute } from "astro";
import { FitSnapshotSchema } from "efa-proto-ts/fit_snapshot_pb";

import { defaultCache } from "../../../lib/cache";
import { getSnapshotByRequestId, REQUEST_ID_PATTERN } from "../../../lib/d1";

export const GET: APIRoute = async ({ params, locals, request }) => {
    const requestId = params.id ?? "";
    if (!REQUEST_ID_PATTERN.test(requestId)) {
        return Response.json(
            { error: "bad_request", message: "invalid request id" },
            { status: 400 },
        );
    }

    const cache = defaultCache();
    const cached = await cache.match(request);
    if (cached) return cached;

    const stored = await getSnapshotByRequestId(env.FIT_DB, requestId);
    if (!stored) {
        return Response.json(
            { error: "not_found", message: "unknown request id" },
            { status: 404 },
        );
    }

    const response = Response.json(
        {
            requestId: stored.requestId,
            fitHash: stored.fitHash,
            createdAt: stored.createdAt,
            snapshot: toJson(FitSnapshotSchema, stored.snapshot),
        },
        { headers: { "Cache-Control": "public, max-age=31536000, immutable" } },
    );
    locals.cfContext.waitUntil(cache.put(request, response.clone()));
    return response;
};
