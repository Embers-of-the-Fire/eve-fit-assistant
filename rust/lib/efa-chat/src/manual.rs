use std::sync::Arc;

use rig::tool::PortableTool;
use serde::{Deserialize, Serialize};
use thiserror::Error;

use crate::config::PromptLanguage;
use crate::fit::ToolTimer;

const DEFAULT_LIMIT: usize = 8;
const MAX_LIMIT: usize = 20;
const MAX_KEYWORDS: usize = 8;
const SNIPPET_RADIUS: usize = 100;

const LINK_SCHEME: &str = "efa://manual";

/// A single localized text payload of a manual document.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ManualDocText {
    pub locale: String,
    pub title: String,
    pub summary: String,
    pub body: String,
}

/// A manual document with all of its localizations. `id` is the path-joined
/// document id, e.g. `fitting/modules`.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ManualDoc {
    pub id: String,
    pub localizations: Vec<ManualDocText>,
}

impl ManualDoc {
    fn url(&self) -> String {
        format!("{LINK_SCHEME}/{}", self.id)
    }

    /// Resolve the localization for [language]: exact match (after
    /// normalizing `-` to `_`, case-insensitive), language-prefix match, `en`
    /// fallback, then first available. `None` selects all localizations.
    fn resolve_locale(&self, language: &str) -> Option<&ManualDocText> {
        let normalized = language.replace('-', "_").to_lowercase();
        let find = |pred: &dyn Fn(&str) -> bool| {
            self.localizations
                .iter()
                .find(|loc| pred(&loc.locale.replace('-', "_").to_lowercase()))
        };
        if let Some(loc) = find(&|key| key == normalized) {
            return Some(loc);
        }
        let prefix = normalized.split('_').next().unwrap_or("");
        if let Some(loc) = find(&|key| key.split('_').next().unwrap_or("") == prefix) {
            return Some(loc);
        }
        if let Some(loc) = find(&|key| key == "en") {
            return Some(loc);
        }
        self.localizations.first()
    }
}

/// The in-memory manual corpus backing the search/read tools.
#[derive(Debug, Default)]
pub struct ManualCorpus {
    docs: Vec<ManualDoc>,
}

/// A search hit returned by [`ManualCorpus::search`].
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ManualSearchHit {
    pub id: String,
    pub locale: String,
    pub title: String,
    pub url: String,
    pub snippet: String,
    pub matched_keywords: Vec<String>,
}

/// The full content of a manual document, returned by [`ManualCorpus::get`].
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ManualDocContent {
    pub id: String,
    pub locale: String,
    pub title: String,
    pub summary: String,
    pub url: String,
    pub content: String,
}

#[derive(Debug, Error)]
pub enum ManualToolError {
    #[error("keywords must contain at least one non-empty term")]
    NoKeywords,
    #[error("manual doc `{0}` not found; available ids containing it: {1}")]
    DocNotFound(String, String),
}

impl ManualCorpus {
    pub fn new(docs: Vec<ManualDoc>) -> Self {
        Self { docs }
    }

    /// Build a corpus from flat `(doc id, localization)` rows, grouping
    /// localizations by doc id while preserving first-seen doc order.
    pub fn from_rows(rows: Vec<(String, ManualDocText)>) -> Self {
        let mut docs: Vec<ManualDoc> = Vec::new();
        for (id, text) in rows {
            match docs.iter_mut().find(|doc| doc.id == id) {
                Some(doc) => doc.localizations.push(text),
                None => docs.push(ManualDoc {
                    id,
                    localizations: vec![text],
                }),
            }
        }
        Self { docs }
    }

    pub fn is_empty(&self) -> bool {
        self.docs.is_empty()
    }

