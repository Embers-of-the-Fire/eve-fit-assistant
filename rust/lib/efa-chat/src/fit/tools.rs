use rig::tool::{IntoToolOutput, PortableDynamicTool, PortableTool, ToolExecutionError};
use serde::Deserialize;

use super::{
    AttrDetail, FitEditProposal, FitStatsReport, FitSummary, FitToolContext, FitToolError,
    FitValidationReport, ItemDetail, ToolTimer,
};

/// Erase a typed [`PortableTool`] into a runtime-defined dynamic tool, so the
/// fit toolset can be attached conditionally (rig's static `.tool()` builder
/// is type-state based and cannot be conditional).
fn erased<T>(tool: T) -> PortableDynamicTool
where
    T: PortableTool + Clone + 'static,
{
    PortableDynamicTool::new(
        T::NAME,
        tool.description(),
        tool.parameters(),
        move |args| {
            let tool = tool.clone();
            Box::pin(async move {
                let args = serde_json::from_value(args)
                    .map_err(|e| ToolExecutionError::invalid_args(e.to_string()))?;
                let output = tool.call(args).await.map_err(|e| tool.map_error(e))?;
                output.into_tool_output()
            })
        },
    )
}

/// All fit tools bound to one shared [context].
pub fn fit_tools(context: FitToolContext) -> Vec<PortableDynamicTool> {
    let mut tools: Vec<PortableDynamicTool> = vec![
        erased(GetCurrentFitTool::new(context.clone())),
        erased(GetFitStatsTool::new(context.clone())),
        erased(GetItemTool::new(context.clone())),
        erased(GetAttrTool::new(context.clone())),
        erased(ValidateFitTool::new(context.clone())),
        erased(ProposeFitEditTool::new(context.clone())),
    ];
    if context.has_callbacks() {
        tools.push(erased(SearchItemsTool::new(context.clone())));
        tools.push(erased(ListUserFitsTool::new(context.clone())));
        tools.push(erased(LoadFitTool::new(context)));
    }
    tools
}

#[derive(Clone)]
pub struct GetCurrentFitTool {
    context: FitToolContext,
}

impl GetCurrentFitTool {
    pub fn new(context: FitToolContext) -> Self {
        Self { context }
    }
}

#[derive(Debug, Deserialize)]
pub struct GetCurrentFitArgs {
    pub include_skills: Option<bool>,
}

impl PortableTool for GetCurrentFitTool {
    const NAME: &'static str = "get_current_fit";
    type Args = GetCurrentFitArgs;
    type Output = FitSummary;
    type Error = FitToolError;

    fn description(&self) -> String {
        self.context.tool_prompt(
            include_str!("../../prompt/tool/get_current_fit/en.prompt"),
            include_str!("../../prompt/tool/get_current_fit/zh.prompt"),
        )
    }

    fn parameters(&self) -> serde_json::Value {
        serde_json::json!({
            "type": "object",
            "properties": {
                "include_skills": {
                    "type": "boolean",
                    "description": "Also include the character's skill levels (default false)"
                }
            }
        })
    }

    async fn call(&self, args: Self::Args) -> Result<Self::Output, Self::Error> {
        let _timer = ToolTimer::start(Self::NAME);
        self.context
            .current_fit(args.include_skills.unwrap_or(false))
    }
}

#[derive(Clone)]
pub struct GetFitStatsTool {
    context: FitToolContext,
}

impl GetFitStatsTool {
    pub fn new(context: FitToolContext) -> Self {
        Self { context }
    }
}

#[derive(Debug, Deserialize)]
pub struct GetFitStatsArgs {}

impl PortableTool for GetFitStatsTool {
    const NAME: &'static str = "get_fit_stats";
    type Args = GetFitStatsArgs;
    type Output = FitStatsReport;
    type Error = FitToolError;

    fn description(&self) -> String {
        self.context.tool_prompt(
            include_str!("../../prompt/tool/get_fit_stats/en.prompt"),
            include_str!("../../prompt/tool/get_fit_stats/zh.prompt"),
        )
    }

    fn parameters(&self) -> serde_json::Value {
        serde_json::json!({ "type": "object", "properties": {} })
    }

    async fn call(&self, _args: Self::Args) -> Result<Self::Output, Self::Error> {
        let _timer = ToolTimer::start(Self::NAME);
        self.context.fit_stats()
    }
}

#[derive(Clone)]
pub struct GetItemTool {
    context: FitToolContext,
}

impl GetItemTool {
    pub fn new(context: FitToolContext) -> Self {
        Self { context }
    }
}

#[derive(Debug, Deserialize)]
pub struct GetItemArgs {
    pub item_type: String,
    pub index: Option<u32>,
}

