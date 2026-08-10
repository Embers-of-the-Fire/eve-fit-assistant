pub mod edit;
pub mod schema;
pub mod tools;

use std::collections::HashMap;
use std::future::Future;
use std::pin::Pin;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, RwLock};

// `web_time::Instant` is std's Instant on native targets and a
// `performance.now()` shim on wasm32, where `std::time::Instant` panics.
use web_time::Instant;

use eve_fit_os::calculate::item::{Item, SlotType};
use eve_fit_os::calculate::{Ship, calculate};
use eve_fit_os::constant::patches::attr as patch_attr;
use eve_fit_os::fit::{FitContainer, ItemState};
use eve_fit_os::protobuf::Database;
use rig::tool::ToolExecutionError;
use serde::Serialize;
use thiserror::Error;

use crate::core::config::PromptLanguage;

/// Times one chat tool call, logging a start record and — via [`Drop`] — a
/// completion record with the elapsed duration, so every exit path (including
/// early `?` returns) is covered.
pub(crate) struct ToolTimer {
    name: &'static str,
    started: Instant,
}

impl ToolTimer {
    pub(crate) fn start(name: &'static str) -> Self {
        log::debug!("[chat] tool `{name}` started");
        Self {
            name,
            started: Instant::now(),
        }
    }
}

impl Drop for ToolTimer {
    fn drop(&mut self) {
        log::debug!(
            "[chat] tool `{}` finished in {}ms",
            self.name,
            self.started.elapsed().as_millis()
        );
    }
}

/// Bidirectional dogma-attribute name lookup pushed from the app, which owns
/// the full attribute metadata. Names are matched case-insensitively.
#[derive(Debug, Default)]
pub struct AttributeNames {
    pub by_id: HashMap<i32, String>,
    pub by_name: HashMap<String, i32>,
}

impl AttributeNames {
    pub fn from_by_id(by_id: HashMap<i32, String>) -> Self {
        let by_name = by_id
            .iter()
            .map(|(id, name)| (name.to_lowercase(), *id))
            .collect();
        Self { by_id, by_name }
    }
}

/// A fit attached to a chat session, plus display names for the types it
/// references (modules, charges, drones, implants, skills, ...).
#[derive(Debug)]
pub struct ActiveFit {
    pub name: Option<String>,
    pub container: FitContainer,
    pub names: HashMap<i32, String>,
}

impl ActiveFit {
    fn type_ref(&self, type_id: i32) -> TypeRef {
        TypeRef {
            type_id,
            name: self.names.get(&type_id).cloned(),
        }
    }
}

/// Boxed future returned by the app-provided fit callbacks.
pub type FitToolFuture = Pin<Box<dyn Future<Output = String> + Send>>;

/// The `search_items` callback signature — see [`FitCallbacks::search_items`].
pub type SearchItemsCallback =
    Arc<dyn Fn(String, Option<String>, Option<String>) -> FitToolFuture + Send + Sync>;

/// App-provided callbacks backing the app-state fit tools (`search_items`,
/// `list_user_fits`, `load_fit`, `create_fit`, `apply_fit_edit`). All
/// callbacks return JSON strings.
#[derive(Clone)]
pub struct FitCallbacks {
    /// `(query, language, kind) -> [{type_id, name, group_id, category_id,
    /// slot_index?, slot_kind?}, ...]`; `language` is the localization to
    /// search (`None` selects the app's display language); `kind` is an
    /// optional item-kind filter (`ship`/`module`/`charge`/`drone`/`fighter`/
    /// `implant`/`booster`).
    pub search_items: SearchItemsCallback,
    /// `() -> [{fit_id, name, ship_type_id, last_modified}, ...]`
    pub list_fits: Arc<dyn Fn() -> FitToolFuture + Send + Sync>,
    /// `(fit_id) -> FitPayload JSON (see `schema::FitPayload`) or
    /// `{"error": ...}`; on success the payload becomes the attached fit.`
    pub load_fit: Arc<dyn Fn(String) -> FitToolFuture + Send + Sync>,
    /// `(ship_id, name, description) -> FitPayload JSON or `{"error": ...}`;
    /// on success the new fit is saved by the app and becomes the attached
    /// fit.`
    pub create_fit: Arc<dyn Fn(i32, String, Option<String>) -> FitToolFuture + Send + Sync>,
    /// `(ops_json) -> FitPayload JSON or `{"error": ...}`; `ops_json` is the
    /// serialized list of edit ops (see `edit::FitEditOp`) that validated
    /// against the attached fit. The app persists them onto the attached fit
    /// and returns its updated payload, which becomes the attached fit.`
    pub apply_fit_edit: Arc<dyn Fn(String) -> FitToolFuture + Send + Sync>,
}

/// Shared, cheaply-clonable handle through which the fit tools reach the
/// engine database and the currently attached fit.
#[derive(Clone)]
pub struct FitToolContext {
    engine: Arc<Database>,
    active: Arc<RwLock<Option<ActiveFit>>>,
    active_order: Arc<ActiveFitOrder>,
    attr_names: Arc<AttributeNames>,
    callbacks: Option<Arc<FitCallbacks>>,
    language: PromptLanguage,
}

/// Last-writer-wins (by request start order) ordering state for
/// callback-backed active-fit replacements. `load_fit`, `create_fit`, and
/// `apply_edit` each await an app callback before installing the returned
/// fit; a ticket taken before the await ensures a stale callback response
/// cannot overwrite a fit attached by a request that started later.
#[derive(Debug, Default)]
struct ActiveFitOrder {
    next: AtomicU64,
    committed: AtomicU64,
}

impl ActiveFitOrder {
    /// Issue a ticket for a replacement that is about to await its app
    /// callback. Tickets are monotonic in request start order.
    fn begin(&self) -> u64 {
        self.next.fetch_add(1, Ordering::Relaxed) + 1
    }

    /// Claim the right to install the fit produced by the request holding
    /// [ticket]. Succeeds only if no replacement that started later has
    /// already committed; on success [ticket] becomes the latest committed
    /// ticket.
    fn try_commit(&self, ticket: u64) -> bool {
        let mut current = self.committed.load(Ordering::Acquire);
        loop {
            if ticket <= current {
                return false;
            }
            match self.committed.compare_exchange_weak(
                current,
                ticket,
                Ordering::AcqRel,
                Ordering::Acquire,
            ) {
                Ok(_) => return true,
                Err(actual) => current = actual,
            }
        }
    }
}

