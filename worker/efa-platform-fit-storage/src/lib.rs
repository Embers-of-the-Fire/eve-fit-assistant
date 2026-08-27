use prost::Message;
use worker::*;

mod d1;
mod engine;
mod error;
mod hash;
mod icons;
mod prefetch;
mod proto;
mod provider;
mod snapshot;
mod statistics;

use error::ApiError;
use proto::fit as pb;

const PROTOBUF_CONTENT_TYPE: &str = "application/x-protobuf";

fn render_error(err: ApiError) -> Response {
    if err.status >= 500 {
        worker::console_error!("{err}");
    }
    match Response::from_json(&err.body()) {
        Ok(res) => res.with_status(err.status),
        Err(e) => Response::error(format!("failed to render error: {e}"), 500)
            .expect("error response construction cannot fail"),
    }
}

fn proto_response<M: Message>(message: &M) -> Result<Response, ApiError> {
    let mut res = Response::from_bytes(message.encode_to_vec())
        .map_err(|e| ApiError::internal(format!("failed to build response: {e}")))?;
    res.headers_mut()
        .set("Content-Type", PROTOBUF_CONTENT_TYPE)
        .map_err(|e| ApiError::internal(format!("failed to set header: {e}")))?;
    Ok(res)
}

fn platform_db(env: &Env) -> Result<D1Database, ApiError> {
    env.d1("PLATFORM_DB")
        .map_err(|e| ApiError::internal(format!("PLATFORM_DB binding not configured: {e}")))
}

fn fit_db(env: &Env) -> Result<D1Database, ApiError> {
    env.d1("FIT_DB")
        .map_err(|e| ApiError::internal(format!("FIT_DB binding not configured: {e}")))
}

/// Submit flow. This worker is binding-only;
/// authentication lives in `efa-platform-api`.
async fn handle_submit(mut req: Request, env: Env) -> Result<Response, ApiError> {
    // 1. Decode and structurally validate.
    let bytes = req
        .bytes()
        .await
        .map_err(|e| ApiError::bad_request(format!("failed to read request body: {e}")))?;
    let request = pb::FitUploadRequest::decode(&bytes[..])?;
    engine::validate_structure(&request)?;
    let state = &request.fit;

    let platform_db = platform_db(&env)?;
    let fit_db = fit_db(&env)?;

    // 2. Snapshot completeness.
    if !d1::snapshot_exists(&platform_db, &request.server_id, &request.snapshot_hash).await? {
        return Err(ApiError::snapshot_incomplete(
            &request.server_id,
            &request.snapshot_hash,
        ));
    }

    // 3. Canonicalize → fit hash.
    let canonical = hash::canonical_state(state);
    let canonical_bytes = canonical.encode_to_vec();
    let fit_hash = hash::fit_hash(&canonical_bytes);

    // 4. Idempotent re-submit: skip computation when the fit row exists (fast path;
    //    the insert below is conflict-tolerant and stays authoritative under races).
    let mut already_existed = d1::fit_exists(&fit_db, &fit_hash).await?;

    if !already_existed {
        // 5a. Prefetch the transitive closure (unknown seed type → 422).
        let key: prefetch::SnapshotKey = (request.server_id.clone(), request.snapshot_hash.clone());
        let mut data = prefetch::cache_get(&key);
        {
            let server_id = request.server_id.clone();
            let snapshot_hash = request.snapshot_hash.clone();
            let platform_db = &platform_db;
            let fetch = |request: prefetch::FetchRequest| {
                let server_id = server_id.clone();
                let snapshot_hash = snapshot_hash.clone();
                async move { d1::fetch_family(platform_db, &server_id, &snapshot_hash, request).await }
            };
            prefetch::prefetch(&mut data, &canonical, fetch).await?;
        }
        if data.decode_warnings > 0 {
            console_log!(
                "fit-storage: {} degraded buff decodes for {}/{}",
                data.decode_warnings,
                request.server_id,
                request.snapshot_hash
            );
        }
        prefetch::cache_merge(key, data.clone());

        // 5b/5c. Calculate + validate (Error-level issues → 422, nothing stored).
        let provider = data.provider();
        let container = engine::build_container(&canonical);
        let (ship, _warnings) = engine::calculate_and_validate(&container, &provider)?;
        if provider.miss_count() > 0 {
            console_log!(
                "fit-storage: {} provider getter misses for fit {} (closure bug or corrupt snapshot)",
                provider.miss_count(),
                fit_hash
            );
        }

        // 5d/5e. Assemble + store the snapshot. Icon URLs are baked at submit
        // time only, best-effort (storage outage ⇒ no `icon_url`, never a
        // failed submit).
        let created_at_ms = Date::now().as_millis() as i64;
        let icon_urls =
            prefetch::resolve_icon_urls(&env, &request.server_id, &data.type_meta).await;
        let snapshot = snapshot::assemble(
            &request,
            &canonical,
            &ship,
            &data,
            &icon_urls,
            created_at_ms,
        );
        let inserted = d1::insert_fit(
            &fit_db,
            &fit_hash,
            &request.server_id,
            &request.snapshot_hash,
            &canonical_bytes,
            &snapshot.encode_to_vec(),
        )
        .await?;
        already_existed = !inserted;
    }

    // 6. Respond.
    proto_response(&pb::FitStoreResponse {
        fit_hash,
        already_existed,
    })
}

async fn handle_by_hash(env: Env, fit_hash: &str) -> Result<Response, ApiError> {
    let fit_db = fit_db(&env)?;
    match d1::get_fit_snapshot(&fit_db, fit_hash).await? {
        Some(bytes) => {
            let mut res = Response::from_bytes(bytes)
                .map_err(|e| ApiError::internal(format!("failed to build response: {e}")))?;
            res.headers_mut()
                .set("Content-Type", PROTOBUF_CONTENT_TYPE)
                .map_err(|e| ApiError::internal(format!("failed to set header: {e}")))?;
            Ok(res)
        }
        None => Err(ApiError::not_found(format!("unknown fit hash: {fit_hash}"))),
    }
}

async fn handle_health(env: Env) -> Result<Response, ApiError> {
    // Binding-only worker: every caller is internal, so the liveness reply
    // always includes a D1 round trip on both databases.
    d1::health_check(&platform_db(&env)?).await?;
    d1::health_check(&fit_db(&env)?).await?;
    Response::from_json(&serde_json::json!({ "ok": true }))
        .map_err(|e| ApiError::internal(format!("failed to build response: {e}")))
}

#[event(fetch)]
async fn main(req: Request, env: Env, _ctx: Context) -> Result<Response> {
    match Router::new()
        .post_async("/platform/storage/fit/submit", |req, ctx| async move {
            Ok(handle_submit(req, ctx.env)
                .await
                .unwrap_or_else(render_error))
        })
        .get_async(
            "/platform/storage/fit/by-hash/:fit_hash",
            |_req, ctx| async move {
                let fit_hash = ctx.param("fit_hash").cloned().unwrap_or_default();
                Ok(handle_by_hash(ctx.env, &fit_hash)
                    .await
                    .unwrap_or_else(render_error))
            },
        )
        .get_async("/platform/storage/fit/health", |_req, ctx| async move {
            Ok(handle_health(ctx.env).await.unwrap_or_else(render_error))
        })
        .run(req, env)
        .await
    {
        Ok(res) => Ok(res),
        // Handlers always return Ok; a routing-level error means no route
        // matched.
        Err(_) => Ok(render_error(ApiError::not_found("unknown route"))),
    }
}