impl PortableTool for GetItemTool {
    const NAME: &'static str = "get_item";
    type Args = GetItemArgs;
    type Output = ItemDetail;
    type Error = FitToolError;

    fn description(&self) -> String {
        self.context.tool_prompt(
            include_str!("../../prompt/tool/get_item/en.prompt"),
            include_str!("../../prompt/tool/get_item/zh.prompt"),
        )
    }

    fn parameters(&self) -> serde_json::Value {
        serde_json::json!({
            "type": "object",
            "properties": {
                "item_type": {
                    "type": "string",
                    "enum": ["hull", "module", "drone", "fighter", "implant", "booster", "character"],
                    "description": "Which section of the fit to inspect"
                },
                "index": {
                    "type": "integer",
                    "description": "0-based index within the section; required except for hull/character"
                }
            },
            "required": ["item_type"]
        })
    }

    async fn call(&self, args: Self::Args) -> Result<Self::Output, Self::Error> {
        let _timer = ToolTimer::start(Self::NAME);
        self.context
            .item_detail(&args.item_type, args.index.map(|i| i as usize))
    }
}

#[derive(Clone)]
pub struct GetAttrTool {
    context: FitToolContext,
}

impl GetAttrTool {
    pub fn new(context: FitToolContext) -> Self {
        Self { context }
    }
}

#[derive(Debug, Deserialize)]
pub struct GetAttrArgs {
    pub item_type: String,
    pub index: Option<u32>,
    pub attribute: String,
}

impl PortableTool for GetAttrTool {
    const NAME: &'static str = "get_attr";
    type Args = GetAttrArgs;
    type Output = AttrDetail;
    type Error = FitToolError;

    fn description(&self) -> String {
        self.context.tool_prompt(
            include_str!("../../prompt/tool/get_attr/en.prompt"),
            include_str!("../../prompt/tool/get_attr/zh.prompt"),
        )
    }

    fn parameters(&self) -> serde_json::Value {
        serde_json::json!({
            "type": "object",
            "properties": {
                "item_type": {
                    "type": "string",
                    "enum": ["hull", "module", "drone", "fighter", "implant", "booster", "character"],
                    "description": "Which section of the fit to inspect"
                },
                "index": {
                    "type": "integer",
                    "description": "0-based index within the section; required except for hull/character"
                },
                "attribute": {
                    "type": "string",
                    "description": "Dogma attribute name, e.g. \"shieldCapacity\" or \"damagePerSecondWithoutReload\""
                }
            },
            "required": ["item_type", "attribute"]
        })
    }

    async fn call(&self, args: Self::Args) -> Result<Self::Output, Self::Error> {
        let _timer = ToolTimer::start(Self::NAME);
        self.context.attr_detail(
            &args.item_type,
            args.index.map(|i| i as usize),
            &args.attribute,
        )
    }
}

#[derive(Clone)]
pub struct ValidateFitTool {
    context: FitToolContext,
}

impl ValidateFitTool {
    pub fn new(context: FitToolContext) -> Self {
        Self { context }
    }
}

#[derive(Debug, Deserialize)]
pub struct ValidateFitArgs {}

impl PortableTool for ValidateFitTool {
    const NAME: &'static str = "validate_fit";
    type Args = ValidateFitArgs;
    type Output = FitValidationReport;
    type Error = FitToolError;

    fn description(&self) -> String {
        self.context.tool_prompt(
            include_str!("../../prompt/tool/validate_fit/en.prompt"),
            include_str!("../../prompt/tool/validate_fit/zh.prompt"),
        )
    }

    fn parameters(&self) -> serde_json::Value {
        serde_json::json!({ "type": "object", "properties": {} })
    }

    async fn call(&self, _args: Self::Args) -> Result<Self::Output, Self::Error> {
        let _timer = ToolTimer::start(Self::NAME);
        self.context.validate()
    }
}

#[derive(Clone)]
pub struct ProposeFitEditTool {
    context: FitToolContext,
}

impl ProposeFitEditTool {
    pub fn new(context: FitToolContext) -> Self {
        Self { context }
    }
}

#[derive(Debug, Deserialize)]
pub struct ProposeFitEditArgs {
    pub edits: Vec<super::edit::FitEditOp>,
}

impl PortableTool for ProposeFitEditTool {
    const NAME: &'static str = "propose_fit_edit";
    type Args = ProposeFitEditArgs;
    type Output = FitEditProposal;
    type Error = FitToolError;

    fn description(&self) -> String {
        self.context.tool_prompt(
            include_str!("../../prompt/tool/propose_fit_edit/en.prompt"),
            include_str!("../../prompt/tool/propose_fit_edit/zh.prompt"),
        )
    }

