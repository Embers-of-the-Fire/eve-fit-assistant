use std::collections::HashMap;
use std::future::Future;
use std::sync::atomic::{AtomicI32, Ordering};
use std::sync::{Arc, Mutex, MutexGuard};

use efa_chat::Message;
use efa_chat::core::agent::ChatAgent;
use efa_chat::core::config::{
    ChatProviderConfig, ChatProviderKind, PromptLanguage, ProxyConfig, ProxyRouting,
};
use efa_chat::core::event::ChatEvent;
use efa_chat::tools::fit::{ActiveFit, FitCallbacks, FitToolFuture};
use efa_chat::tools::manual::{ManualCorpus, ManualDocText};
use flutter_rust_bridge::frb;
use futures::channel::oneshot;

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

/// How the chat endpoint is reached, resolved by the Dart host from the
/// desktop system proxy settings (see `chatProxyRoutingFor` in
/// `lib/features/chat/provider.dart`). Ignored on web, where the browser
/// applies its own proxy.
pub enum ChatProxyRouting {
    /// No host-side routing decision: keep reqwest's default client, which
    /// honors the standard proxy environment variables.
    SystemDefault,
    /// The host resolved a proxy bypass for the endpoint: connect directly,
    /// ignoring any proxy environment variables the default client would
    /// otherwise pick up.
    Direct,
    /// A system proxy covers the endpoint. Carries the full per-scheme
    /// proxy URLs and the bypass list (not just the proxy resolved for the
    /// initial URL) so the reqwest client re-resolves the routing for every
    /// request: reqwest follows redirects inside the client, and a redirect
    /// to a bypassed host must go direct while a cross-scheme redirect must
    /// pick up that scheme's proxy.
    Proxy {
        /// Proxy URL for `http://` request URLs, if configured.
        http_url: Option<String>,
        /// Proxy URL for `https://` request URLs, if configured.
        https_url: Option<String>,
        /// Fallback proxy URL covering both schemes, if configured.
        all_url: Option<String>,
        /// Hosts reached directly (`no_proxy` / GNOME `ignore-hosts`
        /// formats).
        bypass: Vec<String>,
    },
}