impl FitToolContext {
    pub fn new(
        engine: Arc<Database>,
        active: Arc<RwLock<Option<ActiveFit>>>,
        attr_names: Arc<AttributeNames>,
    ) -> Self {
        Self {
            engine,
            active,
            active_order: Arc::new(ActiveFitOrder::default()),
            attr_names,
            callbacks: None,
            language: PromptLanguage::default(),
        }
    }

    pub fn with_callbacks(mut self, callbacks: Arc<FitCallbacks>) -> Self {
        self.callbacks = Some(callbacks);
        self
    }

    pub fn has_callbacks(&self) -> bool {
        self.callbacks.is_some()
    }

    /// Select the language of the bundled tool description prompts.
    pub fn with_language(mut self, language: PromptLanguage) -> Self {
        self.language = language;
        self
    }

    /// Select a bundled tool description by the session language.
    pub(crate) fn tool_prompt(&self, en: &'static str, zh: &'static str) -> String {
        self.language.pick(en, zh).trim().to_string()
    }

    fn with_active<R>(&self, f: impl FnOnce(&ActiveFit) -> R) -> Result<R, FitToolError> {
        let guard = self.active.read().unwrap_or_else(|e| e.into_inner());
        let Some(fit) = guard.as_ref() else {
            return Err(FitToolError::NoActiveFit);
        };
        Ok(f(fit))
    }

    /// Take a ticket for a callback-backed active-fit replacement. Call
    /// before awaiting the app callback; pass the ticket to
    /// [`Self::commit_active`] with the callback's fit.
    fn begin_active_replacement(&self) -> u64 {
        self.active_order.begin()
    }

    /// Install [fit] as the attached fit for the request holding [ticket].
    /// Returns `false` — dropping the stale callback response — when a
    /// replacement that started after [ticket] was taken has already
    /// committed, so a slow callback cannot overwrite a newer attached fit.
    fn commit_active(&self, ticket: u64, fit: ActiveFit) -> bool {
        let mut guard = self.active.write().unwrap_or_else(|e| e.into_inner());
        if !self.active_order.try_commit(ticket) {
            return false;
        }
        *guard = Some(fit);
        true
    }

    /// Run the engine on the active fit and hand the calculated ship to [f].
    fn calculate_active<R>(
        &self,
        f: impl FnOnce(&ActiveFit, &Ship) -> R,
    ) -> Result<R, FitToolError> {
        self.with_active(|fit| {
            let started = Instant::now();
            let ship = calculate(&fit.container, self.engine.as_ref());
            log::debug!(
                "[chat] engine calculate finished in {}ms",
                started.elapsed().as_millis()
            );
            f(fit, &ship)
        })
    }

    fn attr_name(&self, attribute_id: i32) -> Option<String> {
        self.attr_names.by_id.get(&attribute_id).cloned()
    }
}

#[derive(Debug, Error)]
pub enum FitToolError {
    #[error("no fit is currently attached to this chat session")]
    NoActiveFit,
    #[error(
        "unknown item section `{0}`; expected one of: hull, module, drone, fighter, implant, booster, character"
    )]
    UnknownSection(String),
    #[error("index {index} out of range for section `{section}` (size {len})")]
    IndexOutOfRange {
        section: String,
        index: usize,
        len: usize,
    },
    #[error("unknown attribute `{name}`; similar attributes: {suggestions}")]
    UnknownAttribute { name: String, suggestions: String },
    #[error("attribute {0} is not present on the selected item")]
    AttributeNotPresent(i32),
    #[error("app-state callbacks are not available in this session")]
    CallbacksUnavailable,
    #[error("invalid payload from the app: {0}")]
    BadPayload(String),
    #[error("{0}")]
    Superseded(String),
}

/// Surface fit tool failures to the model verbatim. rig's default
/// `map_error` goes through `ToolExecutionError::from_error`, which redacts
/// the model-visible output to the generic "the tool failed"; the
/// [`FitToolError`] messages are deliberately actionable (e.g. attribute
/// suggestions) and must reach the model so it can self-correct.
impl From<FitToolError> for ToolExecutionError {
    fn from(error: FitToolError) -> Self {
        let message = error.to_string();
        match error {
            FitToolError::NoActiveFit => Self::not_found(message),
            FitToolError::UnknownSection(_)
            | FitToolError::IndexOutOfRange { .. }
            | FitToolError::UnknownAttribute { .. }
            | FitToolError::AttributeNotPresent(_) => Self::invalid_args(message),
            FitToolError::CallbacksUnavailable
            | FitToolError::BadPayload(_)
            | FitToolError::Superseded(_) => Self::other(message),
        }
    }
}

