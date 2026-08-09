use std::collections::{HashMap, HashSet};
use std::sync::{Arc, RwLock};

use futures::StreamExt;
use rig::agent::Agent;
use rig::completion::CompletionModel;
use rig::message::{Message, ToolResultContent};
use rig::prelude::*;
use rig::providers::{anthropic, deepseek, openai};
use rig::streaming::{StreamedAssistantContent, StreamedUserContent, ToolCallDeltaContent};

use crate::core::config::{ChatProviderConfig, ChatProviderKind};
use crate::core::error::ChatError;
use crate::core::event::ChatEvent;
use crate::tools::fit::{ActiveFit, AttributeNames, FitCallbacks, FitToolContext};
use crate::tools::manual::{ManualCorpus, ManualDocTool, ManualSearchTool};

pub struct ChatAgent {
    config: ChatProviderConfig,
    history: Vec<Message>,
    manual_corpus: Option<Arc<ManualCorpus>>,
    fit_engine: Option<Arc<eve_fit_os::protobuf::Database>>,
    attr_names: Arc<AttributeNames>,
    active_fit: Arc<RwLock<Option<ActiveFit>>>,
    fit_callbacks: Option<Arc<FitCallbacks>>,
}

/// A per-turn agent for one of the supported providers (enum dispatch over
/// rig's statically-typed provider agents).
enum TurnAgent {
    OpenAiCompatible(Agent<openai::CompletionModel>),
    Anthropic(Agent<anthropic::completion::CompletionModel>),
    DeepSeek(Agent<deepseek::CompletionModel>),
}

impl ChatAgent {
    pub fn new(config: ChatProviderConfig) -> Result<Self, ChatError> {
        config.validate()?;
        Ok(Self {
            config,
            history: Vec::new(),
            manual_corpus: None,
            fit_engine: None,
            attr_names: Arc::new(AttributeNames::default()),
            active_fit: Arc::new(RwLock::new(None)),
            fit_callbacks: None,
        })
    }

    pub fn model(&self) -> &str {
        &self.config.model
    }

    pub fn set_model(&mut self, model: String) {
        self.config.model = model;
    }

    pub fn history(&self) -> &[Message] {
        &self.history
    }

    pub fn restore_history(&mut self, history: Vec<Message>) {
        self.history = history;
    }

    pub fn clear_history(&mut self) {
        self.history.clear();
    }

    /// Attach the bundled user-manual corpus, exposing the `search_manual`
    /// and `get_manual_doc` tools to the model on subsequent turns. Passing
    /// an empty corpus detaches the tools.
    pub fn set_manual_corpus(&mut self, corpus: ManualCorpus) {
        self.manual_corpus = if corpus.is_empty() {
            None
        } else {
            Some(Arc::new(corpus))
        };
    }

    /// Attach the fitting-engine database, exposing the fit tools
    /// (`get_current_fit`, `get_fit_stats`, `get_item`, `get_attr`,
    /// `validate_fit`) to the model on subsequent turns.
    pub fn set_fit_engine(&mut self, engine: Arc<eve_fit_os::protobuf::Database>) {
        self.fit_engine = Some(engine);
    }

    /// Detach the fitting engine and any attached fit, hiding the fit tools.
    pub fn clear_fit_engine(&mut self) {
        self.fit_engine = None;
        self.set_active_fit(None);
    }

    /// Update the dogma-attribute name lookup used by the `get_attr` and
    /// `get_item` tools; keyed by attribute id.
    pub fn set_attribute_names(&mut self, names: HashMap<i32, String>) {
        self.attr_names = Arc::new(AttributeNames::from_by_id(names));
    }

    /// Attach (or clear, with `None`) the fit the fit tools operate on.
    pub fn set_active_fit(&mut self, fit: Option<ActiveFit>) {
        let mut guard = self.active_fit.write().unwrap_or_else(|e| e.into_inner());
        *guard = fit;
    }

