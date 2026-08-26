import { env } from "cloudflare:workers";
import type { APIRoute } from "astro";

// Same-origin reverse proxy for the platform API, forwarding every
// /platform/* request to the PLATFORM_API service binding (the placeholder
// hostname is ignored; only the path is routed by the bound worker).
//
// Preview deployments serve both the site and the API behind Cloudflare
// Access. Cross-origin browser calls to the preview API hostname fail there:
// the API's CF_Authorization cookie is never attached to plain cross-origin
// fetches, credentialed fetches are incompatible with the API's wildcard
// CORS policy, and Access blocks cookie-less preflights. Serving the API
// same-origin removes CORS from the picture entirely: the browser attaches
// the site's own Access cookie automatically, and the service binding
// bypasses Access on the API worker. Production builds still call
// api.efa-tech.dev cross-origin (see astro.config.mjs); the proxy is only
// enabled for preview builds and rejects everything else with 400.

const BINDING_ORIGIN = "https://efa-platform-api.internal";

export const ALL: APIRoute = ({ request, params }) => {
    if (!__PLATFORM_API_PROXY_ENABLED__) {
        return Response.json(
            { error: "bad_request", message: "API proxy not available in this build" },
            { status: 400 },
        );
    }
    const url = new URL(request.url);
    const target = `${BINDING_ORIGIN}/platform/${params.path ?? ""}${url.search}`;
    // Re-wrap the incoming request (method, headers, body stream) under the
    // binding URL; the API worker answers unknown paths with its own 404.
    return env.PLATFORM_API.fetch(new Request(target, request));
};