#[derive(Debug, Clone, Serialize)]
pub struct TypeRef {
    pub type_id: i32,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub name: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct ModuleEntry {
    pub slot_type: String,
    pub index: i32,
    pub item: TypeRef,
    pub state: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub charge: Option<TypeRef>,
}

#[derive(Debug, Clone, Serialize)]
pub struct DroneGroupEntry {
    pub item: TypeRef,
    pub count: usize,
    pub state: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct FighterGroupEntry {
    pub item: TypeRef,
    pub count: usize,
    pub ability: u8,
}

#[derive(Debug, Clone, Serialize)]
pub struct IndexedTypeRef {
    pub index: i32,
    #[serde(flatten)]
    pub item: TypeRef,
}

#[derive(Debug, Clone, Serialize)]
pub struct SkillEntry {
    pub type_id: i32,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub name: Option<String>,
    pub level: u8,
}

#[derive(Debug, Clone, Serialize)]
pub struct FitSummary {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub name: Option<String>,
    pub ship: TypeRef,
    pub modules: Vec<ModuleEntry>,
    pub drones: Vec<DroneGroupEntry>,
    pub fighters: Vec<FighterGroupEntry>,
    pub implants: Vec<IndexedTypeRef>,
    pub boosters: Vec<IndexedTypeRef>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub skills: Option<Vec<SkillEntry>>,
}

#[derive(Debug, Clone, Serialize)]
pub struct StatEntry {
    pub key: String,
    pub attribute_id: i32,
    pub value: f64,
}

#[derive(Debug, Clone, Serialize)]
pub struct StatSection {
    pub section: String,
    pub entries: Vec<StatEntry>,
}

#[derive(Debug, Clone, Serialize)]
pub struct FitStatsReport {
    pub sections: Vec<StatSection>,
}

#[derive(Debug, Clone, Serialize)]
pub struct AttrValue {
    pub attribute_id: i32,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub name: Option<String>,
    pub base_value: f64,
    pub value: f64,
}

#[derive(Debug, Clone, Serialize)]
pub struct ItemDetail {
    pub item: TypeRef,
    pub section: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub index: Option<i32>,
    pub state: String,
    pub max_state: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub charge: Option<TypeRef>,
    pub attributes: Vec<AttrValue>,
}

#[derive(Debug, Clone, Serialize)]
pub struct ModifierEntry {
    pub operator: String,
    pub penalized: bool,
    pub source: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub source_attribute_id: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub source_attribute_name: Option<String>,
    pub original_value: f64,
    pub normalized_value: f64,
    pub penalized_value: f64,
}

#[derive(Debug, Clone, Serialize)]
pub struct AttrDetail {
    pub attribute_id: i32,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub name: Option<String>,
    pub base_value: f64,
    pub value: f64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub default_value: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub high_is_good: Option<bool>,
    pub modifiers: Vec<ModifierEntry>,
}

#[derive(Debug, Clone, Serialize)]
pub struct ValidationIssueEntry {
    pub slot_type: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub index: Option<i32>,
    pub severity: String,
    pub code: String,
    pub details: serde_json::Value,
}

#[derive(Debug, Clone, Serialize)]
pub struct FitValidationReport {
    pub issues: Vec<ValidationIssueEntry>,
}

/// The outcome of a batch of fit edits applied to the attached fit: the
/// per-edit results plus the stats and validation of the edited fit.
#[derive(Debug, Clone, Serialize)]
pub struct FitEditApplyReport {
    /// Human-readable description of each edit that was applied.
    pub applied: Vec<String>,
    /// Edits that could not be applied, with the reason.
    pub rejected: Vec<String>,
    /// Headline stats of the fit after the edits.
    pub after: FitStatsReport,
    /// Validation issues of the fit after the edits.
    pub validation: FitValidationReport,
    /// Whether the applied edits were persisted to the user's fit. `false`
    /// only when every edit was rejected (nothing to persist).
    pub persisted: bool,
}

fn state_name(state: ItemState) -> String {
    match state {
        ItemState::Passive => "passive",
        ItemState::Online => "online",
        ItemState::Active => "active",
        ItemState::Overload => "overload",
    }
    .to_string()
}

fn effect_category_name(category: eve_fit_os::calculate::item::EffectCategory) -> String {
    use eve_fit_os::calculate::item::EffectCategory as C;
    match category {
        C::Passive => "passive",
        C::Online => "online",
        C::Active => "active",
        C::Overload => "overload",
        C::Target => "target",
        C::Area => "area",
        C::Dungeon => "dungeon",
        C::System => "system",
    }
    .to_string()
}

fn slot_type_name(slot_type: SlotType) -> String {
    match slot_type {
        SlotType::High => "high",
        SlotType::Medium => "medium",
        SlotType::Low => "low",
        SlotType::Rig => "rig",
        SlotType::SubSystem => "subsystem",
        SlotType::Service => "service",
        SlotType::TacticalMode => "tactical_mode",
        SlotType::DroneBay { .. } => "drone",
        SlotType::Fighter { .. } => "fighter",
        SlotType::Charge => "charge",
        SlotType::Implant => "implant",
        SlotType::Booster => "booster",
        SlotType::Fake => "fake",
    }
    .to_string()
}

fn item_slot_type_name(slot_type: eve_fit_os::fit::ItemSlotType) -> String {
    use eve_fit_os::fit::ItemSlotType as S;
    match slot_type {
        S::High => "high",
        S::Medium => "medium",
        S::Low => "low",
        S::Rig => "rig",
        S::SubSystem => "subsystem",
        S::Service => "service",
        S::TacticalMode => "tactical_mode",
    }
    .to_string()
}

impl FitToolContext {
    pub fn current_fit(&self, include_skills: bool) -> Result<FitSummary, FitToolError> {
        self.with_active(|fit| {
            let mut summary = self.summarize(fit);
            if include_skills {
                let mut skills: Vec<SkillEntry> = fit
                    .container
                    .skills
                    .iter()
                    .map(|(type_id, level)| SkillEntry {
                        type_id: *type_id,
                        name: fit.names.get(type_id).cloned(),
                        level: *level,
                    })
                    .collect();
                skills.sort_by_key(|skill| skill.type_id);
                summary.skills = Some(skills);
            }
            summary
        })
    }

    pub fn fit_stats(&self) -> Result<FitStatsReport, FitToolError> {
        self.calculate_active(|_fit, ship| self.stats_report(ship))
    }

