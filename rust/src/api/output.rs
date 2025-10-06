use std::collections::HashMap;

use crate::api::storage::{DamageProfile, ItemID};

#[derive(Debug, Clone)]
pub struct Item {
    pub item_id: ItemID,
    pub slot: OutSlot,
    pub charge: Option<Box<Item>>,
    pub attributes: HashMap<i32, Attribute>,
    pub effects: Vec<i32>,
}

#[derive(Debug, Copy, Clone, PartialEq, Eq)]
pub enum OutSlotType {
    High,
    Medium,
    Low,
    Rig,
    SubSystem,
    Service,
    TacticalMode,
    DroneBay { group_id: u8 },
    Fighter { group_id: u8, ability: u8 },
    Charge,
    Implant,
    Booster,
    Fake,
}

impl OutSlotType {
    pub(crate) fn from_native(native: eve_fit_os::calculate::item::SlotType) -> Self {
        match native {
            eve_fit_os::calculate::item::SlotType::High => OutSlotType::High,
            eve_fit_os::calculate::item::SlotType::Medium => OutSlotType::Medium,
            eve_fit_os::calculate::item::SlotType::Low => OutSlotType::Low,
            eve_fit_os::calculate::item::SlotType::Rig => OutSlotType::Rig,
            eve_fit_os::calculate::item::SlotType::SubSystem => OutSlotType::SubSystem,
            eve_fit_os::calculate::item::SlotType::Service => OutSlotType::Service,
            eve_fit_os::calculate::item::SlotType::TacticalMode => OutSlotType::TacticalMode,
            eve_fit_os::calculate::item::SlotType::DroneBay { group_id } => {
                OutSlotType::DroneBay { group_id }
            }
            eve_fit_os::calculate::item::SlotType::Fighter { group_id, ability } => {
                OutSlotType::Fighter {
                    group_id,
                    ability: ability.bits(),
                }
            }
            eve_fit_os::calculate::item::SlotType::Charge => OutSlotType::Charge,
            eve_fit_os::calculate::item::SlotType::Implant => OutSlotType::Implant,
            eve_fit_os::calculate::item::SlotType::Booster => OutSlotType::Booster,
            eve_fit_os::calculate::item::SlotType::Fake => OutSlotType::Fake,
        }
    }
}

#[derive(Debug, Copy, Clone, PartialEq, Eq)]
pub struct OutSlot {
    pub slot_type: OutSlotType,
    pub index: Option<i32>,
}

impl OutSlot {
    pub(crate) fn from_native(native: eve_fit_os::calculate::item::Slot) -> Self {
        Self {
            slot_type: OutSlotType::from_native(native.slot_type),
            index: native.index,
        }
    }
}

