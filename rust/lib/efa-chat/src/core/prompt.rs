//! System-prompt assembly: renders the final system prompt from the bundled
//! section files plus the session's actual tool attachments, so the prompt
//! never advertises tools the model cannot call.
//!
//! Section order: identity, capabilities, workflow, skills, constraint,
//! appendix (only when the provider bundle has real appendix content), then
//! the volatile context block (attached fit) and any app-supplied extra
//! sections last, keeping the stable prefix long for provider prompt caching.

use crate::core::config::{ChatProviderConfig, PromptLanguage};
use crate::core::skill::SkillMeta;

/// Everything about the session that shapes the system prompt: which tool
/// groups are attached, the skills on offer, and the attached fit (if any).
#[derive(Debug, Default)]
pub struct SystemPromptContext {
    /// Fit-engine tools (`get_current_fit`, `get_fit_stats`, `get_item`,
    /// `get_attr`, `validate_fit`).
    pub fit_engine: bool,
    /// App-state fit tools (`search_items`, `list_user_fits`, `load_fit`,
    /// `create_fit`, `apply_fit_edit`); implies `fit_engine`.
    pub fit_data: bool,
    /// Manual tools (`search_manual`, `get_manual_doc`).
    pub manual: bool,
    /// Skill manifest; a non-empty list also attaches the `load_skill` tool.
    pub skills: Vec<SkillMeta>,
    /// The fit attached to the session, if any.
    pub active_fit: Option<ActiveFitSummary>,
}

/// A one-line description of the attached fit for the Context section.
#[derive(Debug)]
pub struct ActiveFitSummary {
    pub name: Option<String>,
    pub hull_name: Option<String>,
    pub hull_type_id: i32,
}

/// One-line capability blurbs for every tool, in display order:
/// `(tool name, en, zh)`. Keep in sync with the tool registrations in
/// `tools::fit::tools::fit_tools`, `tools::manual` and `tools::skill`; the
/// tests below pin the name set to the tools' `NAME` constants.
const TOOL_BLURBS: &[(&str, &str, &str)] = &[
    (
        "get_current_fit",
        "what is fitted on the attached fit",
        "当前挂载装配的装配内容",
    ),
    (
        "get_fit_stats",
        "headline stats of the attached fit: DPS, EHP, capacitor, speed, ...",
        "挂载装配的核心数据：DPS、EHP、电容、速度等",
    ),
    (
        "get_item",
        "all attributes of one fitted item",
        "单个已装配物品的全部属性",
    ),
    (
        "get_attr",
        "one attribute with its modifier breakdown",
        "单个属性及其加成来源分解",
    ),
    (
        "validate_fit",
        "fitting rule violations of the attached fit",
        "挂载装配的装配规则问题",
    ),
    (
        "search_items",
        "resolve an item name to a type id",
        "把物品名称解析为 type id",
    ),
    (
        "list_user_fits",
        "list the user's saved fits",
        "列出用户已保存的装配",
    ),
    (
        "load_fit",
        "switch the attached fit to a saved one",
        "把挂载的装配切换为某个已保存的装配",
    ),
    (
        "create_fit",
        "create a new saved fit for a ship hull (and attach it)",
        "为指定船体创建新装配（并挂载）",
    ),
    (
        "apply_fit_edit",
        "edit the attached fit; applies and persists immediately, no confirmation needed",
        "修改挂载的装配；直接应用并立即保存，无需进一步确认",
    ),
    (
        "search_manual",
        "keyword search over the bundled user manual",
        "在内置用户手册中按关键词搜索",
    ),
    (
        "get_manual_doc",
        "read a full manual page by id",
        "按 id 阅读手册页面的完整内容",
    ),
    (
        "load_skill",
        "load the full instructions of a skill",
        "加载某个技能的完整说明",
    ),
];

fn tool_blurb(language: PromptLanguage, name: &str) -> Option<&'static str> {
    TOOL_BLURBS
        .iter()
        .find(|(tool, _, _)| *tool == name)
        .map(|(_, en, zh)| language.pick(en, zh))
}