    fn stats_report(&self, ship: &Ship) -> FitStatsReport {
        let hull = |id: i32| hull_attr(ship, id);
        let resist = |id: i32| hull(id).map(|resonance| 1.0 - resonance);
        let mut sections = Vec::new();
        let mut section = |name: &str, entries: Vec<(&str, i32, Option<f64>)>| {
            let entries: Vec<StatEntry> = entries
                .into_iter()
                .filter_map(|(key, id, value)| {
                    value.map(|value| StatEntry {
                        key: key.to_string(),
                        attribute_id: id,
                        value,
                    })
                })
                .collect();
            if !entries.is_empty() {
                sections.push(StatSection {
                    section: name.to_string(),
                    entries,
                });
            }
        };

        let damage = |id: i32| Some(hull(id).unwrap_or(0.0));
        section(
            "damage",
            vec![
                (
                    "dpsWithoutReload",
                    patch_attr::ATTR_DAMAGE_PER_SECOND_WITHOUT_RELOAD,
                    damage(patch_attr::ATTR_DAMAGE_PER_SECOND_WITHOUT_RELOAD),
                ),
                (
                    "dpsWithReload",
                    patch_attr::ATTR_DAMAGE_PER_SECOND_WITH_RELOAD,
                    damage(patch_attr::ATTR_DAMAGE_PER_SECOND_WITH_RELOAD),
                ),
                (
                    "volley",
                    patch_attr::ATTR_DAMAGE_VOLLEY,
                    damage(patch_attr::ATTR_DAMAGE_VOLLEY),
                ),
                (
                    "alpha",
                    patch_attr::ATTR_DAMAGE_ALPHA,
                    damage(patch_attr::ATTR_DAMAGE_ALPHA),
                ),
                (
                    "droneDps",
                    patch_attr::ATTR_DRONE_DAMAGE_PER_SECOND,
                    damage(patch_attr::ATTR_DRONE_DAMAGE_PER_SECOND),
                ),
                (
                    "fighterDps",
                    patch_attr::ATTR_FIGHTER_DAMAGE_PER_SECOND,
                    damage(patch_attr::ATTR_FIGHTER_DAMAGE_PER_SECOND),
                ),
            ],
        );

        const SHIELD_HP: i32 = 263;
        const ARMOR_HP: i32 = 265;
        const HULL_HP: i32 = 9;
        section(
            "defense",
            vec![
                ("ehp", patch_attr::ATTR_EHP, hull(patch_attr::ATTR_EHP)),
                (
                    "shieldEhp",
                    patch_attr::ATTR_SHIELD_EHP,
                    hull(patch_attr::ATTR_SHIELD_EHP),
                ),
                (
                    "armorEhp",
                    patch_attr::ATTR_ARMOR_EHP,
                    hull(patch_attr::ATTR_ARMOR_EHP),
                ),
                (
                    "hullEhp",
                    patch_attr::ATTR_HULL_EHP,
                    hull(patch_attr::ATTR_HULL_EHP),
                ),
                ("shieldHp", SHIELD_HP, hull(SHIELD_HP)),
                ("armorHp", ARMOR_HP, hull(ARMOR_HP)),
                ("hullHp", HULL_HP, hull(HULL_HP)),
                (
                    "shieldEmResist",
                    patch_attr::ATTR_SHIELD_EM_DAMAGE_EFFECTIVE_RESONANCE,
                    resist(patch_attr::ATTR_SHIELD_EM_DAMAGE_EFFECTIVE_RESONANCE),
                ),
                (
                    "shieldThermalResist",
                    patch_attr::ATTR_SHIELD_THERMAL_DAMAGE_EFFECTIVE_RESONANCE,
                    resist(patch_attr::ATTR_SHIELD_THERMAL_DAMAGE_EFFECTIVE_RESONANCE),
                ),
                (
                    "shieldKineticResist",
                    patch_attr::ATTR_SHIELD_KINETIC_DAMAGE_EFFECTIVE_RESONANCE,
                    resist(patch_attr::ATTR_SHIELD_KINETIC_DAMAGE_EFFECTIVE_RESONANCE),
                ),
                (
                    "shieldExplosiveResist",
                    patch_attr::ATTR_SHIELD_EXPLOSIVE_DAMAGE_EFFECTIVE_RESONANCE,
                    resist(patch_attr::ATTR_SHIELD_EXPLOSIVE_DAMAGE_EFFECTIVE_RESONANCE),
                ),
                (
                    "armorEmResist",
                    patch_attr::ATTR_ARMOR_EM_DAMAGE_EFFECTIVE_RESONANCE,
                    resist(patch_attr::ATTR_ARMOR_EM_DAMAGE_EFFECTIVE_RESONANCE),
                ),
                (
                    "armorThermalResist",
                    patch_attr::ATTR_ARMOR_THERMAL_DAMAGE_EFFECTIVE_RESONANCE,
                    resist(patch_attr::ATTR_ARMOR_THERMAL_DAMAGE_EFFECTIVE_RESONANCE),
                ),
                (
                    "armorKineticResist",
                    patch_attr::ATTR_ARMOR_KINETIC_DAMAGE_EFFECTIVE_RESONANCE,
                    resist(patch_attr::ATTR_ARMOR_KINETIC_DAMAGE_EFFECTIVE_RESONANCE),
                ),
                (
                    "armorExplosiveResist",
                    patch_attr::ATTR_ARMOR_EXPLOSIVE_DAMAGE_EFFECTIVE_RESONANCE,
                    resist(patch_attr::ATTR_ARMOR_EXPLOSIVE_DAMAGE_EFFECTIVE_RESONANCE),
                ),
                (
                    "hullEmResist",
                    patch_attr::ATTR_HULL_EM_DAMAGE_EFFECTIVE_RESONANCE,
                    resist(patch_attr::ATTR_HULL_EM_DAMAGE_EFFECTIVE_RESONANCE),
                ),
                (
                    "hullThermalResist",
                    patch_attr::ATTR_HULL_THERMAL_DAMAGE_EFFECTIVE_RESONANCE,
                    resist(patch_attr::ATTR_HULL_THERMAL_DAMAGE_EFFECTIVE_RESONANCE),
                ),
                (
                    "hullKineticResist",
                    patch_attr::ATTR_HULL_KINETIC_DAMAGE_EFFECTIVE_RESONANCE,
                    resist(patch_attr::ATTR_HULL_KINETIC_DAMAGE_EFFECTIVE_RESONANCE),
                ),
                (
                    "hullExplosiveResist",
                    patch_attr::ATTR_HULL_EXPLOSIVE_DAMAGE_EFFECTIVE_RESONANCE,
                    resist(patch_attr::ATTR_HULL_EXPLOSIVE_DAMAGE_EFFECTIVE_RESONANCE),
                ),
            ],
        );

        const CAPACITOR_CAPACITY: i32 = 482;
        section(
            "capacitor",
            vec![
                ("capacity", CAPACITOR_CAPACITY, hull(CAPACITOR_CAPACITY)),
                (
                    "peakRecharge",
                    patch_attr::ATTR_CAPACITOR_PEAK_RECHARGE,
                    hull(patch_attr::ATTR_CAPACITOR_PEAK_RECHARGE),
                ),
                (
                    "peakLoad",
                    patch_attr::ATTR_CAPACITOR_PEAK_LOAD,
                    hull(patch_attr::ATTR_CAPACITOR_PEAK_LOAD),
                ),
                (
                    "peakDelta",
                    patch_attr::ATTR_CAPACITOR_PEAK_DELTA,
                    hull(patch_attr::ATTR_CAPACITOR_PEAK_DELTA),
                ),
                (
                    "depletesIn",
                    patch_attr::ATTR_CAPACITOR_DEPLETES_IN,
                    hull(patch_attr::ATTR_CAPACITOR_DEPLETES_IN),
                ),
            ],
        );

        const MAX_VELOCITY: i32 = 37;
        const MASS: i32 = 4;
        const WARP_SPEED_MULTIPLIER: i32 = 1281;
        section(
            "mobility",
            vec![
                ("maxVelocity", MAX_VELOCITY, hull(MAX_VELOCITY)),
                (
                    "alignTime",
                    patch_attr::ATTR_ALIGN_TIME,
                    hull(patch_attr::ATTR_ALIGN_TIME),
                ),
                ("mass", MASS, hull(MASS)),
                (
                    "warpSpeedMultiplier",
                    WARP_SPEED_MULTIPLIER,
                    hull(WARP_SPEED_MULTIPLIER),
                ),
            ],
        );

        const CPU_OUTPUT: i32 = 48;
        const POWER_OUTPUT: i32 = 11;
        section(
            "fitting",
            vec![
                ("cpuOutput", CPU_OUTPUT, hull(CPU_OUTPUT)),
                (
                    "cpuFree",
                    patch_attr::ATTR_CPU_FREE,
                    hull(patch_attr::ATTR_CPU_FREE),
                ),
                ("powerOutput", POWER_OUTPUT, hull(POWER_OUTPUT)),
                (
                    "powerFree",
                    patch_attr::ATTR_POWER_FREE,
                    hull(patch_attr::ATTR_POWER_FREE),
                ),
            ],
        );

        const MAX_LOCKED_TARGETS: i32 = 192;
        const SCAN_RESOLUTION: i32 = 564;
        const SIGNATURE_RADIUS: i32 = 552;
        section(
            "targeting",
            vec![
                (
                    "maxLockedTargets",
                    MAX_LOCKED_TARGETS,
                    hull(MAX_LOCKED_TARGETS),
                ),
                ("scanResolution", SCAN_RESOLUTION, hull(SCAN_RESOLUTION)),
                ("signatureRadius", SIGNATURE_RADIUS, hull(SIGNATURE_RADIUS)),
            ],
        );

        FitStatsReport { sections }
    }

