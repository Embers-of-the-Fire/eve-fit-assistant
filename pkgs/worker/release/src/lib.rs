use prost::Message;
use serde::Serialize;
use sha2::{Digest, Sha256};
use std::collections::HashMap;
use worker::*;

mod proto {
    include!(concat!(env!("OUT_DIR"), "/efa.v2.rs"));
}

use proto::GenerationPointer;
use proto::ReleaseIndex;

const RESOURCE_ROOT: &str = "efa/v2";
const DEFAULT_ORIGIN: &str = "https://prod.storage.efa-tech.dev";

#[derive(Serialize)]
struct ArtifactResponse {
    ok: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    artifacts: Option<HashMap<String, ArtifactInfo>>,
    channels: Vec<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<String>,
}

#[derive(Serialize)]
struct ArtifactInfo {
    id: String,
    version: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    android: Option<HashMap<String, VariantInfo>>,
}

#[derive(Serialize)]
struct VariantInfo {
    identifier: String,
    content_hash: String,
    size: i64,
    download_url: String,
}

fn sha256_hex(input: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(input.as_bytes());
    let result = hasher.finalize();
    result.iter().map(|b| format!("{:02x}", b)).collect()
}

fn hex_prefix_2(hash: &str) -> &str {
    &hash[..2]
}

async fn read_bucket_bytes(bucket: &Bucket, path: &str) -> Result<Vec<u8>> {
    let object = bucket
        .get(path)
        .execute()
        .await?
        .ok_or_else(|| Error::RustError(format!("object not found: {}", path)))?;
    let body = object
        .body()
        .ok_or_else(|| Error::RustError(format!("object has no body: {}", path)))?;
    body.bytes().await
}

async fn read_bucket_json(bucket: &Bucket, path: &str) -> Result<serde_json::Value> {
    let bytes = read_bucket_bytes(bucket, path).await?;
    serde_json::from_slice(&bytes)
        .map_err(|e| Error::RustError(format!("JSON parse error for {}: {}", path, e)))
}

async fn read_bucket_proto<T: Message + Default>(
    bucket: &Bucket,
    path: &str,
) -> Result<T> {
    let bytes = read_bucket_bytes(bucket, path).await?;
    T::decode(&*bytes)
        .map_err(|e| Error::RustError(format!("protobuf decode error for {}: {}", path, e)))
}

fn origin_allowed(req: &Request) -> Option<String> {
    let origin = req.headers().get("Origin").ok()??;
    let is_localhost = origin.starts_with("http://localhost:")
        || origin.starts_with("http://127.0.0.1:");
    is_localhost.then_some(origin)
}

fn add_cors(res: &mut Response, origin: &str) -> Result<()> {
    let headers = res.headers_mut();
    headers.set("Access-Control-Allow-Origin", origin)?;
    headers.set("Access-Control-Allow-Methods", "GET, OPTIONS")?;
    headers.set("Access-Control-Allow-Headers", "Content-Type")?;
    Ok(())
}

async fn fetch_channel_artifact(
    bucket: &Bucket,
    origin: &str,
    channel: &str,
) -> Result<Option<ArtifactInfo>> {
    let head_meta: serde_json::Value = match read_bucket_json(
        bucket,
        &format!("{}/channels/heads/{}/metadata.json", RESOURCE_ROOT, channel),
    )
    .await
    {
        Ok(v) => v,
        Err(_) => return Ok(None),
    };

    let gen_hash = match head_meta["generationHash"].as_str() {
        Some(h) => h.to_string(),
        None => return Ok(None),
    };

    let pointer: GenerationPointer = match read_bucket_proto(
        bucket,
        &format!("{}/channels/refs/{}/releases.pb2", RESOURCE_ROOT, gen_hash),
    )
    .await
    {
        Ok(p) => p,
        Err(_) => return Ok(None),
    };

    let snapshot_hash = pointer.snapshot_hash;

    let index: ReleaseIndex = match read_bucket_proto(
        bucket,
        &format!(
            "{}/assets/releases/{}/releases.pb2",
            RESOURCE_ROOT, snapshot_hash
        ),
    )
    .await
    {
        Ok(idx) => idx,
        Err(_) => return Ok(None),
    };

    let android = index.android.map(|arts| {
        let mut variants = HashMap::new();
        let names = ["general", "armv7", "arm64", "x64"];
        let fields: [Option<proto::AndroidArtifactVariant>; 4] =
            [Some(arts.general), arts.armv7, arts.arm64, arts.x64];
        for (i, field) in fields.iter().enumerate() {
            if let Some(v) = field {
                let ident_hash = sha256_hex(&v.identifier);
                let download_url = format!(
                    "{}/{}/assets/blobs/{}/{}/{}",
                    origin,
                    RESOURCE_ROOT,
                    hex_prefix_2(&ident_hash),
                    ident_hash,
                    v.content_hash
                );
                variants.insert(
                    names[i].to_string(),
                    VariantInfo {
                        identifier: v.identifier.clone(),
                        content_hash: v.content_hash.clone(),
                        size: v.size,
                        download_url,
                    },
                );
            }
        }
        variants
    });

    Ok(Some(ArtifactInfo {
        id: index.id,
        version: index.version,
        android,
    }))
}

#[event(fetch)]
async fn main(req: Request, env: Env, _ctx: Context) -> Result<Response> {
    let origin = origin_allowed(&req);
    if req.method() == Method::Options {
        let mut res = Response::empty()?;
        if let Some(ref o) = origin {
            add_cors(&mut res, o)?;
        }
        return Ok(res);
    }
    let mut res = Router::new()
        .get_async("/releases/artifacts", |req, ctx| async move {
            handle_artifacts(req, ctx.env).await
        })
        .run(req, env)
        .await?;
    if let Some(ref o) = origin {
        add_cors(&mut res, o)?;
    }
    Ok(res)
}

fn origin_from_env(env: &Env) -> String {
    env.var("BLOB_ORIGIN")
        .ok()
        .and_then(|v| v.to_string().into())
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| DEFAULT_ORIGIN.to_string())
}

async fn handle_artifacts(_req: Request, env: Env) -> Result<Response> {
    let bucket = match env.bucket("RELEASE_BUCKET") {
        Ok(b) => b,
        Err(e) => {
            return Response::from_json(&ArtifactResponse {
                ok: false,
                artifacts: None,
                channels: vec![],
                error: Some(format!("RELEASE_BUCKET binding not configured: {}", e)),
            });
        }
    };

    let origin = origin_from_env(&env);

    let registry: serde_json::Value =
        match read_bucket_json(&bucket, &format!("{}/channels/heads/channels.json", RESOURCE_ROOT)).await
        {
            Ok(v) => v,
            Err(e) => {
                return Response::from_json(&ArtifactResponse {
                    ok: false,
                    artifacts: None,
                    channels: vec![],
                    error: Some(format!("channel registry not found: {}", e)),
                });
            }
        };

    let channels: Vec<String> = registry["channels"]
        .as_object()
        .map(|m| m.keys().cloned().collect())
        .unwrap_or_default();

    let mut artifacts = HashMap::new();
    for ch in &channels {
        if let Ok(Some(artifact)) = fetch_channel_artifact(&bucket, &origin, ch).await {
            artifacts.insert(ch.clone(), artifact);
        }
    }

    let body = serde_json::to_string(&ArtifactResponse {
        ok: true,
        artifacts: Some(artifacts),
        channels,
        error: None,
    })
    .map_err(|e| Error::RustError(format!("serialization error: {}", e)))?;
    Response::ok(body)
}
