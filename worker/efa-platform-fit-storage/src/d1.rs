use worker::d1::D1Database;
use worker::wasm_bindgen::JsCast;
use worker::{js_sys, wasm_bindgen::JsValue};

use crate::error::ApiError;
use crate::prefetch::FetchRequest;

/// D1's bound-parameter limit is 100; reserve 2 for snapshot_id/family.
const MAX_ENTRY_IDS_PER_CHUNK: usize = 98;

fn js_text(value: &str) -> JsValue {
    JsValue::from_str(value)
}

fn js_int(value: i64) -> JsValue {
    JsValue::from_f64(value as f64)
}

/// BLOB bind: a copied `Uint8Array`'s backing buffer (D1 stores it as BLOB).
fn js_blob(bytes: &[u8]) -> JsValue {
    js_sys::Uint8Array::from(bytes).buffer().into()
}

/// Lowercase hex -> raw bytes (snapshot hashes are stored as 32-byte BLOBs).
/// Validate before slicing: `str::len` counts UTF-8 bytes, so slicing a
/// non-ASCII hash (e.g. "aé…") would panic on a non-char boundary.
fn hex_to_bytes(hex: &str) -> Result<Vec<u8>, ApiError> {
    if hex.len() != 64 || !hex.bytes().all(|b| b.is_ascii_hexdigit()) {
        return Err(ApiError::bad_request(
            "snapshot_hash must be a 64-character ASCII hexadecimal string",
        ));
    }
    (0..hex.len() / 2)
        .map(|i| {
            u8::from_str_radix(&hex[i * 2..i * 2 + 2], 16)
                .map_err(|e| ApiError::internal(format!("invalid hex: {e}")))
        })
        .collect()
}

/// Raw bytes -> lowercase hex (inverse of `hex_to_bytes`).
fn bytes_to_hex(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}

fn row_int(row: &JsValue, index: u32) -> Result<i32, ApiError> {
    js_sys::Reflect::get(row, &JsValue::from_f64(index as f64))
        .ok()
        .and_then(|v| v.as_f64())
        .map(|v| v as i32)
        .ok_or_else(|| ApiError::internal("D1 row: expected integer column"))
}

fn row_int64(row: &JsValue, index: u32) -> Result<i64, ApiError> {
    js_sys::Reflect::get(row, &JsValue::from_f64(index as f64))
        .ok()
        .and_then(|v| v.as_f64())
        .map(|v| v as i64)
        .ok_or_else(|| ApiError::internal("D1 row: expected integer column"))
}

/// Raw byte access for BLOB columns (spec §14): D1 returns ArrayBuffers.
fn row_blob(row: &JsValue, index: u32) -> Result<Vec<u8>, ApiError> {
    let value = js_sys::Reflect::get(row, &JsValue::from_f64(index as f64))
        .map_err(|_| ApiError::internal("D1 row: missing blob column"))?;
    if value.is_instance_of::<js_sys::Uint8Array>() {
        let array: js_sys::Uint8Array = value.unchecked_into();
        return Ok(array.to_vec());
    }
    if value.is_instance_of::<js_sys::ArrayBuffer>() {
        let buffer: js_sys::ArrayBuffer = value.unchecked_into();
        return Ok(js_sys::Uint8Array::new(&buffer).to_vec());
    }
    if value.is_instance_of::<js_sys::Array>() {
        let array: js_sys::Array = value.unchecked_into();
        return Ok(array
            .iter()
            .filter_map(|v| v.as_f64().map(|f| f as u8))
            .collect());
    }
    Err(ApiError::internal("D1 row: unexpected blob column type"))
}

async fn raw_query(
    db: &D1Database,
    sql: &str,
    params: &[JsValue],
) -> Result<Vec<JsValue>, ApiError> {
    db.prepare(sql)
        .bind(params)
        .map_err(|e| ApiError::internal(format!("D1 bind failed: {e}")))?
        .raw_js_value()
        .await
        .map_err(|e| ApiError::internal(format!("D1 query failed: {e}")))
}

async fn run_change_count(
    db: &D1Database,
    sql: &str,
    params: &[JsValue],
) -> Result<usize, ApiError> {
    let result = db
        .prepare(sql)
        .bind(params)
        .map_err(|e| ApiError::internal(format!("D1 bind failed: {e}")))?
        .run()
        .await
        .map_err(|e| ApiError::internal(format!("D1 run failed: {e}")))?;
    let changes = result
        .meta()
        .map_err(|e| ApiError::internal(format!("D1 meta failed: {e}")))?
        .and_then(|meta| meta.changes)
        .ok_or_else(|| ApiError::internal("D1 run: missing change count"))?;
    Ok(changes)
}

