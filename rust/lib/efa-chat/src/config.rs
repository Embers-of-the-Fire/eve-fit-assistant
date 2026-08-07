use crate::error::ChatError;

pub const DEFAULT_BASE_URL: &str = "https://api.openai.com/v1";

pub const ANTHROPIC_BASE_URL: &str = "https://api.anthropic.com";

pub const DEEPSEEK_BASE_URL: &str = "https://api.deepseek.com";

pub const DEFAULT_SYSTEM_PROMPT: &str = "You are a helpful assistant.";

/// Default multi-turn depth: how many tool-call roundtrips a single turn may
/// take before rig stops the loop.
pub const DEFAULT_MAX_TURNS: usize = 20;

/// The chat completion provider backing a session.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum ChatProviderKind {
    /// Any endpoint speaking the OpenAI Chat Completions API (OpenAI,
    /// OpenRouter, vLLM, Ollama, ...).
    #[default]
    OpenAiCompatible,
    Anthropic,
    DeepSeek,
}

impl ChatProviderKind {
    pub fn default_base_url(&self) -> &'static str {
        match self {
            Self::OpenAiCompatible => DEFAULT_BASE_URL,
            Self::Anthropic => ANTHROPIC_BASE_URL,
            Self::DeepSeek => DEEPSEEK_BASE_URL,
        }
    }
}

#[derive(Debug, Clone)]
pub struct ChatProviderConfig {
    pub provider: ChatProviderKind,
    pub api_key: String,
    pub base_url: String,
    pub model: String,
    pub system_prompt: String,
    /// Multi-turn depth (tool-call roundtrips per turn); see
    /// [`DEFAULT_MAX_TURNS`].
    pub max_turns: usize,
}

impl ChatProviderConfig {
    /// A blank `base_url` selects the provider's default endpoint.
    pub fn new(
        provider: ChatProviderKind,
        api_key: impl Into<String>,
        base_url: impl Into<String>,
        model: impl Into<String>,
    ) -> Result<Self, ChatError> {
        let config = Self {
            provider,
            api_key: api_key.into(),
            base_url: base_url.into(),
            model: model.into(),
            system_prompt: DEFAULT_SYSTEM_PROMPT.into(),
            max_turns: DEFAULT_MAX_TURNS,
        };
        config.validate()?;
        Ok(config)
    }

    /// Override the system prompt. Empty or whitespace-only prompts are
    /// ignored, keeping the default.
    pub fn with_system_prompt(mut self, system_prompt: impl Into<String>) -> Self {
        let prompt = system_prompt.into();
        if !prompt.trim().is_empty() {
            self.system_prompt = prompt;
        }
        self
    }

    /// Override the multi-turn depth. Zero is ignored, keeping the default.
    pub fn with_max_turns(mut self, max_turns: usize) -> Self {
        if max_turns > 0 {
            self.max_turns = max_turns;
        }
        self
    }

    /// The configured base URL, or the provider default when blank.
    pub fn resolved_base_url(&self) -> &str {
        if self.base_url.trim().is_empty() {
            self.provider.default_base_url()
        } else {
            self.base_url.trim_end_matches('/')
        }
    }

    pub fn validate(&self) -> Result<(), ChatError> {
        if self.api_key.trim().is_empty() {
            return Err(ChatError::InvalidConfig("api key must not be empty".into()));
        }
        if self.model.trim().is_empty() {
            return Err(ChatError::InvalidConfig("model must not be empty".into()));
        }
        Ok(())
    }
}
