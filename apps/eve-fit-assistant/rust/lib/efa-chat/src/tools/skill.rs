//! The `load_skill` tool: progressive disclosure for agent skills. The system
//! prompt advertises only each skill's name and description; this tool loads
//! the full instruction body on demand.

use std::sync::Arc;

use rig::tool::{PortableTool, ToolExecutionError};
use serde::Deserialize;
use thiserror::Error;

use crate::core::config::PromptLanguage;
use crate::core::skill::{SkillContent, SkillRegistry};
use crate::tools::fit::ToolTimer;

#[derive(Debug, Error)]
pub enum SkillToolError {
    #[error("skill `{0}` not found; available skills: {1}")]
    NotFound(String, String),
}

/// Surface skill tool failures to the model verbatim; rig's default
/// `map_error` redacts them to the generic "the tool failed" (see the
/// matching `From<ManualToolError>` impl in the manual module).
impl From<SkillToolError> for ToolExecutionError {
    fn from(error: SkillToolError) -> Self {
        let message = error.to_string();
        match error {
            SkillToolError::NotFound(_, _) => Self::not_found(message),
        }
    }
}

#[derive(Debug, Deserialize)]
pub struct LoadSkillArgs {
    pub name: String,
}

/// rig tool: load the full instructions of a skill by name.
#[derive(Clone)]
pub struct LoadSkillTool {
    registry: Arc<SkillRegistry>,
    language: PromptLanguage,
}

impl LoadSkillTool {
    pub fn new(registry: Arc<SkillRegistry>, language: PromptLanguage) -> Self {
        Self { registry, language }
    }
}

impl PortableTool for LoadSkillTool {
    const NAME: &'static str = "load_skill";
    type Args = LoadSkillArgs;
    type Output = SkillContent;
    type Error = SkillToolError;

    fn description(&self) -> String {
        self.language
            .pick(
                include_str!("../../prompt/tool/load_skill/en.prompt"),
                include_str!("../../prompt/tool/load_skill/zh.prompt"),
            )
            .trim()
            .to_string()
    }

    fn parameters(&self) -> serde_json::Value {
        serde_json::json!({
            "type": "object",
            "properties": {
                "name": {
                    "type": "string",
                    "description": "Skill name, as listed in the system prompt's Skills section"
                }
            },
            "required": ["name"]
        })
    }

    fn map_error(&self, error: Self::Error) -> ToolExecutionError {
        error.into()
    }

    async fn call(&self, args: Self::Args) -> Result<Self::Output, Self::Error> {
        let _timer = ToolTimer::start(Self::NAME);
        let name = args.name.trim();
        self.registry.get(name, self.language).ok_or_else(|| {
            let available: Vec<String> = self
                .registry
                .list(self.language)
                .into_iter()
                .map(|meta| meta.name)
                .collect();
            SkillToolError::NotFound(name.to_string(), available.join(", "))
        })
    }
}

#[cfg(test)]
mod tests {
    use rig::tool::ToolErrorKind;

    use super::*;
    use crate::core::skill::Skill;

    fn registry() -> Arc<SkillRegistry> {
        Arc::new(SkillRegistry::new(vec![
            Skill::from_raw(
                "---\nname: fit-analysis\ndescription: Analyze the attached fit\n---\n\nBody EN.\n",
                Some("---\nname: fit-analysis\ndescription: 分析装配\n---\n\n正文。\n"),
            )
            .unwrap(),
        ]))
    }

    #[test]
    fn loads_localized_skill_body() {
        let tool = LoadSkillTool::new(registry(), PromptLanguage::Zh);
        let content = futures::executor::block_on(tool.call(LoadSkillArgs {
            name: "fit-analysis".to_string(),
        }))
        .unwrap();
        assert_eq!(content.name, "fit-analysis");
        assert_eq!(content.description, "分析装配");
        assert_eq!(content.body, "正文。");
    }

    #[test]
    fn unknown_skill_lists_available_names() {
        let tool = LoadSkillTool::new(registry(), PromptLanguage::En);
        let error = futures::executor::block_on(tool.call(LoadSkillArgs {
            name: "nope".to_string(),
        }))
        .unwrap_err();
        let message = error.to_string();
        assert!(message.contains("nope"));
        assert!(message.contains("fit-analysis"));
    }

    #[test]
    fn errors_keep_actionable_model_feedback() {
        let error = SkillToolError::NotFound("nope".to_string(), "fit-analysis".to_string());
        let expected = error.to_string();
        let mapped = ToolExecutionError::from(error);
        assert_eq!(mapped.kind(), ToolErrorKind::NotFound);
        assert_eq!(mapped.model_feedback(), Some(expected.as_str()));
    }

    #[test]
    fn description_follows_language() {
        let en = LoadSkillTool::new(registry(), PromptLanguage::En);
        let zh = LoadSkillTool::new(registry(), PromptLanguage::Zh);
        assert!(en.description().contains("skill"));
        assert!(zh.description().contains("技能"));
        assert_ne!(en.description(), zh.description());
    }
}
