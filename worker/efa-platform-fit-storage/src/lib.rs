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

/// Outcome of resolving the request's snapshot selector (submit step 2).
enum SnapshotResolution {
    /// The requested snapshot is registered and complete.
    Requested(i64),
    /// Consented fallback: compute with the server's latest completed
    /// snapshot (registry id, hex hash).
    Fallback(i64, String),
    /// No usable snapshot; reject with `snapshot_incomplete`, carrying the
    /// latest completed snapshot hash when one exists.
    Rejected(Option<String>),
}

/// The step-2 decision for an unrecognized selector. `latest` is the server's
/// newest completed snapshot, looked up only when the requested selector did
/// not resolve. The fallback is taken only with explicit uploader consent
/// (`allow_latest_snapshot_fallback`); without it the submit is rejected and
/// the error carries the fallback candidate so clients can ask for consent.
fn decide_snapshot_resolution(
    latest: Option<(i64, String)>,
    allow_fallback: bool,
) -> SnapshotResolution {
    match (latest, allow_fallback) {
        (Some((id, hash)), true) => SnapshotResolution::Fallback(id, hash),
        (latest, _) => SnapshotResolution::Rejected(latest.map(|(_, hash)| hash)),
    }
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

    // 2. Snapshot completeness: resolve the selector to its registry id.
    //    Resolved ids are cached per isolate (completed snapshots are frozen).
    //    With explicit uploader consent (`allow_latest_snapshot_fallback`) an
    //    unrecognized selector falls back to the server's latest completed
    //    snapshot; the effective selector keys every downstream cache and the
    //    stored `(fit_hash, snapshot_hash)` variant.
    let requested_key: prefetch::SnapshotKey =
        (request.server_id.clone(), request.snapshot_hash.clone());
    let requested_id = match prefetch::snapshot_id_get(&requested_key) {
        Some(id) => Some(id),
        None => {
            let id = d1::resolve_snapshot(&platform_db, &request.server_id, &request.snapshot_hash)
                .await?;
            if let Some(id) = id {
                prefetch::snapshot_id_put(requested_key.clone(), id);
            }
            id
        }
    };

    // The latest-snapshot lookup happens only on the rejection path.
    let resolution = match requested_id {
        Some(id) => SnapshotResolution::Requested(id),
        None => decide_snapshot_resolution(
            d1::resolve_latest_snapshot(&platform_db, &request.server_id).await?,
            request.allow_latest_snapshot_fallback == Some(true),
        ),
    };
    let (key, snapshot_id, used_fallback) = match resolution {
        SnapshotResolution::Requested(id) => (requested_key, id, false),
        SnapshotResolution::Fallback(id, hash) => {
            let key: prefetch::SnapshotKey = (request.server_id.clone(), hash);
            prefetch::snapshot_id_put(key.clone(), id);
            (key, id, true)
        }
        SnapshotResolution::Rejected(latest_hash) => {
            return Err(ApiError::snapshot_incomplete(
                &request.server_id,
                &request.snapshot_hash,
                latest_hash,
            ));
        }
    };

    // 3. Canonicalize → fit hash.
    let canonical = hash::canonical_state(state);
    let canonical_bytes = canonical.encode_to_vec();
    let fit_hash = hash::fit_hash(&canonical_bytes);

    // 4. Idempotent re-submit: skip computation when this snapshot variant of
    //    the fit exists (fast path; the insert below is conflict-tolerant and
    //    stays authoritative under races). A re-upload under a different
    //    snapshot — e.g. the originally requested one after ingestion — misses
    //    this check and recomputes into its own variant row.
    let mut already_existed = d1::fit_exists(&fit_db, &fit_hash, &key.1).await?;

    if !already_existed {
        // 5a. Prefetch the transitive closure (unknown seed type → 422).
        let mut data = prefetch::cache_get(&key);
        {
            let platform_db = &platform_db;
            let fetch = |request: prefetch::FetchRequest| async move {
                prefetch::fetch_family(platform_db, snapshot_id, request).await
            };
            prefetch::prefetch(&mut data, &canonical, fetch).await?;
        }
        if data.decode_warnings > 0 {
            console_log!(
                "fit-storage: {} degraded buff decodes for {}/{}",
                data.decode_warnings,
                key.0,
                key.1
            );
        }
        prefetch::cache_merge(key.clone(), data.clone());

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
            &key.1,
            used_fallback.then_some(request.snapshot_hash.as_str()),
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
        snapshot_hash: Some(key.1.clone()),
        snapshot_fallback: Some(used_fallback),
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn fallback_requires_consent() {
        let latest = Some((7, "aa".repeat(32)));
        assert!(matches!(
            decide_snapshot_resolution(latest.clone(), false),
            SnapshotResolution::Rejected(Some(hash)) if hash == "aa".repeat(32)
        ));
        assert!(matches!(
            decide_snapshot_resolution(latest, true),
            SnapshotResolution::Fallback(7, _)
        ));
    }

    #[test]
    fn rejection_without_any_completed_snapshot_carries_no_candidate() {
        assert!(matches!(
            decide_snapshot_resolution(None, false),
            SnapshotResolution::Rejected(None)
        ));
        // Consent cannot help when the server has no completed snapshot.
        assert!(matches!(
            decide_snapshot_resolution(None, true),
            SnapshotResolution::Rejected(None)
        ));
    }

    #[test]
    fn snapshot_incomplete_body_carries_latest_hash_when_present() {
        let err =
            ApiError::snapshot_incomplete("tranquility", &"bb".repeat(32), Some("aa".repeat(32)));
        let body = err.body();
        assert_eq!(body["error"], "snapshot_incomplete");
        assert_eq!(body["latest_snapshot_hash"], "aa".repeat(32));

        let err = ApiError::snapshot_incomplete("tranquility", &"bb".repeat(32), None);
        let body = err.body();
        assert_eq!(body["error"], "snapshot_incomplete");
        assert!(body.get("latest_snapshot_hash").is_none());
    }
}