    pub fn item_detail(
        &self,
        section: &str,
        index: Option<usize>,
    ) -> Result<ItemDetail, FitToolError> {
        self.calculate_active(|fit, ship| {
            let item = select_item(ship, section, index)?;
            Ok(item_detail(fit, self, item))
        })?
    }

    pub fn attr_detail(
        &self,
        section: &str,
        index: Option<usize>,
        attribute: &str,
    ) -> Result<AttrDetail, FitToolError> {
        let attribute_id = self
            .attr_names
            .by_name
            .get(&attribute.to_lowercase())
            .copied()
            .ok_or_else(|| FitToolError::UnknownAttribute {
                name: attribute.to_string(),
                suggestions: self.suggest_attributes(attribute),
            })?;
        self.calculate_active(|fit, ship| {
            let item = select_item(ship, section, index)?;
            let detail = attr_detail(fit, self, item, attribute_id)?;
            Ok(detail)
        })?
    }

    fn suggest_attributes(&self, name: &str) -> String {
        let needle = name.to_lowercase();
        let mut suggestions: Vec<&String> = self
            .attr_names
            .by_name
            .keys()
            .filter(|key| key.contains(&needle))
            .collect();
        suggestions.sort();
        suggestions.truncate(8);
        if suggestions.is_empty() {
            "none".to_string()
        } else {
            suggestions
                .into_iter()
                .cloned()
                .collect::<Vec<_>>()
                .join(", ")
        }
    }

    pub fn validate(&self) -> Result<FitValidationReport, FitToolError> {
        self.calculate_active(|fit, ship| {
            let issues =
                eve_fit_os::validate::validate_fit(&fit.container, ship, self.engine.as_ref());
            FitValidationReport {
                issues: issues.into_iter().map(validation_issue_entry).collect(),
            }
        })
    }

    /// Apply [ops] to the attached fit and persist them through the app
    /// callback. Ops are first validated against a copy of the fit; the
    /// validated ops are then forwarded to the app, which applies them to the
    /// stored fit and returns its updated payload, replacing the attached fit
    /// for subsequent tool calls (including within the same turn). The
    /// reported stats and validation describe the payload the app returned.
    /// If a concurrent replacement attached a newer fit while the callback
    /// was in flight, the stale response is dropped instead of overwriting
    /// the newer fit, and a [`FitToolError::Superseded`] error tells the
    /// model the edits were saved but the edited fit is not attached.
    pub async fn apply_edit(
        &self,
        ops: &[edit::FitEditOp],
    ) -> Result<FitEditApplyReport, FitToolError> {
        let result = self
            .with_active(|fit| edit::apply_edit_ops(&fit.container, ops, self.engine.as_ref()))?;
        if !result.applied_ops.is_empty() {
            let Some(callbacks) = &self.callbacks else {
                return Err(FitToolError::CallbacksUnavailable);
            };
            let ticket = self.begin_active_replacement();
            let ops_json = serde_json::to_string(&result.applied_ops)
                .map_err(|e| FitToolError::BadPayload(e.to_string()))?;
            let started = Instant::now();
            let raw = (callbacks.apply_fit_edit)(ops_json).await;
            log::debug!(
                "[chat] apply_fit_edit: Dart callback returned in {}ms",
                started.elapsed().as_millis()
            );
            let payload = parse_callback_fit_payload(&raw)?;
            let active = payload.into_active();
            let (after, validation) = self.calculate_report(&active.container);
            if !self.commit_active(ticket, active) {
                log::debug!(
                    "[chat] apply_fit_edit: dropped stale callback response; \
                     a newer fit was attached while the edit was in flight"
                );
                // The app already saved the edits; the message must make
                // clear the report was discarded and the attached fit did
                // not change.
                return Err(FitToolError::Superseded(
                    "the edits were applied and saved, but the edited fit is not the attached \
                     fit: a newer fit was attached while the edit was in flight; call \
                     get_current_fit to see the attached fit"
                        .to_string(),
                ));
            }
            return Ok(FitEditApplyReport {
                applied: result.applied,
                rejected: result.rejected,
                after,
                validation,
                persisted: true,
            });
        }
        let (after, validation) = self.calculate_report(&result.container);
        Ok(FitEditApplyReport {
            applied: result.applied,
            rejected: result.rejected,
            after,
            validation,
            persisted: false,
        })
    }

