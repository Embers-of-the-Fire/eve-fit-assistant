use futures::StreamExt;
use rig::agent::Agent;
use rig::message::Message;
use rig::prelude::*;
use rig::providers::openai;
use rig::streaming::StreamedAssistantContent;

use crate::config::ChatProviderConfig;
use crate::error::ChatError;
use crate::event::ChatEvent;

pub struct ChatAgent {
    client: openai::CompletionsClient,
    model: String,
    system_prompt: String,
    history: Vec<Message>,
}

impl ChatAgent {
    pub fn new(config: ChatProviderConfig) -> Result<Self, ChatError> {
        config.validate()?;
        let client = openai::CompletionsClient::builder()
            .api_key(config.api_key)
            .base_url(config.base_url)
            .build()
            .map_err(|e| ChatError::Client(e.to_string()))?;
        Ok(Self {
            client,
            model: config.model,
            system_prompt: config.system_prompt,
            history: Vec::new(),
        })
    }

    pub fn model(&self) -> &str {
        &self.model
    }

    pub fn set_model(&mut self, model: String) {
        self.model = model;
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

    fn build_agent(&self) -> Agent<openai::CompletionModel> {
        self.client
            .agent(self.model.clone())
            .preamble(&self.system_prompt)
            .build()
    }

    pub async fn chat_turn(&mut self, prompt: &str) -> Result<String, ChatError> {
        let agent = self.build_agent();
        agent
            .chat(prompt.to_string(), &mut self.history)
            .await
            .map_err(|e| ChatError::Completion(e.to_string()))
    }

    pub async fn stream_turn(
        &mut self,
        prompt: &str,
        mut on_event: impl FnMut(ChatEvent),
    ) -> Result<(), ChatError> {
        let agent = self.build_agent();
        let mut stream = agent
            .stream_chat(prompt.to_string(), self.history.clone())
            .await;
        let mut accumulated = String::new();
        while let Some(item) = stream.next().await {
            match item {
                Ok(MultiTurnStreamItem::StreamAssistantItem(StreamedAssistantContent::Text(
                    text,
                ))) => {
                    accumulated.push_str(&text.text);
                    on_event(ChatEvent::TextDelta(text.text));
                }
                Ok(MultiTurnStreamItem::FinalResponse(_)) => break,
                Ok(_) => {}
                Err(e) => {
                    on_event(ChatEvent::Error(e.to_string()));
                    return Err(ChatError::Stream(e.to_string()));
                }
            }
        }
        self.history.push(Message::user(prompt));
        self.history.push(Message::assistant(accumulated.clone()));
        on_event(ChatEvent::Done(accumulated));
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::config::DEFAULT_BASE_URL;

    fn test_config() -> ChatProviderConfig {
        ChatProviderConfig::new("test-key", DEFAULT_BASE_URL, "gpt-4o-mini").unwrap()
    }

    #[test]
    fn builds_with_default_base_url() {
        let agent = ChatAgent::new(test_config()).unwrap();
        assert_eq!(agent.model(), "gpt-4o-mini");
        assert!(agent.history().is_empty());
    }

    #[test]
    fn builds_with_custom_base_url() {
        let config =
            ChatProviderConfig::new("test-key", "http://localhost:11434/v1", "llama3").unwrap();
        assert!(ChatAgent::new(config).is_ok());
    }

    #[test]
    fn rejects_empty_api_key() {
        assert!(ChatProviderConfig::new("", DEFAULT_BASE_URL, "gpt-4o-mini").is_err());
    }

    #[test]
    fn rejects_empty_model() {
        assert!(ChatProviderConfig::new("test-key", DEFAULT_BASE_URL, "").is_err());
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
    fn custom_system_prompt_overrides_default() {
        let config = test_config().with_system_prompt("custom prompt");
        assert_eq!(config.system_prompt, "custom prompt");
    }

    #[test]
    fn blank_system_prompt_keeps_default() {
        let config = test_config().with_system_prompt("   ");
        assert_eq!(config.system_prompt, crate::config::DEFAULT_SYSTEM_PROMPT);
    }
}
