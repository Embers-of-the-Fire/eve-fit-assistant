use std::collections::HashMap;

use eve_fit_os::calculate::item::FighterAbility;
use eve_fit_os::fit::{
    DynamicItem, FitContainer, ItemBooster, ItemCharge, ItemDrone, ItemFighter, ItemFit,
    ItemImplant, ItemModule, ItemSlot, ItemSlotType, ItemState,
};
use serde::Deserialize;

use super::{ActiveFit, FitToolError};

/// A fit payload as pushed from the app (mirrors the bridge `Fit` DTOs in
/// JSON form), used by the `load_fit` tool to switch the attached fit
/// mid-conversation.
#[derive(Debug, Deserialize)]
pub struct FitPayload {
    #[serde(default)]
    pub name: Option<String>,
    /// The saved fit's id; only the `create_fit` callback includes it.
    #[serde(default)]
    pub fit_id: Option<String>,
    #[serde(default)]
    pub names: HashMap<i32, String>,
    pub fit: FitDto,
    #[serde(default)]
    pub skills: HashMap<i32, u8>,
    #[serde(default)]
    pub dynamic_items: HashMap<i32, DynamicItemDto>,
}

#[derive(Debug, Deserialize)]
pub struct FitDto {
    pub ship_type_id: i32,
    pub damage_profile: DamageProfileDto,
    #[serde(default)]
    pub modules: Vec<ModuleDto>,
    #[serde(default)]
    pub drones: Vec<DroneDto>,
    #[serde(default)]
    pub fighters: Vec<FighterDto>,
    #[serde(default)]
    pub implants: Vec<ImplantDto>,
    #[serde(default)]
    pub boosters: Vec<BoosterDto>,
}

#[derive(Debug, Deserialize)]
pub struct DamageProfileDto {
    pub em: f64,
    pub explosive: f64,
    pub kinetic: f64,
    pub thermal: f64,
}

