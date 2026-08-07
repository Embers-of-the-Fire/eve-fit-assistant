use crate::error::ChatError;

pub const DEFAULT_BASE_URL: &str = "https://api.openai.com/v1";

pub const ANTHROPIC_BASE_URL: &str = "https://api.anthropic.com";

pub const DEEPSEEK_BASE_URL: &str = "https://api.deepseek.com";

/// Base system prompt (persona + bundled-manual tool usage), bundled at
/// compile time.
pub const BASE_SYSTEM_PROMPT: &str = include_str!("../prompt/system.prompt.txt");

/// DeepSeek-specific prompt addition, bundled at compile time.
const DEEPSEEK_PROMPT_EXTRA: &str = include_str!("../prompt/deepseek.prompt.txt");

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

    /// Provider-specific prompt addition bundled under `prompt/`, appended to
    /// the system prompt even when extra sections are configured.
    pub fn system_prompt_extra(&self) -> Option<&'static str> {
        match self {
            Self::DeepSeek => Some(DEEPSEEK_PROMPT_EXTRA.trim_end()),
            _ => None,
        }
    }
}

#[derive(Debug, Clone)]
pub struct ChatProviderConfig {
    pub provider: ChatProviderKind,
    pub api_key: String,
    pub base_url: String,
    pub model: String,
    /// Extra system-prompt sections appended after the bundled base prompt
    /// ([`BASE_SYSTEM_PROMPT`]); blank adds nothing.
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
            system_prompt: String::new(),
            max_turns: DEFAULT_MAX_TURNS,
        };
        config.validate()?;
        Ok(config)
    }

    /// Add extra system-prompt sections appended after the bundled base
    /// prompt. Empty or whitespace-only prompts are ignored.
    pub fn with_system_prompt(mut self, system_prompt: impl Into<String>) -> Self {
        let prompt = system_prompt.into();
        if !prompt.trim().is_empty() {
            self.system_prompt = prompt.trim().to_string();
        }
        self
    }

    /// The full system prompt: the bundled base prompt plus the configured
    /// extra sections and the provider-specific addition (if any).
    pub fn full_system_prompt(&self) -> String {
        let mut prompt = BASE_SYSTEM_PROMPT.trim_end().to_string();
        if !self.system_prompt.is_empty() {
            prompt.push_str("\n\n");
            prompt.push_str(&self.system_prompt);
        }
        if let Some(extra) = self.provider.system_prompt_extra() {
            prompt.push_str("\n\n");
            prompt.push_str(extra);
        }
        prompt
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
