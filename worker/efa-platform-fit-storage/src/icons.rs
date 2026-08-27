//! Submit-time baking of `SnapshotType.icon_url` from the EFA storage
//! catalog chain.
//!
//! Resolution chain (mirrors the app's `RemoteCatalogService`):
//!
//! ```text
//! efa/v2/channels/heads/channels.json            (defaultChannel)
//!   → efa/v2/channels/heads/{channel}/metadata.json   (generationHash)
//!   → efa/v2/channels/refs/{generationHash}/resources.pb2
//!       (`GenerationResources`: server_id → snapshot_hash)
//!   → efa/v2/assets/resources/{snapshotHash}/resources.pb2
//!       (`ResourceIndex`: resource_id → content_hash)
//!   → efa/v2/assets/blobs/{ident[0:2]}/{ident}/{content_hash}
//!     where ident = SHA-256 hex of the resource_id URI
//! ```
//!
//! Everything here is best-effort and runs **only** in the submit path: any
//! failure degrades to "no baked URL" (the consumer's evetech fallback covers
//! it) — a storage outage must never fail a fit submit. There is deliberately
//! no rebake-on-read.

use std::collections::HashMap;

use prost::Message;
use serde::Deserialize;
use sha2::{Digest, Sha256};
use worker::{Cache, Env, Fetch, Method, Request, Response, console_log};

use crate::proto::efa_v2::GenerationResources;
use crate::proto::efa_v2::ResourceIndex;
use crate::proto::platform_data::PlatformTypeMeta;

/// TTL for the mutable channel registry/head metadata (seconds).
const HEAD_CACHE_TTL_S: u32 = 300;
/// TTL for content-addressed refs/indexes (seconds); their URLs embed the
/// generation/snapshot hash, so they are immutable.
const IMMUTABLE_CACHE_TTL_S: u32 = 86_400;

/// `channels/heads/channels.json`. The remote spec uses `defaultChannel`;
/// `active` is the client's mapped key, accepted defensively.
#[derive(Deserialize)]
struct ChannelRegistry {
    #[serde(rename = "defaultChannel", alias = "active")]
    default_channel: String,
}

/// Channel selection, mirroring the app (`generation_nav.dart`): an empty
/// `defaultChannel` falls back to `"testing"`.
fn select_channel(registry: &ChannelRegistry) -> &str {
    if registry.default_channel.is_empty() {
        "testing"
    } else {
        &registry.default_channel
    }
}

/// `channels/heads/{channel}/metadata.json`.
#[derive(Deserialize)]
struct HeadMeta {
    #[serde(rename = "generationHash")]
    generation_hash: String,
}

// In-isolate memoization of immutable, content-addressed bodies (refs and
// resource indexes). Mutable head metadata is left to the Cache API so it can
// expire. Same single-threaded-isolate argument as the prefetch cache.
thread_local! {
    static IMMUTABLE_CACHE: std::cell::RefCell<HashMap<String, Vec<u8>>> =
        std::cell::RefCell::new(HashMap::new());
}

fn catalog_url(origin: &str, path: &str) -> String {
    format!("{}/efa/v2/{path}", origin.trim_end_matches('/'))
}

fn hex_lower(bytes: &[u8]) -> String {
    const HEX: &[u8; 16] = b"0123456789abcdef";
    let mut out = String::with_capacity(bytes.len() * 2);
    for &b in bytes {
        out.push(HEX[(b >> 4) as usize] as char);
        out.push(HEX[(b & 0x0f) as usize] as char);
    }
    out
}

/// `identHash = SHA-256(resource_id)` (lowercase hex), matching the app's
/// `RepoHash.hashIdent`.
fn ident_hash(resource_id: &str) -> String {
    hex_lower(&Sha256::digest(resource_id.as_bytes()))
}

/// The content-addressed blob URL for a resource
/// (`assets/blobs/{ident[0:2]}/{ident}/{content_hash}`).
fn blob_url(origin: &str, resource_id: &str, content_hash: &str) -> String {
    let ident = ident_hash(resource_id);
    catalog_url(
        origin,
        &format!("assets/blobs/{}/{ident}/{content_hash}", &ident[..2]),
    )
}

/// Candidate resource IDs of a type's icon, graphic first (matching the app's
/// `ImageAssetService.resolve` preference).
fn icon_resource_ids(meta: &PlatformTypeMeta) -> Vec<String> {
    let mut ids = Vec::with_capacity(2);
    if let Some(graphic_id) = meta.graphic_id {
        ids.push(format!(
            "resource://static/images/graphics/{graphic_id}.png"
        ));
    }
    if let Some(icon_id) = meta.icon_id {
        ids.push(format!("resource://static/images/icons/{icon_id}.png"));
    }
    ids
}