#[derive(Debug, Deserialize)]
pub struct ModuleDto {
    pub item_id: ItemIdDto,
    pub slot: SlotDto,
    pub state: StateDto,
    #[serde(default)]
    pub charge: Option<ChargeDto>,
    #[serde(default)]
    pub damage_turns: u32,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ItemIdDto {
    Item(i32),
    Dynamic(i32),
}

#[derive(Debug, Deserialize)]
pub struct SlotDto {
    pub slot_type: SlotTypeDto,
    pub index: i32,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SlotTypeDto {
    High,
    Medium,
    Low,
    Rig,
    Subsystem,
    Service,
    TacticalMode,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum StateDto {
    Passive,
    Online,
    Active,
    Overload,
}

#[derive(Debug, Deserialize)]
pub struct ChargeDto {
    pub type_id: i32,
}

#[derive(Debug, Deserialize)]
pub struct DroneDto {
    pub item_id: ItemIdDto,
    pub group_id: u8,
    pub state: StateDto,
}

#[derive(Debug, Deserialize)]
pub struct FighterDto {
    pub type_id: i32,
    pub group_id: u8,
    pub ability: u8,
}

#[derive(Debug, Deserialize)]
pub struct ImplantDto {
    pub type_id: i32,
    pub index: i32,
}

#[derive(Debug, Deserialize)]
pub struct BoosterDto {
    pub type_id: i32,
    pub index: i32,
}

#[derive(Debug, Deserialize)]
pub struct DynamicItemDto {
    pub base_type: i32,
    #[serde(default)]
    pub dynamic_attributes: HashMap<i32, f64>,
}

impl FitPayload {
    pub fn into_active(self) -> Result<ActiveFit, FitToolError> {
        // A drone referencing a dynamic item missing from `dynamic_items`
        // would panic later in `ItemID::as_type_id`, whose
        // `FitContainer::get_dynamic_item_base_type_id` lookup unwraps;
        // reject the dangling reference here instead.
        for drone in &self.fit.drones {
            if let ItemIdDto::Dynamic(id) = &drone.item_id {
                if !self.dynamic_items.contains_key(id) {
                    return Err(FitToolError::BadPayload(format!(
                        "drone references unknown dynamic item {id}"
                    )));
                }
            }
        }
        Ok(ActiveFit {
            name: self.name,
            container: FitContainer::new(
                self.fit.into_native(),
                self.skills,
                self.dynamic_items
                    .into_iter()
                    .map(|(id, item)| {
                        (
                            id,
                            DynamicItem {
                                base_type: item.base_type,
                                dynamic_attributes: item.dynamic_attributes,
                            },
                        )
                    })
                    .collect(),
            ),
            names: self.names,
        })
    }
}

impl FitDto {
    fn into_native(self) -> ItemFit {
        ItemFit {
            ship_type_id: self.ship_type_id,
            damage_profile: eve_fit_os::calculate::DamageProfile {
                em: self.damage_profile.em,
                explosive: self.damage_profile.explosive,
                kinetic: self.damage_profile.kinetic,
                thermal: self.damage_profile.thermal,
            },
            modules: self.modules.into_iter().map(|m| m.into_native()).collect(),
            drones: self.drones.into_iter().map(|d| d.into_native()).collect(),
            fighters: self.fighters.into_iter().map(|f| f.into_native()).collect(),
            implants: self.implants.into_iter().map(|i| i.into_native()).collect(),
            boosters: self.boosters.into_iter().map(|b| b.into_native()).collect(),
        }
    }
}

impl ModuleDto {
    fn into_native(self) -> ItemModule {
        ItemModule {
            item_id: match self.item_id {
                ItemIdDto::Item(id) => eve_fit_os::calculate::item::ItemID::Item(id),
                ItemIdDto::Dynamic(id) => eve_fit_os::calculate::item::ItemID::Dynamic(id),
            },
            slot: ItemSlot {
                slot_type: match self.slot.slot_type {
                    SlotTypeDto::High => ItemSlotType::High,
                    SlotTypeDto::Medium => ItemSlotType::Medium,
                    SlotTypeDto::Low => ItemSlotType::Low,
                    SlotTypeDto::Rig => ItemSlotType::Rig,
                    SlotTypeDto::Subsystem => ItemSlotType::SubSystem,
                    SlotTypeDto::Service => ItemSlotType::Service,
                    SlotTypeDto::TacticalMode => ItemSlotType::TacticalMode,
                },
                index: self.slot.index,
            },
            state: match self.state {
                StateDto::Passive => ItemState::Passive,
                StateDto::Online => ItemState::Online,
                StateDto::Active => ItemState::Active,
                StateDto::Overload => ItemState::Overload,
            },
            charge: self.charge.map(|charge| ItemCharge {
                type_id: charge.type_id,
            }),
            damage_turns: self.damage_turns,
        }
    }
}

impl DroneDto {
    fn into_native(self) -> ItemDrone {
        ItemDrone {
            item_id: match self.item_id {
                ItemIdDto::Item(id) => eve_fit_os::calculate::item::ItemID::Item(id),
                ItemIdDto::Dynamic(id) => eve_fit_os::calculate::item::ItemID::Dynamic(id),
            },
            group_id: self.group_id,
            state: match self.state {
                StateDto::Passive => ItemState::Passive,
                StateDto::Online => ItemState::Online,
                StateDto::Active => ItemState::Active,
                StateDto::Overload => ItemState::Overload,
            },
        }
    }
}

impl FighterDto {
    fn into_native(self) -> ItemFighter {
        ItemFighter {
            type_id: self.type_id,
            group_id: self.group_id,
            ability: FighterAbility::from_bits_truncate(self.ability),
        }
    }
}

impl ImplantDto {
    fn into_native(self) -> ItemImplant {
        ItemImplant {
            type_id: self.type_id,
            index: self.index,
        }
    }
}

impl BoosterDto {
    fn into_native(self) -> ItemBooster {
        ItemBooster {
            type_id: self.type_id,
            index: self.index,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn payload_with_drone(item_id: ItemIdDto) -> FitPayload {
        FitPayload {
            name: None,
            fit_id: None,
            names: HashMap::new(),
            fit: FitDto {
                ship_type_id: 587,
                damage_profile: DamageProfileDto {
                    em: 0.0,
                    explosive: 0.0,
                    kinetic: 0.0,
                    thermal: 0.0,
                },
                modules: vec![],
                drones: vec![DroneDto {
                    item_id,
                    group_id: 0,
                    state: StateDto::Active,
                }],
                fighters: vec![],
                implants: vec![],
                boosters: vec![],
            },
            skills: HashMap::new(),
            dynamic_items: HashMap::new(),
        }
    }

    #[test]
    fn into_active_rejects_drone_with_missing_dynamic_item() {
        // Regression: a drone referencing a dynamic item absent from
        // `dynamic_items` must not reach `ItemID::as_type_id`, whose
        // `get_dynamic_item_base_type_id` lookup unwraps and panics.
        let err = payload_with_drone(ItemIdDto::Dynamic(7))
            .into_active()
            .unwrap_err();
        assert!(matches!(err, FitToolError::BadPayload(_)));
        assert_eq!(
            err.to_string(),
            "invalid payload from the app: drone references unknown dynamic item 7"
        );
    }

    #[test]
    fn into_active_accepts_drone_with_known_dynamic_item() {
        let mut payload = payload_with_drone(ItemIdDto::Dynamic(7));
        payload.dynamic_items.insert(
            7,
            DynamicItemDto {
                base_type: 2456,
                dynamic_attributes: HashMap::new(),
            },
        );
        let active = payload.into_active().unwrap();
        assert_eq!(
            active.container.dynamic.get(&7).map(|item| item.base_type),
            Some(2456)
        );
    }
}