    /// Calculate [container] and build the stats and validation reports for
    /// the resulting ship.
    fn calculate_report(&self, container: &FitContainer) -> (FitStatsReport, FitValidationReport) {
        let started = Instant::now();
        let ship = calculate(container, self.engine.as_ref());
        log::debug!(
            "[chat] engine calculate finished in {}ms",
            started.elapsed().as_millis()
        );
        let after = self.stats_report(&ship);
        let issues = eve_fit_os::validate::validate_fit(container, &ship, self.engine.as_ref());
        (
            after,
            FitValidationReport {
                issues: issues.into_iter().map(validation_issue_entry).collect(),
            },
        )
    }

    /// Create a new saved fit through the app callback, making it the
    /// attached fit for subsequent tool calls (including within the same
    /// turn). If a concurrent replacement attached a newer fit while the
    /// callback was in flight, the stale response is dropped instead of
    /// overwriting the newer fit, and a [`FitToolError::Superseded`] error
    /// tells the model the created fit is saved but not attached.
    pub async fn create_fit(
        &self,
        ship_id: i32,
        name: &str,
        description: Option<String>,
    ) -> Result<FitSummary, FitToolError> {
        let Some(callbacks) = &self.callbacks else {
            return Err(FitToolError::CallbacksUnavailable);
        };
        let ticket = self.begin_active_replacement();
        let started = Instant::now();
        let raw = (callbacks.create_fit)(ship_id, name.to_string(), description).await;
        log::debug!(
            "[chat] create_fit: Dart callback returned in {}ms",
            started.elapsed().as_millis()
        );
        let payload = parse_callback_fit_payload(&raw)?;
        let created_id = payload.fit_id.clone();
        let active = payload.into_active();
        let summary = self.summarize(&active);
        if self.commit_active(ticket, active) {
            return Ok(summary);
        }
        log::debug!(
            "[chat] create_fit: dropped stale callback response; \
             a newer fit was attached while the create was in flight"
        );
        // The app already saved the new fit; the message must steer the model
        // away from retrying the create (which would save a duplicate).
        let created = match &created_id {
            Some(id) => format!("fit `{name}` (fit_id `{id}`)"),
            None => format!("fit `{name}`"),
        };
        Err(FitToolError::Superseded(format!(
            "{created} was created and saved, but is not the attached fit: a newer fit was \
             attached while the create was in flight; use list_user_fits to find it instead of \
             creating another one"
        )))
    }

    /// Search the app's item database by (localized) name substring.
    /// [language] selects the localization to search (`None` defers to the
    /// app's display language); [kind] optionally restricts results to one
    /// item kind (`ship`/`module`/`charge`/`drone`/`fighter`/`implant`/
    /// `booster`).
    pub async fn search_items(
        &self,
        query: &str,
        language: Option<&str>,
        kind: Option<&str>,
    ) -> Result<serde_json::Value, FitToolError> {
        let Some(callbacks) = &self.callbacks else {
            return Err(FitToolError::CallbacksUnavailable);
        };
        let started = Instant::now();
        let raw = (callbacks.search_items)(
            query.to_string(),
            language.map(|l| l.to_string()),
            kind.map(|k| k.to_string()),
        )
        .await;
        log::debug!(
            "[chat] search_items: Dart callback returned in {}ms",
            started.elapsed().as_millis()
        );
        serde_json::from_str(&raw).map_err(|e| FitToolError::BadPayload(e.to_string()))
    }

    /// List the user's saved fits.
    pub async fn list_user_fits(&self) -> Result<serde_json::Value, FitToolError> {
        let Some(callbacks) = &self.callbacks else {
            return Err(FitToolError::CallbacksUnavailable);
        };
        let started = Instant::now();
        let raw = (callbacks.list_fits)().await;
        log::debug!(
            "[chat] list_user_fits: Dart callback returned in {}ms",
            started.elapsed().as_millis()
        );
        serde_json::from_str(&raw).map_err(|e| FitToolError::BadPayload(e.to_string()))
    }

    /// Load one of the user's fits by id, replacing the attached fit for
    /// subsequent tool calls (including within the same turn). If a
    /// concurrent replacement attached a newer fit while the callback was
    /// in flight, the stale response is dropped instead of overwriting the
    /// newer fit, and a [`FitToolError::Superseded`] error tells the model
    /// the requested fit is not attached.
    pub async fn load_fit(&self, fit_id: &str) -> Result<FitSummary, FitToolError> {
        let Some(callbacks) = &self.callbacks else {
            return Err(FitToolError::CallbacksUnavailable);
        };
        let ticket = self.begin_active_replacement();
        let started = Instant::now();
        let raw = (callbacks.load_fit)(fit_id.to_string()).await;
        log::debug!(
            "[chat] load_fit: Dart callback returned in {}ms",
            started.elapsed().as_millis()
        );
        let payload = parse_callback_fit_payload(&raw)?;
        let active = payload.into_active();
        // Summarize straight from the input snapshot (no engine pass needed).
        let summary = self.summarize(&active);
        if self.commit_active(ticket, active) {
            log::debug!(
                "[chat] load_fit: attached fit `{fit_id}` in {}ms",
                started.elapsed().as_millis()
            );
            return Ok(summary);
        }
        log::debug!(
            "[chat] load_fit: dropped stale callback response for `{fit_id}`; \
             a newer fit was attached while the load was in flight"
        );
        Err(FitToolError::Superseded(format!(
            "fit `{fit_id}` was loaded but is not the attached fit: a newer fit was attached \
             while the load was in flight; call get_current_fit to see the attached fit"
        )))
    }