    /// Search the corpus with case-insensitive substring matching. Results
    /// rank first by the number of distinct keywords matched, then by
    /// weighted field hits (title > summary > body). When [language] is
    /// `Some`, each doc contributes only its resolved localization; when
    /// `None`, all localizations are searched.
    pub fn search(
        &self,
        keywords: &[String],
        language: Option<&str>,
        limit: usize,
    ) -> Result<Vec<ManualSearchHit>, ManualToolError> {
        let keywords: Vec<String> = keywords
            .iter()
            .map(|k| k.trim().to_lowercase())
            .filter(|k| !k.is_empty())
            .take(MAX_KEYWORDS)
            .collect();
        if keywords.is_empty() {
            return Err(ManualToolError::NoKeywords);
        }
        let limit = limit.clamp(1, MAX_LIMIT);

        let mut scored: Vec<(usize, usize, ManualSearchHit)> = Vec::new();
        for doc in &self.docs {
            let locales: Vec<&ManualDocText> = match language {
                Some(lang) => doc.resolve_locale(lang).into_iter().collect(),
                None => doc.localizations.iter().collect(),
            };
            for loc in locales {
                let title = loc.title.to_lowercase();
                let summary = loc.summary.to_lowercase();
                let body = loc.body.to_lowercase();

                let mut matched: Vec<String> = Vec::new();
                let mut field_score = 0usize;
                for keyword in &keywords {
                    let in_title = title.contains(keyword.as_str());
                    let in_summary = summary.contains(keyword.as_str());
                    let body_hits = body.matches(keyword.as_str()).count().min(3);
                    if !in_title && !in_summary && body_hits == 0 {
                        continue;
                    }
                    matched.push(keyword.clone());
                    field_score += 10 * in_title as usize + 5 * in_summary as usize + body_hits;
                }
                if matched.is_empty() {
                    continue;
                }

                let snippet = extract_snippet(&loc.body, &loc.summary, &keywords);
                scored.push((
                    matched.len(),
                    field_score,
                    ManualSearchHit {
                        id: doc.id.clone(),
                        locale: loc.locale.clone(),
                        title: loc.title.clone(),
                        url: doc.url(),
                        snippet,
                        matched_keywords: matched,
                    },
                ));
            }
        }

        scored.sort_by(|a, b| b.0.cmp(&a.0).then_with(|| b.1.cmp(&a.1)));
        Ok(scored
            .into_iter()
            .take(limit)
            .map(|(_, _, hit)| hit)
            .collect())
    }

    /// Fetch the full content of a doc by its path-joined [id].
    pub fn get(
        &self,
        id: &str,
        language: Option<&str>,
    ) -> Result<ManualDocContent, ManualToolError> {
        let id = id.trim().trim_matches('/');
        let doc = self.docs.iter().find(|doc| doc.id == id).ok_or_else(|| {
            let suggestions: Vec<&str> = self
                .docs
                .iter()
                .map(|doc| doc.id.as_str())
                .filter(|doc_id| {
                    !id.is_empty()
                        && (doc_id.contains(id)
                            || id
                                .split(['/', ' '])
                                .any(|part| part.len() >= 3 && doc_id.contains(part)))
                })
                .take(10)
                .collect();
            ManualToolError::DocNotFound(id.to_string(), suggestions.join(", "))
        })?;
        let loc = match language {
            Some(lang) => doc.resolve_locale(lang),
            None => doc.localizations.first(),
        };
        let Some(loc) = loc else {
            return Err(ManualToolError::DocNotFound(id.to_string(), String::new()));
        };
        Ok(ManualDocContent {
            id: doc.id.clone(),
            locale: loc.locale.clone(),
            title: loc.title.clone(),
            summary: loc.summary.clone(),
            url: doc.url(),
            content: loc.body.clone(),
        })
    }
}

