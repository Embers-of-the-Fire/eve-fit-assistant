use prost::Message;
use worker::*;

mod auth;
mod d1;
mod engine;
mod error;
mod hash;
mod prefetch;
mod proto;
mod provider;
mod snapshot;
mod statistics;

use error::ApiError;
use proto::fit as pb;

const PROTOBUF_CONTENT_TYPE: &str = "application/x-protobuf";

fn add_cors(res: &mut Response) -> Result<()> {
    let headers = res.headers_mut();
    headers.set("Access-Control-Allow-Origin", "*")?;
    headers.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")?;
    headers.set(
        "Access-Control-Allow-Headers",
        "Content-Type, Authorization",
    )?;
    Ok(())
}

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

/// Submit flow (spec §6.2).
async fn handle_submit(mut req: Request, env: Env) -> Result<Response, ApiError> {
    // 1. Authenticate.
    auth::check_authorization(&req, &env)?;

    // 2. Decode and structurally validate.
    let bytes = req
        .bytes()
        .await
        .map_err(|e| ApiError::bad_request(format!("failed to read request body: {e}")))?;
    let request = pb::FitUploadRequest::decode(&bytes[..])?;
    engine::validate_structure(&request)?;
    let state = &request.fit;

    let platform_db = platform_db(&env)?;
    let fit_db = fit_db(&env)?;

    // 3. Snapshot completeness.
    if !d1::snapshot_exists(&platform_db, &request.server_id, &request.snapshot_hash).await? {
        return Err(ApiError::snapshot_incomplete(
            &request.server_id,
            &request.snapshot_hash,
        ));
    }

    // 4. Canonicalize → fit hash.
    let canonical = hash::canonical_state(state);
    let canonical_bytes = canonical.encode_to_vec();
    let fit_hash = hash::fit_hash(&canonical_bytes);

    // 5. Idempotent re-submit: skip computation when the fit row exists (fast path;
    //    the insert below is conflict-tolerant and stays authoritative under races).
    let mut already_existed = d1::fit_exists(&fit_db, &fit_hash).await?;

    if !already_existed {
        // 6a. Prefetch the transitive closure (unknown seed type → 422).
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

        // 6b/6c. Calculate + validate (Error-level issues → 422, nothing stored).
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

        // 6d/6e. Assemble + store the snapshot.
        let created_at_ms = Date::now().as_millis() as i64;
        let snapshot = snapshot::assemble(&request, &canonical, &ship, &data, created_at_ms);
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

    // 7. Record the request (always, also for re-submits).
    let request_id = hash::request_id();
    d1::insert_request(&fit_db, &request_id, &fit_hash).await?;

    // 8. Respond.
    proto_response(&pb::FitUploadResponse {
        request_id,
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

async fn handle_request(env: Env, request_id: &str) -> Result<Response, ApiError> {
    let fit_db = fit_db(&env)?;
    match d1::get_request(&fit_db, request_id).await? {
        Some((request_id, fit_hash, created_at)) => proto_response(&pb::FitRequestRecord {
            request_id,
            fit_hash,
            created_at,
        }),
        None => Err(ApiError::not_found(format!(
            "unknown request id: {request_id}"
        ))),
    }
}

async fn handle_health(req: Request, env: Env) -> Result<Response, ApiError> {
    // Unauthenticated callers get a cheap in-memory liveness reply; the D1
    // round trips only run for authorized callers to avoid cheap load
    // amplification against both databases.
    if auth::check_authorization(&req, &env).is_ok() {
        d1::health_check(&platform_db(&env)?).await?;
        d1::health_check(&fit_db(&env)?).await?;
    }
    Response::from_json(&serde_json::json!({ "ok": true }))
        .map_err(|e| ApiError::internal(format!("failed to build response: {e}")))
}

#[event(fetch)]
async fn main(req: Request, env: Env, _ctx: Context) -> Result<Response> {
    if req.method() == Method::Options {
        let mut res = Response::empty()?;
        add_cors(&mut res)?;
        return Ok(res);
    }
    let mut res = match Router::new()
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
        .get_async(
            "/platform/storage/fit/request/:request_id",
            |_req, ctx| async move {
                let request_id = ctx.param("request_id").cloned().unwrap_or_default();
                Ok(handle_request(ctx.env, &request_id)
                    .await
                    .unwrap_or_else(render_error))
            },
        )
        .get_async("/platform/storage/fit/health", |req, ctx| async move {
            Ok(handle_health(req, ctx.env)
                .await
                .unwrap_or_else(render_error))
        })
        .run(req, env)
        .await
    {
        Ok(res) => res,
        // Handlers always return Ok; a routing-level error means no route
        // matched.
        Err(_) => render_error(ApiError::not_found("unknown route")),
    };
    add_cors(&mut res)?;
    Ok(res)
}
