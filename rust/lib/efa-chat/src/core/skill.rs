//! Agent skills: reusable, progressively-disclosed instruction packs.
//!
//! A skill is a markdown document with a small frontmatter block (`name` and
//! `description`), bundled under `skills/<name>/SKILL.{en,zh}.md`. Only the
//! name/description manifest enters the system prompt; the model loads the
//! full body on demand through the `load_skill` tool, keeping the per-turn
//! prompt small no matter how many skills exist.

use serde::Serialize;
use thiserror::Error;

use crate::core::config::PromptLanguage;

/// One language variant of a skill: the localized manifest description plus
/// the full markdown body.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SkillVariant {
    pub description: String,
    pub body: String,
}

/// A skill: a stable (language-independent) name plus its localized
/// variants. English is required and serves as the fallback for every other
/// language.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Skill {
    pub name: String,
    pub en: SkillVariant,
    pub zh: Option<SkillVariant>,
}

impl Skill {
    /// Build a skill from its raw per-language documents; see
    /// [`parse_skill`]. The localized variants must agree on the name.
    pub fn from_raw(en: &str, zh: Option<&str>) -> Result<Self, SkillParseError> {
        let (name, en) = parse_skill(en)?;
        let zh = zh
            .map(parse_skill)
            .transpose()?
            .map(|(zh_name, variant)| {
                if zh_name == name {
                    Ok(variant)
                } else {
                    Err(SkillParseError::NameMismatch(name.clone(), zh_name))
                }
            })
            .transpose()?;
        Ok(Self { name, en, zh })
    }

    /// The variant for [language], falling back to English.
    fn variant(&self, language: PromptLanguage) -> &SkillVariant {
        match language {
            PromptLanguage::En => &self.en,
            PromptLanguage::Zh => self.zh.as_ref().unwrap_or(&self.en),
        }
    }
}

/// The manifest entry advertised in the system prompt's Skills section.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SkillMeta {
    pub name: String,
    pub description: String,
}

/// The full skill payload returned by the `load_skill` tool.
#[derive(Debug, Clone, Serialize)]
pub struct SkillContent {
    pub name: String,
    pub description: String,
    pub body: String,
}

#[derive(Debug, Error, PartialEq, Eq)]
pub enum SkillParseError {
    #[error("skill document must start with a `---` frontmatter block")]
    MissingFrontmatter,
    #[error("skill frontmatter is missing the `{0}` field")]
    MissingField(&'static str),
    #[error("skill name mismatch between localizations: `{0}` vs `{1}`")]
    NameMismatch(String, String),
}

/// Parse one raw skill document (`SKILL.<lang>.md`) into its name and
/// variant. The frontmatter is a `---`-delimited block of `key: value` lines;
/// only `name` and `description` are read, everything after the closing
/// delimiter is the body.
pub fn parse_skill(raw: &str) -> Result<(String, SkillVariant), SkillParseError> {
    let mut lines = raw.trim_start_matches('\u{feff}').lines();
    if lines.next().map(str::trim) != Some("---") {
        return Err(SkillParseError::MissingFrontmatter);
    }
    let mut name: Option<String> = None;
    let mut description: Option<String> = None;
    let mut body: Vec<&str> = Vec::new();
    let mut in_frontmatter = true;
    for line in lines {
        if in_frontmatter {
            if line.trim() == "---" {
                in_frontmatter = false;
                continue;
            }
            if let Some((key, value)) = line.split_once(':') {
                let value = value.trim().trim_matches('"').trim_matches('\'');
                match key.trim() {
                    "name" => name = Some(value.to_string()),
                    "description" => description = Some(value.to_string()),
                    _ => {}
                }
            }
        } else {
            body.push(line);
        }
    }
    if in_frontmatter {
        return Err(SkillParseError::MissingFrontmatter);
    }
    let name = name
        .filter(|n| !n.trim().is_empty())
        .ok_or(SkillParseError::MissingField("name"))?;
    let description = description
        .filter(|d| !d.trim().is_empty())
        .ok_or(SkillParseError::MissingField("description"))?;
    Ok((
        name,
        SkillVariant {
            description,
            body: body.join("\n").trim().to_string(),
        },
    ))
}

/// The skills available to a session. Built from the compile-time bundled
/// set by default; replaceable via [`crate::core::agent::ChatAgent::set_skill_registry`]
/// for tests and future app-pushed skill packs.
#[derive(Debug, Default)]
pub struct SkillRegistry {
    skills: Vec<Skill>,
}

impl SkillRegistry {
    pub fn new(skills: Vec<Skill>) -> Self {
        Self { skills }
    }

    /// The compile-time bundled skills (`skills/<name>/SKILL.{en,zh}.md`).
    /// Bundled documents are validated by the tests, so a parse failure here
    /// is a build-time authoring bug, not a runtime condition.
    pub fn bundled() -> Self {
        let skill = |name: &str, en: &str, zh: &str| {
            Skill::from_raw(en, Some(zh))
                .unwrap_or_else(|e| panic!("bundled skill `{name}` must parse: {e}"))
        };
        Self::new(vec![
            skill(
                "app-usage",
                include_str!("../../skills/app-usage/SKILL.en.md"),
                include_str!("../../skills/app-usage/SKILL.zh.md"),
            ),
            skill(
                "fit-analysis",
                include_str!("../../skills/fit-analysis/SKILL.en.md"),
                include_str!("../../skills/fit-analysis/SKILL.zh.md"),
            ),
            skill(
                "fit-create",
                include_str!("../../skills/fit-create/SKILL.en.md"),
                include_str!("../../skills/fit-create/SKILL.zh.md"),
            ),
            skill(
                "fit-edit",
                include_str!("../../skills/fit-edit/SKILL.en.md"),
                include_str!("../../skills/fit-edit/SKILL.zh.md"),
            ),
        ])
    }