impl From<ChatProxyRouting> for ProxyRouting {
    fn from(routing: ChatProxyRouting) -> Self {
        match routing {
            ChatProxyRouting::SystemDefault => ProxyRouting::Default,
            ChatProxyRouting::Direct => ProxyRouting::Direct,
            ChatProxyRouting::Proxy {
                http_url,
                https_url,
                all_url,
                bypass,
            } => ProxyRouting::Proxy(ProxyConfig {
                http: http_url,
                https: https_url,
                all: all_url,
                bypass,
            }),
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
    /// Proxy routing resolved by the Dart host from the desktop system proxy
    /// settings. A bypassed endpoint must arrive as
    /// [`ChatProxyRouting::Direct`] (not `SystemDefault`) so reqwest does not
    /// fall back to the proxy environment variables. Ignored on web.
    pub proxy: ChatProxyRouting,
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

/// A request pushed from an app-state fit tool (`search_items`,
/// `list_user_fits`, `load_fit`, `create_fit`, `apply_fit_edit`) to the Dart
/// host over the session's callback channel (see
/// [`ChatSession::open_callback_channel`]). Dart answers through
/// [`ChatSession::deliver_callback_result`], keyed by `call_id`.
pub enum ChatCallbackRequest {
    /// `search_items(query, language, kind)` — see the chat crate's
    /// `FitCallbacks::search_items` for the argument contract.
    SearchItems {
        call_id: i32,
        query: String,
        language: Option<String>,
        kind: Option<String>,
    },
    /// `list_user_fits()`.
    ListFits { call_id: i32 },
    /// `load_fit(fit_id)`.
    LoadFit { call_id: i32, fit_id: String },
    /// `create_fit(ship_id, name, description)`.
    CreateFit {
        call_id: i32,
        ship_id: i32,
        name: String,
        description: Option<String>,
    },
    /// `apply_fit_edit(ops_json)` — `ops_json` is the serialized list of
    /// validated `FitEditOp`s to persist onto the attached fit.
    ApplyFitEdit { call_id: i32, ops_json: String },
}

/// Host-callback plumbing for the app-state fit tools.
///
/// flutter_rust_bridge Dart closures (DartFn) do not work on dart2wasm: the
/// invoke message crosses a `BroadcastChannel` as a raw `JSValue`, which
/// FRB's Dart-side port manager cannot decode (it expects a `List<dynamic>`
/// and only dart2js auto-converts), crashing the port listener and hanging
/// the tool future. The bridge therefore runs its own request/response
/// channel built from primitives that work on every platform: a
/// [`StreamSink`] carries [`ChatCallbackRequest`]s to Dart, and
/// [`ChatSession::deliver_callback_result`] returns the JSON result.
struct CallbackRegistry {
    sink: Mutex<Option<StreamSink<ChatCallbackRequest>>>,
    pending: Mutex<HashMap<i32, oneshot::Sender<String>>>,
    next_call_id: AtomicI32,
}

impl CallbackRegistry {
    fn new() -> Self {
        Self {
            sink: Mutex::new(None),
            pending: Mutex::new(HashMap::new()),
            next_call_id: AtomicI32::new(1),
        }
    }

    fn lock_sink(&self) -> MutexGuard<'_, Option<StreamSink<ChatCallbackRequest>>> {
        self.sink.lock().unwrap_or_else(|e| e.into_inner())
    }

    fn lock_pending(&self) -> MutexGuard<'_, HashMap<i32, oneshot::Sender<String>>> {
        self.pending.lock().unwrap_or_else(|e| e.into_inner())
    }

    /// Post one callback request and return the future the fit tool awaits.
    /// Failures (no channel yet, closed channel, channel replaced) resolve
    /// to an error payload the model can read, never a hang.
    fn invoke(self: &Arc<Self>, request: impl FnOnce(i32) -> ChatCallbackRequest) -> FitToolFuture {
        const ERR_NO_CHANNEL: &str = "{\"error\":\"app callbacks are not registered\"}";
        const ERR_POST_FAILED: &str = "{\"error\":\"failed to reach the app\"}";
        const ERR_CHANNEL_CLOSED: &str = "{\"error\":\"callback channel closed\"}";

        // The sink lock is held across `add` (StreamSink is not Clone); it is
        // always the outer lock relative to `pending`, so no deadlock.
        let guard = self.lock_sink();
        let Some(sink) = guard.as_ref() else {
            return Box::pin(async move { ERR_NO_CHANNEL.to_string() });
        };
        let call_id = self.next_call_id.fetch_add(1, Ordering::Relaxed);
        let (sender, receiver) = oneshot::channel::<String>();
        self.lock_pending().insert(call_id, sender);
        if sink.add(request(call_id)).is_err() {
            self.lock_pending().remove(&call_id);
            return Box::pin(async move { ERR_POST_FAILED.to_string() });
        }
        Box::pin(async move {
            receiver
                .await
                .unwrap_or_else(|_| ERR_CHANNEL_CLOSED.to_string())
        })
    }

    /// Fail every outstanding request. Dropping a sender resolves its
    /// receiver with `Err(Canceled)`, which the parked tool future maps to
    /// the channel-closed payload; called when the channel is replaced, since
    /// requests posted on the previous sink are cancelled with it and will
    /// never be answered.
    fn fail_all(&self) {
        self.lock_pending().clear();
    }

    fn complete(&self, call_id: i32, result: String) {
        if let Some(sender) = self.lock_pending().remove(&call_id) {
            let _ = sender.send(result);
        }
    }
}

/// Build the [`FitCallbacks`] closures that route through [registry].
fn build_fit_callbacks(registry: &Arc<CallbackRegistry>) -> FitCallbacks {
    let search_items = registry.clone();
    let list_fits = registry.clone();
    let load_fit = registry.clone();
    let create_fit = registry.clone();
    let apply_fit_edit = registry.clone();
    FitCallbacks {
        search_items: Arc::new(move |query, language, kind| {
            search_items.invoke(|call_id| ChatCallbackRequest::SearchItems {
                call_id,
                query,
                language,
                kind,
            })
        }),
        list_fits: Arc::new(move || {
            list_fits.invoke(|call_id| ChatCallbackRequest::ListFits { call_id })
        }),
        load_fit: Arc::new(move |fit_id| {
            load_fit.invoke(|call_id| ChatCallbackRequest::LoadFit { call_id, fit_id })
        }),
        create_fit: Arc::new(move |ship_id, name, description| {
            create_fit.invoke(|call_id| ChatCallbackRequest::CreateFit {
                call_id,
                ship_id,
                name,
                description,
            })
        }),
        apply_fit_edit: Arc::new(move |ops_json| {
            apply_fit_edit.invoke(|call_id| ChatCallbackRequest::ApplyFitEdit { call_id, ops_json })
        }),
    }
}

/// Drives a chat turn future to completion.
///
/// On native targets the future runs on the efa-chat tokio runtime (rig /
/// reqwest need its reactor), spawned as a task so this `async` FRB function
/// never blocks its own executor thread. On wasm32 there is no runtime to
/// spawn onto: FRB executes async functions on the browser event loop, which
/// is exactly where reqwest's fetch-based futures resolve, so the future is
/// awaited directly. (`block_on` on wasm would deadlock: the promise
/// callbacks that resolve fetch futures can only run when the worker's event
/// loop turns.)
#[cfg(not(target_arch = "wasm32"))]
async fn drive_turn<F>(future: F) -> F::Output
where
    F: Future + Send + 'static,
    F::Output: Send + 'static,
{
    efa_chat::runtime()
        .spawn(future)
        .await
        .expect("efa-chat runtime task panicked")
}

/// See the native [`drive_turn`]; on wasm32 the future is awaited in place.
#[cfg(target_arch = "wasm32")]
async fn drive_turn<F: Future>(future: F) -> F::Output {
    future.await
}

/// Fetch the model list exposed by the provider, used to populate the
/// predefined model choices. A blank `base_url` selects the provider's
/// default endpoint. [proxy] is the proxy routing resolved by the Dart host
/// (see [`ChatConfig::proxy`]).
#[frb]
pub async fn list_available_models(
    provider: ChatProvider,
    api_key: String,
    base_url: String,
    proxy: ChatProxyRouting,
) -> anyhow::Result<Vec<ChatModelInfo>> {
    let routing = ProxyRouting::from(proxy);
    let models = drive_turn(async move {
        efa_chat::core::models::list_models(provider.into(), &api_key, &base_url, &routing).await
    })
    .await?;
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
    callbacks: Arc<CallbackRegistry>,
}

impl ChatSession {
    fn lock_agent(&self) -> MutexGuard<'_, ChatAgent> {
        self.agent.lock().unwrap_or_else(|e| e.into_inner())
    }