/// Render the full system prompt: the assembled bundled sections plus the
/// configured app-supplied extra sections appended last.
pub fn render_system_prompt(config: &ChatProviderConfig, context: &SystemPromptContext) -> String {
    let language = config.language;
    let mut sections: Vec<String> = vec![identity(language).to_string()];
    if let Some(capabilities) = render_capabilities(language, context) {
        sections.push(capabilities);
    }
    if let Some(workflow) = render_workflow(language, context) {
        sections.push(workflow);
    }
    if let Some(skills) = render_skills(language, &context.skills) {
        sections.push(skills);
    }
    sections.push(render_constraint(config));
    if let Some(appendix) = render_appendix(config) {
        sections.push(appendix);
    }
    if let Some(context_section) = render_context(language, context.active_fit.as_ref()) {
        sections.push(context_section);
    }
    let mut prompt = sections.join("\n\n");
    if !config.system_prompt.is_empty() {
        prompt.push_str("\n\n");
        prompt.push_str(&config.system_prompt);
    }
    prompt
}

fn identity(language: PromptLanguage) -> &'static str {
    language
        .pick(
            include_str!("../../prompt/system/en.prompt"),
            include_str!("../../prompt/system/zh.prompt"),
        )
        .trim()
}

fn render_capabilities(language: PromptLanguage, context: &SystemPromptContext) -> Option<String> {
    let mut names: Vec<&str> = Vec::new();
    if context.fit_engine {
        names.extend([
            "get_current_fit",
            "get_fit_stats",
            "get_item",
            "get_attr",
            "validate_fit",
        ]);
    }
    if context.fit_data {
        names.extend([
            "search_items",
            "list_user_fits",
            "load_fit",
            "create_fit",
            "apply_fit_edit",
        ]);
    }
    if context.manual {
        names.extend(["search_manual", "get_manual_doc"]);
    }
    if !context.skills.is_empty() {
        names.push("load_skill");
    }
    if names.is_empty() {
        return None;
    }
    let header = language.pick("## Capabilities", "## 能力");
    let intro = language.pick("You have the following tools:", "你可以使用以下工具：");
    let mut out = format!("{header}\n\n{intro}");
    for name in names {
        let blurb = tool_blurb(language, name).expect("every advertised tool has a blurb");
        out.push_str(&format!("\n- `{name}` — {blurb}"));
    }
    Some(out)
}

fn render_workflow(language: PromptLanguage, context: &SystemPromptContext) -> Option<String> {
    let mut fragments: Vec<&str> = Vec::new();
    if context.fit_engine {
        fragments.push(
            language
                .pick(
                    include_str!("../../prompt/workflow/fit/en.prompt"),
                    include_str!("../../prompt/workflow/fit/zh.prompt"),
                )
                .trim(),
        );
    }
    if context.fit_data {
        fragments.push(
            language
                .pick(
                    include_str!("../../prompt/workflow/fit_data/en.prompt"),
                    include_str!("../../prompt/workflow/fit_data/zh.prompt"),
                )
                .trim(),
        );
    }
    if context.manual {
        fragments.push(
            language
                .pick(
                    include_str!("../../prompt/workflow/manual/en.prompt"),
                    include_str!("../../prompt/workflow/manual/zh.prompt"),
                )
                .trim(),
        );
    }
    if fragments.is_empty() {
        return None;
    }
    let header = language.pick("## Workflow", "## 工作流");
    Some(format!("{header}\n\n{}", fragments.join("\n\n")))
}

fn render_skills(language: PromptLanguage, skills: &[SkillMeta]) -> Option<String> {
    if skills.is_empty() {
        return None;
    }
    let header = language.pick("## Skills", "## 技能");
    let intro = language.pick(
        "Skills are reusable instruction packs. When the user's request matches one of the \
         skills below, call the `load_skill` tool with its name first, then follow the returned \
         instructions.",
        "技能是可复用的指令包。当用户的请求与下列某个技能匹配时，先用 `load_skill` 工具按其名\
         称加载，然后遵循返回的说明。",
    );
    let mut out = format!("{header}\n\n{intro}");
    for skill in skills {
        out.push_str(&format!("\n- `{}`: {}", skill.name, skill.description));
    }
    Some(out)
}

fn render_constraint(config: &ChatProviderConfig) -> String {
    let language = config.language;
    let bundle = config.provider.prompt_bundle(language);
    let header = language.pick("## Constraint", "## 约束");
    let note = language.pick(
        "The rules in this section always apply.",
        "本节的规则始终适用。",
    );
    let parts = [
        bundle.constraint_system.trim(),
        bundle.constraint_provider.trim(),
    ];
    format!("{header}\n\n{note}\n\n{}", parts.join("\n\n"))
}

