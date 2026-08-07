use std::sync::{Mutex, MutexGuard};

use efa_chat::Message;
use efa_chat::agent::ChatAgent;
use efa_chat::config::{ChatProviderConfig, ChatProviderKind};
use efa_chat::event::ChatEvent;
use efa_chat::manual::{ManualCorpus, ManualDocText};
use flutter_rust_bridge::frb;

use crate::frb_generated::StreamSink;

/// The chat completion provider backing a session.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ChatProvider {
    /// Any endpoint speaking the OpenAI Chat Completions API (OpenAI,
    /// OpenRouter, vLLM, Ollama, ...).
    OpenAiCompatible,
    Anthropic,
    DeepSeek,
}

impl From<ChatProvider> for ChatProviderKind {
    fn from(provider: ChatProvider) -> Self {
        match provider {
            ChatProvider::OpenAiCompatible => ChatProviderKind::OpenAiCompatible,
            ChatProvider::Anthropic => ChatProviderKind::Anthropic,
            ChatProvider::DeepSeek => ChatProviderKind::DeepSeek,
        }
    }
}

/// User-facing configuration for the chat provider. A blank `base_url`
/// selects the provider's default endpoint.
pub struct ChatConfig {
    pub provider: ChatProvider,
    pub api_key: String,
    pub base_url: String,
    pub model: String,
    /// Extra system-prompt sections (e.g. the in-app link manifest), appended
    /// after the bundled base prompt; empty uses only the bundled prompt.
    pub system_prompt: String,
}

pub enum ChatRole {
    User,
    Assistant,
}

/// A single persisted conversation turn, used to seed session history when a
/// stored conversation is resumed.
pub struct ChatHistoryMessage {
    pub role: ChatRole,
    pub content: String,
}

/// One localization of a user-manual page, used to build the in-session
/// manual search corpus. Rows sharing the same `id` are grouped into a
/// single multi-lingual document.
pub struct ChatManualDoc {
    /// Path-joined doc id, e.g. `fitting/modules`.
    pub id: String,
    pub locale: String,
    pub title: String,
    pub summary: String,
    pub body: String,
}

/// Events forwarded over the [`StreamSink`] during a streaming turn.
pub enum ChatStreamEvent {
    TextDelta {
        text: String,
    },
    /// A new tool call started; `id` correlates the args deltas and the end
    /// event for this call.
    ToolCallStart {
        id: String,
        name: String,
    },
    /// Partial JSON argument data for the tool call with this `id`.
    ToolCallArgsDelta {
        id: String,
        delta: String,
    },
    /// The tool call with this `id` finished (a result was committed).
    ToolCallEnd {
        id: String,
    },
    Done {
        full_text: String,
    },
    Error {
        message: String,
    },
}

/// A model exposed by the provider, with optional owner metadata for display.
pub struct ChatModelInfo {
    pub id: String,
    pub owned_by: Option<String>,
}

/// Fetch the model list exposed by the provider, used to populate the
/// predefined model choices. A blank `base_url` selects the provider's
/// default endpoint.
#[frb]
pub fn list_available_models(
    provider: ChatProvider,
    api_key: String,
    base_url: String,
) -> anyhow::Result<Vec<ChatModelInfo>> {
    let models = efa_chat::runtime().block_on(efa_chat::models::list_models(
        provider.into(),
        &api_key,
        &base_url,
    ))?;
    Ok(models
        .into_iter()
        .map(|m| ChatModelInfo {
            id: m.id,
            owned_by: m.owned_by,
        })
        .collect())
}

pub struct ChatSession {
    agent: Mutex<ChatAgent>,
}

impl ChatSession {
    fn lock_agent(&self) -> MutexGuard<'_, ChatAgent> {
        self.agent.lock().unwrap_or_else(|e| e.into_inner())
    }

    #[frb(sync)]
    pub fn create(config: ChatConfig) -> anyhow::Result<Self> {
        let config = ChatProviderConfig::new(
            config.provider.into(),
            config.api_key,
            config.base_url,
            config.model,
        )?
        .with_system_prompt(config.system_prompt);
        Ok(Self {
            agent: Mutex::new(ChatAgent::new(config)?),
        })
    }

    /// Switch the completion model, keeping the conversation history.
    #[frb(sync)]
    pub fn set_model(&self, model: String) {
        self.lock_agent().set_model(model);
    }

    /// Seed the session history from a persisted conversation.
    #[frb(sync)]
    pub fn restore_history(&self, history: Vec<ChatHistoryMessage>) {
        let history = history
            .into_iter()
            .map(|m| match m.role {
                ChatRole::User => Message::user(m.content),
                ChatRole::Assistant => Message::assistant(m.content),
            })
            .collect();
        self.lock_agent().restore_history(history);
    }

    #[frb(sync)]
    pub fn clear_history(&self) {
        self.lock_agent().clear_history();
    }

    /// Load the bundled user-manual corpus, exposing the `search_manual` and
    /// `get_manual_doc` tools to the model. Passing an empty list detaches
    /// the tools.
    #[frb(sync)]
    pub fn set_manual_docs(&self, docs: Vec<ChatManualDoc>) {
        let rows = docs
            .into_iter()
            .map(|doc| {
                (
                    doc.id,
                    ManualDocText {
                        locale: doc.locale,
                        title: doc.title,
                        summary: doc.summary,
                        body: doc.body,
                    },
                )
            })
            .collect();
        self.lock_agent()
            .set_manual_corpus(ManualCorpus::from_rows(rows));
    }

    /// One-shot completion turn (used for connection tests).
    ///
    /// Deliberately a *normal* FRB function: it blocks a thread-pool thread on
    /// the efa-chat tokio runtime, keeping rig/reqwest off FRB's executor.
    #[frb]
    pub fn prompt(&self, text: String) -> anyhow::Result<String> {
        let mut agent = self.lock_agent();
        Ok(efa_chat::runtime().block_on(agent.chat_turn(&text))?)
    }

    /// Streaming completion turn; deltas are pushed to [sink].
    ///
    /// Errors are reported as [`ChatStreamEvent::Error`] events rather than a
    /// failed future so the Dart side has a single error channel.
    #[frb]
    pub fn stream_prompt(&self, sink: StreamSink<ChatStreamEvent>, text: String) {
        let mut agent = self.lock_agent();
        let _ = efa_chat::runtime().block_on(agent.stream_turn(&text, |event| {
            let mapped = match event {
                ChatEvent::TextDelta(text) => ChatStreamEvent::TextDelta { text },
                ChatEvent::ToolCallStart { id, name } => {
                    ChatStreamEvent::ToolCallStart { id, name }
                }
                ChatEvent::ToolCallArgsDelta { id, delta } => {
                    ChatStreamEvent::ToolCallArgsDelta { id, delta }
                }
                ChatEvent::ToolCallEnd { id } => ChatStreamEvent::ToolCallEnd { id },
                ChatEvent::Done(full_text) => ChatStreamEvent::Done { full_text },
                ChatEvent::Error(message) => ChatStreamEvent::Error { message },
            };
            let _ = sink.add(mapped);
        }));
    }
}
