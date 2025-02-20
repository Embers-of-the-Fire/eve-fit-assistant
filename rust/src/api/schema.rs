use std::{collections::HashMap, iter};

#[flutter_rust_bridge::frb(unignore, non_opaque)]
#[derive(Debug, Clone)]
pub struct Fit {
    pub ship_id: i32,
    pub modules: Module,
    pub drones: Vec<DroneGroup>,
    pub implant: Vec<Implant>,
    pub skills: HashMap<i32, u8>,
    pub damage_profile: DamageProfile,
}

impl Fit {
    #[flutter_rust_bridge::frb(ignore)]
    pub(crate) fn into_native(self) -> eve_fit_os::fit::FitContainer {
        use eve_fit_os::fit::{
            ItemCharge, ItemDrone, ItemFit, ItemImplant, ItemModule, ItemSlot, ItemSlotType,
            ItemState,
        };

        let skills = self.skills;

        let fit = ItemFit {
            ship_type_id: self.ship_id,
            modules: [
                (self.modules.high, ItemSlotType::High),
                (self.modules.medium, ItemSlotType::Medium),
                (self.modules.low, ItemSlotType::Low),
                (self.modules.rig, ItemSlotType::Rig),
                (self.modules.subsystem, ItemSlotType::SubSystem),
            ]
            .into_iter()
            .flat_map(|(a, b)| a.into_iter().map(move |k| (k, b)))
            .chain(
                self.modules
                    .tactical_mode
                    .into_iter()
                    .map(|t| (t, ItemSlotType::TacticalMode)),
            )
            .map(|(item, slot)| ItemModule {
                type_id: item.item_id,
                slot: ItemSlot {
                    slot_type: slot,
                    index: item.index,
                },
                state: item.state.into(),
                charge: item.charge.map(|c| ItemCharge { type_id: c }),
            })
            .collect(),
            drones: self
                .drones
                .into_iter()
                .flat_map(|drone| {
                    iter::repeat_n(
                        ItemDrone {
                            group_id: drone.index,
                            type_id: drone.item_id,
                            state: ItemState::Active,
                        },
                        drone.amount as usize,
                    )
                })
                .collect(),
            implants: self
                .implant
                .into_iter()
                .enumerate()
                .map(|(idx, imp)| ItemImplant {
                    type_id: imp.item_id,
                    index: idx as i32,
                })
                .collect(),
            damage_profile: eve_fit_os::calculate::DamageProfile {
                em: self.damage_profile.em,
                explosive: self.damage_profile.explosive,
                kinetic: self.damage_profile.kinetic,
                thermal: self.damage_profile.thermal,
            },
        };

        eve_fit_os::fit::FitContainer::new(fit, skills)
    }
}

#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Module {
    pub high: Vec<Item>,
    pub medium: Vec<Item>,
    pub low: Vec<Item>,
    pub rig: Vec<Item>,
    pub subsystem: Vec<Item>,
    pub tactical_mode: Option<Item>,
}

#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Item {
    pub item_id: i32,
    pub charge: Option<i32>,
    pub state: ItemState,
    pub index: i32,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ItemState {
    Passive,
    Online,
    Active,
    Overload,
}

#[flutter_rust_bridge::frb(ignore)]
impl From<ItemState> for eve_fit_os::fit::ItemState {
    fn from(state: ItemState) -> Self {
        match state {
            ItemState::Passive => eve_fit_os::fit::ItemState::Passive,
            ItemState::Online => eve_fit_os::fit::ItemState::Online,
            ItemState::Active => eve_fit_os::fit::ItemState::Active,
            ItemState::Overload => eve_fit_os::fit::ItemState::Overload,
        }
    }
}

#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct DroneGroup {
    pub item_id: i32,
    pub amount: i32,
    pub index: u8,
}

#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Implant {
    pub item_id: i32,
    pub index: i32,
}

#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone, Copy)]
pub struct DamageProfile {
    pub em: f64,
    pub explosive: f64,
    pub kinetic: f64,
    pub thermal: f64,
}