/// The appendix only renders when the provider bundle ships real content;
/// providers without provider-specific notes leave the file empty and the
/// section is omitted entirely.
fn render_appendix(config: &ChatProviderConfig) -> Option<String> {
    let language = config.language;
    let bundle = config.provider.prompt_bundle(language);
    let body = bundle.appendix_provider.trim();
    if body.is_empty() {
        return None;
    }
    let header = language.pick("## Appendix", "## 附录");
    Some(format!("{header}\n\n{body}"))
}

fn render_context(language: PromptLanguage, fit: Option<&ActiveFitSummary>) -> Option<String> {
    let fit = fit?;
    let header = language.pick("## Context", "## 上下文");
    let hull = fit.hull_name.clone().unwrap_or_else(|| match language {
        PromptLanguage::En => format!("hull type id {}", fit.hull_type_id),
        PromptLanguage::Zh => format!("船体 type id {}", fit.hull_type_id),
    });
    let line = match (language, &fit.name) {
        (PromptLanguage::En, Some(name)) => {
            format!("The user's attached fit is \"{name}\" (hull: {hull}).")
        }
        (PromptLanguage::En, None) => format!("The user's attached fit is a {hull} fit."),
        (PromptLanguage::Zh, Some(name)) => {
            format!("用户当前挂载的装配是“{name}”（船体：{hull}）。")
        }
        (PromptLanguage::Zh, None) => format!("用户当前挂载的装配使用船体 {hull}。"),
    };
    Some(format!("{header}\n\n{line}"))
}

#[cfg(test)]
mod tests {
    use rig::tool::PortableTool;

    use super::*;
    use crate::core::config::{ChatProviderKind, DEFAULT_BASE_URL};
    use crate::tools::fit::tools::{
        ApplyFitEditTool, CreateFitTool, GetAttrTool, GetCurrentFitTool, GetFitStatsTool,
        GetItemTool, ListUserFitsTool, LoadFitTool, SearchItemsTool, ValidateFitTool,
    };
    use crate::tools::manual::{ManualDocTool, ManualSearchTool};
    use crate::tools::skill::LoadSkillTool;

    fn config() -> ChatProviderConfig {
        ChatProviderConfig::new(
            ChatProviderKind::OpenAiCompatible,
            "test-key",
            DEFAULT_BASE_URL,
            "gpt-4o-mini",
        )
        .unwrap()
    }

    /// DeepSeek is the provider whose bundle ships a non-empty appendix.
    fn deepseek_config() -> ChatProviderConfig {
        ChatProviderConfig::new(ChatProviderKind::DeepSeek, "test-key", "", "deepseek-chat")
            .unwrap()
    }

    fn full_context() -> SystemPromptContext {
        SystemPromptContext {
            fit_engine: true,
            fit_data: true,
            manual: true,
            skills: vec![SkillMeta {
                name: "fit-analysis".to_string(),
                description: "Analyze the attached fit".to_string(),
            }],
            active_fit: Some(ActiveFitSummary {
                name: Some("My Vexor".to_string()),
                hull_name: Some("Vexor".to_string()),
                hull_type_id: 626,
            }),
        }
    }

    #[test]
    fn blurb_table_covers_every_tool_in_both_languages() {
        let names = [
            GetCurrentFitTool::NAME,
            GetFitStatsTool::NAME,
            GetItemTool::NAME,
            GetAttrTool::NAME,
            ValidateFitTool::NAME,
            SearchItemsTool::NAME,
            ListUserFitsTool::NAME,
            LoadFitTool::NAME,
            CreateFitTool::NAME,
            ApplyFitEditTool::NAME,
            ManualSearchTool::NAME,
            ManualDocTool::NAME,
            LoadSkillTool::NAME,
        ];
        for language in [PromptLanguage::En, PromptLanguage::Zh] {
            for name in names {
                assert!(
                    tool_blurb(language, name).is_some(),
                    "missing blurb for {name}"
                );
            }
        }
        assert_eq!(TOOL_BLURBS.len(), names.len(), "stale blurb table entries");
    }

    #[test]
    fn bare_context_renders_identity_and_constraint_only() {
        let prompt = render_system_prompt(&config(), &SystemPromptContext::default());
        assert!(prompt.starts_with("You are a helpful assistant"));
        assert!(!prompt.contains("## Capabilities"));
        assert!(!prompt.contains("## Workflow"));
        assert!(!prompt.contains("## Skills"));
        assert!(!prompt.contains("## Context"));
        assert!(!prompt.contains("search_manual"));
        assert!(prompt.contains("## Constraint"));
        // Providers without appendix content omit the section entirely.
        assert!(!prompt.contains("## Appendix"));
    }

