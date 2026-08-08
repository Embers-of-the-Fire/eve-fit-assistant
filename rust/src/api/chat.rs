use std::collections::HashMap;
use std::sync::{Arc, Mutex, MutexGuard};

use efa_chat::Message;
use efa_chat::agent::ChatAgent;
use efa_chat::config::{ChatProviderConfig, ChatProviderKind, PromptLanguage};
use efa_chat::event::ChatEvent;
use efa_chat::fit::{ActiveFit, FitCallbacks};
use efa_chat::manual::{ManualCorpus, ManualDocText};
use flutter_rust_bridge::DartFnFuture;
use flutter_rust_bridge::frb;

use crate::api::server::FitEngineData;
use crate::api::storage::FitStorage;
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
    /// Locale tag ("en", "zh", ...) selecting the language of the bundled
    /// prompt files; unrecognized tags fall back to English.
    pub language: String,
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
    /// The tool call with this `id` finished (a result was committed);
    /// `result` is the textual tool output returned to the model.
    ToolCallEnd {
        id: String,
        result: String,
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

/// Newtype asserting `Send + Sync` for a wrapped value.
///
/// flutter_rust_bridge Dart closures route every call through message ports
/// and are designed to be invoked from any thread, yet their generated Rust
/// type implements neither `Send` nor `Sync`. The fit tools store these
/// callbacks in a shared context that the rig runtime accesses from its
/// worker threads, so both markers are asserted here.
///
/// The [`ThreadSafeFn::call`]/[`ThreadSafeFn::call_with`]/
/// [`ThreadSafeFn::call_with_search`] accessors matter: a closure that
/// invokes them captures the *whole* wrapper (which is `Send + Sync`),
/// whereas inlining `(wrapper.0)(...)` would make Rust capture only the
/// non-`Send` inner field.
///
/// SAFETY: the wrapped value is only ever a flutter_rust_bridge Dart closure
/// (see [`ChatSession::set_fit_callbacks`]), whose invocation is thread-safe
/// by construction.
struct ThreadSafeFn<F>(F);

// SAFETY: see the doc comment on [`ThreadSafeFn`].
unsafe impl<F> Send for ThreadSafeFn<F> {}
unsafe impl<F> Sync for ThreadSafeFn<F> {}

impl<F> ThreadSafeFn<F> {
    fn call(&self) -> efa_chat::fit::FitToolFuture
    where
        F: Fn() -> efa_chat::fit::FitToolFuture,
    {
        (self.0)()
    }

    fn call_with(&self, arg: String) -> efa_chat::fit::FitToolFuture
    where
        F: Fn(String) -> efa_chat::fit::FitToolFuture,
    {
        (self.0)(arg)
    }

    fn call_with_search(
        &self,
        query: String,
        language: Option<String>,
    ) -> efa_chat::fit::FitToolFuture
    where
        F: Fn(String, Option<String>) -> efa_chat::fit::FitToolFuture,
    {
        (self.0)(query, language)
    }
}

/// Wrap the three FRB Dart closures into the shared [`FitCallbacks`].
fn build_fit_callbacks(
    search_items: impl Fn(String, Option<String>) -> DartFnFuture<String> + 'static,
    list_fits: impl Fn() -> DartFnFuture<String> + 'static,
    load_fit: impl Fn(String) -> DartFnFuture<String> + 'static,
) -> FitCallbacks {
    let search_items = ThreadSafeFn(search_items);
    let list_fits = ThreadSafeFn(list_fits);
    let load_fit = ThreadSafeFn(load_fit);
    FitCallbacks {
        search_items: Arc::new(move |query, language| {
            search_items.call_with_search(query, language)
        }),
        list_fits: Arc::new(move || list_fits.call()),
        load_fit: Arc::new(move |fit_id| load_fit.call_with(fit_id)),
    }
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
        .with_system_prompt(config.system_prompt)
        .with_language(PromptLanguage::from_locale(&config.language));
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

    /// Attach the fitting engine (via [`FitEngineData::share`]), exposing the
    /// fit tools (`get_current_fit`, `get_fit_stats`, `get_item`, `get_attr`,
    /// `validate_fit`) to the model.
    #[frb(sync)]
    pub fn set_fit_engine(&self, engine: FitEngineData) {
        self.lock_agent().set_fit_engine(engine.database().clone());
    }

    /// Detach the fitting engine and any attached fit, hiding the fit tools.
    #[frb(sync)]
    pub fn clear_fit_engine(&self) {
        self.lock_agent().clear_fit_engine();
    }

    /// Update the dogma-attribute name lookup (attribute id → attribute name,
    /// e.g. `263 -> "shieldCapacity"`) used by the `get_attr`/`get_item` tools.
    #[frb(sync)]
    pub fn set_attribute_names(&self, names: HashMap<i32, String>) {
        self.lock_agent().set_attribute_names(names);
    }

    /// Attach the fit the fit tools operate on. `names` maps every referenced
    /// type id (ship, modules, charges, drones, implants, boosters, skills)
    /// to its display name.
    #[frb(sync)]
    pub fn set_fit_context(
        &self,
        name: Option<String>,
        fit: FitStorage,
        names: HashMap<i32, String>,
    ) {
        self.lock_agent().set_active_fit(Some(ActiveFit {
            name,
            container: fit.into_container(),
            names,
        }));
    }

    /// Detach the current fit; fit tools will report that no fit is attached.
    #[frb(sync)]
    pub fn clear_fit_context(&self) {
        self.lock_agent().set_active_fit(None);
    }

    /// Register the app-provided callbacks backing the app-state fit tools
    /// (`search_items`, `list_user_fits`, `load_fit`). Each callback returns
    /// a JSON string; `load_fit` must return the fit payload JSON described
    /// by the chat crate's fit schema (or `{"error": ...}`). `search_items`
    /// receives the query plus an optional localization language code
    /// (`None` defers to the app's display language).
    ///
    /// Deliberately `#[frb(sync)]` with bare `impl Fn(...) -> DartFnFuture<...>`
    /// parameters: that shape is what flutter_rust_bridge recognizes as a Dart
    /// closure, and running synchronously keeps FRB from moving the (not
    /// `Send`) closure onto its thread pool. The closures are only *stored*
    /// here, wrapped in [`ThreadSafeFn`] for the shared tool context.
    #[frb(sync)]
    pub fn set_fit_callbacks(
        &self,
        search_items: impl Fn(String, Option<String>) -> DartFnFuture<String> + 'static,
        list_fits: impl Fn() -> DartFnFuture<String> + 'static,
        load_fit: impl Fn(String) -> DartFnFuture<String> + 'static,
    ) {
        let callbacks = build_fit_callbacks(search_items, list_fits, load_fit);
        self.lock_agent().set_fit_callbacks(callbacks);
    }

    /// One-shot completion turn (used for connection tests).
    ///
    /// Deliberately a *normal* FRB function: it blocks a thread-pool thread on
    /// the efa-chat tokio runtime, keeping rig/reqwest off FRB's executor. The
    /// agent lock is held only to prepare and commit, never across the turn,
    /// so a concurrent `#[frb(sync)]` session call never blocks the Dart
    /// isolate on an in-flight turn (which would also deadlock any fit tool
    /// that calls back into Dart mid-turn).
    #[frb]
    pub fn prompt(&self, text: String) -> anyhow::Result<String> {
        let prepared = self.lock_agent().prepare_turn()?;
        let (output, messages) = efa_chat::runtime().block_on(prepared.chat(&text))?;
        self.lock_agent().commit_chat_turn(messages);
        Ok(output)
    }

    /// Streaming completion turn; deltas are pushed to [sink].
    ///
    /// Errors are reported as [`ChatStreamEvent::Error`] events rather than a
    /// failed future so the Dart side has a single error channel. The agent
    /// lock is held only to prepare and commit, never across the turn (see
    /// [`ChatSession::prompt`]).
    #[frb]
    pub fn stream_prompt(&self, sink: StreamSink<ChatStreamEvent>, text: String) {
        let prepared = match self.lock_agent().prepare_turn() {
            Ok(prepared) => prepared,
            Err(e) => {
                let _ = sink.add(ChatStreamEvent::Error {
                    message: e.to_string(),
                });
                return;
            }
        };
        let result = efa_chat::runtime().block_on(prepared.stream(&text, |event| {
            let mapped = match event {
                ChatEvent::TextDelta(text) => ChatStreamEvent::TextDelta { text },
                ChatEvent::ToolCallStart { id, name } => {
                    ChatStreamEvent::ToolCallStart { id, name }
                }
                ChatEvent::ToolCallArgsDelta { id, delta } => {
                    ChatStreamEvent::ToolCallArgsDelta { id, delta }
                }
                ChatEvent::ToolCallEnd { id, result } => {
                    ChatStreamEvent::ToolCallEnd { id, result }
                }
                ChatEvent::Done(full_text) => ChatStreamEvent::Done { full_text },
                ChatEvent::Error(message) => ChatStreamEvent::Error { message },
            };
            let _ = sink.add(mapped);
        }));
        if let Ok(accumulated) = result {
            self.lock_agent().commit_stream_turn(&text, &accumulated);
        }
    }
}