/// Extract a single-line snippet around the first keyword match in [body],
/// falling back to the summary when no keyword matches the body.
fn extract_snippet(body: &str, summary: &str, keywords: &[String]) -> String {
    let lower = body.to_lowercase();
    let position = keywords
        .iter()
        .filter_map(|keyword| lower.find(keyword.as_str()))
        .min();
    let text = match position {
        Some(position) => {
            let start = floor_char_boundary(body, position.saturating_sub(SNIPPET_RADIUS));
            let end = ceil_char_boundary(body, (position + SNIPPET_RADIUS).min(body.len()));
            let mut snippet = String::new();
            if start > 0 {
                snippet.push('…');
            }
            snippet.push_str(body[start..end].trim());
            if end < body.len() {
                snippet.push('…');
            }
            snippet
        }
        None => summary.to_string(),
    };
    text.split_whitespace().collect::<Vec<_>>().join(" ")
}

fn floor_char_boundary(text: &str, mut index: usize) -> usize {
    while index > 0 && !text.is_char_boundary(index) {
        index -= 1;
    }
    index
}

fn ceil_char_boundary(text: &str, mut index: usize) -> usize {
    while index < text.len() && !text.is_char_boundary(index) {
        index += 1;
    }
    index
}

#[derive(Debug, Deserialize)]
pub struct SearchManualArgs {
    pub keywords: Vec<String>,
    pub language: Option<String>,
    pub limit: Option<usize>,
}

#[derive(Debug, Serialize)]
pub struct SearchManualOutput {
    pub results: Vec<ManualSearchHit>,
}

/// rig tool: multi-keyword, multi-lingual search over the bundled user manual.
#[derive(Clone)]
pub struct ManualSearchTool {
    corpus: Arc<ManualCorpus>,
    language: PromptLanguage,
}

impl ManualSearchTool {
    pub fn new(corpus: Arc<ManualCorpus>, language: PromptLanguage) -> Self {
        Self { corpus, language }
    }
}

impl PortableTool for ManualSearchTool {
    const NAME: &'static str = "search_manual";
    type Args = SearchManualArgs;
    type Output = SearchManualOutput;
    type Error = ManualToolError;

    fn description(&self) -> String {
        self.language
            .pick(
                include_str!("../prompt/tool/search_manual/en.prompt"),
                include_str!("../prompt/tool/search_manual/zh.prompt"),
            )
            .trim()
            .to_string()
    }

    fn parameters(&self) -> serde_json::Value {
        serde_json::json!({
            "type": "object",
            "properties": {
                "keywords": {
                    "type": "array",
                    "items": { "type": "string" },
                    "description": "1-5 short search terms; pages matching more keywords rank higher"
                },
                "language": {
                    "type": "string",
                    "description": "Optional language code (e.g. \"en\", \"zh\"); omit to search all languages"
                },
                "limit": {
                    "type": "integer",
                    "description": "Maximum number of results (default 8, max 20)"
                }
            },
            "required": ["keywords"]
        })
    }

    async fn call(&self, args: Self::Args) -> Result<Self::Output, Self::Error> {
        let _timer = ToolTimer::start(Self::NAME);
        let limit = args.limit.unwrap_or(DEFAULT_LIMIT);
        let results = self
            .corpus
            .search(&args.keywords, args.language.as_deref(), limit)?;
        Ok(SearchManualOutput { results })
    }
}

#[derive(Debug, Deserialize)]
pub struct GetManualDocArgs {
    pub id: String,
    pub language: Option<String>,
}

/// rig tool: read the full content of a manual page by its id.
#[derive(Clone)]
pub struct ManualDocTool {
    corpus: Arc<ManualCorpus>,
    language: PromptLanguage,
}

impl ManualDocTool {
    pub fn new(corpus: Arc<ManualCorpus>, language: PromptLanguage) -> Self {
        Self { corpus, language }
    }
}

impl PortableTool for ManualDocTool {
    const NAME: &'static str = "get_manual_doc";
    type Args = GetManualDocArgs;
    type Output = ManualDocContent;
    type Error = ManualToolError;

    fn description(&self) -> String {
        self.language
            .pick(
                include_str!("../prompt/tool/get_manual_doc/en.prompt"),
                include_str!("../prompt/tool/get_manual_doc/zh.prompt"),
            )
            .trim()
            .to_string()
    }

