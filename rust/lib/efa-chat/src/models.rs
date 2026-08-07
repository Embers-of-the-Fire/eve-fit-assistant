use rig::client::ModelListingClient;
use rig::model::ModelList;
use rig::providers::{anthropic, deepseek, openai};

use crate::config::ChatProviderKind;
use crate::error::ChatError;

/// A model exposed by a provider's list endpoint.
#[derive(Debug)]
pub struct ListedModel {
    pub id: String,
    /// Owner for OpenAI-compatible providers, display name for Anthropic.
    pub owned_by: Option<String>,
}

/// List the models available for [provider] via rig's native model listing
/// (auth headers and pagination handled by the provider client). A blank
/// `base_url` selects the provider's default endpoint.
pub async fn list_models(
    provider: ChatProviderKind,
    api_key: &str,
    base_url: &str,
) -> Result<Vec<ListedModel>, ChatError> {
    if api_key.trim().is_empty() {
        return Err(ChatError::InvalidConfig("api key is empty".into()));
    }
    let base_url = if base_url.trim().is_empty() {
        provider.default_base_url().to_string()
    } else {
        base_url.trim_end_matches('/').to_string()
    };
    let list: ModelList = match provider {
        ChatProviderKind::OpenAiCompatible => {
            openai::Client::builder()
                .api_key(api_key)
                .base_url(base_url)
                .build()
                .map_err(|e| ChatError::Client(e.to_string()))?
                .list_models()
                .await
        }
        ChatProviderKind::Anthropic => {
            anthropic::Client::builder()
                .api_key(api_key)
                .base_url(base_url)
                .build()
                .map_err(|e| ChatError::Client(e.to_string()))?
                .list_models()
                .await
        }
        ChatProviderKind::DeepSeek => {
            deepseek::Client::builder()
                .api_key(api_key)
                .base_url(base_url)
                .build()
                .map_err(|e| ChatError::Client(e.to_string()))?
                .list_models()
                .await
        }
    }
    .map_err(|e| ChatError::ModelListing(e.to_string()))?;

    let mut models: Vec<ListedModel> = list
        .data
        .into_iter()
        .map(|model| ListedModel {
            id: model.id,
            owned_by: model.owned_by.or(model.name),
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
            .block_on(list_models(
                ChatProviderKind::OpenAiCompatible,
                "",
                "https://api.openai.com/v1",
            ))
            .unwrap_err();
        assert!(matches!(err, ChatError::InvalidConfig(_)));
    }
}