    /// Attach the app-provided callbacks backing the app-state fit tools
    /// (`search_items`, `list_user_fits`, `load_fit`).
    pub fn set_fit_callbacks(&mut self, callbacks: FitCallbacks) {
        self.fit_callbacks = Some(Arc::new(callbacks));
    }

    fn attach_tools<M>(&self, builder: rig::agent::AgentBuilder<M>) -> Agent<M>
    where
        M: CompletionModel + 'static,
    {
        let builder = builder.preamble(&self.config.full_system_prompt());
        // The static `.tool()` builder is type-state based and cannot be
        // conditional, so the fit toolset goes through the dynamic-tool path.
        let mut builder = match &self.fit_engine {
            Some(engine) => {
                let mut context = FitToolContext::new(
                    engine.clone(),
                    self.active_fit.clone(),
                    self.attr_names.clone(),
                )
                .with_language(self.config.language);
                if let Some(callbacks) = &self.fit_callbacks {
                    context = context.with_callbacks(callbacks.clone());
                }
                builder.dynamic_tools(
                    crate::tools::fit::tools::fit_tools(context)
                        .into_iter()
                        .map(rig::tool::DynamicTool::from)
                        .collect(),
                )
            }
            None => builder.dynamic_tools(vec![]),
        };
        if let Some(corpus) = &self.manual_corpus {
            builder = builder
                .tool(ManualSearchTool::new(corpus.clone(), self.config.language))
                .tool(ManualDocTool::new(corpus.clone(), self.config.language));
        }
        builder.build()
    }

    fn build_agent(&self) -> Result<TurnAgent, ChatError> {
        let base_url = self.config.resolved_base_url();
        let model = self.config.model.clone();
        let agent = match self.config.provider {
            ChatProviderKind::OpenAiCompatible => {
                let client = openai::CompletionsClient::builder()
                    .api_key(self.config.api_key.clone())
                    .base_url(base_url)
                    .build()
                    .map_err(|e| ChatError::Client(e.to_string()))?;
                TurnAgent::OpenAiCompatible(self.attach_tools(client.agent(model)))
            }
            ChatProviderKind::Anthropic => {
                let client = anthropic::Client::builder()
                    .api_key(self.config.api_key.clone())
                    .base_url(base_url)
                    .build()
                    .map_err(|e| ChatError::Client(e.to_string()))?;
                TurnAgent::Anthropic(self.attach_tools(client.agent(model)))
            }
            ChatProviderKind::DeepSeek => {
                let client = deepseek::Client::builder()
                    .api_key(self.config.api_key.clone())
                    .base_url(base_url)
                    .build()
                    .map_err(|e| ChatError::Client(e.to_string()))?;
                TurnAgent::DeepSeek(self.attach_tools(client.agent(model)))
            }
        };
        Ok(agent)
    }

    /// Snapshot everything a single turn needs (the per-turn agent, history
    /// and multi-turn depth) so it can run WITHOUT holding the session lock.
    /// Fast; callers should hold the session lock only for this call.
    pub fn prepare_turn(&self) -> Result<PreparedTurn, ChatError> {
        Ok(PreparedTurn {
            agent: self.build_agent()?,
            history: self.history.clone(),
            max_turns: self.config.max_turns,
        })
    }

    /// Commit a completed non-streaming turn's messages to history. Fast;
    /// callers should hold the session lock only for this call.
    pub fn commit_chat_turn(&mut self, messages: Option<Vec<Message>>) {
        if let Some(messages) = messages {
            self.history.extend(messages);
        }
    }

    /// Commit a completed streaming turn to history. Fast; callers should
    /// hold the session lock only for this call.
    pub fn commit_stream_turn(&mut self, prompt: &str, accumulated: &str) {
        self.history.push(Message::user(prompt));
        self.history.push(Message::assistant(accumulated));
    }
}

