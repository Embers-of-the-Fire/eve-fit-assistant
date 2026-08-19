import { env } from "cloudflare:workers";
import { fromBinary, type JsonValue, toJson } from "@bufbuild/protobuf";
import { type FitSnapshot, FitSnapshotSchema } from "efa-proto-ts/fit_snapshot_pb";

// SSR access to the platform API through the PLATFORM_API service binding
// (docs/temp/api-unit/spec.md §7.1). The hostname is a placeholder; only the
// path is routed by the bound worker.

const BINDING_ORIGIN = "https://efa-platform-api.internal";

export const POST_ID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export interface StoredPost {
    postId: string;
    fitHash: string;
    snapshot: FitSnapshot;
    snapshotJson: JsonValue;
}

// A binding failure (missing binding, remote exception) must degrade to the
// 404 page, never a render-time 500.
async function fetchApi(path: string): Promise<Response | null> {
    try {
        return await env.PLATFORM_API.fetch(`${BINDING_ORIGIN}${path}`);
    } catch (err) {
        console.error("PLATFORM_API binding call failed", err);
        return null;
    }
}

export async function getPostSnapshot(postId: string): Promise<StoredPost | null> {
    const recordResponse = await fetchApi(`/platform/internal/posts/${postId}`);
    if (!recordResponse?.ok) return null;
    let raw: unknown;
    try {
        raw = await recordResponse.json();
    } catch {
        return null;
    }
    if (typeof raw !== "object" || raw === null) return null;
    const record = raw as { fitHash?: unknown };
    if (typeof record.fitHash !== "string") return null;

    const snapshotResponse = await fetchApi(`/platform/internal/posts/${postId}/snapshot`);
    if (!snapshotResponse?.ok) return null;
    let snapshot: FitSnapshot;
    let snapshotJson: JsonValue;
    try {
        snapshot = fromBinary(
            FitSnapshotSchema,
            new Uint8Array(await snapshotResponse.arrayBuffer()),
        );
        // fromBinary does not enforce proto2 required fields; toJson does.
        // Validate here so a corrupt payload degrades to 404 instead of
        // throwing mid-render.
        snapshotJson = toJson(FitSnapshotSchema, snapshot);
    } catch {
        return null;
    }
    return { postId, fitHash: record.fitHash, snapshot, snapshotJson };
}
