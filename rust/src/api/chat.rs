use std::sync::{Mutex, MutexGuard};

use efa_chat::Message;
use efa_chat::agent::ChatAgent;
use efa_chat::config::ChatProviderConfig;
use efa_chat::event::ChatEvent;
use flutter_rust_bridge::frb;

use crate::frb_generated::StreamSink;

/// User-facing configuration for the OpenAI-compatible chat provider.
pub struct ChatConfig {
    pub api_key: String,
    pub base_url: String,
    pub model: String,
    /// System prompt for the session; empty falls back to the crate default.
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

/// Events forwarded over the [`StreamSink`] during a streaming turn.
pub enum ChatStreamEvent {
    TextDelta { text: String },
    Done { full_text: String },
    Error { message: String },
}

/// A model exposed by the provider, with optional owner metadata for display.
pub struct ChatModelInfo {
    pub id: String,
    pub owned_by: Option<String>,
}

/// Fetch the model list exposed by the provider (`GET {base_url}/models`),
/// used to populate the predefined model choices.
#[frb]
pub fn list_available_models(
    api_key: String,
    base_url: String,
) -> anyhow::Result<Vec<ChatModelInfo>> {
    let models =
        efa_chat::runtime().block_on(efa_chat::models::list_models(&api_key, &base_url))?;
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
        let config = ChatProviderConfig::new(config.api_key, config.base_url, config.model)?
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
                ChatEvent::Done(full_text) => ChatStreamEvent::Done { full_text },
                ChatEvent::Error(message) => ChatStreamEvent::Error { message },
            };
            let _ = sink.add(mapped);
        }));
    }
}
