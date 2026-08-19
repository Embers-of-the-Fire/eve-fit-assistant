import { env } from "cloudflare:workers";
import { fromBinary } from "@bufbuild/protobuf";
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
}

export async function getPostSnapshot(postId: string): Promise<StoredPost | null> {
    const recordResponse = await env.PLATFORM_API.fetch(
        `${BINDING_ORIGIN}/platform/internal/posts/${postId}`,
    );
    if (!recordResponse.ok) return null;
    let raw: unknown;
    try {
        raw = await recordResponse.json();
    } catch {
        return null;
    }
    if (typeof raw !== "object" || raw === null) return null;
    const record = raw as { fitHash?: unknown };
    if (typeof record.fitHash !== "string") return null;

    const snapshotResponse = await env.PLATFORM_API.fetch(
        `${BINDING_ORIGIN}/platform/internal/posts/${postId}/snapshot`,
    );
    if (!snapshotResponse.ok) return null;
    let snapshot: FitSnapshot;
    try {
        snapshot = fromBinary(
            FitSnapshotSchema,
            new Uint8Array(await snapshotResponse.arrayBuffer()),
        );
    } catch {
        return null;
    }
    return { postId, fitHash: record.fitHash, snapshot };
}