    fn parameters(&self) -> serde_json::Value {
        serde_json::json!({
            "type": "object",
            "properties": {
                "id": {
                    "type": "string",
                    "description": "Path-joined manual page id, e.g. \"fitting/modules\""
                },
                "language": {
                    "type": "string",
                    "description": "Optional language code (e.g. \"en\", \"zh\")"
                }
            },
            "required": ["id"]
        })
    }

    async fn call(&self, args: Self::Args) -> Result<Self::Output, Self::Error> {
        let _timer = ToolTimer::start(Self::NAME);
        self.corpus.get(&args.id, args.language.as_deref())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn doc(id: &str, locale: &str, title: &str, summary: &str, body: &str) -> ManualDoc {
        ManualDoc {
            id: id.to_string(),
            localizations: vec![ManualDocText {
                locale: locale.to_string(),
                title: title.to_string(),
                summary: summary.to_string(),
                body: body.to_string(),
            }],
        }
    }

    fn corpus() -> ManualCorpus {
        ManualCorpus::new(vec![
            doc(
                "fitting/modules",
                "en",
                "Modules",
                "Fitting modules to your ship.",
                "Modules consume CPU and powergrid. Online a module to save powergrid.",
            ),
            ManualDoc {
                id: "fitting/overloading".to_string(),
                localizations: vec![
                    ManualDocText {
                        locale: "en".to_string(),
                        title: "Overloading".to_string(),
                        summary: "Overloading racks.".to_string(),
                        body: "Overloading boosts module output but damages modules.".to_string(),
                    },
                    ManualDocText {
                        locale: "zh".to_string(),
                        title: "超载".to_string(),
                        summary: "超载装备槽。".to_string(),
                        body: "超载会提升装备性能，但会损伤装备。".to_string(),
                    },
                ],
            },
            doc(
                "characters/skills",
                "en",
                "Skill Levels",
                "Managing character skills.",
                "Skill levels affect module requirements and fitting stats.",
            ),
        ])
    }

    #[test]
    fn search_ranks_more_matched_keywords_first() {
        let hits = corpus()
            .search(&["modules".into(), "powergrid".into()], Some("en"), 10)
            .unwrap();
        assert_eq!(hits.first().unwrap().id, "fitting/modules");
        assert_eq!(hits.first().unwrap().matched_keywords.len(), 2);
        assert!(hits.iter().any(|h| h.id == "fitting/overloading"));
        assert_eq!(
            hits.iter()
                .find(|h| h.id == "fitting/overloading")
                .unwrap()
                .matched_keywords
                .len(),
            1
        );
    }

    #[test]
    fn search_title_hit_outranks_body_only() {
        let hits = corpus().search(&["skill".into()], Some("en"), 10).unwrap();
        assert_eq!(hits.first().unwrap().id, "characters/skills");
    }

    #[test]
    fn search_selects_language() {
        let hits = corpus().search(&["超载".into()], Some("zh"), 10).unwrap();
        assert_eq!(hits.len(), 1);
        assert_eq!(hits[0].id, "fitting/overloading");
        assert_eq!(hits[0].locale, "zh");
        assert_eq!(hits[0].title, "超载");

        let misses = corpus().search(&["超载".into()], Some("en"), 10).unwrap();
        assert!(misses.is_empty());
    }

    #[test]
    fn search_without_language_covers_all_locales() {
        let hits = corpus().search(&["overloading".into()], None, 10).unwrap();
        assert!(hits.iter().any(|h| h.locale == "en"));
        let zh_hits = corpus().search(&["超载".into()], None, 10).unwrap();
        assert_eq!(zh_hits.len(), 1);
    }

    #[test]
    fn search_language_prefix_falls_back_to_en() {
        let hits = corpus()
            .search(&["modules".into()], Some("en-US"), 10)
            .unwrap();
        assert!(!hits.is_empty());
        let hits = corpus()
            .search(&["modules".into()], Some("fr"), 10)
            .unwrap();
        assert!(hits.iter().all(|h| h.locale == "en"));
    }

    #[test]
    fn search_rejects_blank_keywords() {
        assert!(matches!(
            corpus().search(&["  ".into()], None, 10),
            Err(ManualToolError::NoKeywords)
        ));
        assert!(matches!(
            corpus().search(&[], None, 10),
            Err(ManualToolError::NoKeywords)
        ));
    }

    #[test]
    fn search_respects_limit() {
        let hits = corpus().search(&["module".into()], Some("en"), 1).unwrap();
        assert_eq!(hits.len(), 1);
    }

    #[test]
    fn snippet_centers_on_match_and_flattens_whitespace() {
        let body = format!("{}目标关键词{}", "前文 ".repeat(80), " 后文\n\n换行");
        let snippet = extract_snippet(&body, "summary", &["目标关键词".to_string()]);
        assert!(snippet.contains("目标关键词"));
        assert!(snippet.starts_with('…'));
        assert!(!snippet.contains('\n'));
    }

    #[test]
    fn snippet_falls_back_to_summary_without_body_match() {
        let snippet = extract_snippet("no match here", "the summary", &["absent".to_string()]);
        assert_eq!(snippet, "the summary");
    }

    #[test]
    fn get_returns_full_content_with_url() {
        let content = corpus().get("fitting/overloading", Some("zh")).unwrap();
        assert_eq!(content.locale, "zh");
        assert_eq!(content.url, "efa://manual/fitting/overloading");
        assert!(content.content.contains("损伤装备"));
    }

    #[test]
    fn get_tolerates_slashes_and_suggests_on_miss() {
        assert!(corpus().get("/fitting/modules/", Some("en")).is_ok());
        let err = corpus().get("fitting/missiles", None).unwrap_err();
        let message = err.to_string();
        assert!(message.contains("fitting/missiles"));
        assert!(message.contains("fitting/modules"));
    }

    #[test]
    fn from_rows_groups_localizations_by_doc_id() {
        let corpus = ManualCorpus::from_rows(vec![
            (
                "a".to_string(),
                ManualDocText {
                    locale: "en".to_string(),
                    title: "A".to_string(),
                    summary: String::new(),
                    body: "alpha".to_string(),
                },
            ),
            (
                "b".to_string(),
                ManualDocText {
                    locale: "en".to_string(),
                    title: "B".to_string(),
                    summary: String::new(),
                    body: "beta".to_string(),
                },
            ),
            (
                "a".to_string(),
                ManualDocText {
                    locale: "zh".to_string(),
                    title: "甲".to_string(),
                    summary: String::new(),
                    body: "阿尔法".to_string(),
                },
            ),
        ]);
        assert_eq!(corpus.docs.len(), 2);
        assert_eq!(corpus.docs[0].id, "a");
        assert_eq!(corpus.docs[0].localizations.len(), 2);
        assert_eq!(corpus.docs[1].localizations.len(), 1);
    }

    #[test]
    fn hit_url_uses_manual_link_scheme() {
        let hits = corpus()
            .search(&["modules".into()], Some("en"), 10)
            .unwrap();
        assert_eq!(hits[0].url, "efa://manual/fitting/modules");
    }

    #[test]
    fn tool_descriptions_follow_language() {
        let corpus = Arc::new(corpus());
        let en_search = ManualSearchTool::new(corpus.clone(), PromptLanguage::En);
        let zh_search = ManualSearchTool::new(corpus.clone(), PromptLanguage::Zh);
        assert_ne!(en_search.description(), zh_search.description());
        assert!(en_search.description().starts_with("Search the bundled"));
        assert!(zh_search.description().contains("用户手册"));
        let en_doc = ManualDocTool::new(corpus.clone(), PromptLanguage::En);
        let zh_doc = ManualDocTool::new(corpus, PromptLanguage::Zh);
        assert_ne!(en_doc.description(), zh_doc.description());
        assert!(zh_doc.description().contains("用户手册"));
    }
}