/// Server selection within a generation: the fit's own `server_id` where it
/// matches, else `tranquility`, else the first entry.
fn select_snapshot_hash<'a>(gen: &'a GenerationResources, server_id: &str) -> Option<&'a str> {
    gen.entries
        .iter()
        .find(|e| e.server_id == server_id)
        .or_else(|| gen.entries.iter().find(|e| e.server_id == "tranquility"))
        .or_else(|| gen.entries.first())
        .map(|e| e.snapshot_hash.as_str())
}

/// Fetch `url` through the Cloudflare Cache API, populating it on a miss.
/// Content-addressed URLs additionally hit the in-isolate memoization.
async fn fetch_cached(url: &str, ttl_s: u32, immutable: bool) -> Option<Vec<u8>> {
    if immutable {
        if let Some(bytes) = IMMUTABLE_CACHE.with(|c| c.borrow().get(url).cloned()) {
            return Some(bytes);
        }
    }

    let cache = Cache::default();
    match cache.get(url, true).await {
        Ok(Some(mut resp)) => return resp.bytes().await.ok(),
        Ok(None) => {}
        Err(e) => console_log!("fit-storage: icon cache get failed for {url}: {e}"),
    }

    let request = Request::new(url, Method::Get).ok()?;
    let mut resp = Fetch::Request(request).send().await.ok()?;
    if resp.status_code() != 200 {
        return None;
    }
    let bytes = resp.bytes().await.ok()?;

    // Best-effort cache population; a put failure only loses edge caching.
    if let Ok(stored) = Response::from_bytes(bytes.clone()) {
        let mut stored = stored;
        if stored
            .headers_mut()
            .set("Cache-Control", &format!("public, max-age={ttl_s}"))
            .is_ok()
        {
            let _ = cache.put(url, stored).await;
        }
    }
    if immutable {
        IMMUTABLE_CACHE.with(|c| c.borrow_mut().insert(url.to_string(), bytes.clone()));
    }
    Some(bytes)
}

async fn fetch_json<T: for<'de> Deserialize<'de>>(url: &str, ttl_s: u32) -> Option<T> {
    let bytes = fetch_cached(url, ttl_s, false).await?;
    serde_json::from_slice(&bytes).ok()
}

async fn fetch_pb<M: Message + Default>(url: &str) -> Option<M> {
    let bytes = fetch_cached(url, IMMUTABLE_CACHE_TTL_S, true).await?;
    M::decode(&bytes[..]).ok()
}

async fn resolve_icon_urls_inner(
    env: &Env,
    server_id: &str,
    metas: &HashMap<i32, PlatformTypeMeta>,
) -> Result<HashMap<i32, String>, String> {
    let origin = env
        .var("STORAGE_ORIGIN")
        .map_err(|_| "STORAGE_ORIGIN var not configured".to_string())?
        .to_string();

    let registry_url = catalog_url(&origin, "channels/heads/channels.json");
    let registry: ChannelRegistry = fetch_json(&registry_url, HEAD_CACHE_TTL_S)
        .await
        .ok_or_else(|| format!("channel registry {registry_url}: fetch/parse failed"))?;
    let head_url = catalog_url(
        &origin,
        &format!("channels/heads/{}/metadata.json", select_channel(&registry)),
    );
    let head: HeadMeta = fetch_json(&head_url, HEAD_CACHE_TTL_S)
        .await
        .ok_or_else(|| format!("head metadata {head_url}: fetch/parse failed"))?;
    let gen_url = catalog_url(
        &origin,
        &format!("channels/refs/{}/resources.pb2", head.generation_hash),
    );
    let gen: GenerationResources = fetch_pb(&gen_url)
        .await
        .ok_or_else(|| format!("generation resources {gen_url}: fetch/decode failed"))?;
    let snapshot_hash = select_snapshot_hash(&gen, server_id)
        .ok_or_else(|| format!("generation resources {gen_url}: no server entries"))?;
    let index_url = catalog_url(
        &origin,
        &format!("assets/resources/{snapshot_hash}/resources.pb2"),
    );
    let index: ResourceIndex = fetch_pb(&index_url)
        .await
        .ok_or_else(|| format!("resource index {index_url}: fetch/decode failed"))?;

    let content_hashes: HashMap<&str, &str> = index
        .entries
        .iter()
        .map(|e| (e.resource_id.as_str(), e.content_hash.as_str()))
        .collect();

    let mut urls = HashMap::new();
    for (type_id, meta) in metas {
        for resource_id in icon_resource_ids(meta) {
            if let Some(content_hash) = content_hashes.get(resource_id.as_str()) {
                urls.insert(*type_id, blob_url(&origin, &resource_id, content_hash));
                break;
            }
        }
    }
    Ok(urls)
}