    #[test]
    fn full_context_renders_every_section_in_order() {
        let prompt = render_system_prompt(&deepseek_config(), &full_context());
        let capabilities = prompt.find("## Capabilities").unwrap();
        let workflow = prompt.find("## Workflow").unwrap();
        let skills = prompt.find("## Skills").unwrap();
        let constraint = prompt.find("## Constraint").unwrap();
        let appendix = prompt.find("## Appendix").unwrap();
        let context = prompt.find("## Context").unwrap();
        assert!(capabilities < workflow);
        assert!(workflow < skills);
        assert!(skills < constraint);
        assert!(constraint < appendix);
        // The volatile context block renders last, after the stable prefix.
        assert!(appendix < context);
    }

    #[test]
    fn capabilities_list_only_attached_tools() {
        let context = SystemPromptContext {
            manual: true,
            ..SystemPromptContext::default()
        };
        let prompt = render_system_prompt(&config(), &context);
        assert!(prompt.contains("`search_manual`"));
        assert!(prompt.contains("`get_manual_doc`"));
        assert!(!prompt.contains("`get_fit_stats`"));
        assert!(!prompt.contains("`apply_fit_edit`"));
        assert!(!prompt.contains("`load_skill`"));
    }

    #[test]
    fn workflow_fragments_follow_attachments() {
        let prompt = render_system_prompt(&config(), &full_context());
        assert!(prompt.contains("the `fit-analysis` skill has the full procedure"));
        assert!(prompt.contains("persists them immediately"));
        assert!(prompt.contains("efa://manual/..."));

        let context = SystemPromptContext {
            fit_engine: true,
            ..SystemPromptContext::default()
        };
        let prompt = render_system_prompt(&config(), &context);
        assert!(prompt.contains("the `fit-analysis` skill has the full procedure"));
        assert!(!prompt.contains("persists them immediately"));
        assert!(!prompt.contains("efa://manual"));
    }

    #[test]
    fn skills_manifest_lists_names_and_descriptions() {
        let prompt = render_system_prompt(&config(), &full_context());
        let skills = prompt.find("## Skills").unwrap();
        let constraint = prompt.find("## Constraint").unwrap();
        let section = &prompt[skills..constraint];
        assert!(section.contains("`load_skill`"));
        assert!(section.contains("- `fit-analysis`: Analyze the attached fit"));
    }

    #[test]
    fn context_block_renders_fit_name_and_hull() {
        let prompt = render_system_prompt(&config(), &full_context());
        assert!(prompt.contains("The user's attached fit is \"My Vexor\" (hull: Vexor)."));

        let context = SystemPromptContext {
            active_fit: Some(ActiveFitSummary {
                name: None,
                hull_name: None,
                hull_type_id: 626,
            }),
            ..SystemPromptContext::default()
        };
        let prompt = render_system_prompt(&config(), &context);
        assert!(prompt.contains("The user's attached fit is a hull type id 626 fit."));
    }

    #[test]
    fn zh_sections_and_content_render_in_chinese() {
        let config = deepseek_config().with_language(PromptLanguage::Zh);
        let context = SystemPromptContext {
            fit_engine: true,
            manual: true,
            skills: vec![SkillMeta {
                name: "fit-analysis".to_string(),
                description: "分析当前挂载的装配".to_string(),
            }],
            active_fit: Some(ActiveFitSummary {
                name: Some("我的毒蜥".to_string()),
                hull_name: Some("毒蜥级".to_string()),
                hull_type_id: 17703,
            }),
            ..SystemPromptContext::default()
        };
        let prompt = render_system_prompt(&config, &context);
        for header in [
            "## 能力",
            "## 工作流",
            "## 技能",
            "## 约束",
            "## 附录",
            "## 上下文",
        ] {
            assert!(prompt.contains(header), "missing {header}");
        }
        assert!(prompt.contains("不要编造"));
        assert!(prompt.contains("- `fit-analysis`: 分析当前挂载的装配"));
        assert!(prompt.contains("用户当前挂载的装配是“我的毒蜥”（船体：毒蜥级）。"));
        // fit_data was not attached, so its fragment must be absent.
        assert!(!prompt.contains("无需进一步确认"));
    }

    #[test]
    fn app_supplied_extras_stay_last() {
        let config = config().with_system_prompt("custom prompt");
        let prompt = render_system_prompt(&config, &full_context());
        assert!(prompt.ends_with("custom prompt"));
    }
}
