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
        "Get the ship fit currently attached to this chat session: ship hull, fitted modules \
         grouped by slot with their state and charge, drones and fighters (grouped with counts), \
         implants and boosters. Pass `include_skills: true` to also list the character's skill \
         levels. Use this first when the user asks about their fit."
            .to_string()
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
        "Compute the headline stats of the attached fit by running the full fitting engine: \
         damage (DPS with/without reload, volley, alpha, drone/fighter DPS), defense (EHP per \
         layer, raw HP, effective resists), capacitor (capacity, peak recharge/load/delta, \
         depletion time in seconds - a negative or huge value means stable), mobility (velocity, \
         align time, mass, warp speed), fitting resources (CPU/powergrid output and free), and \
         targeting (max locked targets, scan resolution, signature radius). Use `get_item` or \
         `get_attr` for anything more specific."
            .to_string()
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
        "Inspect one calculated item of the attached fit with every attribute (id, name, base \
         value, computed value). `item_type` is one of: hull (the ship itself), module (fitted \
         high/medium/low/rig/subsystem modules), drone, fighter, implant, booster, character. \
         `index` selects the item within that section (0-based, in fitted order) and is required \
         for all sections except hull and character."
            .to_string()
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
        "Inspect a single dogma attribute of one calculated item: base vs computed value, \
         metadata (default value, whether higher is better), and the modifier tree explaining \
         which effects/skills/buffs changed it and by how much. `attribute` is the dogma \
         attribute name, e.g. \"shieldCapacity\", \"maxVelocity\", or patch attributes like \
         \"damagePerSecondWithoutReload\", \"ehp\", \"capacitorDepletesIn\". `item_type`/`index` \
         select the item exactly like `get_item`."
            .to_string()
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
        "Validate the attached fit against the fitting rules: turret/launcher hardpoint limits, \
         module-vs-ship group/type restrictions, rig size compatibility, duplicate booster \
         slots, charge size/capacity/group compatibility, missing charges, and mutually \
         exclusive active module groups. Returns errors and warnings; an empty list means the \
         fit is legal."
            .to_string()
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
        "Propose fit changes and preview the outcome WITHOUT modifying the user's actual fit. \
         Applies each edit to a copy of the attached fit and returns the projected stats and \
         validation issues. Edit ops: {\"op\":\"add_module\",\"slot_type\":\"high|medium|low|rig\",\
         \"type_id\":<int>,\"state\":\"active|online|passive|overload\"?,\"charge_type_id\":<int>?}; \
         {\"op\":\"remove_module\",\"slot_type\":...,\"index\":<int>}; \
         {\"op\":\"set_module_charge\",\"slot_type\":...,\"index\":<int>,\"charge_type_id\":<int>?}; \
         {\"op\":\"set_module_state\",\"slot_type\":...,\"index\":<int>,\"state\":...}. This is a \
         what-if simulation: the user must still make the change in the fitting editor. Use \
         `search_items` to resolve an item name to a `type_id` first."
            .to_string()
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
}

impl PortableTool for SearchItemsTool {
    const NAME: &'static str = "search_items";
    type Args = SearchItemsArgs;
    type Output = serde_json::Value;
    type Error = FitToolError;

    fn description(&self) -> String {
        "Search the game's item database by (localized) name substring. Returns up to 20 \
         matches with `type_id`, `name`, `group_id`, and `category_id`. Use this to resolve an \
         item the user mentions by name before reasoning about it; category 6 is ships, 7 \
         modules, 8 charges, 18 drones, 20 implants, 22 deployables."
            .to_string()
    }

    fn parameters(&self) -> serde_json::Value {
        serde_json::json!({
            "type": "object",
            "properties": {
                "query": {
                    "type": "string",
                    "description": "Item name fragment in the user's language, e.g. \"Large Shield Extender\""
                }
            },
            "required": ["query"]
        })
    }

    async fn call(&self, args: Self::Args) -> Result<Self::Output, Self::Error> {
        let _timer = ToolTimer::start(Self::NAME);
        self.context.search_items(&args.query).await
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
        "List the user's saved fits with `fit_id`, `name`, `ship_type_id`, and \
         `last_modified`. Use this when the user refers to one of their fits by name instead of \
         the currently attached one, then switch to it with `load_fit`."
            .to_string()
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
        "Switch the attached fit to one of the user's saved fits by `fit_id` (see \
         `list_user_fits`). The loaded fit becomes the current fit for all subsequent tool \
         calls, including within this same conversation turn; the tool returns its summary."
            .to_string()
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