impl Item {
    pub(crate) fn from_native(native: eve_fit_os::calculate::item::Item) -> Self {
        Self {
            item_id: match native.item_id {
                eve_fit_os::calculate::item::ItemID::Item(id) => ItemID::Item(id),
                eve_fit_os::calculate::item::ItemID::Dynamic(id) => ItemID::Dynamic(id),
            },
            slot: OutSlot::from_native(native.slot),
            charge: native.charge.map(|c| Box::new(Item::from_native(*c))),
            attributes: native
                .attributes
                .into_iter()
                .map(|(k, v)| (k, Attribute::from_native(v)))
                .collect(),
            effects: native.effects.clone(),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum EffectOperator {
    PreAssign,
    PreMul,
    PreDiv,
    ModAdd,
    ModSub,
    PostMul,
    PostDiv,
    PostPercent,
    PostAssign,
}

impl EffectOperator {
    pub(crate) fn from_native(native: eve_fit_os::calculate::item::EffectOperator) -> Self {
        match native {
            eve_fit_os::calculate::item::EffectOperator::PreAssign => EffectOperator::PreAssign,
            eve_fit_os::calculate::item::EffectOperator::PreMul => EffectOperator::PreMul,
            eve_fit_os::calculate::item::EffectOperator::PreDiv => EffectOperator::PreDiv,
            eve_fit_os::calculate::item::EffectOperator::ModAdd => EffectOperator::ModAdd,
            eve_fit_os::calculate::item::EffectOperator::ModSub => EffectOperator::ModSub,
            eve_fit_os::calculate::item::EffectOperator::PostMul => EffectOperator::PostMul,
            eve_fit_os::calculate::item::EffectOperator::PostDiv => EffectOperator::PostDiv,
            eve_fit_os::calculate::item::EffectOperator::PostPercent => EffectOperator::PostPercent,
            eve_fit_os::calculate::item::EffectOperator::PostAssign => EffectOperator::PostAssign,
        }
    }
}

#[derive(Debug, Copy, Clone, PartialEq, Eq)]
pub enum FitObject {
    Ship,
    Item(usize),
    Implant(usize),
    Booster(usize),
    Charge(usize),
    Skill(usize),
    Character,
    Structure,
    Target,
}

impl FitObject {
    pub(crate) fn from_native(native: eve_fit_os::calculate::item::Object) -> Self {
        match native {
            eve_fit_os::calculate::item::Object::Ship => FitObject::Ship,
            eve_fit_os::calculate::item::Object::Item(idx) => FitObject::Item(idx),
            eve_fit_os::calculate::item::Object::Implant(idx) => FitObject::Implant(idx),
            eve_fit_os::calculate::item::Object::Booster(idx) => FitObject::Booster(idx),
            eve_fit_os::calculate::item::Object::Charge(idx) => FitObject::Charge(idx),
            eve_fit_os::calculate::item::Object::Skill(idx) => FitObject::Skill(idx),
            eve_fit_os::calculate::item::Object::Character => FitObject::Character,
            eve_fit_os::calculate::item::Object::Structure => FitObject::Structure,
            eve_fit_os::calculate::item::Object::Target => FitObject::Target,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub enum EffectCategory {
    Passive,
    Online,
    Active,
    Overload,
    Target,
    Area,
    Dungeon,
    System,
}

impl EffectCategory {
    pub(crate) fn from_native(native: eve_fit_os::calculate::item::EffectCategory) -> Self {
        match native {
            eve_fit_os::calculate::item::EffectCategory::Passive => EffectCategory::Passive,
            eve_fit_os::calculate::item::EffectCategory::Online => EffectCategory::Online,
            eve_fit_os::calculate::item::EffectCategory::Active => EffectCategory::Active,
            eve_fit_os::calculate::item::EffectCategory::Overload => EffectCategory::Overload,
            eve_fit_os::calculate::item::EffectCategory::Target => EffectCategory::Target,
            eve_fit_os::calculate::item::EffectCategory::Area => EffectCategory::Area,
            eve_fit_os::calculate::item::EffectCategory::Dungeon => EffectCategory::Dungeon,
            eve_fit_os::calculate::item::EffectCategory::System => EffectCategory::System,
        }
    }
}

#[derive(Debug, Clone, Copy)]
pub struct Effect {
    pub operator: EffectOperator,
    pub penalty: bool,
    pub source: FitObject,
    pub source_category: EffectCategory,
    pub source_attribute_id: i32,
}

impl Effect {
    pub(crate) fn from_native(native: eve_fit_os::calculate::item::Effect) -> Self {
        Self {
            operator: EffectOperator::from_native(native.operator),
            penalty: native.penalty,
            source: FitObject::from_native(native.source),
            source_category: EffectCategory::from_native(native.source_category),
            source_attribute_id: native.source_attribute_id,
        }
    }
}

#[derive(Debug, Clone)]
pub struct Attribute {
    pub base_value: f64,
    pub value: Option<f64>,
    pub buffs: Vec<i32>,
    pub tracked_modifiers: Vec<ModifierTracker>,
}

impl Attribute {
    pub(crate) fn from_native(native: eve_fit_os::calculate::item::Attribute) -> Self {
        Self {
            base_value: native.base_value,
            value: native.value,
            buffs: native.buffs.clone(),
            tracked_modifiers: native
                .tracked_modifiers
                .borrow()
                .iter()
                .map(|m| ModifierTracker::from_native(*m))
                .collect(),
        }
    }
}

#[derive(Debug, Clone, Copy)]
pub enum ModifierSource {
    Effect(Effect),
    Buff { buff_id: i32 },
}

impl ModifierSource {
    pub(crate) fn from_native(native: eve_fit_os::calculate::item::ModifierSource) -> Self {
        match native {
            eve_fit_os::calculate::item::ModifierSource::Effect(effect) => {
                ModifierSource::Effect(Effect::from_native(effect))
            }
            eve_fit_os::calculate::item::ModifierSource::Buff { buff_id } => {
                ModifierSource::Buff { buff_id }
            }
        }
    }
}

#[derive(Debug, Clone, Copy)]
pub struct ModifierTracker {
    pub source: ModifierSource,
    pub original_value: f64,
    pub normalized_value: f64,
    pub penalized_value: f64,
}

impl ModifierTracker {
    pub(crate) fn from_native(native: eve_fit_os::calculate::item::ModifierTracker) -> Self {
        Self {
            source: ModifierSource::from_native(native.source),
            original_value: native.original_value,
            normalized_value: native.normalized_value,
            penalized_value: native.penalized_value,
        }
    }
}

#[derive(Debug, Clone)]
pub struct Ship {
    pub hull: Item,
    pub modules: Vec<Item>,
    pub skills: Vec<Item>,
    pub implants: Vec<Item>,
    pub boosters: Vec<Item>,
    pub character: Item,
    pub damage_profile: DamageProfile,

    // not implemented yet
    pub structure: Item,
    pub target: Item,
}

impl Ship {
    pub(crate) fn from_native(native: eve_fit_os::calculate::Ship) -> Self {
        Self {
            hull: Item::from_native(native.hull),
            modules: native.modules.into_iter().map(Item::from_native).collect(),
            skills: native.skills.into_iter().map(Item::from_native).collect(),
            implants: native.implants.into_iter().map(Item::from_native).collect(),
            boosters: native.boosters.into_iter().map(Item::from_native).collect(),
            character: Item::from_native(native.character),
            damage_profile: DamageProfile::from_native(native.damage_profile),
            structure: Item::from_native(native.structure),
            target: Item::from_native(native.target),
        }
    }
}