    fn summarize(&self, fit: &ActiveFit) -> FitSummary {
        let input = &fit.container.fit;
        let modules = input
            .modules
            .iter()
            .map(|module| ModuleEntry {
                slot_type: item_slot_type_name(module.slot.slot_type),
                index: module.slot.index,
                item: fit.type_ref(module.item_id.as_type_id(&fit.container)),
                state: state_name(module.state),
                charge: module.charge.map(|charge| fit.type_ref(charge.type_id)),
            })
            .collect();

        let mut drones: Vec<DroneGroupEntry> = Vec::new();
        for drone in &input.drones {
            match drones.iter_mut().find(|group| {
                group.item.type_id == drone.type_id && group.state == state_name(drone.state)
            }) {
                Some(group) => group.count += 1,
                None => drones.push(DroneGroupEntry {
                    item: fit.type_ref(drone.type_id),
                    count: 1,
                    state: state_name(drone.state),
                }),
            }
        }

        let mut fighters: Vec<FighterGroupEntry> = Vec::new();
        for fighter in &input.fighters {
            let ability = fighter.ability.bits();
            match fighters
                .iter_mut()
                .find(|group| group.item.type_id == fighter.type_id && group.ability == ability)
            {
                Some(group) => group.count += 1,
                None => fighters.push(FighterGroupEntry {
                    item: fit.type_ref(fighter.type_id),
                    count: 1,
                    ability,
                }),
            }
        }

        let implants = input
            .implants
            .iter()
            .map(|implant| IndexedTypeRef {
                index: implant.index,
                item: fit.type_ref(implant.type_id),
            })
            .collect();
        let boosters = input
            .boosters
            .iter()
            .map(|booster| IndexedTypeRef {
                index: booster.index,
                item: fit.type_ref(booster.type_id),
            })
            .collect();

        FitSummary {
            name: fit.name.clone(),
            ship: fit.type_ref(input.ship_type_id),
            modules,
            drones,
            fighters,
            implants,
            boosters,
            skills: None,
        }
    }
}

/// Parse a `FitPayload` returned by an app callback, surfacing the app's
/// `{"error": ...}` envelope as an actionable error instead of a bare
/// deserialization failure.
fn parse_callback_fit_payload(raw: &str) -> Result<schema::FitPayload, FitToolError> {
    if let Ok(value) = serde_json::from_str::<serde_json::Value>(raw) {
        if let Some(error) = value.get("error").and_then(|e| e.as_str()) {
            return Err(FitToolError::BadPayload(error.to_string()));
        }
    }
    serde_json::from_str(raw).map_err(|e| FitToolError::BadPayload(format!("{e}; payload: {raw}")))
}

fn hull_attr(ship: &Ship, attribute_id: i32) -> Option<f64> {
    ship.hull
        .attributes
        .get(&attribute_id)
        .map(|attribute| attribute.value.unwrap_or(attribute.base_value))
}

fn select_item<'a>(
    ship: &'a Ship,
    section: &str,
    index: Option<usize>,
) -> Result<&'a Item, FitToolError> {
    let normalized = section.to_lowercase();
    let at =
        |len: usize, items: &mut dyn Iterator<Item = &'a Item>| -> Result<&'a Item, FitToolError> {
            let index = index.ok_or(FitToolError::IndexOutOfRange {
                section: normalized.clone(),
                index: usize::MAX,
                len,
            })?;
            items.nth(index).ok_or(FitToolError::IndexOutOfRange {
                section: normalized.clone(),
                index,
                len,
            })
        };
    match normalized.as_str() {
        "hull" | "ship" => Ok(&ship.hull),
        "character" => Ok(&ship.character),
        "module" => at(
            ship.modules
                .iter()
                .filter(|item| item.slot.is_module())
                .count(),
            &mut ship.modules.iter().filter(|item| item.slot.is_module()),
        ),
        "drone" => at(
            ship.modules
                .iter()
                .filter(|item| matches!(item.slot.slot_type, SlotType::DroneBay { .. }))
                .count(),
            &mut ship
                .modules
                .iter()
                .filter(|item| matches!(item.slot.slot_type, SlotType::DroneBay { .. })),
        ),
        "fighter" => at(
            ship.modules
                .iter()
                .filter(|item| matches!(item.slot.slot_type, SlotType::Fighter { .. }))
                .count(),
            &mut ship
                .modules
                .iter()
                .filter(|item| matches!(item.slot.slot_type, SlotType::Fighter { .. })),
        ),
        "implant" => at(ship.implants.len(), &mut ship.implants.iter()),
        "booster" => at(ship.boosters.len(), &mut ship.boosters.iter()),
        _ => Err(FitToolError::UnknownSection(section.to_string())),
    }
}

fn item_detail(fit: &ActiveFit, context: &FitToolContext, item: &Item) -> ItemDetail {
    let mut attributes: Vec<AttrValue> = item
        .attributes
        .iter()
        .map(|(id, attribute)| AttrValue {
            attribute_id: *id,
            name: context.attr_name(*id),
            base_value: attribute.base_value,
            value: attribute.value.unwrap_or(attribute.base_value),
        })
        .collect();
    attributes.sort_by_key(|attr| attr.attribute_id);
    ItemDetail {
        item: fit.type_ref(item.item_id.as_type_id(&fit.container)),
        section: slot_type_name(item.slot.slot_type),
        index: item.slot.index,
        state: effect_category_name(item.state),
        max_state: effect_category_name(item.max_state),
        charge: item
            .charge
            .as_ref()
            .map(|charge| fit.type_ref(charge.item_id.as_type_id(&fit.container))),
        attributes,
    }
}

fn attr_detail(
    fit: &ActiveFit,
    context: &FitToolContext,
    item: &Item,
    attribute_id: i32,
) -> Result<AttrDetail, FitToolError> {
    let attribute = item
        .attributes
        .get(&attribute_id)
        .ok_or(FitToolError::AttributeNotPresent(attribute_id))?;
    let meta = context.engine.dogma_attributes.get(&attribute_id);
    let modifiers = attribute
        .tracked_modifiers
        .borrow()
        .iter()
        .map(|tracker| {
            let (operator, penalized, source, source_attribute_id) = match tracker.source {
                eve_fit_os::calculate::item::ModifierSource::Effect(effect) => (
                    format!("{:?}", effect.operator),
                    effect.penalty,
                    object_source(effect.source),
                    Some(effect.source_attribute_id),
                ),
                eve_fit_os::calculate::item::ModifierSource::Buff { buff_id } => {
                    ("buff".to_string(), false, format!("buff({buff_id})"), None)
                }
            };
            ModifierEntry {
                operator,
                penalized,
                source,
                source_attribute_id,
                source_attribute_name: source_attribute_id.and_then(|id| context.attr_name(id)),
                original_value: tracker.original_value,
                normalized_value: tracker.normalized_value,
                penalized_value: tracker.penalized_value,
            }
        })
        .collect();
    let _ = fit;
    Ok(AttrDetail {
        attribute_id,
        name: context.attr_name(attribute_id),
        base_value: attribute.base_value,
        value: attribute.value.unwrap_or(attribute.base_value),
        default_value: meta.map(|meta| meta.default_value),
        high_is_good: meta.map(|meta| meta.high_is_good),
        modifiers,
    })
}

