use worker::d1::D1Database;
use worker::wasm_bindgen::JsCast;
use worker::{js_sys, wasm_bindgen::JsValue};

use crate::error::ApiError;
use crate::prefetch::FetchRequest;

/// D1's bound-parameter limit is 100; reserve 2 for server_id/snapshot_hash.
const MAX_ENTRY_IDS_PER_CHUNK: usize = 98;

fn js_text(value: &str) -> JsValue {
    JsValue::from_str(value)
}

fn js_int(value: i32) -> JsValue {
    JsValue::from_f64(value as f64)
}

/// BLOB bind: a copied `Uint8Array`'s backing buffer (D1 stores it as BLOB).
fn js_blob(bytes: &[u8]) -> JsValue {
    js_sys::Uint8Array::from(bytes).buffer().into()
}

fn row_int(row: &JsValue, index: u32) -> Result<i32, ApiError> {
    js_sys::Reflect::get(row, &JsValue::from_f64(index as f64))
        .ok()
        .and_then(|v| v.as_f64())
        .map(|v| v as i32)
        .ok_or_else(|| ApiError::internal("D1 row: expected integer column"))
}

fn row_text(row: &JsValue, index: u32) -> Result<String, ApiError> {
    js_sys::Reflect::get(row, &JsValue::from_f64(index as f64))
        .ok()
        .and_then(|v| v.as_string())
        .ok_or_else(|| ApiError::internal("D1 row: expected text column"))
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

async fn run(db: &D1Database, sql: &str, params: &[JsValue]) -> Result<(), ApiError> {
    db.prepare(sql)
        .bind(params)
        .map_err(|e| ApiError::internal(format!("D1 bind failed: {e}")))?
        .run()
        .await
        .map_err(|e| ApiError::internal(format!("D1 run failed: {e}")))?;
    Ok(())
}

/// Chunked family lookup (spec §7.2). `ids == None` fetches the whole family.
pub async fn fetch_family(
    db: &D1Database,
    server_id: &str,
    snapshot_hash: &str,
    request: FetchRequest,
) -> anyhow::Result<Vec<(i32, Vec<u8>)>> {
    let family = request.family;
    let table = family.table();
    let mut out = Vec::new();

    match request.ids {
        None => {
            let sql = format!(
                "SELECT r.entry_id, c.content FROM {table}_reg r \
                 JOIN {table} c ON c.content_hash = r.content_hash \
                 WHERE r.server_id = ? AND r.snapshot_hash = ?"
            );
            let rows = raw_query(db, &sql, &[js_text(server_id), js_text(snapshot_hash)]).await?;
            for row in &rows {
                out.push((row_int(row, 0)?, row_blob(row, 1)?));
            }
        }
        Some(ids) => {
            for chunk in ids.chunks(MAX_ENTRY_IDS_PER_CHUNK) {
                let placeholders = chunk.iter().map(|_| "?").collect::<Vec<_>>().join(", ");
                let sql = format!(
                    "SELECT r.entry_id, c.content FROM {table}_reg r \
                     JOIN {table} c ON c.content_hash = r.content_hash \
                     WHERE r.server_id = ? AND r.snapshot_hash = ? \
                     AND r.entry_id IN ({placeholders})"
                );
                let mut params = vec![js_text(server_id), js_text(snapshot_hash)];
                params.extend(chunk.iter().map(|id| js_int(*id)));
                let rows = raw_query(db, &sql, &params).await?;
                for row in &rows {
                    out.push((row_int(row, 0)?, row_blob(row, 1)?));
                }
            }
        }
    }
    Ok(out)
}

/// Snapshot completeness probe (spec §6.2 step 3).
pub async fn snapshot_exists(
    db: &D1Database,
    server_id: &str,
    snapshot_hash: &str,
) -> Result<bool, ApiError> {
    let rows = raw_query(
        db,
        "SELECT 1 FROM snapshots WHERE server_id = ? AND snapshot_hash = ?",
        &[js_text(server_id), js_text(snapshot_hash)],
    )
    .await?;
    Ok(!rows.is_empty())
}

/// The stored `FitSnapshot` protobuf bytes for a fit hash, if any.
pub async fn get_fit_snapshot(
    db: &D1Database,
    fit_hash: &str,
) -> Result<Option<Vec<u8>>, ApiError> {
    let rows = raw_query(
        db,
        "SELECT snapshot FROM fits WHERE fit_hash = ?",
        &[js_text(fit_hash)],
    )
    .await?;
    match rows.first() {
        Some(row) => Ok(Some(row_blob(row, 0)?)),
        None => Ok(None),
    }
}

pub async fn fit_exists(db: &D1Database, fit_hash: &str) -> Result<bool, ApiError> {
    let rows = raw_query(
        db,
        "SELECT 1 FROM fits WHERE fit_hash = ?",
        &[js_text(fit_hash)],
    )
    .await?;
    Ok(!rows.is_empty())
}

pub async fn insert_fit(
    db: &D1Database,
    fit_hash: &str,
    server_id: &str,
    snapshot_hash: &str,
    fit_state: &[u8],
    snapshot: &[u8],
) -> Result<(), ApiError> {
    run(
        db,
        "INSERT INTO fits (fit_hash, server_id, snapshot_hash, fit_state, snapshot) \
         VALUES (?, ?, ?, ?, ?)",
        &[
            js_text(fit_hash),
            js_text(server_id),
            js_text(snapshot_hash),
            js_blob(fit_state),
            js_blob(snapshot),
        ],
    )
    .await
}

pub async fn insert_request(
    db: &D1Database,
    request_id: &str,
    fit_hash: &str,
) -> Result<(), ApiError> {
    run(
        db,
        "INSERT INTO requests (request_id, fit_hash) VALUES (?, ?)",
        &[js_text(request_id), js_text(fit_hash)],
    )
    .await
}

/// (request_id, fit_hash, created_at) for the request record endpoint.
pub async fn get_request(
    db: &D1Database,
    request_id: &str,
) -> Result<Option<(String, String, String)>, ApiError> {
    let rows = raw_query(
        db,
        "SELECT request_id, fit_hash, created_at FROM requests WHERE request_id = ?",
        &[js_text(request_id)],
    )
    .await?;
    match rows.first() {
        Some(row) => Ok(Some((
            row_text(row, 0)?,
            row_text(row, 1)?,
            row_text(row, 2)?,
        ))),
        None => Ok(None),
    }
}

pub async fn health_check(db: &D1Database) -> Result<(), ApiError> {
    raw_query(db, "SELECT 1", &[]).await?;
    Ok(())
}