    pub fn is_empty(&self) -> bool {
        self.skills.is_empty()
    }

    /// The manifest advertised in the system prompt, localized to [language]
    /// (per-skill English fallback).
    pub fn list(&self, language: PromptLanguage) -> Vec<SkillMeta> {
        self.skills
            .iter()
            .map(|skill| SkillMeta {
                name: skill.name.clone(),
                description: skill.variant(language).description.clone(),
            })
            .collect()
    }

    /// The full content of one skill for the `load_skill` tool, localized to
    /// [language] (English fallback). `None` when no skill has that name.
    pub fn get(&self, name: &str, language: PromptLanguage) -> Option<SkillContent> {
        let skill = self.skills.iter().find(|skill| skill.name == name.trim())?;
        let variant = skill.variant(language);
        Some(SkillContent {
            name: skill.name.clone(),
            description: variant.description.clone(),
            body: variant.body.clone(),
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const EN_DOC: &str = "---\nname: fit-analysis\ndescription: Analyze the attached fit\n---\n\n# Fit Analysis\n\nCall `get_fit_stats` first.\n";
    const ZH_DOC: &str = "---\nname: fit-analysis\ndescription: 分析当前挂载的装配\n---\n\n# 装配分析\n\n先调用 `get_fit_stats`。\n";

    fn registry() -> SkillRegistry {
        SkillRegistry::new(vec![
            Skill::from_raw(EN_DOC, Some(ZH_DOC)).unwrap(),
            Skill::from_raw(
                "---\nname: en-only\ndescription: English only skill\n---\n\nBody.\n",
                None,
            )
            .unwrap(),
        ])
    }

    #[test]
    fn parses_frontmatter_and_body() {
        let (name, variant) = parse_skill(EN_DOC).unwrap();
        assert_eq!(name, "fit-analysis");
        assert_eq!(variant.description, "Analyze the attached fit");
        assert!(variant.body.starts_with("# Fit Analysis"));
        assert!(variant.body.contains("get_fit_stats"));
    }

    #[test]
    fn rejects_documents_without_frontmatter() {
        assert_eq!(
            parse_skill("no frontmatter here"),
            Err(SkillParseError::MissingFrontmatter)
        );
        assert_eq!(
            parse_skill("---\nname: a\n"),
            Err(SkillParseError::MissingFrontmatter)
        );
    }

    #[test]
    fn rejects_missing_required_fields() {
        assert_eq!(
            parse_skill("---\ndescription: d\n---\nbody"),
            Err(SkillParseError::MissingField("name"))
        );
        assert_eq!(
            parse_skill("---\nname: a\n---\nbody"),
            Err(SkillParseError::MissingField("description"))
        );
        assert_eq!(
            parse_skill("---\nname: \" \"\ndescription: d\n---\nbody"),
            Err(SkillParseError::MissingField("name"))
        );
    }

    #[test]
    fn rejects_mismatched_localization_names() {
        let zh = "---\nname: other\ndescription: 其他\n---\nbody";
        assert_eq!(
            Skill::from_raw(EN_DOC, Some(zh)),
            Err(SkillParseError::NameMismatch(
                "fit-analysis".to_string(),
                "other".to_string()
            ))
        );
    }

    #[test]
    fn list_localizes_descriptions() {
        let metas = registry().list(PromptLanguage::Zh);
        assert_eq!(metas.len(), 2);
        assert_eq!(metas[0].name, "fit-analysis");
        assert_eq!(metas[0].description, "分析当前挂载的装配");
        // A skill without a zh variant falls back to English.
        assert_eq!(metas[1].description, "English only skill");
    }

    #[test]
    fn get_returns_localized_body_with_en_fallback() {
        let registry = registry();
        let zh = registry.get("fit-analysis", PromptLanguage::Zh).unwrap();
        assert!(zh.body.contains("装配分析"));
        let fallback = registry.get("en-only", PromptLanguage::Zh).unwrap();
        assert_eq!(fallback.body, "Body.");
        assert!(registry.get("missing", PromptLanguage::En).is_none());
    }

    #[test]
    fn bundled_skills_parse_with_unique_names_and_full_localization() {
        let bundled = SkillRegistry::bundled();
        let en = bundled.list(PromptLanguage::En);
        let zh = bundled.list(PromptLanguage::Zh);
        assert_eq!(en.len(), 4, "expected the four bundled skills");
        assert_eq!(en.len(), zh.len());
        let mut names: Vec<&str> = en.iter().map(|meta| meta.name.as_str()).collect();
        names.sort_unstable();
        names.dedup();
        assert_eq!(names.len(), en.len(), "skill names must be unique");
        for meta in en.iter().chain(zh.iter()) {
            assert!(!meta.description.is_empty());
        }
        for (en_meta, zh_meta) in en.iter().zip(zh.iter()) {
            let content = bundled.get(&en_meta.name, PromptLanguage::En).unwrap();
            assert!(!content.body.is_empty());
            // The bundled set ships a real zh variant for every skill (no
            // silent English fallback).
            assert_ne!(en_meta.description, zh_meta.description);
        }
    }
}
