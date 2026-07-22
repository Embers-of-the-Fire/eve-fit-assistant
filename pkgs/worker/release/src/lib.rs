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
const APK_CONTENT_TYPE: &str = "application/vnd.android.package-archive";

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

struct RawVariantInfo {
    identifier: String,
    content_hash: String,
    size: i64,
}

struct RawArtifactInfo {
    id: String,
    version: String,
    android: Option<HashMap<String, RawVariantInfo>>,
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

fn blob_path(identifier: &str, content_hash: &str) -> String {
    let ident_hash = sha256_hex(identifier);
    format!(
        "{}/assets/blobs/{}/{}/{}",
        RESOURCE_ROOT,
        hex_prefix_2(&ident_hash),
        ident_hash,
        content_hash
    )
}

fn sanitize_filename_part(part: &str) -> String {
    part.chars()
        .map(|c| {
            if c.is_ascii_alphanumeric() || matches!(c, '.' | '-' | '_') {
                c
            } else {
                '-'
            }
        })
        .collect()
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

async fn read_bucket_proto<T: Message + Default>(bucket: &Bucket, path: &str) -> Result<T> {
    let bytes = read_bucket_bytes(bucket, path).await?;
    T::decode(&*bytes)
        .map_err(|e| Error::RustError(format!("protobuf decode error for {}: {}", path, e)))
}

fn add_cors(res: &mut Response) -> Result<()> {
    let headers = res.headers_mut();
    headers.set("Access-Control-Allow-Origin", "*")?;
    headers.set("Access-Control-Allow-Methods", "GET, OPTIONS")?;
    headers.set("Access-Control-Allow-Headers", "Content-Type")?;
    Ok(())
}

async fn fetch_channel_artifact(bucket: &Bucket, channel: &str) -> Result<Option<RawArtifactInfo>> {
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
                variants.insert(
                    names[i].to_string(),
                    RawVariantInfo {
                        identifier: v.identifier.clone(),
                        content_hash: v.content_hash.clone(),
                        size: v.size,
                    },
                );
            }
        }
        variants
    });

    Ok(Some(RawArtifactInfo {
        id: index.id,
        version: index.version,
        android,
    }))
}

#[event(fetch)]
async fn main(req: Request, env: Env, _ctx: Context) -> Result<Response> {
    if req.method() == Method::Options {
        let mut res = Response::empty()?;
        add_cors(&mut res)?;
        return Ok(res);
    }
    let mut res = Router::new()
        .get_async("/releases/artifacts", |req, ctx| async move {
            handle_artifacts(req, ctx.env).await
        })
        .get_async(
            "/releases/download/:channel/:variant",
            |req, ctx| async move {
                let channel = ctx.param("channel").cloned().unwrap_or_default();
                let variant = ctx.param("variant").cloned().unwrap_or_default();
                handle_download(req, ctx.env, &channel, &variant).await
            },
        )
        .run(req, env)
        .await?;
    add_cors(&mut res)?;
    Ok(res)
}

async fn handle_artifacts(req: Request, env: Env) -> Result<Response> {
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

    let origin = req.url()?.origin().ascii_serialization();

    let registry: serde_json::Value = match read_bucket_json(
        &bucket,
        &format!("{}/channels/heads/channels.json", RESOURCE_ROOT),
    )
    .await
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
        if let Ok(Some(raw)) = fetch_channel_artifact(&bucket, ch).await {
            let android = raw.android.map(|variants| {
                variants
                    .into_iter()
                    .map(|(name, v)| {
                        let info = VariantInfo {
                            identifier: v.identifier,
                            content_hash: v.content_hash,
                            size: v.size,
                            download_url: format!("{}/releases/download/{}/{}", origin, ch, name),
                        };
                        (name, info)
                    })
                    .collect()
            });
            artifacts.insert(
                ch.clone(),
                ArtifactInfo {
                    id: raw.id,
                    version: raw.version,
                    android,
                },
            );
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

async fn handle_download(
    _req: Request,
    env: Env,
    channel: &str,
    variant: &str,
) -> Result<Response> {
    let bucket = env
        .bucket("RELEASE_BUCKET")
        .map_err(|e| Error::RustError(format!("RELEASE_BUCKET binding not configured: {}", e)))?;

    let artifact = match fetch_channel_artifact(&bucket, channel).await? {
        Some(a) => a,
        None => return Response::error(format!("channel not found: {}", channel), 404),
    };

    let info = match artifact
        .android
        .as_ref()
        .and_then(|variants| variants.get(variant))
    {
        Some(v) => v,
        None => return Response::error(format!("variant not found: {}/{}", channel, variant), 404),
    };

    let path = blob_path(&info.identifier, &info.content_hash);
    let object = match bucket.get(&path).execute().await? {
        Some(o) => o,
        None => return Response::error(format!("blob not found: {}", path), 404),
    };

    let size = object.size();
    let body = object
        .body()
        .ok_or_else(|| Error::RustError(format!("object has no body: {}", path)))?;

    let filename = format!(
        "eve-fit-assistant-{}-{}.apk",
        sanitize_filename_part(&artifact.version),
        sanitize_filename_part(variant)
    );

    let mut res = Response::from_body(body.response_body()?)?;
    let headers = res.headers_mut();
    headers.set("Content-Type", APK_CONTENT_TYPE)?;
    headers.set(
        "Content-Disposition",
        &format!("attachment; filename=\"{}\"", filename),
    )?;
    headers.set("Content-Length", &size.to_string())?;
    headers.set("Cache-Control", "public, max-age=31536000, immutable")?;
    Ok(res)
}