/// A single turn fully prepared from a [`ChatAgent`] snapshot. It owns
/// everything the turn needs, so it can run without holding the session lock;
/// only the outcome is committed back via [`ChatAgent::commit_chat_turn`] or
/// [`ChatAgent::commit_stream_turn`].
pub struct PreparedTurn {
    agent: TurnAgent,
    history: Vec<Message>,
    max_turns: usize,
}

impl PreparedTurn {
    /// Run one non-streaming turn. Returns the assistant output plus the
    /// turn's messages, to commit via [`ChatAgent::commit_chat_turn`].
    pub async fn chat(self, prompt: &str) -> Result<(String, Option<Vec<Message>>), ChatError> {
        let PreparedTurn {
            agent,
            history,
            max_turns,
        } = self;
        match &agent {
            TurnAgent::OpenAiCompatible(agent) => {
                drive_chat(agent, prompt, history, max_turns).await
            }
            TurnAgent::Anthropic(agent) => drive_chat(agent, prompt, history, max_turns).await,
            TurnAgent::DeepSeek(agent) => drive_chat(agent, prompt, history, max_turns).await,
        }
    }

    /// Run one streaming turn, reporting events through [on_event]. Emits
    /// [`ChatEvent::Done`] on success and returns the accumulated assistant
    /// text, to commit via [`ChatAgent::commit_stream_turn`].
    pub async fn stream(
        self,
        prompt: &str,
        mut on_event: impl FnMut(ChatEvent),
    ) -> Result<String, ChatError> {
        let PreparedTurn {
            agent,
            history,
            max_turns,
        } = self;
        let accumulated = match &agent {
            TurnAgent::OpenAiCompatible(agent) => {
                drive_stream(agent, prompt, history, max_turns, &mut on_event).await?
            }
            TurnAgent::Anthropic(agent) => {
                drive_stream(agent, prompt, history, max_turns, &mut on_event).await?
            }
            TurnAgent::DeepSeek(agent) => {
                drive_stream(agent, prompt, history, max_turns, &mut on_event).await?
            }
        };
        on_event(ChatEvent::Done(accumulated.clone()));
        Ok(accumulated)
    }
}

/// Drive one non-streaming turn (rig's `Chat::chat` with a configurable
/// multi-turn depth). Returns the assistant output plus the turn's messages;
/// the caller commits them to session history.
async fn drive_chat<M>(
    agent: &Agent<M>,
    prompt: &str,
    history: Vec<Message>,
    max_turns: usize,
) -> Result<(String, Option<Vec<Message>>), ChatError>
where
    M: CompletionModel + 'static,
{
    let response = agent
        .prompt(prompt.to_string())
        .history(history)
        .max_turns(max_turns)
        .extended_details()
        .await
        .map_err(|e| ChatError::Completion(e.to_string()))?;
    Ok((response.output, response.messages))
}

