import { fromBinary } from "@bufbuild/protobuf";
import { type FitSnapshot, FitSnapshotSchema } from "efa-proto-ts/fit_snapshot_pb";

import type { FitListEntry } from "./types";

export const REQUEST_ID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export interface StoredSnapshot {
    requestId: string;
    fitHash: string;
    snapshot: FitSnapshot;
    createdAt: string;
}

export function localizedName(names: Record<string, string>, locale = "en"): string {
    return names[locale] ?? names.en ?? Object.values(names)[0] ?? "";
}

interface RequestRow {
    request_id: string;
    fit_hash: string;
    created_at: string;
    snapshot: ArrayBuffer;
}

export async function getSnapshotByRequestId(
    db: D1Database,
    requestId: string,
): Promise<StoredSnapshot | null> {
    const row = await db
        .prepare(
            "SELECT r.request_id, r.fit_hash, r.created_at, f.snapshot " +
                "FROM requests r JOIN fits f ON f.fit_hash = r.fit_hash " +
                "WHERE r.request_id = ?",
        )
        .bind(requestId)
        .first<RequestRow>();
    if (!row) return null;
    return {
        requestId: row.request_id,
        fitHash: row.fit_hash,
        snapshot: fromBinary(FitSnapshotSchema, new Uint8Array(row.snapshot)),
        createdAt: row.created_at,
    };
}

export async function listFits(db: D1Database, limit = 100): Promise<FitListEntry[]> {
    const { results } = await db
        .prepare(
            "SELECT r.request_id, r.fit_hash, r.created_at, f.snapshot " +
                "FROM requests r JOIN fits f ON f.fit_hash = r.fit_hash " +
                "ORDER BY r.created_at DESC LIMIT ?",
        )
        .bind(limit)
        .all<RequestRow>();

    const entries: FitListEntry[] = [];
    for (const row of results) {
        try {
            const snapshot = fromBinary(FitSnapshotSchema, new Uint8Array(row.snapshot));
            entries.push({
                requestId: row.request_id,
                fitHash: row.fit_hash,
                fitName: snapshot.header?.fitName ?? "",
                shipName: localizedName(snapshot.ship?.type?.names ?? {}),
                shipTypeId: snapshot.ship?.type?.typeId ?? 0,
                createdAt: row.created_at,
                lastModifiedMs: Number(snapshot.header?.lastModifiedMs ?? 0),
                generator: snapshot.header?.generator ?? null,
            });
        } catch {
            // Skip rows whose snapshot cannot be decoded; the list must stay available.
        }
    }
    return entries;
}
