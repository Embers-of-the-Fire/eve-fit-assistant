use rig::http_client::{self, HttpClientExt};
use rig::providers::openai;
use serde::Deserialize;

use crate::error::ChatError;

/// A model exposed by an OpenAI-compatible endpoint (`GET {base_url}/models`).
///
/// Many compatible providers (DeepSeek, Moonshot, vLLM, ...) return only a
/// subset of the official schema, so every field except `id` is optional.
#[derive(Debug)]
pub struct ListedModel {
    pub id: String,
    pub owned_by: Option<String>,
}

#[derive(Debug, Deserialize)]
struct ListModelsResponse {
    data: Vec<ListModelEntry>,
}

#[derive(Debug, Deserialize)]
struct ListModelEntry {
    id: String,
    owned_by: Option<String>,
}

/// List the models exposed by an OpenAI-compatible endpoint.
///
/// Uses rig's raw request API (auth header applied from the client config) but
/// deserializes leniently: rig's builtin lister requires `created`/`owned_by`
/// on every entry, which several compatible providers omit.
pub async fn list_models(api_key: &str, base_url: &str) -> Result<Vec<ListedModel>, ChatError> {
    if api_key.is_empty() {
        return Err(ChatError::InvalidConfig("api key is empty".into()));
    }
    if base_url.is_empty() {
        return Err(ChatError::InvalidConfig("base url is empty".into()));
    }
    let client = openai::CompletionsClient::builder()
        .api_key(api_key)
        .base_url(base_url)
        .build()
        .map_err(|e| ChatError::Client(e.to_string()))?;
    let req = client
        .get("/models")
        .map_err(|e| ChatError::ModelListing(e.to_string()))?
        .body(http_client::NoBody)
        .map_err(|e| ChatError::ModelListing(e.to_string()))?;
    let response = client
        .send::<_, Vec<u8>>(req)
        .await
        .map_err(|e| ChatError::ModelListing(e.to_string()))?;
    let body = response
        .into_body()
        .await
        .map_err(|e| ChatError::ModelListing(e.to_string()))?;
    let parsed: ListModelsResponse =
        serde_json::from_slice(&body).map_err(|e| ChatError::ModelListing(e.to_string()))?;
    let mut models: Vec<ListedModel> = parsed
        .data
        .into_iter()
        .map(|entry| ListedModel {
            id: entry.id,
            owned_by: entry.owned_by,
        })
        .collect();
    models.sort_by(|a, b| a.id.cmp(&b.id));
    models.dedup_by(|a, b| a.id == b.id);
    Ok(models)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_empty_api_key() {
        let err = crate::runtime()
            .block_on(list_models("", "https://api.openai.com/v1"))
            .unwrap_err();
        assert!(matches!(err, ChatError::InvalidConfig(_)));
    }

    #[test]
    fn rejects_empty_base_url() {
        let err = crate::runtime()
            .block_on(list_models("test-key", ""))
            .unwrap_err();
        assert!(matches!(err, ChatError::InvalidConfig(_)));
    }

    #[test]
    fn parses_official_schema() {
        let body = br#"{"object":"list","data":[{"id":"gpt-4o","object":"model","created":1,"owned_by":"openai"}]}"#;
        let parsed: ListModelsResponse = serde_json::from_slice(body).unwrap();
        assert_eq!(parsed.data[0].id, "gpt-4o");
        assert_eq!(parsed.data[0].owned_by.as_deref(), Some("openai"));
    }

    #[test]
    fn parses_lenient_schema_without_created_and_owned_by() {
        let body = br#"{"object":"list","data":[{"id":"deepseek-v4-flash","object":"model"},{"id":"deepseek-v4-pro","object":"model","owned_by":"deepseek"}]}"#;
        let parsed: ListModelsResponse = serde_json::from_slice(body).unwrap();
        assert_eq!(parsed.data.len(), 2);
        assert_eq!(parsed.data[0].owned_by, None);
        assert_eq!(parsed.data[1].owned_by.as_deref(), Some("deepseek"));
    }
}