    fn parameters(&self) -> serde_json::Value {
        serde_json::json!({
            "type": "object",
            "properties": {
                "edits": {
                    "type": "array",
                    "description": "Ordered list of edit operations to apply to a copy of the fit",
                    "items": {
                        "type": "object",
                        "properties": {
                            "op": {
                                "type": "string",
                                "enum": ["add_module", "remove_module", "set_module_charge", "set_module_state"]
                            },
                            "slot_type": {
                                "type": "string",
                                "enum": ["high", "medium", "low", "rig", "subsystem", "service"]
                            },
                            "index": { "type": "integer", "description": "Slot index within slot_type" },
                            "type_id": { "type": "integer", "description": "Item type id (add_module)" },
                            "state": { "type": "string", "enum": ["passive", "online", "active", "overload"] },
                            "charge_type_id": { "type": "integer", "description": "Charge type id, or omit to clear" }
                        },
                        "required": ["op"]
                    }
                }
            },
            "required": ["edits"]
        })
    }

    async fn call(&self, args: Self::Args) -> Result<Self::Output, Self::Error> {
        let _timer = ToolTimer::start(Self::NAME);
        self.context.propose_edit(&args.edits)
    }
}

#[derive(Clone)]
pub struct SearchItemsTool {
    context: FitToolContext,
}

impl SearchItemsTool {
    pub fn new(context: FitToolContext) -> Self {
        Self { context }
    }
}

#[derive(Debug, Deserialize)]
pub struct SearchItemsArgs {
    pub query: String,
    pub language: Option<String>,
}

impl PortableTool for SearchItemsTool {
    const NAME: &'static str = "search_items";
    type Args = SearchItemsArgs;
    type Output = serde_json::Value;
    type Error = FitToolError;

    fn description(&self) -> String {
        self.context.tool_prompt(
            include_str!("../../prompt/tool/search_items/en.prompt"),
            include_str!("../../prompt/tool/search_items/zh.prompt"),
        )
    }

    fn parameters(&self) -> serde_json::Value {
        serde_json::json!({
            "type": "object",
            "properties": {
                "query": {
                    "type": "string",
                    "description": "Item name fragment in the user's language, e.g. \"Large Shield Extender\""
                },
                "language": {
                    "type": "string",
                    "description": "Optional language code of the item name (e.g. \"en\", \"zh\"); omit to use the app's display language"
                }
            },
            "required": ["query"]
        })
    }

    async fn call(&self, args: Self::Args) -> Result<Self::Output, Self::Error> {
        let _timer = ToolTimer::start(Self::NAME);
        self.context
            .search_items(&args.query, args.language.as_deref())
            .await
    }
}

#[derive(Clone)]
pub struct ListUserFitsTool {
    context: FitToolContext,
}

impl ListUserFitsTool {
    pub fn new(context: FitToolContext) -> Self {
        Self { context }
    }
}

#[derive(Debug, Deserialize)]
pub struct ListUserFitsArgs {}

impl PortableTool for ListUserFitsTool {
    const NAME: &'static str = "list_user_fits";
    type Args = ListUserFitsArgs;
    type Output = serde_json::Value;
    type Error = FitToolError;

    fn description(&self) -> String {
        self.context.tool_prompt(
            include_str!("../../prompt/tool/list_user_fits/en.prompt"),
            include_str!("../../prompt/tool/list_user_fits/zh.prompt"),
        )
    }

    fn parameters(&self) -> serde_json::Value {
        serde_json::json!({ "type": "object", "properties": {} })
    }

    async fn call(&self, _args: Self::Args) -> Result<Self::Output, Self::Error> {
        let _timer = ToolTimer::start(Self::NAME);
        self.context.list_user_fits().await
    }
}

#[derive(Clone)]
pub struct LoadFitTool {
    context: FitToolContext,
}

impl LoadFitTool {
    pub fn new(context: FitToolContext) -> Self {
        Self { context }
    }
}

#[derive(Debug, Deserialize)]
pub struct LoadFitArgs {
    pub fit_id: String,
}

impl PortableTool for LoadFitTool {
    const NAME: &'static str = "load_fit";
    type Args = LoadFitArgs;
    type Output = FitSummary;
    type Error = FitToolError;

    fn description(&self) -> String {
        self.context.tool_prompt(
            include_str!("../../prompt/tool/load_fit/en.prompt"),
            include_str!("../../prompt/tool/load_fit/zh.prompt"),
        )
    }

    fn parameters(&self) -> serde_json::Value {
        serde_json::json!({
            "type": "object",
            "properties": {
                "fit_id": {
                    "type": "string",
                    "description": "The fit id as returned by `list_user_fits`"
                }
            },
            "required": ["fit_id"]
        })
    }

    async fn call(&self, args: Self::Args) -> Result<Self::Output, Self::Error> {
        let _timer = ToolTimer::start(Self::NAME);
        self.context.load_fit(&args.fit_id).await
    }
}
