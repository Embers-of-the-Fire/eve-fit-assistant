use crate::core::error::ChatError;

pub const DEFAULT_BASE_URL: &str = "https://api.openai.com/v1";

pub const ANTHROPIC_BASE_URL: &str = "https://api.anthropic.com";

pub const DEEPSEEK_BASE_URL: &str = "https://api.deepseek.com";

/// Default multi-turn depth: how many tool-call roundtrips a single turn may
/// take before rig stops the loop.
pub const DEFAULT_MAX_TURNS: usize = 20;

/// The language of the bundled prompt files (`prompt/**/{en,zh}.prompt`).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum PromptLanguage {
    #[default]
    En,
    Zh,
}

impl PromptLanguage {
    /// Resolve from a locale tag ("en", "zh", "zh-CN", ...); anything not
    /// starting with "zh" maps to English.
    pub fn from_locale(locale: &str) -> Self {
        if locale.trim().to_lowercase().starts_with("zh") {
            Self::Zh
        } else {
            Self::En
        }
    }

    /// Pick one of two bundled texts by language.
    pub fn pick(self, en: &'static str, zh: &'static str) -> &'static str {
        match self {
            Self::En => en,
            Self::Zh => zh,
        }
    }
}

/// The prompt sections bundled for one (provider, language) pair. The
/// `system/{lang}.prompt` header is a rust-fmt template taking the other
/// three as `{constraint_system}` / `{constraint_provider}` /
/// `{appendix_provider}` args, so wrappers (section headers, "must be
/// followed" notes) live in the template while the content lives in the
/// per-scope files.
struct PromptBundle {
    constraint_system: &'static str,
    constraint_provider: &'static str,
    appendix_provider: &'static str,
}

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

    /// Directory name under `prompt/constraint/provider/` and
    /// `prompt/appendix/provider/` holding this provider's prompt files.
    pub fn prompt_dir(&self) -> &'static str {
        match self {
            Self::OpenAiCompatible => "openai",
            Self::Anthropic => "anthropic",
            Self::DeepSeek => "deepseek",
        }
    }

    fn prompt_bundle(&self, language: PromptLanguage) -> PromptBundle {
        use PromptLanguage::{En, Zh};
        match (*self, language) {
            (Self::OpenAiCompatible, En) => PromptBundle {
                constraint_system: include_str!("../../prompt/constraint/system/en.prompt"),
                constraint_provider: include_str!(
                    "../../prompt/constraint/provider/openai/en.prompt"
                ),
                appendix_provider: include_str!("../../prompt/appendix/provider/openai/en.prompt"),
            },
            (Self::OpenAiCompatible, Zh) => PromptBundle {
                constraint_system: include_str!("../../prompt/constraint/system/zh.prompt"),
                constraint_provider: include_str!(
                    "../../prompt/constraint/provider/openai/zh.prompt"
                ),
                appendix_provider: include_str!("../../prompt/appendix/provider/openai/zh.prompt"),
            },
            (Self::Anthropic, En) => PromptBundle {
                constraint_system: include_str!("../../prompt/constraint/system/en.prompt"),
                constraint_provider: include_str!(
                    "../../prompt/constraint/provider/anthropic/en.prompt"
                ),
                appendix_provider: include_str!(
                    "../../prompt/appendix/provider/anthropic/en.prompt"
                ),
            },
            (Self::Anthropic, Zh) => PromptBundle {
                constraint_system: include_str!("../../prompt/constraint/system/zh.prompt"),
                constraint_provider: include_str!(
                    "../../prompt/constraint/provider/anthropic/zh.prompt"
                ),
                appendix_provider: include_str!(
                    "../../prompt/appendix/provider/anthropic/zh.prompt"
                ),
            },
            (Self::DeepSeek, En) => PromptBundle {
                constraint_system: include_str!("../../prompt/constraint/system/en.prompt"),
                constraint_provider: include_str!(
                    "../../prompt/constraint/provider/deepseek/en.prompt"
                ),
                appendix_provider: include_str!(
                    "../../prompt/appendix/provider/deepseek/en.prompt"
                ),
            },
            (Self::DeepSeek, Zh) => PromptBundle {
                constraint_system: include_str!("../../prompt/constraint/system/zh.prompt"),
                constraint_provider: include_str!(
                    "../../prompt/constraint/provider/deepseek/zh.prompt"
                ),
                appendix_provider: include_str!(
                    "../../prompt/appendix/provider/deepseek/zh.prompt"
                ),
            },
        }
    }
}

#[derive(Debug, Clone)]
pub struct ChatProviderConfig {
    pub provider: ChatProviderKind,
    pub api_key: String,
    pub base_url: String,
    pub model: String,
    /// Language of the bundled prompt files; see [`PromptLanguage`].
    pub language: PromptLanguage,
    /// Extra system-prompt sections appended after the rendered bundled
    /// prompt; blank adds nothing.
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
            language: PromptLanguage::default(),
            system_prompt: String::new(),
            max_turns: DEFAULT_MAX_TURNS,
        };
        config.validate()?;
        Ok(config)
    }

    /// Select the language of the bundled prompt files.
    pub fn with_language(mut self, language: PromptLanguage) -> Self {
        self.language = language;
        self
    }

    /// Add extra system-prompt sections appended after the rendered bundled
    /// prompt. Empty or whitespace-only prompts are ignored.
    pub fn with_system_prompt(mut self, system_prompt: impl Into<String>) -> Self {
        let prompt = system_prompt.into();
        if !prompt.trim().is_empty() {
            self.system_prompt = prompt.trim().to_string();
        }
        self
    }

    /// The full system prompt: the bundled `system/{lang}.prompt` rust-fmt
    /// template rendered with the shared and provider-specific sections,
    /// plus the configured extra sections appended last.
    pub fn full_system_prompt(&self) -> String {
        let bundle = self.provider.prompt_bundle(self.language);
        let constraint_system = bundle.constraint_system.trim();
        let constraint_provider = bundle.constraint_provider.trim();
        let appendix_provider = bundle.appendix_provider.trim();
        let rendered = match self.language {
            PromptLanguage::En => format!(
                include_str!("../../prompt/system/en.prompt"),
                constraint_system = constraint_system,
                constraint_provider = constraint_provider,
                appendix_provider = appendix_provider,
            ),
            PromptLanguage::Zh => format!(
                include_str!("../../prompt/system/zh.prompt"),
                constraint_system = constraint_system,
                constraint_provider = constraint_provider,
                appendix_provider = appendix_provider,
            ),
        };
        let mut prompt = rendered.trim_end().to_string();
        if !self.system_prompt.is_empty() {
            prompt.push_str("\n\n");
            prompt.push_str(&self.system_prompt);
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