fn object_source(object: eve_fit_os::calculate::item::Object) -> String {
    use eve_fit_os::calculate::item::Object;
    match object {
        Object::Ship => "ship".to_string(),
        Object::Item(index) => format!("module[{index}]"),
        Object::Implant(index) => format!("implant[{index}]"),
        Object::Booster(index) => format!("booster[{index}]"),
        Object::Charge(index) => format!("charge[{index}]"),
        Object::Skill(index) => format!("skill[{index}]"),
        Object::Character => "character".to_string(),
        Object::Structure => "structure".to_string(),
        Object::Target => "target".to_string(),
    }
}

fn validation_issue_entry(issue: eve_fit_os::validate::ValidationIssue) -> ValidationIssueEntry {
    use eve_fit_os::validate::{
        ValidationErrorKey as E, ValidationIssueKind, ValidationWarningKey as W,
    };
    let slot_type = match issue.slot_type {
        eve_fit_os::validate::ValidationSlotType::High => "high",
        eve_fit_os::validate::ValidationSlotType::Medium => "medium",
        eve_fit_os::validate::ValidationSlotType::Low => "low",
        eve_fit_os::validate::ValidationSlotType::Rig => "rig",
        eve_fit_os::validate::ValidationSlotType::SubSystem => "subsystem",
        eve_fit_os::validate::ValidationSlotType::Service => "service",
        eve_fit_os::validate::ValidationSlotType::TacticalMode => "tactical_mode",
        eve_fit_os::validate::ValidationSlotType::Implant => "implant",
        eve_fit_os::validate::ValidationSlotType::Booster => "booster",
        eve_fit_os::validate::ValidationSlotType::Drone => "drone",
        eve_fit_os::validate::ValidationSlotType::Fighter => "fighter",
    }
    .to_string();
    let (severity, code, details) = match issue.kind {
        ValidationIssueKind::Error(E::IncompatibleChargeSize { expected, actual }) => (
            "error",
            "incompatible_charge_size",
            serde_json::json!({ "expected": expected, "actual": actual }),
        ),
        ValidationIssueKind::Error(E::IncompatibleChargeCapacity { max, actual }) => (
            "error",
            "incompatible_charge_capacity",
            serde_json::json!({ "max": max, "actual": actual }),
        ),
        ValidationIssueKind::Error(E::IncompatibleChargeGroup { expected, actual }) => (
            "error",
            "incompatible_charge_group",
            serde_json::json!({ "expected": expected, "actual": actual }),
        ),
        ValidationIssueKind::Error(E::TooMuchTurret { expected, actual }) => (
            "error",
            "too_much_turret",
            serde_json::json!({ "expected": expected, "actual": actual }),
        ),
        ValidationIssueKind::Error(E::TooMuchLauncher { expected, actual }) => (
            "error",
            "too_much_launcher",
            serde_json::json!({ "expected": expected, "actual": actual }),
        ),
        ValidationIssueKind::Error(E::ConflictItem { group_id }) => (
            "error",
            "conflict_item",
            serde_json::json!({ "group_id": group_id }),
        ),
        ValidationIssueKind::Error(E::DuplicateBooster { slot }) => (
            "error",
            "duplicate_booster",
            serde_json::json!({ "slot": slot }),
        ),
        ValidationIssueKind::Error(E::IncompatibleShipGroup { expected }) => (
            "error",
            "incompatible_ship_group",
            serde_json::json!({ "expected": expected }),
        ),
        ValidationIssueKind::Error(E::IncompatibleShipType { expected }) => (
            "error",
            "incompatible_ship_type",
            serde_json::json!({ "expected": expected }),
        ),
        ValidationIssueKind::Error(E::IncompatibleRigSize { expected, actual }) => (
            "error",
            "incompatible_rig_size",
            serde_json::json!({ "expected": expected, "actual": actual }),
        ),
        ValidationIssueKind::Warning(W::MissingCharge) => {
            ("warning", "missing_charge", serde_json::json!({}))
        }
    };
    ValidationIssueEntry {
        slot_type,
        index: issue.index,
        severity: severity.to_string(),
        code: code.to_string(),
        details,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use rig::tool::ToolErrorKind;

    #[test]
    fn fit_tool_errors_keep_actionable_model_feedback() {
        let cases = [
            (FitToolError::NoActiveFit, ToolErrorKind::NotFound),
            (
                FitToolError::UnknownSection("warp_core".to_string()),
                ToolErrorKind::InvalidArgs,
            ),
            (
                FitToolError::IndexOutOfRange {
                    section: "module".to_string(),
                    index: 9,
                    len: 3,
                },
                ToolErrorKind::InvalidArgs,
            ),
            (
                FitToolError::UnknownAttribute {
                    name: "foo".to_string(),
                    suggestions: "shieldCapacity".to_string(),
                },
                ToolErrorKind::InvalidArgs,
            ),
            (
                FitToolError::AttributeNotPresent(123),
                ToolErrorKind::InvalidArgs,
            ),
            (FitToolError::CallbacksUnavailable, ToolErrorKind::Other),
            (
                FitToolError::BadPayload("bad json".to_string()),
                ToolErrorKind::Other,
            ),
            (
                FitToolError::Superseded("superseded".to_string()),
                ToolErrorKind::Other,
            ),
        ];
        for (error, kind) in cases {
            let expected = error.to_string();
            let mapped = ToolExecutionError::from(error);
            assert_eq!(mapped.kind(), kind);
            // The message must reach the model verbatim, not rig's
            // redacted "the tool failed".
            assert_eq!(mapped.model_feedback(), Some(expected.as_str()));
        }
    }
}
