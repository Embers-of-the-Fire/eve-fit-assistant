use std::collections::HashSet;
use std::sync::Arc;

use futures::StreamExt;
use rig::agent::Agent;
use rig::completion::CompletionModel;
use rig::message::Message;
use rig::prelude::*;
use rig::providers::{anthropic, deepseek, openai};
use rig::streaming::{StreamedAssistantContent, StreamedUserContent, ToolCallDeltaContent};

use crate::config::{ChatProviderConfig, ChatProviderKind};
use crate::error::ChatError;
use crate::event::ChatEvent;
use crate::manual::{ManualCorpus, ManualDocTool, ManualSearchTool};

pub struct ChatAgent {
    config: ChatProviderConfig,
    history: Vec<Message>,
    manual_corpus: Option<Arc<ManualCorpus>>,
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

    fn attach_tools<M>(&self, builder: rig::agent::AgentBuilder<M>) -> Agent<M>
    where
        M: CompletionModel + 'static,
    {
        let builder = builder
            .preamble(&self.config.full_system_prompt())
            .temperature(0.2);
        match &self.manual_corpus {
            Some(corpus) => builder
                .tool(ManualSearchTool::new(corpus.clone()))
                .tool(ManualDocTool::new(corpus.clone()))
                .build(),
            None => builder.build(),
        }
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

    pub async fn chat_turn(&mut self, prompt: &str) -> Result<String, ChatError> {
        let agent = self.build_agent()?;
        let max_turns = self.config.max_turns;
        match &agent {
            TurnAgent::OpenAiCompatible(agent) => {
                drive_chat(agent, prompt, &mut self.history, max_turns).await
            }
            TurnAgent::Anthropic(agent) => {
                drive_chat(agent, prompt, &mut self.history, max_turns).await
            }
            TurnAgent::DeepSeek(agent) => {
                drive_chat(agent, prompt, &mut self.history, max_turns).await
            }
        }
    }

    pub async fn stream_turn(
        &mut self,
        prompt: &str,
        mut on_event: impl FnMut(ChatEvent),
    ) -> Result<(), ChatError> {
        let agent = self.build_agent()?;
        let max_turns = self.config.max_turns;
        let accumulated = match &agent {
            TurnAgent::OpenAiCompatible(agent) => {
                drive_stream(
                    agent,
                    prompt,
                    self.history.clone(),
                    max_turns,
                    &mut on_event,
                )
                .await?
            }
            TurnAgent::Anthropic(agent) => {
                drive_stream(
                    agent,
                    prompt,
                    self.history.clone(),
                    max_turns,
                    &mut on_event,
                )
                .await?
            }
            TurnAgent::DeepSeek(agent) => {
                drive_stream(
                    agent,
                    prompt,
                    self.history.clone(),
                    max_turns,
                    &mut on_event,
                )
                .await?
            }
        };
        self.history.push(Message::user(prompt));
        self.history.push(Message::assistant(accumulated.clone()));
        on_event(ChatEvent::Done(accumulated));
        Ok(())
    }
}

/// Drive one non-streaming turn (rig's `Chat::chat` with a configurable
/// multi-turn depth), appending the turn's messages to [history].
async fn drive_chat<M>(
    agent: &Agent<M>,
    prompt: &str,
    history: &mut Vec<Message>,
    max_turns: usize,
) -> Result<String, ChatError>
where
    M: CompletionModel + 'static,
{
    let response = agent
        .prompt(prompt.to_string())
        .history(history.clone())
        .max_turns(max_turns)
        .extended_details()
        .await
        .map_err(|e| ChatError::Completion(e.to_string()))?;
    if let Some(messages) = response.messages {
        history.extend(messages);
    }
    Ok(response.output)
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
                internal_call_id,
                ..
            })) => {
                on_event(ChatEvent::ToolCallEnd {
                    id: internal_call_id,
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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::config::DEFAULT_BASE_URL;

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
            crate::config::ANTHROPIC_BASE_URL
        );
        let config =
            ChatProviderConfig::new(ChatProviderKind::DeepSeek, "key", "", "deepseek-chat")
                .unwrap();
        assert_eq!(config.resolved_base_url(), crate::config::DEEPSEEK_BASE_URL);
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
    fn custom_system_prompt_is_appended_to_base() {
        let config = test_config().with_system_prompt("custom prompt");
        let full = config.full_system_prompt();
        assert!(full.starts_with(crate::config::BASE_SYSTEM_PROMPT.trim_end()));
        assert!(full.ends_with("custom prompt"));
    }

    #[test]
    fn blank_system_prompt_keeps_base_only() {
        let config = test_config().with_system_prompt("   ");
        assert_eq!(
            config.full_system_prompt(),
            crate::config::BASE_SYSTEM_PROMPT.trim_end()
        );
    }

    #[test]
    fn base_prompt_covers_persona_and_manual_tools() {
        let base = crate::config::BASE_SYSTEM_PROMPT;
        assert!(base.contains("EVE Fit Assistant"));
        assert!(base.contains("search_manual"));
        assert!(base.contains("get_manual_doc"));
    }

    #[test]
    fn deepseek_full_prompt_appends_dsml_note_after_extra_sections() {
        let config =
            ChatProviderConfig::new(ChatProviderKind::DeepSeek, "key", "", "deepseek-chat")
                .unwrap()
                .with_system_prompt("custom prompt");
        let full = config.full_system_prompt();
        assert!(full.contains("custom prompt"));
        assert!(full.contains("DSML"));
        assert!(full.find("custom prompt") < full.find("DSML"));
    }

    #[test]
    fn deepseek_prompt_extra_is_dsml_ascii_note() {
        let extra = ChatProviderKind::DeepSeek.system_prompt_extra().unwrap();
        assert!(extra.contains("DSML"));
        assert!(extra.contains("ASCII"));
        assert!(
            ChatProviderKind::OpenAiCompatible
                .system_prompt_extra()
                .is_none()
        );
        assert!(ChatProviderKind::Anthropic.system_prompt_extra().is_none());
    }

    #[test]
    fn max_turns_defaults_to_20_and_overrides() {
        let config = test_config();
        assert_eq!(config.max_turns, crate::config::DEFAULT_MAX_TURNS);
        assert_eq!(config.max_turns, 20);
        let config = test_config().with_max_turns(5);
        assert_eq!(config.max_turns, 5);
        let config = test_config().with_max_turns(0);
        assert_eq!(config.max_turns, crate::config::DEFAULT_MAX_TURNS);
    }

    #[test]
    fn set_manual_corpus_keeps_history() {
        let mut agent = ChatAgent::new(test_config()).unwrap();
        agent.restore_history(vec![Message::user("hi"), Message::assistant("hello")]);
        agent.set_manual_corpus(crate::manual::ManualCorpus::new(vec![]));
        assert_eq!(agent.history().len(), 2);
    }

    #[test]
    fn corpus_builds_agent_with_tools() {
        let mut agent = ChatAgent::new(test_config()).unwrap();
        let corpus = ManualCorpus::from_rows(vec![(
            "a".to_string(),
            crate::manual::ManualDocText {
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