/// Resolve a baked, content-addressed icon URL for every type with metadata.
///
/// Best-effort: any catalog-chain failure (including a missing
/// `STORAGE_ORIGIN` var) yields an empty map; consumers then fall back to
/// their default icon resolution. Never fails a fit submit.
pub async fn resolve_icon_urls(
    env: &Env,
    server_id: &str,
    metas: &HashMap<i32, PlatformTypeMeta>,
) -> HashMap<i32, String> {
    match resolve_icon_urls_inner(env, server_id, metas).await {
        Ok(urls) => urls,
        Err(stage) => {
            console_log!("fit-storage: icon URL resolution failed ({stage}); baking no icon_url");
            HashMap::new()
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::proto::efa_v2::generation_resources;

    fn meta(icon_id: Option<u32>, graphic_id: Option<u32>) -> PlatformTypeMeta {
        PlatformTypeMeta {
            type_id: 0,
            name: Default::default(),
            icon_id,
            graphic_id,
        }
    }

    #[test]
    fn ident_hash_is_sha256_hex_of_resource_id() {
        // Matches `RepoHash.hashIdent` (SHA-256 hex of the UTF-8 URI);
        // expected value verified against `sha256sum`.
        assert_eq!(
            ident_hash("resource://static/images/icons/0.png"),
            "f7a7af34e2dc355b898b3d80e061cb6e67fdf5328a6f0be5cc8c466082b0ef7b".to_string(),
        );
    }

    #[test]
    fn blob_url_layout() {
        let url = blob_url(
            "https://prod.storage.efa-tech.dev/",
            "resource://static/images/icons/1.png",
            "deadbeef",
        );
        let ident = ident_hash("resource://static/images/icons/1.png");
        assert_eq!(
            url,
            format!(
                "https://prod.storage.efa-tech.dev/efa/v2/assets/blobs/{}/{ident}/deadbeef",
                &ident[..2]
            )
        );
    }

    #[test]
    fn graphic_preferred_over_icon() {
        let ids = icon_resource_ids(&meta(Some(7), Some(9)));
        assert_eq!(
            ids,
            vec![
                "resource://static/images/graphics/9.png".to_string(),
                "resource://static/images/icons/7.png".to_string(),
            ]
        );
        assert_eq!(
            icon_resource_ids(&meta(Some(7), None)),
            vec!["resource://static/images/icons/7.png".to_string()]
        );
        assert!(icon_resource_ids(&meta(None, None)).is_empty());
    }

    #[test]
    fn empty_default_channel_falls_back_to_testing() {
        // Mirrors the app (`generation_nav.dart`): the live prod registry
        // ships `"defaultChannel": ""`.
        let registry = ChannelRegistry {
            default_channel: String::new(),
        };
        assert_eq!(select_channel(&registry), "testing");
        let registry = ChannelRegistry {
            default_channel: "stable".to_string(),
        };
        assert_eq!(select_channel(&registry), "stable");
    }

    #[test]
    fn server_selection_prefers_fit_server() {
        let entry = |server_id: &str, hash: &str| generation_resources::Entry {
            server_id: server_id.to_string(),
            snapshot_hash: hash.to_string(),
        };
        let gen = GenerationResources {
            schema_version: 1,
            entries: vec![entry("serenity", "aaa"), entry("tranquility", "bbb")],
        };
        assert_eq!(select_snapshot_hash(&gen, "serenity"), Some("aaa"));
        assert_eq!(select_snapshot_hash(&gen, "tranquility"), Some("bbb"));
        // Unknown fit server falls back to tranquility, then first entry.
        assert_eq!(select_snapshot_hash(&gen, "other"), Some("bbb"));
        let no_tq = GenerationResources {
            schema_version: 1,
            entries: vec![entry("serenity", "aaa")],
        };
        assert_eq!(select_snapshot_hash(&no_tq, "other"), Some("aaa"));
        let empty = GenerationResources {
            schema_version: 1,
            entries: vec![],
        };
        assert_eq!(select_snapshot_hash(&empty, "other"), None);
    }
}