/// Chunked family lookup (spec §7.2). `ids == None` fetches the whole family.
pub async fn fetch_family(
    db: &D1Database,
    snapshot_id: i64,
    request: FetchRequest,
) -> anyhow::Result<Vec<(i32, Vec<u8>)>> {
    let family = request.family;
    let family_code = family.code();
    let mut out = Vec::new();

    match request.ids {
        None => {
            let sql = "SELECT se.entry_id, e.content FROM snapshot_entries se \
                 JOIN entries e ON e.content_id = se.content_id \
                 WHERE se.snapshot_id = ? AND se.family = ?";
            let rows = raw_query(db, sql, &[js_int(snapshot_id), js_int(family_code)]).await?;
            for row in &rows {
                out.push((row_int(row, 0)?, row_blob(row, 1)?));
            }
        }
        Some(ids) => {
            for chunk in ids.chunks(MAX_ENTRY_IDS_PER_CHUNK) {
                let placeholders = chunk.iter().map(|_| "?").collect::<Vec<_>>().join(", ");
                let sql = format!(
                    "SELECT se.entry_id, e.content FROM snapshot_entries se \
                     JOIN entries e ON e.content_id = se.content_id \
                     WHERE se.snapshot_id = ? AND se.family = ? \
                     AND se.entry_id IN ({placeholders})"
                );
                let mut params = vec![js_int(snapshot_id), js_int(family_code)];
                params.extend(chunk.iter().map(|id| js_int(*id as i64)));
                let rows = raw_query(db, &sql, &params).await?;
                for row in &rows {
                    out.push((row_int(row, 0)?, row_blob(row, 1)?));
                }
            }
        }
    }
    Ok(out)
}

/// Resolve a snapshot selector to its registry id, requiring the snapshot to
/// be complete (spec §6.2 step 3): pending rows (`completed_at IS NULL`) are
/// incomplete and resolve to `None`.
pub async fn resolve_snapshot(
    db: &D1Database,
    server_id: &str,
    snapshot_hash: &str,
) -> Result<Option<i64>, ApiError> {
    let snapshot_hash_bytes = hex_to_bytes(snapshot_hash)?;
    let rows = raw_query(
        db,
        "SELECT snapshot_id FROM snapshots \
         WHERE server_id = ? AND snapshot_hash = ? AND completed_at IS NOT NULL",
        &[js_text(server_id), js_blob(&snapshot_hash_bytes)],
    )
    .await?;
    match rows.first() {
        Some(row) => Ok(Some(row_int64(row, 0)?)),
        None => Ok(None),
    }
}

/// Resolve the newest completed snapshot for a server — the fallback selector
/// used with `allow_latest_snapshot_fallback` consent, and the payload of the
/// enriched `snapshot_incomplete` error. Returns the registry id and the
/// lowercase-hex hash.
pub async fn resolve_latest_snapshot(
    db: &D1Database,
    server_id: &str,
) -> Result<Option<(i64, String)>, ApiError> {
    let rows = raw_query(
        db,
        "SELECT snapshot_id, snapshot_hash FROM snapshots \
         WHERE server_id = ? AND completed_at IS NOT NULL \
         ORDER BY completed_at DESC, snapshot_id DESC LIMIT 1",
        &[js_text(server_id)],
    )
    .await?;
    match rows.first() {
        Some(row) => Ok(Some((row_int64(row, 0)?, bytes_to_hex(&row_blob(row, 1)?)))),
        None => Ok(None),
    }
}

/// The stored `FitSnapshot` protobuf bytes for a fit hash, if any. A fit hash
/// may have several snapshot variants; serve the most recently computed one.
pub async fn get_fit_snapshot(
    db: &D1Database,
    fit_hash: &str,
) -> Result<Option<Vec<u8>>, ApiError> {
    let rows = raw_query(
        db,
        "SELECT snapshot FROM fits WHERE fit_hash = ? \
         ORDER BY created_at DESC, rowid DESC LIMIT 1",
        &[js_text(fit_hash)],
    )
    .await?;
    match rows.first() {
        Some(row) => Ok(Some(row_blob(row, 0)?)),
        None => Ok(None),
    }
}

/// Whether the `(fit_hash, snapshot_hash)` variant is already stored.
pub async fn fit_exists(
    db: &D1Database,
    fit_hash: &str,
    snapshot_hash: &str,
) -> Result<bool, ApiError> {
    let rows = raw_query(
        db,
        "SELECT 1 FROM fits WHERE fit_hash = ? AND snapshot_hash = ?",
        &[js_text(fit_hash), js_text(snapshot_hash)],
    )
    .await?;
    Ok(!rows.is_empty())
}

/// Inserts the fit variant row, tolerating concurrent re-submits of the same
/// `(fit_hash, snapshot_hash)` pair. `requested_snapshot_hash` is the
/// fallback provenance: `None` when the fit was computed with the requested
/// snapshot. Returns `true` when this call inserted the row, `false` when it
/// already existed.
pub async fn insert_fit(
    db: &D1Database,
    fit_hash: &str,
    server_id: &str,
    snapshot_hash: &str,
    requested_snapshot_hash: Option<&str>,
    fit_state: &[u8],
    snapshot: &[u8],
) -> Result<bool, ApiError> {
    let requested = match requested_snapshot_hash {
        Some(hash) => js_text(hash),
        None => JsValue::NULL,
    };
    let changes = run_change_count(
        db,
        "INSERT OR IGNORE INTO fits \
         (fit_hash, server_id, snapshot_hash, requested_snapshot_hash, fit_state, snapshot) \
         VALUES (?, ?, ?, ?, ?, ?)",
        &[
            js_text(fit_hash),
            js_text(server_id),
            js_text(snapshot_hash),
            requested,
            js_blob(fit_state),
            js_blob(snapshot),
        ],
    )
    .await?;
    Ok(changes > 0)
}

pub async fn health_check(db: &D1Database) -> Result<(), ApiError> {
    raw_query(db, "SELECT 1", &[]).await?;
    Ok(())
}