/// Drive one streaming turn, reporting text deltas and tool-call lifecycle
/// events through [on_event] and returning the accumulated assistant text.
async fn drive_stream<M>(
    agent: &Agent<M>,
    prompt: &str,
    history: Vec<Message>,
    max_turns: usize,
    on_event: &mut impl FnMut(ChatEvent),
) -> Result<String, ChatError>
where
    M: CompletionModel + 'static,
{
    let mut stream = agent
        .stream_chat(prompt.to_string(), history)
        .max_turns(max_turns)
        .await;
    let mut accumulated = String::new();
    // Tool calls already announced via `ToolCallStart`, so a later complete
    // `ToolCall` item for the same call is not reported twice.
    let mut announced_calls: HashSet<String> = HashSet::new();
    while let Some(item) = stream.next().await {
        match item {
            Ok(MultiTurnStreamItem::StreamAssistantItem(content)) => match content {
                StreamedAssistantContent::Text(text) => {
                    accumulated.push_str(&text.text);
                    on_event(ChatEvent::TextDelta(text.text));
                }
                StreamedAssistantContent::ToolCall {
                    tool_call,
                    internal_call_id,
                } => {
                    if announced_calls.insert(internal_call_id.clone()) {
                        on_event(ChatEvent::ToolCallStart {
                            id: internal_call_id.clone(),
                            name: tool_call.function.name,
                        });
                        on_event(ChatEvent::ToolCallArgsDelta {
                            id: internal_call_id,
                            delta: tool_call.function.arguments.to_string(),
                        });
                    }
                }
                StreamedAssistantContent::ToolCallDelta {
                    internal_call_id,
                    content,
                    ..
                } => match content {
                    ToolCallDeltaContent::Name(name) => {
                        if announced_calls.insert(internal_call_id.clone()) {
                            on_event(ChatEvent::ToolCallStart {
                                id: internal_call_id,
                                name,
                            });
                        }
                    }
                    ToolCallDeltaContent::Delta(delta) => {
                        on_event(ChatEvent::ToolCallArgsDelta {
                            id: internal_call_id,
                            delta,
                        });
                    }
                },
                _ => {}
            },
            Ok(MultiTurnStreamItem::StreamUserItem(StreamedUserContent::ToolResult {
                tool_result,
                internal_call_id,
            })) => {
                on_event(ChatEvent::ToolCallEnd {
                    id: internal_call_id,
                    result: tool_result_text(&tool_result.content),
                });
            }
            Ok(MultiTurnStreamItem::FinalResponse(_)) => break,
            Ok(_) => {}
            Err(e) => {
                on_event(ChatEvent::Error(e.to_string()));
                return Err(ChatError::Stream(e.to_string()));
            }
        }
    }
    Ok(accumulated)
}