    #[frb(sync)]
    pub fn create(config: ChatConfig) -> anyhow::Result<Self> {
        let mut provider_config = ChatProviderConfig::new(
            config.provider.into(),
            config.api_key,
            config.base_url,
            config.model,
        )?
        .with_system_prompt(config.system_prompt)
        .with_language(PromptLanguage::from_locale(&config.language));
        provider_config.proxy = ProxyRouting::from(config.proxy);
        Ok(Self {
            agent: Mutex::new(ChatAgent::new(provider_config)?),
            callbacks: Arc::new(CallbackRegistry::new()),
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

    /// Open the session's host-callback channel: the app-state fit tools
    /// (`search_items`, `list_user_fits`, `load_fit`, `create_fit`,
    /// `apply_fit_edit`) push
    /// [`ChatCallbackRequest`]s to [sink], and Dart returns each result as a
    /// JSON string through [`ChatSession::deliver_callback_result`]. Opening
    /// the channel also (re)registers the callbacks on the agent.
    ///
    /// Deliberately *not* flutter_rust_bridge Dart closures (DartFn): those
    /// are delivered through FRB's handler port, whose dart2wasm receiver
    /// cannot decode the invoke message (see [`CallbackRegistry`]). A
    /// `StreamSink` plus explicit result delivery only uses primitives that
    /// work on every platform.
    #[frb]
    pub fn open_callback_channel(&self, sink: StreamSink<ChatCallbackRequest>) {
        // Replacing the sink orphans requests posted on the previous one:
        // Dart cancels that subscription when re-registering (see
        // `registerFitCallbacks`), so those requests are never dispatched or
        // delivered. Fail them while holding the sink lock — the same lock
        // `invoke` holds across post — so the parked tool futures resolve
        // instead of hanging the turn.
        let mut guard = self.callbacks.lock_sink();
        self.callbacks.fail_all();
        *guard = Some(sink);
        drop(guard);
        let callbacks = build_fit_callbacks(&self.callbacks);
        self.lock_agent().set_fit_callbacks(callbacks);
    }

    /// Deliver the JSON result of a [`ChatCallbackRequest`] back to the
    /// waiting fit tool. Unknown or stale call ids are ignored.
    ///
    /// Async so that, on web, the oneshot completing the parked tool future
    /// is signalled on the browser event loop — the same thread the turn
    /// future is suspended on.
    #[frb]
    pub async fn deliver_callback_result(&self, call_id: i32, result: String) {
        self.callbacks.complete(call_id, result);
    }

    /// One-shot completion turn (used for connection tests).
    ///
    /// The agent lock is held only to prepare and commit, never across the
    /// turn, so a concurrent `#[frb(sync)]` session call never blocks the
    /// Dart isolate on an in-flight turn (which would also deadlock any fit
    /// tool that calls back into Dart mid-turn). Turn execution goes through
    /// [`drive_turn`]: the efa-chat tokio runtime on native, a direct await
    /// on the browser event loop on web.
    #[frb]
    pub async fn prompt(&self, text: String) -> anyhow::Result<String> {
        let prepared = self.lock_agent().prepare_turn()?;
        let (output, messages) = drive_turn(async move { prepared.chat(&text).await }).await?;
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
    pub async fn stream_prompt(&self, sink: StreamSink<ChatStreamEvent>, text: String) {
        let prepared = match self.lock_agent().prepare_turn() {
            Ok(prepared) => prepared,
            Err(e) => {
                let _ = sink.add(ChatStreamEvent::Error {
                    message: e.to_string(),
                });
                return;
            }
        };
        let turn_text = text.clone();
        let result = drive_turn(async move {
            prepared
                .stream(&turn_text, |event| {
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
                })
                .await
        })
        .await;
        if let Ok(accumulated) = result {
            self.lock_agent().commit_stream_turn(&text, &accumulated);
        }
    }
}
