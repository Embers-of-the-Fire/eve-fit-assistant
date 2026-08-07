use crate::error::ChatError;

pub const DEFAULT_BASE_URL: &str = "https://api.openai.com/v1";

pub const SYSTEM_PROMPT: &str = "You are a helpful assistant.";

#[derive(Debug, Clone)]
pub struct ChatProviderConfig {
    pub api_key: String,
    pub base_url: String,
    pub model: String,
}

impl ChatProviderConfig {
    pub fn new(
        api_key: impl Into<String>,
        base_url: impl Into<String>,
        model: impl Into<String>,
    ) -> Result<Self, ChatError> {
        let config = Self {
            api_key: api_key.into(),
            base_url: base_url.into(),
            model: model.into(),
        };
        config.validate()?;
        Ok(config)
    }

    pub fn validate(&self) -> Result<(), ChatError> {
        if self.api_key.trim().is_empty() {
            return Err(ChatError::InvalidConfig("api key must not be empty".into()));
        }
        if self.model.trim().is_empty() {
            return Err(ChatError::InvalidConfig("model must not be empty".into()));
        }
        if self.base_url.trim().is_empty() {
            return Err(ChatError::InvalidConfig(
                "base url must not be empty".into(),
            ));
        }
        Ok(())
    }
}
