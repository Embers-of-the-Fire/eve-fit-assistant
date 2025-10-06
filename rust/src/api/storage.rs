use std::collections::HashMap;

use eve_fit_os::{
    calculate::item::FighterAbility,
    fit::{
        FitContainer, ItemBooster, ItemCharge, ItemDrone, ItemFighter, ItemFit, ItemImplant,
        ItemModule, ItemSlot, ItemSlotType, ItemState,
    },
};
use flutter_rust_bridge::frb;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum State {
    Passive,
    Online,
    Active,
    Overload,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SlotType {
    High,
    Medium,
    Low,
    Rig,
    SubSystem,
    Service,
    TacticalMode,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Charge {
    pub type_id: i32,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Slot {
    pub slot_type: SlotType,
    pub index: i32,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Module {
    pub item_id: ItemID,
    pub slot: Slot,
    pub state: State,
    pub charge: Option<Charge>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ItemID {
    Item(i32),
    Dynamic(i32),
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Drone {
    pub type_id: i32,
    pub group_id: u8,
    pub state: State,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Fighter {
    pub type_id: i32,
    pub group_id: u8,
    pub ability: u8,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Implant {
    pub type_id: i32,
    pub index: i32,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Booster {
    pub type_id: i32,
    pub index: i32,
}

#[derive(Debug, Clone, PartialEq)]
pub struct Fit {
    pub ship_type_id: i32,
    pub damage_profile: DamageProfile,
    pub modules: Vec<Module>,
    pub drones: Vec<Drone>,
    pub fighters: Vec<Fighter>,
    pub implants: Vec<Implant>,
    pub boosters: Vec<Booster>,
}

pub struct FitStorage {
    container: FitContainer,
}

#[derive(Debug, Clone, PartialEq)]
pub struct DynamicItem {
    pub base_type: i32,
    /// attr key, factor
    pub dynamic_attributes: HashMap<i32, f64>,
}

impl DynamicItem {
    fn into_native(self) -> eve_fit_os::fit::DynamicItem {
        eve_fit_os::fit::DynamicItem {
            base_type: self.base_type,
            dynamic_attributes: self.dynamic_attributes,
        }
    }
}

impl FitStorage {
    #[frb(sync)]
    pub fn new(
        fit: Fit,
        skills: HashMap<i32, u8>,
        dynamic_items: HashMap<i32, DynamicItem>,
    ) -> Self {
        Self {
            container: FitContainer {
                fit: fit.into_native(),
                skills,
                dynamic: dynamic_items
                    .into_iter()
                    .map(|(k, v)| (k, v.into_native()))
                    .collect(),
            },
        }
    }

    pub(crate) fn get_container(&self) -> &FitContainer {
        &self.container
    }
}

impl State {
    pub(crate) fn into_native(self) -> ItemState {
        match self {
            State::Passive => ItemState::Passive,
            State::Online => ItemState::Online,
            State::Active => ItemState::Active,
            State::Overload => ItemState::Overload,
        }
    }
}

impl SlotType {
    pub(crate) fn into_native(self) -> ItemSlotType {
        match self {
            SlotType::High => ItemSlotType::High,
            SlotType::Medium => ItemSlotType::Medium,
            SlotType::Low => ItemSlotType::Low,
            SlotType::Rig => ItemSlotType::Rig,
            SlotType::SubSystem => ItemSlotType::SubSystem,
            SlotType::Service => ItemSlotType::Service,
            SlotType::TacticalMode => ItemSlotType::TacticalMode,
        }
    }
}

impl Charge {
    pub(crate) fn into_native(self) -> ItemCharge {
        ItemCharge {
            type_id: self.type_id,
        }
    }
}

impl Slot {
    pub(crate) fn into_native(self) -> ItemSlot {
        ItemSlot {
            slot_type: self.slot_type.into_native(),
            index: self.index,
        }
    }

    pub(crate) fn from_native(native: ItemSlot) -> Self {
        Self {
            slot_type: match native.slot_type {
                ItemSlotType::High => SlotType::High,
                ItemSlotType::Medium => SlotType::Medium,
                ItemSlotType::Low => SlotType::Low,
                ItemSlotType::Rig => SlotType::Rig,
                ItemSlotType::SubSystem => SlotType::SubSystem,
                ItemSlotType::Service => SlotType::Service,
                ItemSlotType::TacticalMode => SlotType::TacticalMode,
            },
            index: native.index,
        }
    }
}

impl Module {
    pub(crate) fn into_native(self) -> ItemModule {
        ItemModule {
            item_id: self.item_id.into_native(),
            slot: self.slot.into_native(),
            state: self.state.into_native(),
            charge: self.charge.map(|c| c.into_native()),
        }
    }
}

impl ItemID {
    pub(crate) fn into_native(self) -> eve_fit_os::calculate::item::ItemID {
        match self {
            ItemID::Item(id) => eve_fit_os::calculate::item::ItemID::Item(id),
            ItemID::Dynamic(id) => eve_fit_os::calculate::item::ItemID::Dynamic(id),
        }
    }
}

impl Drone {
    pub(crate) fn into_native(self) -> ItemDrone {
        ItemDrone {
            type_id: self.type_id,
            group_id: self.group_id,
            state: self.state.into_native(),
        }
    }
}

impl Fighter {
    pub(crate) fn into_native(self) -> ItemFighter {
        ItemFighter {
            type_id: self.type_id,
            group_id: self.group_id,
            ability: FighterAbility::from_bits_truncate(self.ability),
        }
    }
}

impl Implant {
    pub(crate) fn into_native(self) -> ItemImplant {
        ItemImplant {
            type_id: self.type_id,
            index: self.index,
        }
    }
}

impl Booster {
    pub(crate) fn into_native(self) -> ItemBooster {
        ItemBooster {
            type_id: self.type_id,
            index: self.index,
        }
    }
}

impl Fit {
    pub(crate) fn into_native(self) -> ItemFit {
        ItemFit {
            ship_type_id: self.ship_type_id,
            damage_profile: self.damage_profile.into_native(),
            modules: self.modules.into_iter().map(|m| m.into_native()).collect(),
            drones: self.drones.into_iter().map(|d| d.into_native()).collect(),
            fighters: self.fighters.into_iter().map(|f| f.into_native()).collect(),
            implants: self.implants.into_iter().map(|i| i.into_native()).collect(),
            boosters: self.boosters.into_iter().map(|b| b.into_native()).collect(),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct DamageProfile {
    pub em: f64,
    pub explosive: f64,
    pub kinetic: f64,
    pub thermal: f64,
}

impl DamageProfile {
    pub(crate) fn into_native(self) -> eve_fit_os::calculate::DamageProfile {
        eve_fit_os::calculate::DamageProfile {
            em: self.em,
            explosive: self.explosive,
            kinetic: self.kinetic,
            thermal: self.thermal,
        }
    }

    pub(crate) fn from_native(native: eve_fit_os::calculate::DamageProfile) -> Self {
        Self {
            em: native.em,
            explosive: native.explosive,
            kinetic: native.kinetic,
            thermal: native.thermal,
        }
    }
}