/// Flatten a tool result's content items into displayable text: text items
/// are joined verbatim, JSON items serialized, and images skipped.
fn tool_result_text(content: &OneOrMany<ToolResultContent>) -> String {
    let mut out = String::new();
    for item in content.iter() {
        match item {
            ToolResultContent::Text(text) => {
                if !out.is_empty() {
                    out.push('\n');
                }
                out.push_str(&text.text);
            }
            ToolResultContent::Json { value } => {
                if !out.is_empty() {
                    out.push('\n');
                }
                out.push_str(&value.to_string());
            }
            ToolResultContent::Image(_) => {}
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::core::config::DEFAULT_BASE_URL;

    fn test_config() -> ChatProviderConfig {
        ChatProviderConfig::new(
            ChatProviderKind::OpenAiCompatible,
            "test-key",
            DEFAULT_BASE_URL,
            "gpt-4o-mini",
        )
        .unwrap()
    }

    #[test]
    fn builds_with_default_base_url() {
        let agent = ChatAgent::new(test_config()).unwrap();
        assert_eq!(agent.model(), "gpt-4o-mini");
        assert!(agent.history().is_empty());
    }

    #[test]
    fn builds_for_every_provider() {
        for provider in [
            ChatProviderKind::OpenAiCompatible,
            ChatProviderKind::Anthropic,
            ChatProviderKind::DeepSeek,
        ] {
            let config = ChatProviderConfig::new(provider, "test-key", "", "some-model").unwrap();
            let agent = ChatAgent::new(config).unwrap();
            assert!(agent.build_agent().is_ok());
        }
    }

    #[test]
    fn blank_base_url_resolves_to_provider_default() {
        let config =
            ChatProviderConfig::new(ChatProviderKind::Anthropic, "key", "  ", "claude").unwrap();
        assert_eq!(
            config.resolved_base_url(),
            crate::core::config::ANTHROPIC_BASE_URL
        );
        let config =
            ChatProviderConfig::new(ChatProviderKind::DeepSeek, "key", "", "deepseek-chat")
                .unwrap();
        assert_eq!(
            config.resolved_base_url(),
            crate::core::config::DEEPSEEK_BASE_URL
        );
        let config = ChatProviderConfig::new(
            ChatProviderKind::OpenAiCompatible,
            "key",
            "http://localhost:11434/v1/",
            "llama3",
        )
        .unwrap();
        assert_eq!(config.resolved_base_url(), "http://localhost:11434/v1");
    }

    #[test]
    fn builds_with_custom_base_url() {
        let config = ChatProviderConfig::new(
            ChatProviderKind::OpenAiCompatible,
            "test-key",
            "http://localhost:11434/v1",
            "llama3",
        )
        .unwrap();
        assert!(ChatAgent::new(config).is_ok());
    }

    #[test]
    fn rejects_empty_api_key() {
        assert!(
            ChatProviderConfig::new(
                ChatProviderKind::OpenAiCompatible,
                "",
                DEFAULT_BASE_URL,
                "gpt-4o-mini",
            )
            .is_err()
        );
    }

    #[test]
    fn rejects_empty_model() {
        assert!(
            ChatProviderConfig::new(
                ChatProviderKind::OpenAiCompatible,
                "test-key",
                DEFAULT_BASE_URL,
                "",
            )
            .is_err()
        );
    }

    #[test]
    fn set_model_keeps_history() {
        let mut agent = ChatAgent::new(test_config()).unwrap();
        agent.restore_history(vec![Message::user("hi"), Message::assistant("hello")]);
        agent.set_model("gpt-4o".into());
        assert_eq!(agent.model(), "gpt-4o");
        assert_eq!(agent.history().len(), 2);
    }

    #[test]
    fn restore_and_clear_history() {
        let mut agent = ChatAgent::new(test_config()).unwrap();
        agent.restore_history(vec![Message::user("a"), Message::assistant("b")]);
        assert_eq!(agent.history().len(), 2);
        agent.clear_history();
        assert!(agent.history().is_empty());
    }

    #[test]
    fn prepare_turn_snapshots_without_touching_history() {
        let mut agent = ChatAgent::new(test_config()).unwrap();
        agent.restore_history(vec![Message::user("a")]);
        // Preparing must not mutate history; the prepared turn owns a snapshot.
        agent.prepare_turn().unwrap();
        assert_eq!(agent.history().len(), 1);
    }

    #[test]
    fn commit_stream_turn_appends_user_and_assistant() {
        let mut agent = ChatAgent::new(test_config()).unwrap();
        agent.commit_stream_turn("hello", "world");
        assert_eq!(agent.history().len(), 2);
    }

    #[test]
    fn commit_chat_turn_extends_with_returned_messages() {
        let mut agent = ChatAgent::new(test_config()).unwrap();
        agent.commit_chat_turn(Some(vec![Message::user("a"), Message::assistant("b")]));
        assert_eq!(agent.history().len(), 2);
        // `None` (a provider that returned no message list) commits nothing.
        agent.commit_chat_turn(None);
        assert_eq!(agent.history().len(), 2);
    }

    #[test]
    fn custom_system_prompt_is_appended_to_base() {
        let config = test_config().with_system_prompt("custom prompt");
        let full = config.full_system_prompt();
        assert!(full.starts_with("You are a helpful assistant"));
        assert!(full.ends_with("custom prompt"));
    }

    #[test]
    fn blank_system_prompt_keeps_base_only() {
        let config = test_config().with_system_prompt("   ");
        assert!(!config.full_system_prompt().ends_with("   "));
    }

    #[test]
    fn base_prompt_covers_persona_and_manual_tools() {
        let base = test_config().full_system_prompt();
        assert!(base.contains("EVE Fit Assistant"));
        assert!(base.contains("search_manual"));
        assert!(base.contains("get_manual_doc"));
    }

    #[test]
    fn base_prompt_wraps_sections_in_constraint_and_appendix_headers() {
        let base = test_config().full_system_prompt();
        let constraint = base.find("## Constraint").unwrap();
        let system = base.find("Never fabricate").unwrap();
        let provider = base.find("OpenAI-compatible").unwrap();
        let appendix = base.find("## Appendix").unwrap();
        assert!(constraint < system);
        assert!(system < provider);
        assert!(provider < appendix);
    }

    #[test]
    fn zh_language_renders_zh_template_and_sections() {
        let config = test_config().with_language(crate::core::config::PromptLanguage::Zh);
        let full = config.full_system_prompt();
        assert!(full.contains("## 约束"));
        assert!(full.contains("## 附录"));
        assert!(full.contains("不要编造"));
    }

    #[test]
    fn prompt_language_resolves_from_locale_tags() {
        use crate::core::config::PromptLanguage;
        assert_eq!(PromptLanguage::from_locale("zh"), PromptLanguage::Zh);
        assert_eq!(PromptLanguage::from_locale("zh-CN"), PromptLanguage::Zh);
        assert_eq!(PromptLanguage::from_locale("en"), PromptLanguage::En);
        assert_eq!(PromptLanguage::from_locale("en-US"), PromptLanguage::En);
        assert_eq!(PromptLanguage::from_locale("  "), PromptLanguage::En);
    }

    #[test]
    fn deepseek_full_prompt_covers_dsml_syntax_and_parameter_typing() {
        let config =
            ChatProviderConfig::new(ChatProviderKind::DeepSeek, "key", "", "deepseek-chat")
                .unwrap()
                .with_system_prompt("custom prompt");
        let full = config.full_system_prompt();
        assert!(full.contains("DSML"));
        assert!(full.contains("U+FF5C"));
        assert!(full.ends_with("custom prompt"));
        let typing_rule = full.find("string=\"false\"").unwrap();
        let example = full.find("<｜DSML｜tool_calls>").unwrap();
        assert!(typing_rule < example);
    }

    #[test]
    fn max_turns_defaults_to_20_and_overrides() {
        let config = test_config();
        assert_eq!(config.max_turns, crate::core::config::DEFAULT_MAX_TURNS);
        assert_eq!(config.max_turns, 20);
        let config = test_config().with_max_turns(5);
        assert_eq!(config.max_turns, 5);
        let config = test_config().with_max_turns(0);
        assert_eq!(config.max_turns, crate::core::config::DEFAULT_MAX_TURNS);
    }

    #[test]
    fn set_manual_corpus_keeps_history() {
        let mut agent = ChatAgent::new(test_config()).unwrap();
        agent.restore_history(vec![Message::user("hi"), Message::assistant("hello")]);
        agent.set_manual_corpus(crate::tools::manual::ManualCorpus::new(vec![]));
        assert_eq!(agent.history().len(), 2);
    }

    #[test]
    fn tool_result_text_joins_text_and_json_items() {
        let content = OneOrMany::many([
            ToolResultContent::Text(rig::message::Text::new("alpha")),
            ToolResultContent::Json {
                value: serde_json::json!({"k": 1}),
            },
        ])
        .unwrap();
        assert_eq!(tool_result_text(&content), "alpha\n{\"k\":1}");
    }

    #[test]
    fn tool_result_text_single_text_item() {
        let content = OneOrMany::one(ToolResultContent::Text(rig::message::Text::new("beta")));
        assert_eq!(tool_result_text(&content), "beta");
    }

    #[test]
    fn corpus_builds_agent_with_tools() {
        let mut agent = ChatAgent::new(test_config()).unwrap();
        let corpus = ManualCorpus::from_rows(vec![(
            "a".to_string(),
            crate::tools::manual::ManualDocText {
                locale: "en".to_string(),
                title: "A".to_string(),
                summary: String::new(),
                body: "alpha".to_string(),
            },
        )]);
        agent.set_manual_corpus(corpus);
        for provider in [
            ChatProviderKind::OpenAiCompatible,
            ChatProviderKind::Anthropic,
            ChatProviderKind::DeepSeek,
        ] {
            agent.config.provider = provider;
            assert!(agent.build_agent().is_ok());
        }
    }
}
